#!/bin/bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Uso: $0 <output_final_dir> <scripts_dir> <python_cmd> <matrix_output_name>"
  exit 1
fi

OUTPUT_FINAL_DIR="$1"
SCRIPTS_DIR="$2"
PYTHON_CMD="$3"
MATRIX_OUTPUT_NAME="$4"

FILTERED_DIR="$OUTPUT_FINAL_DIR/filtered_blastp"
GENE_MATRIX_PY="$SCRIPTS_DIR/gene_presence_matrix.py"
DICT_FILE="$SCRIPTS_DIR/dictionary.txt"
LOG_FILE="$OUTPUT_FINAL_DIR/module4_gene_presence.log"

if [[ ! -d "$FILTERED_DIR" ]]; then
  echo "❌ No existe directorio filtrado: $FILTERED_DIR"
  exit 1
fi

if [[ ! -f "$GENE_MATRIX_PY" ]]; then
  echo "❌ No existe: $GENE_MATRIX_PY"
  exit 1
fi

if [[ ! -f "$DICT_FILE" ]]; then
  echo "❌ No existe: $DICT_FILE"
  exit 1
fi

echo "[M4] Ejecutando gene_presence_matrix.py"

cp "$DICT_FILE" "$FILTERED_DIR/dictionary.txt"

{
  echo "[$(date '+%F %T')] Iniciando M4"
  (
    cd "$FILTERED_DIR"
    "$PYTHON_CMD" "$GENE_MATRIX_PY"
  )
  echo "[$(date '+%F %T')] Finalizando M4"
} 2>&1 | tee -a "$LOG_FILE"

if [[ "$MATRIX_OUTPUT_NAME" != "gene_presence_matrix.tsv" ]]; then
  if [[ -f "$FILTERED_DIR/gene_presence_matrix.tsv" ]]; then
    mv "$FILTERED_DIR/gene_presence_matrix.tsv" "$OUTPUT_FINAL_DIR/$MATRIX_OUTPUT_NAME"
  fi
else
  if [[ -f "$FILTERED_DIR/gene_presence_matrix.tsv" ]]; then
    cp "$FILTERED_DIR/gene_presence_matrix.tsv" "$OUTPUT_FINAL_DIR/gene_presence_matrix.tsv"
  fi
fi

echo "[M4] ✅ Matriz de presencia generada"
