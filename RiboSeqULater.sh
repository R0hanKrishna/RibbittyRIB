#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"
TOTAL_STEPS=1

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Run the full RiboSeqULater analysis pipeline.

Required:
  -m, --mode          SE or PE (single-end or paired-end)
  -1, --read1         Input FASTQ file (or R1 for PE)

Optional:
  -2, --read2         R2 input FASTQ file (PE only)
  -a, --adapter       3' adapter sequence [default: TGGAATTCTCGGGTGCCAAGG]
  -A, --adapter2      5' adapter for R2 (PE only) [default: AGATCGGAAGAGCGTCGTGTAGGGAAAGA]
  -q, --quality       3' quality cutoff [default: 20]
  -l, --min-length    Minimum insert length to keep [default: 16]
  -o, --outdir        Output directory [default: <input_name>_output/]
  -p, --pair-adapters Require both adapters in PE mode (flag, no value needed)
  -h, --help          Show this help message
EOF
    exit 1
}

# --- Defaults ---
MODE=""
READ1=""
READ2=""
ADAPTER_3="TGGAATTCTCGGGTGCCAAGG"
ADAPTER_5="AGATCGGAAGAGCGTCGTGTAGGGAAAGA"
QUALITY=20
MIN_LENGTH=16
OUTDIR=""
PAIR_ADAPTERS=false

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)          MODE="${2^^}"; shift 2 ;;
        -1|--read1)         READ1="$2"; shift 2 ;;
        -2|--read2)         READ2="$2"; shift 2 ;;
        -a|--adapter)       ADAPTER_3="$2"; shift 2 ;;
        -A|--adapter2)      ADAPTER_5="$2"; shift 2 ;;
        -q|--quality)       QUALITY="$2"; shift 2 ;;
        -l|--min-length)    MIN_LENGTH="$2"; shift 2 ;;
        -o|--outdir)        OUTDIR="$2"; shift 2 ;;
        -p|--pair-adapters) PAIR_ADAPTERS=true; shift ;;
        -h|--help)          usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# --- Validate ---
[[ -z "$MODE" ]]  && { echo "Error: --mode is required."; usage; }
[[ -z "$READ1" ]] && { echo "Error: --read1 is required."; usage; }

# --- Derive output directory from input filename if not set ---
if [[ -z "$OUTDIR" ]]; then
    base=$(basename "$READ1")
    base="${base%.fastq.gz}"
    base="${base%.fastq}"
    OUTDIR="${base}_output"
fi

# --- Record pipeline start time ---
PIPELINE_START=$(date +%s)

# --- Setup output and log directories ---
LOG_DIR="$OUTDIR/logs"
TRIM_DIR="$OUTDIR/01_trimmed"
mkdir -p "$LOG_DIR" "$TRIM_DIR"

# --- Progress helpers ---
CURRENT_STEP=0

progress_bar() {
    local step=$1
    local total=$2
    local filled=$(( step * 20 / total ))
    local empty=$(( 20 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="#"; done
    for ((i=0; i<empty; i++)); do bar+="-"; done
    printf "[%s] %d/%d\n" "$bar" "$step" "$total"
}

step_start() {
    local name=$1
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    echo ""
    echo "=========================================="
    printf " Step %d/%d: %s\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$name"
    progress_bar "$CURRENT_STEP" "$TOTAL_STEPS"
    echo "=========================================="
}

step_done() {
    local logfile=$1
    echo "  Done. Log: $logfile"
}

# --- Spinner (runs in background while a step executes) ---
spinner() {
    local pid=$1
    local delay=0.1
    local frames=('|' '/' '-' '\')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  Running... %s" "${frames[i]}"
        i=$(( (i+1) % 4 ))
        sleep "$delay"
    done
    printf "\r                \r"
}

run_step() {
    local name=$1
    local logfile=$2
    shift 2

    step_start "$name"

    # Run step, tee output to log, show spinner
    ("$@" 2>&1 | tee "$logfile") &
    local pid=$!
    spinner "$pid"
    wait "$pid"

    step_done "$logfile"
}

# ============================================================
# Step 1: Trim adapters
# ============================================================
PAIR_FLAG=""
[[ "$PAIR_ADAPTERS" == true ]] && PAIR_FLAG="-p"

TRIM_ARGS=(
    -m "$MODE"
    -1 "$READ1"
    -a "$ADAPTER_3"
    -q "$QUALITY"
    -l "$MIN_LENGTH"
    -o "$TRIM_DIR"
)
[[ -n "$READ2" ]]      && TRIM_ARGS+=(-2 "$READ2")
[[ -n "$PAIR_FLAG" ]]  && TRIM_ARGS+=("$PAIR_FLAG")
[[ "$MODE" == "PE" ]]  && TRIM_ARGS+=(-A "$ADAPTER_5")

run_step "Trimming adapters" "$LOG_DIR/01_trim_adapters.log" \
    bash "$SCRIPTS_DIR/01_trim_adapters.sh" "${TRIM_ARGS[@]}"

# ============================================================
# Add future steps here, passing trimmed output as input
# ============================================================

PIPELINE_END=$(date +%s)
ELAPSED=$(( PIPELINE_END - PIPELINE_START ))
HOURS=$(( ELAPSED / 3600 ))
MINUTES=$(( (ELAPSED % 3600) / 60 ))
SECONDS=$(( ELAPSED % 60 ))

echo ""
echo "=========================================="
echo " Pipeline complete!"
printf " Total time : %02dh %02dm %02ds\n" "$HOURS" "$MINUTES" "$SECONDS"
echo " Results    : $OUTDIR"
echo " Logs       : $LOG_DIR"
echo "=========================================="
