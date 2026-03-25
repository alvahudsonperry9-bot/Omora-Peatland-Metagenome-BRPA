#!/bin/bash
set -euo pipefail

# module_megahit.sh
# Args: sample fwd rev out_dir threads conda_env memory_gb min_contig_assembly

sample="$1"
fwd="$2"
rev="$3"
out_dir="$4"
threads="$5"
env="$6"
memory_gb="$7"
min_contig_assembly="${8:-1000}"

echo "[megahit] Running megahit for $sample -> $out_dir"
if [[ -d "$out_dir" ]]; then
	if [[ -s "${out_dir}/final.contigs.fa" ]]; then
		echo "[megahit] Output already exists and final.contigs.fa present in $out_dir — skipping assembly"
		exit 0
	else
		ts=$(date +%s)
		backup_dir="${out_dir}_backup_${ts}"
		echo "[megahit] Output dir $out_dir exists but no final.contigs.fa — moving to $backup_dir and continuing"
		if ! mv "$out_dir" "$backup_dir"; then
			echo "[megahit] ERROR: failed to move existing $out_dir to $backup_dir" >&2
			exit 1
		fi
	fi
fi

# Ensure parent directory exists, but DO NOT create the final out_dir (megahit requires -o not to exist)
parent_dir=$(dirname "$out_dir")
mkdir -p "$parent_dir"

conda run -n "$env" bash -lc "megahit -1 '${fwd}' -2 '${rev}' -t ${threads} --memory ${memory_gb} --k-min 27 --k-step 10 --min-contig-len ${min_contig_assembly} -o '${out_dir}'"

echo "[megahit] Done: ${out_dir}/final.contigs.fa"
