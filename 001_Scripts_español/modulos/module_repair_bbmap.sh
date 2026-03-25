#!/bin/bash
set -euo pipefail

# module_repair_bbmap.sh
# Args: sample in_dir out_dir threads conda_env xm_mem (e.g. 110g)

sample="$1"
in_dir="$2"
out_dir="$3"
threads="$4"
env="$5"
xm="$6"

mkdir -p "$out_dir"

in1="${in_dir}/${sample}_R1_clean.fastq.gz"
in2="${in_dir}/${sample}_R2_clean.fastq.gz"
out1="${out_dir}/${sample}_R1_repair.fastq.gz"
out2="${out_dir}/${sample}_R2_repair.fastq.gz"

if [[ ! -f "$in1" || ! -f "$in2" ]]; then
  echo "[bbmap] Inputs missing for $sample: $in1 or $in2" >&2
  exit 1
fi

echo "[bbmap] Repairing pairs for $sample -> $out_dir"
conda run -n "$env" bash -lc "repair.sh -Xmx${xm} in='${in1}' in2='${in2}' out='${out1}' out2='${out2}' repair=t"

echo "[bbmap] Done: $out1 $out2"
