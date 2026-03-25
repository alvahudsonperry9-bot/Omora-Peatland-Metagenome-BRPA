#!/bin/bash
set -euo pipefail

#############################################
#            CONFIGURACIÓN
#############################################

THREADS=30
MIN_CONTIG_LEN=2000

ENV_BOWTIE2="bowtie2"
ENV_SAMTOOLS="samtools_1.21"
ENV_SEMIBIN2="semibin2"

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"

READS_SUBDIR="004_quality_clean4"
MEGAHIT_SUBDIR="005_megahit"
MULTI_SUBDIR="001_multi"
CONTIGS_FILE="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/001_multi/concatenated.fa"

SAM_DIR="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${MULTI_SUBDIR}"
BAM_DIR="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${MULTI_SUBDIR}"
SEMIBIN_OUTPUT_DIR="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}"

ERROR_LOG="${DISK_A}/${BASE_REL}/001_Scripts/semibin2_multi_errors.log"

MUESTRAS=(
  A02_P4-2 A04_P2-4 A06_P1-6 A07_P4-7 A09_P4-9 A12_P1-12
  A01_P1-1 A03_P1-3 A04_P4-4 A06_P2-6 A08_P1-8 A10_P1-10 A13_P1-13
  A01_P2-1 A03_P2-3 A05_P1-5 A06_P4-6 A08_P4-8 A10_P2-10 A14_P1-14
  A01_P4-1 A03_P4-3 A05_P2-5 A07_P1-7 A09_P1-9 A11_P1-11
  A02_P2-2 A04_P1-4 A05_P4-5 A07_P2-7 A09_P2-9 A11_P2-11
)

#############################################
#               UTILIDADES
#############################################

log_error() {
  local scope="$1"
  local step="$2"
  echo "❌ ${scope} | ${step} | $(date '+%F %T')" >> "$ERROR_LOG"
  echo "❌ ERROR en ${step} (${scope})"
}

run_cmd_bash() {
  local env="$1"
  local cmd="$2"
  local scope="$3"
  local step="$4"

  echo "→ [${step}] (${scope})"
  if ! conda run -n "$env" bash -lc "$cmd"; then
    log_error "$scope" "$step"
    return 1
  fi
  return 0
}

run_cmd_array() {
  local env="$1"
  local scope="$2"
  local step="$3"
  shift 3

  echo "→ [${step}] (${scope})"
  if ! conda run -n "$env" "$@"; then
    log_error "$scope" "$step"
    return 1
  fi
  return 0
}

check_file() {
  local file="$1"
  [[ -f "$file" && -s "$file" ]]
}

usage() {
  cat <<'EOF'
Uso:
  008_Semibin2_multi.sh [--start-step 1|2] [--end-step 1|2]

Pasos:
  1 = mapear lecturas nonhuman_unmapped a concatenated.fa y generar SAM/BAM
  2 = ejecutar SemiBin2 multi_easy_bin con los BAM

Comportamiento por defecto:
  --start-step 1 --end-step 2 (ejecuta todo)

Ejemplos:
  ./008_Semibin2_multi.sh
  ./008_Semibin2_multi.sh --start-step 1 --end-step 1
  ./008_Semibin2_multi.sh --start-step 2 --end-step 2
EOF
}

find_reads_for_sample() {
  local sample="$1"
  local r1_a="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}/${READS_SUBDIR}/${sample}/${sample}_nonhuman_unmapped.1.gz"
  local r2_a="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}/${READS_SUBDIR}/${sample}/${sample}_nonhuman_unmapped.2.gz"
  local r1_b="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}/${READS_SUBDIR}/${sample}/${sample}_nonhuman_unmapped.1.gz"
  local r2_b="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}/${READS_SUBDIR}/${sample}/${sample}_nonhuman_unmapped.2.gz"

  if check_file "$r1_a" && check_file "$r2_a"; then
    printf '%s\n' "$r1_a" "$r2_a"
    return 0
  fi

  if check_file "$r1_b" && check_file "$r2_b"; then
    printf '%s\n' "$r1_b" "$r2_b"
    return 0
  fi

  return 1
}

list_existing_bams() {
  local sample
  for sample in "${MUESTRAS[@]}"; do
    local bam_file="${BAM_DIR}/${sample}.bam"
    if check_file "$bam_file"; then
      printf '%s\n' "$bam_file"
    fi
  done
}

#############################################
#         PASO 1: MAPEAR Y BAM
#############################################

