#!/bin/bash
set -euo pipefail

# module_hostremoval.sh
# Args: sample in_dir out_dir threads conda_env human_ref out_prefix

sample="$1"
in_dir="$2"
out_dir="$3"
threads="$4"
env="$5"
human_ref="$6"
out_prefix="$7"

mkdir -p "$out_dir"

in1="${in_dir}/${sample}_R1_repair.fastq.gz"
in2="${in_dir}/${sample}_R2_repair.fastq.gz"

if [[ ! -f "$in1" || ! -f "$in2" ]]; then
  echo "[hostremoval] Inputs missing for $sample: $in1 or $in2" >&2
  exit 1
fi

echo "[hostremoval] Running bowtie2 host removal for $sample -> $out_dir"
conda run -n "$env" bash -lc "bowtie2 -x '${human_ref}' -1 '${in1}' -2 '${in2}' --threads ${threads} --no-mixed --no-discordant --un-conc-gz '${out_dir}/${out_prefix}_unmapped' -S /dev/null"

# Normalize bowtie2 unmapped outputs: ensure .1.gz and .2.gz exist
echo "[hostremoval] Normalizing unmapped outputs for prefix: ${out_dir}/${out_prefix}_unmapped"
f1="${out_dir}/${out_prefix}_unmapped.1.gz"
f2="${out_dir}/${out_prefix}_unmapped.2.gz"

if [[ -f "${out_dir}/${out_prefix}_unmapped.1" && ! -f "$f1" ]]; then
  echo "[hostremoval] Gzipping ${out_dir}/${out_prefix}_unmapped.1"
  gzip -c "${out_dir}/${out_prefix}_unmapped.1" > "$f1" && rm -f "${out_dir}/${out_prefix}_unmapped.1"
fi
if [[ -f "${out_dir}/${out_prefix}_unmapped.2" && ! -f "$f2" ]]; then
  echo "[hostremoval] Gzipping ${out_dir}/${out_prefix}_unmapped.2"
  gzip -c "${out_dir}/${out_prefix}_unmapped.2" > "$f2" && rm -f "${out_dir}/${out_prefix}_unmapped.2"
fi

# Some bowtie2 versions may create files without the _unmapped suffix; attempt to detect alternatives
if [[ ! -f "$f1" || ! -f "$f2" ]]; then
  alt1="${out_dir}/${out_prefix}.1.gz"
  alt2="${out_dir}/${out_prefix}.2.gz"
  if [[ -f "$alt1" && -f "$alt2" && (! -f "$f1" || ! -f "$f2") ]]; then
    echo "[hostremoval] Renaming alternative bowtie outputs to expected unmapped names"
    mv -f "$alt1" "$f1"
    mv -f "$alt2" "$f2"
  fi
fi

if [[ -f "$f1" && -f "$f2" ]]; then
  echo "[hostremoval] Unmapped pairs: $f1 $f2"
else
  echo "[hostremoval] WARNING: unmapped paired files not found for prefix ${out_dir}/${out_prefix}_unmapped" >&2
  ls -la "${out_dir}" || true
fi

echo "[hostremoval] Done. Unmapped prefix: ${out_dir}/${out_prefix}_unmapped"
