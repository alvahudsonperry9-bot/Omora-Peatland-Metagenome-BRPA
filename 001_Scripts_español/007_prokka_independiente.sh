#!/bin/bash
set -euo pipefail

INPUT_MAG_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/005_megahit/001_multi/001_MAGs_multi"
OUTPUT_PROKKA_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/005_megahit/001_multi/001_MAGs_multi/003_Prokka"
THREADS=31
ENV_PROKKA="prokka"
FAST_MODE=0

usage() {
  cat << 'EOF'
Uso:
  007_prokka_independiente.sh [opciones]

Opciones:
  --input-mag-dir PATH   Directorio con .fa (archivos o vínculos simbólicos)
  --output-dir PATH      Directorio de salida Prokka
  --threads INT          Hilos para Prokka (default: 31)
  --env-prokka NAME      Ambiente conda de Prokka (default: prokka)
  --fast                 Activa modo rápido de Prokka (--fast)
  -h, --help             Muestra esta ayuda

Notas:
  - Todas las muestras se anotan como Bacteria.
  - Imprime log en pantalla y también guarda log por muestra en prokka_run.log.
  - Crea automáticamente el directorio de salida si no existe.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-mag-dir) INPUT_MAG_DIR="$2"; shift 2 ;;
    --output-dir) OUTPUT_PROKKA_DIR="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --env-prokka) ENV_PROKKA="$2"; shift 2 ;;
    --fast) FAST_MODE=1; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción no reconocida: $1"; usage; exit 1 ;;
  esac
done

if [[ ! -d "$INPUT_MAG_DIR" ]]; then
  echo "❌ No existe directorio de entrada: $INPUT_MAG_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_PROKKA_DIR"

echo "[INFO] Buscando FASTA en: $INPUT_MAG_DIR"
mapfile -t MAG_ENTRIES < <(find "$INPUT_MAG_DIR" -maxdepth 1 \( -type f -o -type l \) -name "*.fa" | sort)

if [[ ${#MAG_ENTRIES[@]} -eq 0 ]]; then
  echo "❌ No se encontraron .fa en: $INPUT_MAG_DIR"
  exit 1
fi

MAG_FILES=()
for entry in "${MAG_ENTRIES[@]}"; do
  if [[ -L "$entry" ]]; then
    target="$(readlink -f "$entry" || true)"
    if [[ -n "$target" && -f "$target" ]]; then
      MAG_FILES+=("$entry")
    else
      echo "⚠️ Symlink inválido, se omite: $entry"
    fi
  elif [[ -f "$entry" ]]; then
    MAG_FILES+=("$entry")
  fi
done

if [[ ${#MAG_FILES[@]} -eq 0 ]]; then
  echo "❌ No hay FASTA válidos para procesar"
  exit 1
fi

total="${#MAG_FILES[@]}"
ok=0
fail=0
idx=0
FAIL_LIST_FILE="$OUTPUT_PROKKA_DIR/prokka_failed_samples.txt"
> "$FAIL_LIST_FILE"

echo "[INFO] Total de FASTA válidos: $total"

for mag_file in "${MAG_FILES[@]}"; do
  ((idx+=1))
  sample_name="$(basename "$mag_file" .fa)"
  sample_outdir="$OUTPUT_PROKKA_DIR/$sample_name"
  sample_log="$sample_outdir/prokka_run.log"
  mkdir -p "$sample_outdir"

  echo "[RUN] Prokka ${idx}/${total} -> $sample_name"

  set +e
  {
    echo "[$(date '+%F %T')] Iniciando Prokka: $sample_name"
    echo "[$(date '+%F %T')] Input: $mag_file"

    cmd=(
      conda run --no-capture-output -n "$ENV_PROKKA" prokka
      --outdir "$sample_outdir"
      --prefix "$sample_name"
      --kingdom Bacteria
      --cpus "$THREADS"
      --force
      --addgenes
      --metagenome
    )

    if [[ "$FAST_MODE" -eq 1 ]]; then
      cmd+=(--fast)
    fi

    cmd+=("$mag_file")

    "${cmd[@]}"
    echo "[$(date '+%F %T')] Finalizado Prokka: $sample_name"
  } 2>&1 | tee -a "$sample_log"
  rc=${PIPESTATUS[0]}
  set -e

  if [[ $rc -eq 0 ]]; then
    ((ok+=1))
  else
    ((fail+=1))
    echo "$sample_name" >> "$FAIL_LIST_FILE"
    echo "[WARN] Falló $sample_name (rc=$rc), continuo con la siguiente muestra"
  fi
done

echo "[DONE] Prokka terminado | OK=$ok FAIL=$fail TOTAL=$total"
if [[ $fail -gt 0 ]]; then
  echo "[DONE] Revisa muestras fallidas en: $FAIL_LIST_FILE"
fi
