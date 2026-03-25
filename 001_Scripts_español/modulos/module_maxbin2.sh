#!/bin/bash
set -euo pipefail

# module_maxbin2.sh
# Args: sample contigs_fa depth_file out_dir threads env_maxbin2

sample="$1"
contigs_fa="$2"
depth_file="$3"
out_dir="$4"
threads="$5"
env_maxbin2="$6"

mkdir -p "$out_dir"

if [[ ! -s "$contigs_fa" ]]; then
  echo "[maxbin2] Contigs not found: $contigs_fa" >&2
  exit 1
fi
if [[ ! -s "$depth_file" ]]; then
  echo "[maxbin2] Depth file not found: $depth_file" >&2
  exit 1
fi

echo "[maxbin2] Running MaxBin2 for $sample"
conda run -n "$env_maxbin2" bash -lc "run_MaxBin.pl -contig '${contigs_fa}' -abund '${depth_file}' -out '${out_dir}/${sample}_maxbin' -thread ${threads}"

echo "[maxbin2] Output in $out_dir"
