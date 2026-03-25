#!/bin/bash
set -euo pipefail

# 004_run_coassembly.sh
# Co-assembly (A00_Co) from repaired reads -> megahit -> filter/map -> metabat2 -> maxbin2

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"
OUT4_SUBDIR="004_quality_clean4"
MEGAHIT_SUBDIR="005_megahit"
COASSEMBLY_SAMPLE="A00_Co"

THREADS=31
START_MODULE=8 # 4=megahit,7=rename,8=map_sam,9=map_bam,10=metabat2,11=maxbin2
END_MODULE=11
MEGAHIT_MEM_G=120
MIN_CONTIG_LEN=2000
MIN_CONTIG_ASSEMBLY=2000
FORCE_REBUILD=0

ENV_MEGAHIT="megahit"
ENV_BOWTIE2="bowtie2"
ENV_SAMTOOLS="samtools_1.21"
ENV_MAXBIN2="maxbin2_env"
METABAT_DOCKER_IMG="metabat/metabat:latest"

MODULE_DIR="${DISK_A}/${BASE_REL}/001_Scripts/modulos"

DEFAULT_SAMPLES="A01_P1-1,A01_P2-1,A01_P4-1,A02_P2-2,A02_P4-2,A03_P1-3,A03_P2-3,A03_P4-3,A04_P1-4,A04_P2-4,A04_P4-4,A05_P1-5,A05_P2-5,A05_P4-5,A06_P1-6,A06_P2-6,A06_P4-6,A07_P1-7,A07_P2-7,A07_P4-7,A08_P1-8,A08_P4-8,A09_P1-9,A09_P2-9,A09_P4-9,A10_P1-10,A10_P2-10,A11_P1-11,A11_P2-11,A12_P1-12,A13_P1-13,A14_P1-14"

usage(){
  echo "Usage: $0 [-a DISK_A] [-b DISK_B] [-s SAMPLE_TYPE] [-t THREADS] [-m START_MODULE] [-e END_MODULE] [-L sample1,sample2] [-f]"
  exit 1
}

while getopts ":a:b:s:t:m:e:L:f" opt; do
  case $opt in
    a) DISK_A="$OPTARG";;
    b) DISK_B="$OPTARG";;
    s) SAMPLE_TYPE="$OPTARG";;
    t) THREADS="$OPTARG";;
    m) START_MODULE="$OPTARG";;
    e) END_MODULE="$OPTARG";;
    L) MANUAL_SAMPLES="$OPTARG";;
    f) FORCE_REBUILD=1;;
    *) usage;;
  esac
done

if [[ -n "${MANUAL_SAMPLES:-}" ]]; then
  IFS=',' read -r -a SAMPLES <<< "${MANUAL_SAMPLES}"
  echo "Using manual sample list: ${SAMPLES[*]}"
else
  IFS=',' read -r -a SAMPLES <<< "${DEFAULT_SAMPLES}"
fi

SAMPLE_TYPE_DIR_A="${DISK_A}/${BASE_REL}/${SAMPLE_TYPE}"
SAMPLE_TYPE_DIR_B="${DISK_B}/${BASE_REL}/${SAMPLE_TYPE}"

READS_DIR_A="${SAMPLE_TYPE_DIR_A}/${OUT4_SUBDIR}"
READS_DIR_B="${SAMPLE_TYPE_DIR_B}/${OUT4_SUBDIR}"

if [[ -d "$READS_DIR_A" && -n "$(ls -A "$READS_DIR_A" 2>/dev/null)" ]]; then
  INPUT_DISK="$DISK_A"
  OTHER_DISK="$DISK_B"
elif [[ -d "$READS_DIR_B" && -n "$(ls -A "$READS_DIR_B" 2>/dev/null)" ]]; then
  INPUT_DISK="$DISK_B"
  OTHER_DISK="$DISK_A"
else
  echo "${OUT4_SUBDIR} not found in $READS_DIR_A or $READS_DIR_B"
  exit 1
fi

READS_DIR="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${OUT4_SUBDIR}"
CO_DIR_INPUT="${INPUT_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${COASSEMBLY_SAMPLE}"
CO_DIR_OTHER="${OTHER_DISK}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${COASSEMBLY_SAMPLE}"

VALID_SAMPLES=()
R1_FILES=()
R2_FILES=()
FORWARD_LIST=""
REVERSE_LIST=""

