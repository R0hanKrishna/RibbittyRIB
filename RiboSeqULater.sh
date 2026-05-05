#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"

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
  -o, --outdir        Output directory [default: results/]
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
OUTDIR="results"
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

# --- Output subdirectories ---
TRIM_DIR="$OUTDIR/01_trimmed"
mkdir -p "$TRIM_DIR"

PAIR_FLAG=""
[[ "$PAIR_ADAPTERS" == true ]] && PAIR_FLAG="-p"

# ============================================================
# Step 1: Trim adapters
# ============================================================
echo ""
echo "=========================================="
echo " Step 1: Trimming adapters"
echo "=========================================="

TRIM_ARGS=(
    -m "$MODE"
    -1 "$READ1"
    -a "$ADAPTER_3"
    -q "$QUALITY"
    -l "$MIN_LENGTH"
    -o "$TRIM_DIR"
)
[[ -n "$READ2" ]]          && TRIM_ARGS+=(-2 "$READ2")
[[ -n "$PAIR_FLAG" ]]      && TRIM_ARGS+=("$PAIR_FLAG")
[[ "$MODE" == "PE" ]]      && TRIM_ARGS+=(-A "$ADAPTER_5")

bash "$SCRIPTS_DIR/01_trim_adapters.sh" "${TRIM_ARGS[@]}"

# ============================================================
# Add future steps here, passing trimmed output as input
# ============================================================

echo ""
echo "=========================================="
echo " Pipeline complete. Results in: $OUTDIR"
echo "=========================================="
