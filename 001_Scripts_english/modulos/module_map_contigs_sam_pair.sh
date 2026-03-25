#!/bin/bash
set -euo pipefail

# module_map_contigs_sam_pair.sh
# Args: sample assembly_fa reads_dir sam_out_dir threads env_bowtie2

if [[ $# -lt 6 ]]; then
  echo "Usage: $0 <sample> <assembly_fa> <reads_dir> <sam_out_dir> <threads> <env_bowtie2>" >&2
  exit 2
fi

sample="$1"
assembly_fa="$2"
reads_dir="$3"
sam_out_dir="$4"
threads="$5"
env_bowtie2="$6"

mkdir -p "$sam_out_dir"

if [[ ! -s "$assembly_fa" ]]; then
  echo "[map_contigs_sam_pair] Assembly FASTA not found: $assembly_fa" >&2
  exit 1
fi

idx_prefix="${sam_out_dir}/assembly"
sam_out="${sam_out_dir}/${sample}.sam"

# Prefer host-filtered reads when present; fallback to repaired reads.
fwd="${reads_dir}/${sample}_nonhuman_unmapped.1.gz"
rev="${reads_dir}/${sample}_nonhuman_unmapped.2.gz"
if [[ ! -f "$fwd" || ! -f "$rev" ]]; then
  fwd="${reads_dir}/${sample}_R1_repair.fastq.gz"
  rev="${reads_dir}/${sample}_R2_repair.fastq.gz"
fi

if [[ ! -f "$fwd" || ! -f "$rev" ]]; then
  echo "[map_contigs_sam_pair] Reads for mapping not found: $fwd or $rev" >&2
  exit 1
fi

# quick check read counts
echo "[map_contigs_sam_pair] Checking read counts for $sample"
reads1=$(zcat "$fwd" | wc -l || true)
reads2=$(zcat "$rev" | wc -l || true)
if [[ -z "$reads1" || -z "$reads2" ]]; then
  echo "[map_contigs_sam_pair] Warning: unable to read counts; proceeding to mapping" >&2
else
  reads1=$((reads1/4))
  reads2=$((reads2/4))
  if [[ "$reads1" -ne "$reads2" ]]; then
    echo "[map_contigs_sam_pair] ERROR: unequal read counts: R1=$reads1 R2=$reads2. Run repair before mapping." >&2
    exit 1
  fi
fi

echo "[map_contigs_sam_pair] Building bowtie2 index and mapping to produce SAM: $sam_out"
conda run -n "$env_bowtie2" bash -lc "bowtie2-build '${assembly_fa}' '${idx_prefix}'"
conda run -n "$env_bowtie2" bash -lc "bowtie2 -q -x '${idx_prefix}' -1 '${fwd}' -2 '${rev}' --no-unal -p ${threads} -S '${sam_out}'"

echo "[map_contigs_sam_pair] SAM produced: $sam_out"
