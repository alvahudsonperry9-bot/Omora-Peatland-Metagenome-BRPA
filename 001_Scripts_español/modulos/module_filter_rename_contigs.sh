#!/bin/bash
set -euo pipefail

# module_filter_rename_contigs.sh
# Args: sample assembly_fa out_fa min_contig_len

sample="$1"
assembly_fa="$2"
out_fa="$3"
min_len="${4:-2000}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [[ ! -s "$assembly_fa" ]]; then
  echo "[filter_rename] Assembly not found: $assembly_fa" >&2
  exit 1
fi

echo "[filter_rename] Filtering contigs >= ${min_len} and renaming with sample prefix $sample"

# Create filtered fasta with headers: >sample:orig_contig
awk -v minlen="$min_len" -v sample="$sample" '
  BEGIN{RS=">"; ORS=""}
  NR>1{
    split($0, lines, "\n");
    header = lines[1]; seq=""; for(i=2;i<=length(lines);i++) seq=seq lines[i] "\n";
    gsub(/ .*/,"",header);
    gsub(/\r/,"",seq);
    gsub(/\n/,"",seq);
    if(length(seq) >= minlen){
      print ">" sample ":" header "\n";
      # print sequence in 60-char lines
      for(i=1;i<=length(seq); i+=60) print substr(seq,i,60) "\n";
    }
  }
' "$assembly_fa" > "$tmpdir/filtered.fasta"

mv "$tmpdir/filtered.fasta" "$out_fa"
echo "[filter_rename] Wrote $out_fa"
