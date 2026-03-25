#!/bin/bash
set -euo pipefail

# module3_fastqc.sh
# Args: sample in_dir out_dir threads conda_env

sample="$1"
in_dir="$2"
out_dir="$3"
threads="$4"
env="$5"

mkdir -p "$out_dir"

echo "FastQC: processing files in $in_dir -> $out_dir"

# Find paired trimmed files produced by our Trimmomatic outputs
mapfile -t files < <(ls "$in_dir"/*_R1_trimmed.* "$in_dir"/*_R2_trimmed.* 2>/dev/null || true)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "FastQC: no *_R?_trimmed files found in $in_dir" >&2
  ls -la "$in_dir" || true
  exit 1
fi

cmd="fastqc -t ${threads} -o '${out_dir}' ${files[*]}"
echo "> $cmd"
conda run -n "$env" bash -lc "$cmd"

echo "FastQC: finished, results in $out_dir"
