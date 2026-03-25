#!/bin/bash
set -euo pipefail

SCRIPT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Scripts/modulos2"
MODULE_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Scripts/modulos2"

PROKKA_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/008_Prokka_28_02_2026"
BLAST_DB_INPUT="/media/pinguicula/1T_BRPA/Blastp/DB_22_02_2026"
OUTPUT_BLASTP_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/009_blastp_28_02_202"
OUTPUT_FINAL_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/010_final_genes_28_02_202"
GTDB_AR53_TSV="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026/002_gtdbtk/gtdbtk.ar53.summary.tsv"
GTDB_BAC120_TSV="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026/002_gtdbtk/gtdbtk.bac120.summary.tsv"

THREADS=31
QCOV_HSP_PERC=30

ENV_BLASTP="blast"
PYTHON_CMD="python"

MIN_IDENTITY="40"
MAX_EVALUE="1e-10"
MIN_BIT_SCORE="150"
CRITERION=2
MATRIX_OUTPUT_NAME="gene_presence_matrix.tsv"

START_MODULE=2
END_MODULE=4
SHOW_ENVS=0
SHOW_BIO_FILTERS=0

usage() {
  cat << 'EOF'
Usage:
  007_blastp_to_geneID.sh [options]

Modular pipeline:
  M2: BLASTP from Prokka .faa files
  M3: ko_selector_deep.py (auto-generates metadata from .blastp)
  M4: gene_presence_matrix.py

Path options:
  --prokka-dir PATH           Directory with Prokka results (.faa)
  --blast-db PATH             BLAST DB prefix or directory with .pin files
  --output-blastp-dir PATH    BLASTP output (created if it does not exist)
  --output-final-dir PATH     Final output (created if it does not exist)
  --gtdb-ar53-tsv PATH        Path to gtdbtk.ar53.summary.tsv
  --gtdb-bac120-tsv PATH      Path to gtdbtk.bac120.summary.tsv
  --script-dir PATH           Directory of Python scripts/data (default 001_Scripts/modulos2)
  --module-dir PATH           Module directory (default 001_Scripts/modulos2)

General execution options:
  --threads INT               Threads for BLASTP
  --start-module INT          Starting module (2..4)
  --end-module INT            Ending module (2..4)
  --show-envs                 Shows configured environment names and exits
  --show-bio-filters          Shows prohibited biological paths and exits

Environment/command options:
  --env-blastp NAME           Conda environment for BLASTP
  --python-cmd CMD            Python command for modules 3 and 4 (e.g.: python, python3)

M2 options (BLASTP):
  --qcov FLOAT                Value for -qcov_hsp_perc (default: 30)

M3 options (ko_selector_deep.py):
  --min-identity FLOAT        Minimum pident filter (optional)
  --max-evalue FLOAT          Maximum evalue filter (optional)
  --min-bit-score FLOAT       Minimum bitscore filter (optional)
  --criterion INT             1=Alignment Length, 2=Query Length

M4 options (matrix):
  --matrix-output-name NAME   Matrix file name in output_final_dir

Notes:
  - This global script does not run Prokka.
  - By default runs modules 2 to 4.
  - To resume, use --start-module and/or --end-module.
  - M3 does not need a manual sample list: detects .blastp files automatically.

Examples:
  007_blastp_to_geneID.sh
  007_blastp_to_geneID.sh --start-module 2 --end-module 4
  007_blastp_to_geneID.sh --threads 40 --min-identity 40 --max-evalue 1e-20 --criterion 2
  007_blastp_to_geneID.sh --show-envs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prokka-dir) PROKKA_DIR="$2"; shift 2 ;;
    --blast-db) BLAST_DB_INPUT="$2"; shift 2 ;;
    --output-blastp-dir) OUTPUT_BLASTP_DIR="$2"; shift 2 ;;
    --output-final-dir) OUTPUT_FINAL_DIR="$2"; shift 2 ;;
    --gtdb-ar53-tsv) GTDB_AR53_TSV="$2"; shift 2 ;;
    --gtdb-bac120-tsv) GTDB_BAC120_TSV="$2"; shift 2 ;;
    --script-dir) SCRIPT_DIR="$2"; shift 2 ;;
    --module-dir) MODULE_DIR="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --start-module) START_MODULE="$2"; shift 2 ;;
    --end-module) END_MODULE="$2"; shift 2 ;;
    --show-envs) SHOW_ENVS=1; shift 1 ;;
    --show-bio-filters) SHOW_BIO_FILTERS=1; shift 1 ;;
    --env-blastp) ENV_BLASTP="$2"; shift 2 ;;
    --python-cmd) PYTHON_CMD="$2"; shift 2 ;;
    --qcov) QCOV_HSP_PERC="$2"; shift 2 ;;
    --min-identity) MIN_IDENTITY="$2"; shift 2 ;;
    --max-evalue) MAX_EVALUE="$2"; shift 2 ;;
    --min-bit-score) MIN_BIT_SCORE="$2"; shift 2 ;;
    --criterion) CRITERION="$2"; shift 2 ;;
    --matrix-output-name) MATRIX_OUTPUT_NAME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unrecognized option: $1"; usage; exit 1 ;;
  esac
