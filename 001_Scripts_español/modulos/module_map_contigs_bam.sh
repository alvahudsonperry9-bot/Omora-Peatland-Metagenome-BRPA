#!/bin/bash
set -euo pipefail

# module_map_contigs_bam.sh
# Args: sample sam_path bam_out_dir threads env_samtools

if [[ $# -lt 5 ]]; then
  echo "Usage: $0 <sample> <sam_path> <bam_out_dir> <threads> <env_samtools>" >&2
  exit 2
fi

sample="$1"
sam_path="$2"
bam_out_dir="$3"
threads="$4"
env_samtools="$5"

mkdir -p "$bam_out_dir"

if [[ ! -f "$sam_path" ]]; then
  echo "[map_contigs_bam] SAM not found: $sam_path" >&2
  exit 1
fi

bam_out="${bam_out_dir}/${sample}.bam"
echo "[map_contigs_bam] Converting SAM to BAM and sorting -> ${bam_out}"
conda run -n "$env_samtools" bash -lc "samtools view -b -S '${sam_path}' | samtools sort -o '${bam_out}' -@ ${threads}"
conda run -n "$env_samtools" bash -lc "samtools index '${bam_out}'"

echo "[map_contigs_bam] BAM ready: ${bam_out}"
