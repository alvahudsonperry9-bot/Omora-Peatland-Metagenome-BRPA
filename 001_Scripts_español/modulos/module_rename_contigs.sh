#!/bin/bash
set -euo pipefail

# module_rename_contigs.sh
# Args: sample assembly_fasta out_fasta

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <sample> <assembly_fasta> <out_fasta>" >&2
  exit 2
fi

sample="$1"
assembly_fa="$2"
out_fa="$3"

if [[ ! -s "$assembly_fa" ]]; then
  echo "[rename_contigs] Input assembly not found: $assembly_fa" >&2
  exit 1
fi

echo "[rename_contigs] Renaming headers in $assembly_fa -> $out_fa (prefix: $sample:)"

if [[ "$assembly_fa" == *.gz ]]; then
  zcat "$assembly_fa" | awk -v sample="$sample" '/^>/ { sub(/^>/, ""); split($0,a,/\s+/); print ">"sample":"a[1]; next } { print }' > "$out_fa"
else
  awk -v sample="$sample" '/^>/ { sub(/^>/, ""); split($0,a,/\s+/); print ">"sample":"a[1]; next } { print }' "$assembly_fa" > "$out_fa"
fi

echo "[rename_contigs] Done"
