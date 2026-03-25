#!/bin/bash
set -euo pipefail

# 003_run_semibin2.sh
# SemiBin2 single_easy_bin mode only

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"
MEGAHIT_SUBDIR="005_megahit"

THREADS=30
# Contigs filename changed: now uses ${sample}_contigs.fasta (no MIN_CONTIG_LEN in filename)
ENV_SEMIBIN2="semibin2"

usage(){
	echo "Usage: $0 [-a DISK_A] [-b DISK_B] [-s SAMPLE_TYPE] [-t THREADS] [-L sample1,sample2]"
	echo "  -L: Comma-separated list of samples (required)"
	exit 1
}

while getopts ":a:b:s:t:L:" opt; do
	case $opt in
		a) DISK_A="$OPTARG";;
		b) DISK_B="$OPTARG";;
		s) SAMPLE_TYPE="$OPTARG";;
		t) THREADS="$OPTARG";;
		L) MANUAL_SAMPLES="$OPTARG";;
		*) usage;;
	esac
done

if [[ -z "${MANUAL_SAMPLES:-}" ]]; then
	echo "Error: Debe especificar las muestras con -L"
	usage
fi

IFS=',' read -r -a SAMPLES <<< "${MANUAL_SAMPLES}"
echo "Procesando ${#SAMPLES[@]} muestras: ${SAMPLES[*]}"

sample_type_dir_a="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}"
sample_type_dir_b="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}"

find_contigs(){
	local sample="$1"
	# Updated: now contigs are named ${sample}_contigs.fasta (no MIN_CONTIG_LEN in filename)
	local rel="${MEGAHIT_SUBDIR}/${sample}/${sample}_contigs.fasta"
	if [[ -s "${sample_type_dir_a}/${rel}" ]]; then
		echo "${sample_type_dir_a}/${rel}"
	elif [[ -s "${sample_type_dir_b}/${rel}" ]]; then
		echo "${sample_type_dir_b}/${rel}"
	else
		echo ""
	fi
}

find_bam(){
	local sample="$1"
	local rel="${MEGAHIT_SUBDIR}/${sample}/${sample}.bam"
	if [[ -s "${sample_type_dir_a}/${rel}" ]]; then
		echo "${sample_type_dir_a}/${rel}"
	elif [[ -s "${sample_type_dir_b}/${rel}" ]]; then
		echo "${sample_type_dir_b}/${rel}"
	else
		echo ""
	fi
}

# SemiBin2 single_easy_bin for each sample
for sample in "${SAMPLES[@]}"; do
	contigs=$(find_contigs "$sample")
	bam=$(find_bam "$sample")
	
	if [[ -z "$contigs" ]]; then
		echo "[ERROR] Contigs no encontrados para $sample, saltando"
		continue
	fi
	
	if [[ -z "$bam" ]]; then
		echo "[ERROR] BAM no encontrado para $sample, saltando"
		continue
	fi

	sample_dir=$(dirname "$contigs")
	out_dir="${sample_dir}/001_SemiBin2"
	mkdir -p "$out_dir"

	echo "=== Procesando $sample ==="
	echo "  Contigs: $contigs"
	echo "  BAM: $bam"
	echo "  Output: $out_dir"
	
	conda run -n "$ENV_SEMIBIN2" SemiBin2 single_easy_bin \
		--self-supervised \
		-i "${contigs}" \
		-b "${bam}" \
		-o "${out_dir}" \
		-t "${THREADS}" || {
		echo "[ERROR] SemiBin2 falló para $sample"
		continue
	}
	
	echo "✅ $sample completado"
done

echo "SemiBin2 single mode completado"

