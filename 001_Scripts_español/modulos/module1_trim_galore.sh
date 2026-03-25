#!/bin/bash
set -euo pipefail

#!/bin/bash
set -euo pipefail

# module1_trim_galore.sh
# Args: sample raw_dir out_dir r1_suffix r2_suffix threads conda_env trim_quality trim_minlen

sample="$1"
raw_dir="$2"
out_dir="$3"
r1_suf="$4"
r2_suf="$5"
threads="$6"
env="$7"
trim_quality="${8:-20}"
trim_minlen="${9:-20}"

mkdir -p "$out_dir"

r1_in="${raw_dir}/${sample}${r1_suf}"
r2_in="${raw_dir}/${sample}${r2_suf}"

if [[ ! -f "$r1_in" || ! -f "$r2_in" ]]; then
  echo "Inputs missing for trim_galore: $r1_in or $r2_in"
  exit 1
fi

logfile="${out_dir}/${sample}_trim_galore.log"

echo "Running Trim Galore for $sample -> $out_dir (quality=${trim_quality}, minlen=${trim_minlen})"

conda run -n "$env" bash -lc "trim_galore --paired --cores ${threads} --quality ${trim_quality} --length ${trim_minlen} --illumina -o '${out_dir}' '${r1_in}' '${r2_in}'" > "$logfile" 2>&1

# Robust detection of paired outputs (val_1/val_2 or *_trimmed)
out1="${out_dir}/${sample}_R1_trimmed.fq.gz"
out2="${out_dir}/${sample}_R2_trimmed.fq.gz"

# First, try to find _val_1/_val_2 pairs
mapfile -t val1_files < <(ls "${out_dir}"/*val*1*.gz 2>/dev/null || true)
mapfile -t val2_files < <(ls "${out_dir}"/*val*2*.gz 2>/dev/null || true)

found=0
for f1 in "${val1_files[@]}"; do
  base=$(basename "$f1")
  # try to compute corresponding val2 name variants
  candidate1="${out_dir}/${base%val*}val_2.fq.gz"
  # try naive replacement patterns
  candidate2=$(echo "$f1" | sed -E 's/_val_1/_val_2/')
  candidate3=$(echo "$f1" | sed -E 's/_R1_val_1/_R2_val_2/')
  for cand in "$candidate1" "$candidate2" "$candidate3"; do
    if [[ -f "$cand" ]]; then
      mv -f "$f1" "$out1"
      mv -f "$cand" "$out2"
      found=1
      break 2
    fi
  done
done

if [[ $found -eq 0 ]]; then
  # Try *_trimmed patterns
  t1=$(ls "${out_dir}"/*_R1_trimmed.* 2>/dev/null || true)
  t2=$(ls "${out_dir}"/*_R2_trimmed.* 2>/dev/null || true)
  if [[ -n "$t1" && -n "$t2" ]]; then
    mv -f $t1 "$out1" 2>/dev/null || true
    mv -f $t2 "$out2" 2>/dev/null || true
    found=1
  fi
fi

if [[ $found -eq 0 ]]; then
  echo "Trim Galore did not produce expected paired outputs for $sample" >&2
  echo "Contents of $out_dir:" >&2
  ls -la "$out_dir" >&2 || true
  tail -n 200 "$logfile" || true
  exit 1
fi

echo "Trim Galore finished: $out1 $out2"
