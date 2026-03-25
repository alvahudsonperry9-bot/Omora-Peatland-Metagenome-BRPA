#!/bin/bash
set -euo pipefail

# 002_run_pipeline_trim_to_binning.sh
# Filtrado y preparación desde trimmed -> repair -> host removal -> assembly -> mapping
# Alterna discos similar a 001_run_pipeline_trim_modules.sh

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"
IN_SUBDIR="002_quality_clean2"   # entrada (trimmed from previous pipeline)

OUT3_SUBDIR="003_quality_clean3"  # seqkit output on OTHER disk
OUT4_SUBDIR="004_quality_clean4"  # bbmap repair and bowtie2 outputs
MEGAHIT_SUBDIR="005_megahit"

THREADS=30
START_MODULE=4  # default start module. Modules: 1=bbduk(filter), 2=repair, 3=bowtie2_host_removal, 4=megahit, 6=filter, 7=rename, 8=map_sam, 9=map_bam, 10=metabat2, 11=maxbin2
MEGAHIT_MEM_G=120
MIN_CONTIG_ASSEMBLY=2000

# Conda envs (configurables)
ENV_SEQKIT="seqkit_env"
ENV_BBMAP="bbmap"
ENV_BOWTIE2="bowtie2"
ENV_MEGAHIT="megahit"
ENV_SAMTOOLS="samtools_1.21"
ENV_MAXBIN2="maxbin2_env"
METABAT_DOCKER_IMG="metabat/metabat:latest"
MIN_CONTIG_LEN=2000

SEQREP="${DISK_A}/${BASE_REL}/001_Scripts/modulos/Seq_rep.fa"
HUMAN_REF="/media/pinguicula/1T_BRPA/Genome_reference/T2T/human_T2T"

MODULE_DIR="${DISK_A}/${BASE_REL}/001_Scripts/modulos"

# BBduk parameters (used instead of seqkit)
BBDUK_K=31
BBDUK_MINK=1
BBDUK_RCOMP="t"

usage(){
  echo "Usage: $0 [-a DISK_A] [-b DISK_B] [-s SAMPLE_TYPE] [-t THREADS] [-m START_MODULE] [-L sample1,sample2]"
  exit 1
}

while getopts ":a:b:s:t:m:L:" opt; do
  case $opt in
    a) DISK_A="$OPTARG";;
    b) DISK_B="$OPTARG";;
    s) SAMPLE_TYPE="$OPTARG";;
    t) THREADS="$OPTARG";;
    m) START_MODULE="$OPTARG";;
    L) MANUAL_SAMPLES="$OPTARG";;
    *) usage;;
  esac
done

# Support manual sample list via env var or -L (comma-separated), example: P1-14,P1-13
if [[ -n "${MANUAL_SAMPLES:-}" ]]; then
  IFS=',' read -r -a SAMPLES <<< "${MANUAL_SAMPLES}"
  echo "Usando lista manual de muestras: ${SAMPLES[*]}"
fi

SAMPLE_TYPE_DIR_A="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}"
SAMPLE_TYPE_DIR_B="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}"

# Determine base input directory depending on START_MODULE
if (( START_MODULE <= 1 )); then
  DETECT_SUBDIR="$IN_SUBDIR"
elif (( START_MODULE == 2 )); then
  DETECT_SUBDIR="$OUT3_SUBDIR"
elif (( START_MODULE <= 4 )); then
  DETECT_SUBDIR="$OUT4_SUBDIR"
else
  DETECT_SUBDIR="$MEGAHIT_SUBDIR"
fi

DETECT_DIR_A="${SAMPLE_TYPE_DIR_A}/${DETECT_SUBDIR}"
DETECT_DIR_B="${SAMPLE_TYPE_DIR_B}/${DETECT_SUBDIR}"

if (( START_MODULE == 2 )); then
  # Module 2 reads from OUT3 on OTHER_DISK and writes to OUT4 on INPUT_DISK
  if [[ -d "$DETECT_DIR_A" && -n "$(ls -A "$DETECT_DIR_A" 2>/dev/null)" ]]; then
    OTHER_DISK="$DISK_A"
    INPUT_DISK="$DISK_B"
  elif [[ -d "$DETECT_DIR_B" && -n "$(ls -A "$DETECT_DIR_B" 2>/dev/null)" ]]; then
    OTHER_DISK="$DISK_B"
    INPUT_DISK="$DISK_A"
  else
    echo "No se encontró directorio de entrada ${DETECT_SUBDIR} en $DETECT_DIR_A ni en $DETECT_DIR_B"
    exit 1
  fi
  IN_DIR="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${DETECT_SUBDIR}"
