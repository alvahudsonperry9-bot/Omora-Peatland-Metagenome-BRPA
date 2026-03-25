#!/bin/bash
set -euo pipefail

# module_map_contigs_sam_list.sh
# Args: sample assembly_fa forward_list reverse_list sam_out_dir threads env_bowtie2

if [[ $# -lt 7 ]]; then
  echo "Usage: $0 <sample> <assembly_fa> <forward_list> <reverse_list> <sam_out_dir> <threads> <env_bowtie2>" >&2
  exit 2
fi

sample="$1"
assembly_fa="$2"
forward_list="$3"
reverse_list="$4"
sam_out_dir="$5"
threads="$6"
env_bowtie2="$7"

mkdir -p "$sam_out_dir"

if [[ ! -s "$assembly_fa" ]]; then
  echo "[map_contigs_sam_list] Assembly FASTA not found: $assembly_fa" >&2
  exit 1
fi

idx_prefix="${sam_out_dir}/assembly"
sam_out="${sam_out_dir}/${sample}.sam"

echo "[map_contigs_sam_list] Building bowtie2 index and mapping combined lists -> $sam_out"
echo "[map_contigs_sam_list] Forward list has $(echo "$forward_list" | tr ',' '\n' | wc -l) files"
echo "[map_contigs_sam_list] Reverse list has $(echo "$reverse_list" | tr ',' '\n' | wc -l) files"

conda run -n "$env_bowtie2" bash -c "bowtie2-build '${assembly_fa}' '${idx_prefix}'"
conda run -n "$env_bowtie2" bash -c "bowtie2 -q -x '${idx_prefix}' -1 '${forward_list}' -2 '${reverse_list}' --no-unal -p ${threads} -S '${sam_out}'"

echo "[map_contigs_sam_list] SAM produced: $sam_out"
