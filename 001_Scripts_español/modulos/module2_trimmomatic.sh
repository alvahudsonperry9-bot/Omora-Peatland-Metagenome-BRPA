#!/bin/bash
set -euo pipefail

#!/bin/bash
set -euo pipefail

# module2_trimmomatic.sh
# Args: sample in_dir out_dir r1_suffix r2_suffix threads conda_env minlen adapters slidingwindow leading trailing

sample="$1"
in_dir="$2"
out_dir="$3"
r1_suf="$4"
r2_suf="$5"
threads="$6"
env="$7"
minlen="${8:-50}"
adapters="${9:-TruSeq3-PE.fa}"
slidingwindow="${10:-4:20}"
leading="${11:-3}"
trailing="${12:-3}"

mkdir -p "$out_dir"

# Find TrimGalore outputs (val_1/val_2 or *_R1_trimmed)
mapfile -t cand1 < <(ls "${in_dir}"/*val*1*.gz 2>/dev/null || true)
mapfile -t cand2 < <(ls "${in_dir}"/*_R1_trimmed.* "${in_dir}"/*_trimmed*R1* 2>/dev/null || true)

r1=""
r2=""
if [[ ${#cand1[@]} -gt 0 ]]; then
  # prefer files that include sample name
  for f in "${cand1[@]}"; do
    if [[ "$(basename "$f")" == *"${sample}"* ]]; then r1="$f"; break; fi
  done
  [[ -z "$r1" ]] && r1="${cand1[0]}"
  # find corresponding val_2
  r2_candidate=$(echo "$r1" | sed -E 's/_val_1/_val_2/; s/_R1_val_1/_R2_val_2/')
  if [[ -f "$r2_candidate" ]]; then r2="$r2_candidate"; fi
fi

if [[ -z "$r1" && ${#cand2[@]} -gt 0 ]]; then
  r1="${cand2[0]}"
  r2="$(echo "$r1" | sed -E 's/_R1/_R2/; s/_1/_2/')"
fi

if [[ -z "$r1" || -z "$r2" || ! -f "$r1" || ! -f "$r2" ]]; then
  echo "Trimmomatic: no se encontraron archivos de entrada desde TrimGalore para $sample" >&2
  ls -la "$in_dir" || true
  exit 1
fi

echo "Trimmomatic: procesando $sample"

out_p1="${out_dir}/${sample}_R1_trimmed.fq.gz"
out_up1="${out_dir}/${sample}_R1_unpaired.fq.gz"
out_p2="${out_dir}/${sample}_R2_trimmed.fq.gz"
out_up2="${out_dir}/${sample}_R2_unpaired.fq.gz"
logfile="${out_dir}/${sample}_trimmomatic.log"

cmd="trimmomatic PE -threads ${threads} '${r1}' '${r2}' '${out_p1}' '${out_up1}' '${out_p2}' '${out_up2}' ILLUMINACLIP:${adapters}:2:30:10 LEADING:${leading} TRAILING:${trailing} SLIDINGWINDOW:${slidingwindow} MINLEN:${minlen}"
echo "> $cmd"
conda run -n "$env" bash -lc "$cmd" > "$logfile" 2>&1

if [[ ! -f "$out_p1" || ! -f "$out_p2" ]]; then
  echo "Trimmomatic did not produce paired outputs for $sample" >&2
  tail -n 200 "$logfile" || true
  exit 1
fi

echo "Trimmomatic finished: $out_p1 $out_p2"