run_step_1_mapping() {
  echo ""
  echo "--- PASO 1: MAPEAR LECTURAS Y CREAR SAM/BAM ---"

  check_file "$CONTIGS_FILE" || {
    echo "❌ No existe contig concatenado: $CONTIGS_FILE"
    return 1
  }

  mkdir -p "$SAM_DIR" "$BAM_DIR"

  local index_prefix="${BAM_DIR}/concatenated_bt2_idx"
  if ! check_file "${index_prefix}.1.bt2"; then
    if ! run_cmd_bash "$ENV_BOWTIE2" \
      "bowtie2-build --threads ${THREADS} '${CONTIGS_FILE}' '${index_prefix}'" \
      "CO-ASSEMBLY" "Bowtie2-build-index"; then
      return 1
    fi
  else
    echo "✓ Índice Bowtie2 detectado, se reutiliza"
  fi

  local ok_count=0
  local sample
  for sample in "${MUESTRAS[@]}"; do
    echo ""
    echo "Procesando muestra: $sample"

    local reads
    if ! reads="$(find_reads_for_sample "$sample")"; then
      echo "⚠️ Lecturas faltantes para $sample (_nonhuman_unmapped.1.gz/.2.gz)"
      log_error "$sample" "Lecturas-nonhuman-unmapped-no-encontradas"
      continue
    fi

    local r1
    local r2
    r1="$(printf '%s\n' "$reads" | sed -n '1p')"
    r2="$(printf '%s\n' "$reads" | sed -n '2p')"

    local sam_file="${SAM_DIR}/${sample}.sam"
    local bam_file="${BAM_DIR}/${sample}.bam"

    if ! run_cmd_bash "$ENV_BOWTIE2" \
      "bowtie2 -p ${THREADS} -x '${index_prefix}' -1 '${r1}' -2 '${r2}' -S '${sam_file}'" \
      "$sample" "Bowtie2-map-to-concatenated"; then
      continue
    fi

    if ! run_cmd_bash "$ENV_SAMTOOLS" \
      "samtools view -@ ${THREADS} -bS '${sam_file}' | samtools sort -@ ${THREADS} -o '${bam_file}' -" \
      "$sample" "SAM-to-sorted-BAM"; then
      continue
    fi

    if ! run_cmd_bash "$ENV_SAMTOOLS" \
      "samtools index -@ ${THREADS} '${bam_file}'" \
      "$sample" "Index-BAM"; then
      continue
    fi

    ok_count=$((ok_count + 1))
    echo "✓ Muestra $sample con SAM y BAM"
  done

  if [[ "$ok_count" -eq 0 ]]; then
    echo "❌ No se generó ningún BAM válido"
    return 1
  fi

  echo ""
  echo "✓ Paso 1 completado: ${ok_count}/${#MUESTRAS[@]} muestras procesadas"
  return 0
}

#############################################
#         PASO 2: SEMIBIN2 MULTI
#############################################

run_step_2_semibin() {
  echo ""
  echo "--- PASO 2: SEMIBIN2 MULTI ---"

  check_file "$CONTIGS_FILE" || {
    echo "❌ No existe contig concatenado: $CONTIGS_FILE"
    return 1
  }

  mapfile -t bams_list < <(list_existing_bams)
  if [[ "${#bams_list[@]}" -eq 0 ]]; then
    echo "❌ No hay BAMs válidos en $BAM_DIR"
    return 1
  fi

  mkdir -p "$SEMIBIN_OUTPUT_DIR"

  local semibin_args=(
    SemiBin2 multi_easy_bin
    -i "$CONTIGS_FILE"
    -o "$SEMIBIN_OUTPUT_DIR"
    -b
  )

  local bam
  for bam in "${bams_list[@]}"; do
    semibin_args+=("$bam")
  done

  semibin_args+=(
    -p "$THREADS"
    -m "$MIN_CONTIG_LEN"
  )

  echo "BAMs usados (${#bams_list[@]}):"
  for bam in "${bams_list[@]}"; do
    echo "  - $bam"
  done

  if ! run_cmd_array "$ENV_SEMIBIN2" "CO-ASSEMBLY" "SemiBin2-multi_easy_bin" "${semibin_args[@]}"; then
    return 1
  fi

  echo ""
  echo "✓ Paso 2 completado"
  return 0
}

#############################################
#                 MAIN
#############################################

main() {
  local start_step=1
  local end_step=2

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --start-step)
        [[ "${2:-}" =~ ^[12]$ ]] || { echo "❌ --start-step debe ser 1 o 2"; usage; exit 1; }
        start_step="$2"
        shift 2
        ;;
      --end-step)
        [[ "${2:-}" =~ ^[12]$ ]] || { echo "❌ --end-step debe ser 1 o 2"; usage; exit 1; }
        end_step="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "❌ Opción no reconocida: $1"
        usage
        exit 1
        ;;
    esac
  done

  if (( start_step > end_step )); then
    echo "❌ --start-step no puede ser mayor que --end-step"
    exit 1
  fi

  echo "=========================================================="
  echo "🧬 SemiBin2 multi (modular 2 pasos)"
  echo "=========================================================="
  echo "Muestras: ${#MUESTRAS[@]}"
  echo "Hilos: $THREADS"
  echo "Contigs: $CONTIGS_FILE"
  echo "SAM dir: $SAM_DIR"
  echo "BAM dir: $BAM_DIR"
  echo "Salida SemiBin2: $SEMIBIN_OUTPUT_DIR"
  echo "Rango de ejecución: paso $start_step -> paso $end_step"

  if (( start_step <= 1 && end_step >= 1 )); then
    run_step_1_mapping
  fi

  if (( start_step <= 2 && end_step >= 2 )); then
    run_step_2_semibin
  fi

  echo ""
  echo "=========================================================="
  echo "✅ Proceso finalizado"
  echo "=========================================================="
}

main "$@"

