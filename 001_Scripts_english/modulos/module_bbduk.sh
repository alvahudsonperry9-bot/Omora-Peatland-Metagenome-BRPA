#!/bin/bash
set -euo pipefail

# module_bbduk.sh
# Args: sample in_dir out_dir threads conda_env ref_fasta k minkmerhits rcomp

sample="$1"
in_dir="$2"
out_dir="$3"
threads="$4"
env="$5"
ref="$6"
k="$7"
mink="$8"
rcomp="$9"

mkdir -p "$out_dir"

# locate inputs robustly
in1=$(find "$in_dir" -maxdepth 1 -type f -iname "${sample}*_R1*.gz" -print -quit || true)
in2=$(find "$in_dir" -maxdepth 1 -type f -iname "${sample}*_R2*.gz" -print -quit || true)
if [[ -z "$in1" || -z "$in2" ]]; then
  in1=$(find "$in_dir" -type f -iname "*${sample}*R1*.gz" -print -quit || true)
  in2=$(find "$in_dir" -type f -iname "*${sample}*R2*.gz" -print -quit || true)
fi

if [[ -z "$in1" || -z "$in2" ]]; then
  echo "[bbduk] Inputs not found for $sample in $in_dir" >&2
  ls -la "$in_dir" || true
  exit 1
fi

out1="${out_dir}/${sample}_R1_clean.fastq.gz"
out2="${out_dir}/${sample}_R2_clean.fastq.gz"

echo "[bbduk] Running bbduk for $sample -> $out1 $out2"
conda run -n "$env" bash -lc "bbduk.sh in1='${in1}' in2='${in2}' ref='${ref}' out1='${out1}' out2='${out2}' k=${k} minkmerhits=${mink} rcomp=${rcomp} threads=${threads}"

if [[ ! -s "$out1" || ! -s "$out2" ]]; then
  echo "[bbduk] bbduk produced empty outputs for $sample" >&2
  exit 1
fi

echo "[bbduk] Done: $out1 $out2"
