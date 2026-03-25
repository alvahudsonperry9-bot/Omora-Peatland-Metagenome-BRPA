#!/bin/bash
set -euo pipefail

if [[ $# -lt 10 ]]; then
  echo "Uso: $0 <input_blastp_dir> <output_final_dir> <scripts_dir> <python_cmd> <min_identity_or_empty> <max_evalue_or_empty> <min_bit_score_or_empty> <criterion> <gtdb_ar53_tsv> <gtdb_bac120_tsv> [show_filters:0|1]"
  exit 1
fi

INPUT_BLASTP_DIR="$1"
OUTPUT_FINAL_DIR="$2"
SCRIPTS_DIR="$3"
PYTHON_CMD="$4"
MIN_IDENTITY="$5"
MAX_EVALUE="$6"
MIN_BIT_SCORE="$7"
CRITERION="$8"
GTDB_AR53_TSV="$9"
GTDB_BAC120_TSV="${10}"
SHOW_FILTERS="${11:-0}"

KO_SELECTOR_PY="$SCRIPTS_DIR/ko_selector_deep.py"
KO_LIST_FILE="$SCRIPTS_DIR/ko_list.txt"
BIO_FILTER_PY="$SCRIPTS_DIR/ko_biological_route_filter.py"
DICT_FILE="$SCRIPTS_DIR/dictionary.txt"

if [[ ! -d "$INPUT_BLASTP_DIR" ]]; then
  echo "❌ No existe directorio BLASTP: $INPUT_BLASTP_DIR"
  exit 1
fi

if [[ ! -f "$KO_SELECTOR_PY" ]]; then
  echo "❌ No existe: $KO_SELECTOR_PY"
  exit 1
fi

if [[ ! -f "$KO_LIST_FILE" ]]; then
  echo "❌ No existe: $KO_LIST_FILE"
  exit 1
fi

if [[ ! -f "$BIO_FILTER_PY" ]]; then
  echo "❌ No existe: $BIO_FILTER_PY"
  exit 1
fi

if [[ ! -f "$DICT_FILE" ]]; then
  echo "❌ No existe: $DICT_FILE"
  exit 1
fi

if [[ ! -f "$GTDB_AR53_TSV" ]]; then
  echo "❌ No existe GTDB ar53 TSV: $GTDB_AR53_TSV"
  exit 1
fi

if [[ ! -f "$GTDB_BAC120_TSV" ]]; then
  echo "❌ No existe GTDB bac120 TSV: $GTDB_BAC120_TSV"
  exit 1
fi

FILTERED_DIR="$OUTPUT_FINAL_DIR/filtered_blastp"
METADATA_FILE="$OUTPUT_FINAL_DIR/metadata_blastp.tsv"
LOG_FILE="$OUTPUT_FINAL_DIR/module3_ko_selector.log"

mkdir -p "$OUTPUT_FINAL_DIR"
mkdir -p "$FILTERED_DIR"

echo -e "Blastp_directory\tSample_ID" > "$METADATA_FILE"

mapfile -t BLAST_FILES < <(find "$INPUT_BLASTP_DIR" -type f -name "*.blastp" | sort)

if [[ ${#BLAST_FILES[@]} -eq 0 ]]; then
  echo "❌ No se encontraron archivos .blastp en: $INPUT_BLASTP_DIR"
  exit 1
fi

for blast_file in "${BLAST_FILES[@]}"; do
  sample_id="$(basename "$blast_file" .blastp)"
  echo -e "${blast_file}\t${sample_id}" >> "$METADATA_FILE"
done

echo "[M3] Ejecutando ko_selector_deep.py"

CMD=(
  "$PYTHON_CMD" "$KO_SELECTOR_PY"
  --metadata "$METADATA_FILE"
  --ko_list "$KO_LIST_FILE"
  --criterion "$CRITERION"
  --output_dir "$FILTERED_DIR"
)

if [[ -n "$MIN_IDENTITY" ]]; then
  CMD+=(--min_identity "$MIN_IDENTITY")
fi
if [[ -n "$MAX_EVALUE" ]]; then
  CMD+=(--max_evalue "$MAX_EVALUE")
fi
if [[ -n "$MIN_BIT_SCORE" ]]; then
  CMD+=(--min_bit_score "$MIN_BIT_SCORE")
fi

{
  echo "[$(date '+%F %T')] Iniciando M3"
  echo "[$(date '+%F %T')] Metadata: $METADATA_FILE"
  "${CMD[@]}"
  echo "[$(date '+%F %T')] Ejecutando filtro biológico intermedio"
  BIO_CMD=(
    "$PYTHON_CMD" "$BIO_FILTER_PY"
    --filtered_dir "$FILTERED_DIR"
    --dictionary "$DICT_FILE"
    --gtdb-ar53 "$GTDB_AR53_TSV"
    --gtdb-bac120 "$GTDB_BAC120_TSV"
  )
  if [[ "$SHOW_FILTERS" -eq 1 ]]; then
    BIO_CMD+=(--show-filters)
  fi
  "${BIO_CMD[@]}"
  echo "[$(date '+%F %T')] Finalizando M3"
} 2>&1 | tee -a "$LOG_FILE"

echo "[M3] ✅ Filtrado KO finalizado"
