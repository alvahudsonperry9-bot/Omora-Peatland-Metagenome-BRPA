#!/bin/bash
set -euo pipefail

# module_map_contigs.sh
# Args: sample assembly_fa reads_dir sam_out_dir bam_out_dir threads env_bowtie2 env_samtools

sample="$1"
assembly_fa="$2"
reads_dir="$3"
sam_out_dir="$4"
bam_out_dir="$5"
threads="$6"
env_bowtie2="$7"
env_samtools="$8"

mkdir -p "$sam_out_dir"
mkdir -p "$bam_out_dir"

if [[ ! -s "$assembly_fa" ]]; then
  echo "[map_contigs] Assembly FASTA not found for $sample: $assembly_fa" >&2
  exit 1
fi

idx_prefix="${sam_out_dir}/assembly"
sam_out="${sam_out_dir}/${sample}.sam"
bam_out="${bam_out_dir}/${sample}.bam"

echo "[map_contigs] Building bowtie2 index for $sample from $assembly_fa (index in $sam_out_dir)"
conda run -n "$env_bowtie2" bash -lc "bowtie2-build '${assembly_fa}' '${idx_prefix}'"

fwd="${reads_dir}/${sample}_R1_repair.fastq.gz"
rev="${reads_dir}/${sample}_R2_repair.fastq.gz"

if [[ ! -f "$fwd" || ! -f "$rev" ]]; then
  echo "[map_contigs] Reads for mapping not found: $fwd or $rev" >&2
  exit 1
fi

echo "[map_contigs] Mapping reads to assembly -> ${sam_out}"
conda run -n "$env_bowtie2" bash -lc "bowtie2 -q -x '${idx_prefix}' -1 '${fwd}' -2 '${rev}' --no-unal -p ${threads} -S '${sam_out}'"

if [[ -f "$sam_out" ]]; then
  echo "[map_contigs] Converting SAM to BAM and sorting -> ${bam_out}"
  conda run -n "$env_samtools" bash -lc "samtools view -b -S '${sam_out}' | samtools sort -o '${bam_out}' -@ ${threads}"
  conda run -n "$env_samtools" bash -lc "samtools index '${bam_out}'"
else
  echo "[map_contigs] SAM not produced for $sample" >&2
  exit 1
fi

echo "[map_contigs] Done for $sample"
