#!/usr/bin/env bash
set -euo pipefail

if ! command -v cutadapt &>/dev/null; then
    echo "Error: cutadapt not found. Activate the conda environment with: conda activate RiboSeqULater"
    exit 1
fi

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Trim adapter sequences using cutadapt (NEXTFLEX small RNA-seq kit).

Required:
  -m, --mode          SE or PE (single-end or paired-end)
  -1, --read1         Input FASTQ file (or R1 for PE)

Optional:
  -2, --read2         R2 input FASTQ file (PE only)
  -a, --adapter       3' adapter sequence [default: TGGAATTCTCGGGTGCCAAGG]
  -A, --adapter2      5' adapter sequence for R2 (PE only) [default: AGATCGGAAGAGCGTCGTGTAGGGAAAGA]
  -q, --quality       3' quality cutoff [default: 20]
  -l, --min-length    Minimum insert length to keep [default: 16]
  -o, --outdir        Output directory [default: trimmed/]
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
OUTDIR="trimmed"
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
[[ ! -f "$READ1" ]] && { echo "Error: File not found: $READ1"; exit 1; }

if [[ "$MODE" == "PE" ]]; then
    [[ -z "$READ2" ]] && { echo "Error: --read2 is required for PE mode."; usage; }
    [[ ! -f "$READ2" ]] && { echo "Error: File not found: $READ2"; exit 1; }
elif [[ "$MODE" != "SE" ]]; then
    echo "Error: --mode must be SE or PE."; usage
fi

mkdir -p "$OUTDIR"

# --- Derive output filenames from input basename ---
base1=$(basename "$READ1")
base1="${base1%.fastq.gz}"
base1="${base1%.fastq}"

if [[ "$MODE" == "SE" ]]; then
    OUT1="$OUTDIR/${base1}.cut.fastq"

    echo "Running single-end trimming..."
    cutadapt \
        --cores 0 \
        --quality-cutoff "$QUALITY" \
        --adapter "$ADAPTER_3" \
        --minimum-length "$MIN_LENGTH" \
        --output "$OUT1" \
        "$READ1"

    echo "Output: $OUT1"

else
    base2=$(basename "$READ2")
    base2="${base2%.fastq.gz}"
    base2="${base2%.fastq}"

    OUT1="$OUTDIR/${base1}.cut.fastq"
    OUT2="$OUTDIR/${base2}.cut.fastq"

    PAIR_FLAG=""
    [[ "$PAIR_ADAPTERS" == true ]] && PAIR_FLAG="--pair-adapters"

    echo "Running paired-end trimming..."
    cutadapt \
        --cores 0 \
        $PAIR_FLAG \
        --quality-cutoff "$QUALITY" \
        --adapter "$ADAPTER_3" \
        -A "$ADAPTER_5" \
        --minimum-length "$MIN_LENGTH" \
        --output "$OUT1" \
        --paired-output "$OUT2" \
        "$READ1" \
        "$READ2"

    echo "Output: $OUT1"
    echo "Output: $OUT2"
fi
