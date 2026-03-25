#!/bin/bash
set -euo pipefail

if [[ $# -lt 6 ]]; then
  echo "Uso: $0 <input_prokka_dir> <output_blastp_dir> <blast_db_or_base_dir> <threads> <env_blastp> <qcov_hsp_perc>"
  exit 1
fi

INPUT_PROKKA_DIR="$1"
OUTPUT_BLASTP_DIR="$2"
BLAST_DB_INPUT="$3"
THREADS="$4"
ENV_BLASTP="$5"
QCOV_HSP_PERC="$6"

resolve_blast_db_prefix() {
  local db_input="$1"

  if [[ -f "${db_input}.pin" || -f "${db_input}.psq" || -f "${db_input}.phr" ]]; then
    echo "$db_input"
    return 0
  fi

  if [[ -d "$db_input" ]]; then
    local first_pin
    first_pin="$(find "$db_input" -maxdepth 1 -type f -name "*.pin" | sort | head -n 1 || true)"
    if [[ -n "$first_pin" ]]; then
      echo "${first_pin%.pin}"
      return 0
    fi
  fi

  return 1
}

if [[ ! -d "$INPUT_PROKKA_DIR" ]]; then
  echo "❌ No existe directorio Prokka: $INPUT_PROKKA_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_BLASTP_DIR"
mkdir -p "$OUTPUT_BLASTP_DIR/logs"

if ! DB_PREFIX="$(resolve_blast_db_prefix "$BLAST_DB_INPUT")"; then
  echo "❌ No se pudo resolver prefijo de base BLAST desde: $BLAST_DB_INPUT"
  echo "   Entrega prefijo de DB (sin .pin) o un directorio que contenga archivos .pin"
  exit 1
fi

echo "[M2] Usando BLAST DB: $DB_PREFIX"

mapfile -t FAA_FILES < <(find "$INPUT_PROKKA_DIR" -type f -name "*.faa" | sort)

if [[ ${#FAA_FILES[@]} -eq 0 ]]; then
  echo "❌ No se encontraron .faa dentro de: $INPUT_PROKKA_DIR"
  exit 1
fi

total_faa="${#FAA_FILES[@]}"
idx=0

for faa_file in "${FAA_FILES[@]}"; do
  ((idx+=1))
  sample_name="$(basename "$faa_file" .faa)"
  out_file="$OUTPUT_BLASTP_DIR/${sample_name}.blastp"
  log_file="$OUTPUT_BLASTP_DIR/logs/${sample_name}.blastp.log"

  echo "[M2] BLASTP -> $sample_name (${idx}/${total_faa})"
  {
    echo "[$(date '+%F %T')] Iniciando BLASTP: sample=$sample_name"
    echo "[$(date '+%F %T')] Query: $faa_file"
    echo "[$(date '+%F %T')] Output: $out_file"
    conda run --no-capture-output -n "$ENV_BLASTP" blastp \
    -query "$faa_file" \
    -db "$DB_PREFIX" \
    -out "$out_file" \
    -evalue 1e-10 \
    -num_threads "$THREADS" \
    -outfmt 6 \
    -qcov_hsp_perc "$QCOV_HSP_PERC"
    echo "[$(date '+%F %T')] BLASTP finalizado: sample=$sample_name"
  } 2>&1 | tee -a "$log_file"
done

echo "[M2] ✅ BLASTP finalizado"