else
  # Modules 1,3,4,6+ read from INPUT_DISK
  if [[ -d "$DETECT_DIR_A" && -n "$(ls -A "$DETECT_DIR_A" 2>/dev/null)" ]]; then
    INPUT_DISK="$DISK_A"
    OTHER_DISK="$DISK_B"
  elif [[ -d "$DETECT_DIR_B" && -n "$(ls -A "$DETECT_DIR_B" 2>/dev/null)" ]]; then
    INPUT_DISK="$DISK_B"
    OTHER_DISK="$DISK_A"
  else
    echo "No se encontró directorio de entrada ${DETECT_SUBDIR} en $DETECT_DIR_A ni en $DETECT_DIR_B"
    exit 1
  fi
  IN_DIR="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${DETECT_SUBDIR}"
fi

echo "Usando IN_DIR: $IN_DIR"

# Detect samples by locating R1 files recursively only if no manual list provided
if [[ -z "${MANUAL_SAMPLES:-}" ]]; then
  mapfile -t R1_FILES < <(find "$IN_DIR" -type f -iname "*_R1*.gz" -print 2>/dev/null || true)
  declare -A _smap
  for f in "${R1_FILES[@]}"; do
    base=$(basename "$f")
    sample_name=$(echo "$base" | sed -E 's/_R1.*$//I')
    _smap["$sample_name"]=1
  done
  SAMPLES=()
  for k in "${!_smap[@]}"; do SAMPLES+=("$k"); done

  if [[ ${#SAMPLES[@]} -eq 0 ]]; then
    mapfile -t DIR_SAMPLES < <(find "$IN_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort)
    SAMPLES=("${DIR_SAMPLES[@]}")
  fi

  if [[ ${#SAMPLES[@]} -eq 0 ]]; then
    echo "No se detectaron muestras en $IN_DIR"
    exit 1
  fi
fi

echo "Muestras detectadas: ${SAMPLES[*]}"

for sample in "${SAMPLES[@]}"; do
  echo "========================================"
  echo "Procesando muestra: $sample"
  echo "========================================"

  set +e
  # define alternating paths per sample
  seqkit_out_dir="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${OUT3_SUBDIR}/${sample}"
  repair_out_dir="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${OUT4_SUBDIR}/${sample}"
  bowtie_out_dir="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${OUT4_SUBDIR}/${sample}"
  megahit_sample_dir="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${sample}"
  map_sam_out_dir="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${sample}"

  mkdir -p "$seqkit_out_dir" "$repair_out_dir" "$bowtie_out_dir" "$map_sam_out_dir"

  # 1) bbduk (BBMap) filter — reemplaza seqkit
  if (( START_MODULE <= 1 )); then
    # Determine sample-specific input directory (if files are inside a per-sample subdirectory)
    if [[ -d "${IN_DIR}/${sample}" ]]; then
      sample_input_dir="${IN_DIR}/${sample}"
    else
      sample_input_dir="$IN_DIR"
    fi
    bash "$MODULE_DIR/module_bbduk.sh" "$sample" "$sample_input_dir" "$seqkit_out_dir" "$THREADS" "$ENV_BBMAP" "$SEQREP" "$BBDUK_K" "$BBDUK_MINK" "$BBDUK_RCOMP" || { echo "module_bbduk failed for $sample"; set -e; continue; }
    # update variables for downstream modules: bbduk outputs named *_R?_clean.fastq.gz
  fi

  # 2) bbmap repair
  if (( START_MODULE <= 2 )); then
    bash "$MODULE_DIR/module_repair_bbmap.sh" "$sample" "$seqkit_out_dir" "$repair_out_dir" "$THREADS" "$ENV_BBMAP" "110g" || { echo "module_repair_bbmap failed for $sample"; set -e; continue; }
  fi

  # 3) bowtie2 host removal
  if (( START_MODULE <= 3 )); then
    bash "$MODULE_DIR/module_hostremoval.sh" "$sample" "$repair_out_dir" "$bowtie_out_dir" "$THREADS" "$ENV_BOWTIE2" "$HUMAN_REF" "${sample}_nonhuman" || { echo "module_hostremoval failed for $sample"; set -e; continue; }
  fi

  # 4) megahit assembly
  if (( START_MODULE <= 4 )); then
    # prefer bowtie nonhuman outputs if exist
    unm1="${bowtie_out_dir}/${sample}_nonhuman_unmapped.1.gz"
    unm2="${bowtie_out_dir}/${sample}_nonhuman_unmapped.2.gz"
    if [[ ! -f "$unm1" || ! -f "$unm2" ]]; then
      echo "[megahit] Faltan lecturas nonhuman_unmapped para $sample: $unm1 o $unm2" >&2
      set -e
      continue
    fi
    fwd="$unm1"
    rev="$unm2"
    bash "$MODULE_DIR/module_megahit.sh" "$sample" "$fwd" "$rev" "$megahit_sample_dir" "$THREADS" "$ENV_MEGAHIT" "$MEGAHIT_MEM_G" "$MIN_CONTIG_ASSEMBLY" || { echo "module_megahit failed for $sample"; set -e; continue; }
  fi

  # prepare binner output base on OTHER_DISK (do not create dirs until needed)
  other_base="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}"
  metab_out_dir="${other_base}/${sample}/001_Metabat2"
  maxbin_out_dir="${other_base}/${sample}/001_Maxbin2"

  # 5) rename contigs (add sample prefix to FASTA headers)
  # NOTE: megahit already filters contigs >= MIN_CONTIG_ASSEMBLY (2000bp), no additional filtering needed
  if (( START_MODULE <= 5 )); then
    assembly_fa="${megahit_sample_dir}/final.contigs.fa"
    renamed_fa="${megahit_sample_dir}/${sample}_contigs.fasta"
    bash "$MODULE_DIR/module_rename_contigs.sh" "$sample" "$assembly_fa" "$renamed_fa" || { echo "module_rename_contigs failed for $sample"; set -e; continue; }
  fi

  # 6) map reads to contigs (bowtie2) -> SAM file
  # Uses nonhuman_unmapped reads from module 3 (host removal)
  if (( START_MODULE <= 6 )); then
    if [[ -z "${renamed_fa:-}" ]]; then
      renamed_fa="${megahit_sample_dir}/${sample}_contigs.fasta"
    fi
    bash "$MODULE_DIR/module_map_contigs_sam_pair.sh" "$sample" "$renamed_fa" "$bowtie_out_dir" "$map_sam_out_dir" "$THREADS" "$ENV_BOWTIE2" || { echo "module_map_contigs_sam_pair failed for $sample"; set -e; continue; }
  fi

  # 7) convert SAM to sorted BAM (samtools)
  if (( START_MODULE <= 7 )); then
    bash "$MODULE_DIR/module_map_contigs_bam.sh" "$sample" "${map_sam_out_dir}/${sample}.sam" "$megahit_sample_dir" "$THREADS" "$ENV_SAMTOOLS" || { echo "module_map_contigs_bam failed for $sample"; set -e; continue; }
  fi

  # 8) binning: metabat2 (Docker)
  # Generates depth file and bins contigs into MAGs
  if (( START_MODULE <= 8 )); then
    mkdir -p "$metab_out_dir"
    if [[ -z "${renamed_fa:-}" ]]; then
      renamed_fa="${megahit_sample_dir}/${sample}_contigs.fasta"
    fi
    bam_file="${megahit_sample_dir}/${sample}.bam"
    bash "$MODULE_DIR/module_metabat2_docker.sh" "$sample" "$renamed_fa" "$bam_file" "$metab_out_dir" "$THREADS" "$METABAT_DOCKER_IMG" "$MIN_CONTIG_LEN" || { echo "module_metabat2 failed for $sample"; set -e; continue; }
  fi

  # 9) binning: maxbin2
  # Uses depth file generated by metabat2 in module 8
  if (( START_MODULE <= 9 )); then
    mkdir -p "$maxbin_out_dir"
    if [[ -z "${renamed_fa:-}" ]]; then
      renamed_fa="${megahit_sample_dir}/${sample}_contigs.fasta"
    fi
    depth_file="${metab_out_dir}/${sample}.depth"
    bash "$MODULE_DIR/module_maxbin2.sh" "$sample" "$renamed_fa" "$depth_file" "$maxbin_out_dir" "$THREADS" "$ENV_MAXBIN2" || { echo "module_maxbin2 failed for $sample"; set -e; continue; }
  fi

  set -e
  echo "✅ Muestra $sample completada"
done

echo "Pipeline trim->binning completado"