done

if (( START_MODULE < 2 || START_MODULE > 4 )); then
  echo "❌ --start-module must be between 2 and 4"
  exit 1
fi

if (( END_MODULE < 2 || END_MODULE > 4 )); then
  echo "❌ --end-module must be between 2 and 4"
  exit 1
fi

if (( START_MODULE > END_MODULE )); then
  echo "❌ --start-module cannot be greater than --end-module"
  exit 1
fi

if [[ "$CRITERION" != "1" && "$CRITERION" != "2" ]]; then
  echo "❌ --criterion must be 1 or 2"
  exit 1
fi

if [[ $SHOW_ENVS -eq 1 ]]; then
  echo "BLASTP environment : $ENV_BLASTP"
  echo "Python command     : $PYTHON_CMD"
  exit 0
fi

if [[ $SHOW_BIO_FILTERS -eq 1 ]]; then
  "$PYTHON_CMD" "$SCRIPT_DIR/ko_biological_route_filter.py" \
    --filtered_dir "$OUTPUT_FINAL_DIR/filtered_blastp" \
    --dictionary "$SCRIPT_DIR/dictionary.txt" \
    --gtdb-ar53 "$GTDB_AR53_TSV" \
    --gtdb-bac120 "$GTDB_BAC120_TSV" \
    --show-filters
  exit 0
fi

M2="$MODULE_DIR/module2_blastp_from_prokka.sh"
M3="$MODULE_DIR/module3_ko_selector.sh"
M4="$MODULE_DIR/module4_gene_presence_matrix.sh"

for mod in "$M2" "$M3" "$M4"; do
  if [[ ! -f "$mod" ]]; then
    echo "❌ Missing module: $mod"
    exit 1
  fi
done

mkdir -p "$OUTPUT_BLASTP_DIR" "$OUTPUT_FINAL_DIR"

echo "========================================"
echo "007_blastp_to_geneID.sh"
echo "Modules: ${START_MODULE} -> ${END_MODULE}"
echo "Input Prokka   : $PROKKA_DIR"
echo "Output BLASTP  : $OUTPUT_BLASTP_DIR"
echo "Output Final   : $OUTPUT_FINAL_DIR"
echo "GTDB ar53 TSV  : $GTDB_AR53_TSV"
echo "GTDB bac120 TSV: $GTDB_BAC120_TSV"
echo "BLAST DB input : $BLAST_DB_INPUT"
echo "Threads        : $THREADS"
echo "KO Criterion   : $CRITERION"
echo "========================================"

if (( START_MODULE <= 2 && END_MODULE >= 2 )); then
  bash "$M2" "$PROKKA_DIR" "$OUTPUT_BLASTP_DIR" "$BLAST_DB_INPUT" "$THREADS" "$ENV_BLASTP" "$QCOV_HSP_PERC"
fi

if (( START_MODULE <= 3 && END_MODULE >= 3 )); then
  bash "$M3" "$OUTPUT_BLASTP_DIR" "$OUTPUT_FINAL_DIR" "$SCRIPT_DIR" "$PYTHON_CMD" "$MIN_IDENTITY" "$MAX_EVALUE" "$MIN_BIT_SCORE" "$CRITERION" "$GTDB_AR53_TSV" "$GTDB_BAC120_TSV" "$SHOW_BIO_FILTERS"
fi

if (( START_MODULE <= 4 && END_MODULE >= 4 )); then
  bash "$M4" "$OUTPUT_FINAL_DIR" "$SCRIPT_DIR" "$PYTHON_CMD" "$MATRIX_OUTPUT_NAME"
fi

echo "✅ Pipeline completed"
