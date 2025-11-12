#!/usr/bin/env bash
# Compute N50 for a FASTQ/FASTQ.GZ file.
# Usage: n50_fastq.sh <reads.fastq[.gz]>    (use '-' to read from stdin)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <reads.fastq|reads.fastq.gz|->" >&2
  exit 1
fi

IN="$1"

# Pick a reader (cat, zcat, or stdin)
if [[ "$IN" == "-" ]]; then
  READER="cat -"
elif [[ "$IN" =~ \.gz$ ]]; then
  READER="zcat -- '$IN'"
else
  READER="cat -- '$IN'"
fi

# Temp file for read lengths
LENFILE="$(mktemp)"
trap 'rm -f "$LENFILE"' EXIT

# Extract sequence lengths (line 2 of every 4 in FASTQ)
# Note: assumes standard 4-line FASTQ (no wrapped sequence lines).
eval "$READER" \
  | awk 'NR%4==2 { print length($0) }' > "$LENFILE"

# Sanity check
if [[ ! -s "$LENFILE" ]]; then
  echo "No reads found (did you pass a valid FASTQ?)." >&2
  exit 2
fi

# Total bases
TOTAL_BASES=$(awk '{s+=$1} END{print s+0}' "$LENFILE")

# N50: sort lengths desc, accumulate until >= 50% of total
N50=$(sort -nr "$LENFILE" \
  | awk -v T="$TOTAL_BASES" '{
      cum += $1;
      if (cum*2 >= T) { print $1; exit }
    }')

# Optional: some quick stats (read count & mean)
READS=$(wc -l < "$LENFILE")
MEAN=$(awk -v n="$READS" '{s+=$1} END{if(n>0) printf "%.2f", s/n; else print 0}' "$LENFILE")

echo "Reads:        $READS"
echo "Total bases:  $TOTAL_BASES"
echo "Mean length:  $MEAN"
echo "N50:          $N50"
