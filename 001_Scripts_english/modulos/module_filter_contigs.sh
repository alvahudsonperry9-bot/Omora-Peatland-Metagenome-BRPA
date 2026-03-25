#!/bin/bash
set -euo pipefail

# module_filter_contigs.sh
# Args: assembly_fasta out_fasta min_contig_len

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <assembly_fasta> <out_fasta> <min_contig_len>" >&2
  exit 2
fi

assembly_fa="$1"
out_fa="$2"
min_len="$3"

if [[ ! -s "$assembly_fa" ]]; then
  echo "[filter_contigs] Assembly not found: $assembly_fa" >&2
  exit 1
fi

echo "[filter_contigs] Filtering contigs >= ${min_len} from $assembly_fa -> $out_fa"

awk -v minlen="$min_len" 'BEGIN{RS=">"; ORS=""} NR>1{ split($0, lines, "\n"); header=lines[1]; seq=""; for(i=2;i<=length(lines);i++) seq=seq lines[i] "\n"; gsub(/\r/,"",seq); gsub(/\n/,"",seq); if(length(seq) >= minlen){ print ">" header "\n"; for(i=1;i<=length(seq); i+=60) print substr(seq,i,60) "\n" } }' "$assembly_fa" > "$out_fa"

echo "[filter_contigs] Wrote $out_fa"