build_read_lists(){
  VALID_SAMPLES=()
  R1_FILES=()
  R2_FILES=()

  for sample in "${SAMPLES[@]}"; do
    # Require human-filtered unmapped reads produced by host-removal (must be present and paired)
    r1_h_a_gz="${READS_DIR_A}/${sample}/${sample}_nonhuman_unmapped.1.gz"
    r2_h_a_gz="${READS_DIR_A}/${sample}/${sample}_nonhuman_unmapped.2.gz"
    r1_h_a="${READS_DIR_A}/${sample}/${sample}_nonhuman_unmapped.1"
    r2_h_a="${READS_DIR_A}/${sample}/${sample}_nonhuman_unmapped.2"

    r1_h_b_gz="${READS_DIR_B}/${sample}/${sample}_nonhuman_unmapped.1.gz"
    r2_h_b_gz="${READS_DIR_B}/${sample}/${sample}_nonhuman_unmapped.2.gz"
    r1_h_b="${READS_DIR_B}/${sample}/${sample}_nonhuman_unmapped.1"
    r2_h_b="${READS_DIR_B}/${sample}/${sample}_nonhuman_unmapped.2"

    if [[ -s "$r1_h_a_gz" && -s "$r2_h_a_gz" ]]; then
      VALID_SAMPLES+=("$sample")
      R1_FILES+=("$r1_h_a_gz")
      R2_FILES+=("$r2_h_a_gz")
    elif [[ -s "$r1_h_a" && -s "$r2_h_a" ]]; then
      VALID_SAMPLES+=("$sample")
      R1_FILES+=("$r1_h_a")
      R2_FILES+=("$r2_h_a")
    elif [[ -s "$r1_h_b_gz" && -s "$r2_h_b_gz" ]]; then
      VALID_SAMPLES+=("$sample")
      R1_FILES+=("$r1_h_b_gz")
      R2_FILES+=("$r2_h_b_gz")
    elif [[ -s "$r1_h_b" && -s "$r2_h_b" ]]; then
      VALID_SAMPLES+=("$sample")
      R1_FILES+=("$r1_h_b")
      R2_FILES+=("$r2_h_b")
    else
      echo "[coassembly] No paired 'nonhuman_unmapped' reads found for $sample — skipping (fallback to repair files not allowed)"
    fi
  done

  if [[ ${#R1_FILES[@]} -eq 0 ]]; then
    echo "[coassembly] No reads found for co-assembly"
    exit 1
  fi

  FORWARD_LIST=$(printf "%s," "${R1_FILES[@]}" | sed 's/,$//')
  REVERSE_LIST=$(printf "%s," "${R2_FILES[@]}" | sed 's/,$//')
}

  # helper: return 0 if module should run (between START_MODULE and END_MODULE)
  should_run(){
    local mod=$1
    if (( mod >= START_MODULE && mod <= END_MODULE )); then
      return 0
    else
      return 1
    fi
  }

if should_run 4; then
  build_read_lists

  if [[ -d "$CO_DIR_INPUT" ]]; then
    if [[ -s "${CO_DIR_INPUT}/final.contigs.fa" && $FORCE_REBUILD -eq 0 ]]; then
      echo "[coassembly] Output already exists with final.contigs.fa, skipping megahit"
    else
      ts=$(date +%s)
      backup_dir="${CO_DIR_INPUT}_backup_${ts}"
      echo "[coassembly] Moving $CO_DIR_INPUT to $backup_dir"
      mv "$CO_DIR_INPUT" "$backup_dir"
    fi
  fi

  if [[ ! -s "${CO_DIR_INPUT}/final.contigs.fa" ]]; then
    echo "[coassembly] Running megahit with read lists"
    conda run -n "$ENV_MEGAHIT" bash -lc "megahit -1 '${FORWARD_LIST}' -2 '${REVERSE_LIST}' -t ${THREADS} --memory ${MEGAHIT_MEM_G} --k-min 27 --k-step 10 --min-contig-len ${MIN_CONTIG_ASSEMBLY} -o '${CO_DIR_INPUT}'"
  fi
fi

other_base="${CO_DIR_OTHER}"
metab_out_dir="${other_base}/001_Metabat2"
maxbin_out_dir="${other_base}/001_Maxbin2"

# Module 6 removed: megahit already filters with --min-contig-len, no re-filtering needed

if should_run 7; then
  assembly_fa="${CO_DIR_INPUT}/final.contigs.fa"
  renamed_fa="${CO_DIR_INPUT}/${COASSEMBLY_SAMPLE}_contigs_renamed.fasta"
  # 7) Rename headers: sample:contig (directly from final.contigs.fa)
  bash "$MODULE_DIR/module_rename_contigs.sh" \
    "$COASSEMBLY_SAMPLE" "${assembly_fa}" "${renamed_fa}" || { echo "module_rename_contigs failed"; exit 1; }
fi

if should_run 8; then
  # Build lists if they don't exist (in case module 4 is skipped)
  if [[ -z "${FORWARD_LIST}" || -z "${REVERSE_LIST}" ]]; then
    build_read_lists
  fi
  renamed_fa="${CO_DIR_INPUT}/${COASSEMBLY_SAMPLE}_contigs_renamed.fasta"
  # 8) Map combined lists -> SAM (on OTHER_DISK)
  bash "$MODULE_DIR/module_map_contigs_sam_list.sh" "$COASSEMBLY_SAMPLE" "${renamed_fa}" "${FORWARD_LIST}" "${REVERSE_LIST}" "$CO_DIR_OTHER" "$THREADS" "$ENV_BOWTIE2" || { echo "module_map_contigs_sam_list failed"; exit 1; }
fi

if should_run 9; then
  # 9) Convert SAM -> BAM and sort (on INPUT_DISK)
  bash "$MODULE_DIR/module_map_contigs_bam.sh" "$COASSEMBLY_SAMPLE" "${CO_DIR_OTHER}/${COASSEMBLY_SAMPLE}.sam" "$CO_DIR_INPUT" "$THREADS" "$ENV_SAMTOOLS" || { echo "module_map_contigs_bam failed"; exit 1; }
fi

if should_run 10; then
  mkdir -p "$metab_out_dir"
  bam_file="${CO_DIR_INPUT}/${COASSEMBLY_SAMPLE}.bam"
  renamed_fa="${CO_DIR_INPUT}/${COASSEMBLY_SAMPLE}_contigs_renamed.fasta"
  bash "$MODULE_DIR/module_metabat2_docker.sh" \
    "$COASSEMBLY_SAMPLE" "${renamed_fa}" \
    "$bam_file" "$metab_out_dir" "$THREADS" "$METABAT_DOCKER_IMG" "$MIN_CONTIG_LEN"
fi
