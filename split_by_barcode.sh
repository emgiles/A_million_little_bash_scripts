#!/usr/bin/env bash
# Non-destructive FASTQ demultiplexer by barcode tag in header.

set -euo pipefail

OUTDIR="${1:-demux_by_barcode}"
shift || true

# Collect input files (recursively)
if [ "$#" -eq 0 ]; then
  mapfile -t INPUTS < <(
    find . -type f \( -iname "*.fastq" -o -iname "*.fq" -o -iname "*.fastq.gz" -o -iname "*.fq.gz" \) | sort
  )
else
  INPUTS=("$@")
fi

if [ "${#INPUTS[@]}" -eq 0 ]; then
  echo "❌ No FASTQ files found." >&2
  exit 1
fi

mkdir -p "$OUTDIR"

# Read and split by barcode pattern safely (works with mawk/busybox awk)
for f in "${INPUTS[@]}"; do
  echo "Processing: $f"
  if [[ "$f" =~ \.gz$ ]]; then
    zcat -- "$f"
  else
    cat -- "$f"
  fi
done | awk -v OUT="$OUTDIR" '
  {
    line = $0
    # Track which line of the FASTQ record we’re on (1–4)
    n = NR % 4
    if (n == 1) {
      header = line
      bc = "unclassified"
      # match "_barcodeNN" pattern (two digits)
      if (match(header, /_barcode[0-9][0-9]/)) {
        bc = substr(header, RSTART+1, RLENGTH-1)
      }
    } else if (n == 2) {
      seq = line
    } else if (n == 3) {
      plus = line
    } else if (n == 0) {
      qual = line
      file = OUT "/" bc ".fastq"
      print header >> file
      print seq >> file
      print plus >> file
      print qual >> file
    }
  }
'

echo "✅ Done. Demultiplexed FASTQs written to: $OUTDIR"
