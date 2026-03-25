#!/bin/bash
set -euo pipefail

# module_seqkit.sh
# Args: sample in_dir out_dir threads conda_env seqrep_fasta

sample="$1"
in_dir="$2"
out_dir="$3"
threads="$4"
env="$5"
seqrep="$6"

mkdir -p "$out_dir"

# Locate input R1/R2 robustly (support *_R1_trimmed.fq.gz and similar)
in1=""
in2=""
in1=$(find "$in_dir" -maxdepth 1 -type f -iname "${sample}_R1*.gz" -print -quit || true)
in2=$(find "$in_dir" -maxdepth 1 -type f -iname "${sample}_R2*.gz" -print -quit || true)

if [[ -z "$in1" || -z "$in2" ]]; then
  # try recursive search
  in1=$(find "$in_dir" -type f -iname "*${sample}*R1*.gz" -print -quit || true)
  in2=$(find "$in_dir" -type f -iname "*${sample}*R2*.gz" -print -quit || true)
fi

if [[ -z "$in1" || -z "$in2" ]]; then
  echo "[seqkit] Inputs missing for $sample in $in_dir" >&2
  ls -la "$in_dir" || true
  exit 1
fi

out1="${out_dir}/${sample}_R1_filtered.fastq.gz"
out2="${out_dir}/${sample}_R2_filtered.fastq.gz"

echo "[seqkit] Filtering Seq_rep for $sample -> $out_dir (in1=$in1)"
conda run -n "$env" bash -lc "seqkit grep -s -v -f '${seqrep}' '${in1}' | gzip > '${out1}'"
conda run -n "$env" bash -lc "seqkit grep -s -v -f '${seqrep}' '${in2}' | gzip > '${out2}'"

echo "[seqkit] Done: $out1 $out2"
