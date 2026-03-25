#!/bin/bash
set -euo pipefail

#############################################
#            CONFIGURATION
#############################################

THREADS=30
MIN_CONTIG_LEN=0

ENV_BOWTIE2="bowtie2"
ENV_SAMTOOLS="samtools_1.21"

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

ERROR_LOG="${DISK_A}/${BASE_REL}/001_Scripts/semibin2_multi_errors.log"

MUESTRAS=(
A01_P1-1 A01_P2-1 A01_P4-1
A02_P2-2 A02_P4-2
A03_P1-3 A03_P2-3 A03_P4-3
A04_P1-4 A04_P2-4 A04_P4-4
A05_P1-5 A05_P2-5 A05_P4-5
A06_P1-6 A06_P2-6 A06_P4-6
A07_P1-7 A07_P2-7 A07_P4-7
A08_P1-8 A08_P4-8
A09_P1-9 A09_P2-9 A09_P4-9
A10_P1-10 A10_P2-10
A11_P1-11 A11_P2-11
A12_P1-12
A13_P1-13
A14_P1-14
)

#############################################
#               UTILITIES
#############################################

log_error() {
  local scope="$1"
  local step="$2"
  echo "❌ ${scope} | ${step} | $(date '+%F %T')" >> "$ERROR_LOG"
  echo "❌ ERROR in ${step} (${scope})"
}

run_cmd_bash() {
  local env="$1"
  local cmd="$2"
  local scope="$3"
  local step="$4"

  echo "→ [${step}] (${scope})"
  if ! conda run --no-capture-output -n "$env" bash -lc "$cmd"; then
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
Usage:
  009_Semibin2_multi.sh

Step:
  1 = map nonhuman_unmapped reads to concatenated.fa and generate SAM/BAM

Default behavior:
  Runs step 1 (mapping)

Examples:
  ./009_Semibin2_multi.sh
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

#############################################
#         STEP 1: MAP READS AND CREATE BAM
#############################################

run_step_1_mapping() {
  echo ""
  echo "--- STEP 1: MAP READS AND CREATE SAM/BAM ---"

  check_file "$CONTIGS_FILE" || {
    echo "❌ Concatenated contig file does not exist: $CONTIGS_FILE"
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
    echo "✓ Bowtie2 index detected, reusing it"
  fi

  local ok_count=0
  local sample
  for sample in "${MUESTRAS[@]}"; do
    echo ""
    echo "Processing sample: $sample"

    local reads
    if ! reads="$(find_reads_for_sample "$sample")"; then
      echo "⚠️ Missing reads for $sample (_nonhuman_unmapped.1.gz/.2.gz)"
      log_error "$sample" "nonhuman-unmapped-reads-not-found"
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
    echo "✓ Sample $sample: SAM and BAM created"
  done

  if [[ "$ok_count" -eq 0 ]]; then
    echo "❌ No valid BAM was generated"
    return 1
  fi

  echo ""
  echo "✓ Step 1 completed: ${ok_count}/${#MUESTRAS[@]} samples processed"
  return 0
}

#############################################
#                 MAIN
#############################################

main() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "❌ Unrecognized option: $1"
        usage
        exit 1
        ;;
    esac
  done

  echo "=========================================================="
  echo "🧬 Read mapping to concatenated contigs (modular step 1)"
  echo "=========================================================="
  echo "Samples: ${#MUESTRAS[@]}"
  echo "Threads: $THREADS"
  echo "Contigs: $CONTIGS_FILE"
  echo "SAM dir: $SAM_DIR"
  echo "BAM dir: $BAM_DIR"

  run_step_1_mapping

  echo ""
  echo "=========================================================="
  echo "✅ Process finished"
  echo "=========================================================="
}

main "$@"
