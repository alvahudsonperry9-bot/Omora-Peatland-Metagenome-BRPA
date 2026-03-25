#!/bin/bash
set -euo pipefail

# Script principal modular para trimming y QC
# Ubicación módulos: /media/pinguicula/8T_BRPA/Muestras/001_Scripts/modulos

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"
RAW_SUBDIR="000_raw"

QUALITY_A="001_quality_clean"
QUALITY_B="002_quality_clean2"

PREFIXES="A07_P1-7" # coma-separados; si vacío se detectan
R1_SUFFIX="_R1.fastq.gz"
R2_SUFFIX="_R2.fastq.gz"

THREADS=30
START_MODULE=1 # 1=trim_galore,2=trimmomatic,3=fastqc

# Trim Galore defaults
TRIMGALORE_QUALITY=20
TRIMGALORE_MINLEN=20

# Trimmomatic defaults
TRIMMOMATIC_MINLEN=50
TRIMMOMATIC_ADAPTERS="TruSeq3-PE.fa"
TRIMMOMATIC_SLIDINGWINDOW="4:20"
TRIMMOMATIC_LEADING=3
TRIMMOMATIC_TRAILING=3

ENV_TRIMGALORE="trim_galore"
ENV_TRIMMOMATIC="trimmomatic"
ENV_FASTQC="fastqc_env"

MODULE_DIR="${DISK_A}/${BASE_REL}/001_Scripts/modulos"

usage(){
  echo "Usage: $0 [-a DISK_A] [-b DISK_B] [-t THREADS] [-m START_MODULE] [-p PREFIXES] [-s SAMPLE_TYPE]"
  exit 1
}

while getopts ":a:b:t:m:p:s:q:L:n:d:w:X:Y:" opt; do
  case $opt in
    a) DISK_A="$OPTARG";;
    b) DISK_B="$OPTARG";;
    t) THREADS="$OPTARG";;
    m) START_MODULE="$OPTARG";;
    p) PREFIXES="$OPTARG";;
    s) SAMPLE_TYPE="$OPTARG";;
    q) TRIMGALORE_QUALITY="$OPTARG";;
    L) TRIMGALORE_MINLEN="$OPTARG";;
    n) TRIMMOMATIC_MINLEN="$OPTARG";;
    d) TRIMMOMATIC_ADAPTERS="$OPTARG";;
    w) TRIMMOMATIC_SLIDINGWINDOW="$OPTARG";;
    X) TRIMMOMATIC_LEADING="$OPTARG";;
    Y) TRIMMOMATIC_TRAILING="$OPTARG";;
    *) usage;;
  esac
done

# Allow manual sample list via env var MANUAL_SAMPLES (comma-separated), example: P1-14,P1-13
if [[ -n "${MANUAL_SAMPLES:-}" ]]; then
  PREFIXES="${MANUAL_SAMPLES}"
  echo "Usando lista manual de muestras (MANUAL_SAMPLES): ${PREFIXES}"
fi

SAMPLE_TYPE_DIR_A="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}"
SAMPLE_TYPE_DIR_B="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}"

# Determinar dónde están los RAW
RAW_DIR_A="${SAMPLE_TYPE_DIR_A}/${RAW_SUBDIR}"
RAW_DIR_B="${SAMPLE_TYPE_DIR_B}/${RAW_SUBDIR}"

if [[ -d "$RAW_DIR_A" && -n "$(ls -A "$RAW_DIR_A" 2>/dev/null)" ]]; then
  INPUT_DISK="$DISK_A"
  OTHER_DISK="$DISK_B"
elif [[ -d "$RAW_DIR_B" && -n "$(ls -A "$RAW_DIR_B" 2>/dev/null)" ]]; then
  INPUT_DISK="$DISK_B"
  OTHER_DISK="$DISK_A"
else
  echo "No se encontró RAW en ninguno de los discos: $RAW_DIR_A o $RAW_DIR_B"
  exit 1
fi

RAW_DIR="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${RAW_SUBDIR}"

mkdir -p "${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}"
mkdir -p "${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}"
mkdir -p "$MODULE_DIR"

# Detectar muestras
IFS=',' read -r -a SAMPLES_ARRAY <<< "${PREFIXES}"
if [[ -z "${PREFIXES// }" ]]; then
  mapfile -t SAMPLES_ARRAY < <(ls "$RAW_DIR"/*"${R1_SUFFIX}" 2>/dev/null | xargs -n1 basename | sed "s/${R1_SUFFIX}$//" | sort -u)
fi

if [[ ${#SAMPLES_ARRAY[@]} -eq 0 ]]; then
  echo "No se detectaron muestras en $RAW_DIR"
  exit 1
fi

echo "Procesando muestras: ${SAMPLES_ARRAY[*]}"

for sample in "${SAMPLES_ARRAY[@]}"; do
  echo "----------------------------------------"
  echo "Muestra: $sample"

  set +e
  in_r1="${RAW_DIR}/${sample}${R1_SUFFIX}"
  in_r2="${RAW_DIR}/${sample}${R2_SUFFIX}"
  if [[ ! -f "$in_r1" || ! -f "$in_r2" ]]; then
    echo "Archivos raw faltantes para $sample, saltando"
    set -e
    continue
  fi

  # Definir rutas alternadas:
  module1_out="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${QUALITY_A}/${sample}"
  module2_out="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${QUALITY_B}/${sample}"
  fastqc_outdir="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${QUALITY_A}/001/fastqc"

  mkdir -p "$module1_out"
  mkdir -p "$module2_out"
  mkdir -p "$fastqc_outdir"

  # Module 1: Trim Galore (reads from RAW_DIR, writes to module1_out on OTHER_DISK)
  if (( START_MODULE <= 1 )); then
    bash "$MODULE_DIR/module1_trim_galore.sh" \
      "$sample" "$RAW_DIR" "$module1_out" "$R1_SUFFIX" "$R2_SUFFIX" "$THREADS" "$ENV_TRIMGALORE" "$TRIMGALORE_QUALITY" "$TRIMGALORE_MINLEN"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "module1 failed for $sample (rc=$rc); continuing"
      set -e
      continue
    fi
  fi

  # Module 2: Trimmomatic (reads from module1_out on OTHER_DISK, writes to module2_out on INPUT_DISK)
  if (( START_MODULE <= 2 )); then
    bash "$MODULE_DIR/module2_trimmomatic.sh" \
      "$sample" "$module1_out" "$module2_out" "$R1_SUFFIX" "$R2_SUFFIX" "$THREADS" "$ENV_TRIMMOMATIC" \
      "$TRIMMOMATIC_MINLEN" "$TRIMMOMATIC_ADAPTERS" "$TRIMMOMATIC_SLIDINGWINDOW" "$TRIMMOMATIC_LEADING" "$TRIMMOMATIC_TRAILING"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "module2 failed for $sample (rc=$rc); continuing"
      set -e
      continue
    fi
  fi

  # Module 3: FastQC (reads from module2_out on INPUT_DISK, writes HTML to fastqc_outdir on OTHER_DISK)
  if (( START_MODULE <= 3 )); then
    bash "$MODULE_DIR/module3_fastqc.sh" \
      "$sample" "$module2_out" "$fastqc_outdir" "$THREADS" "$ENV_FASTQC"
    rc=$?
    if [[ $rc -ne 0 ]]; then
      echo "module3 failed for $sample (rc=$rc); continuing"
      set -e
      continue
    fi
  fi

  set -e
  echo "✅ Muestra $sample completada"
done

echo "Pipeline finalizado"
