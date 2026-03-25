#!/bin/bash
set -euo pipefail

#############################################
#            CONFIGURACIÓN
#############################################

INPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/005_megahit/001_multi/bins"
OUTPUT_BASE="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/005_megahit/001_multi"

CHECKM_OUT="${OUTPUT_BASE}/CheckM1"
CHECKM2_OUT="${OUTPUT_BASE}/CheckM2"

CORES=30

ENV_CHECKM="checkm"
ENV_CHECKM2="checkm2"

#############################################
#        VALIDACIONES INICIALES
#############################################

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "❌ El directorio de entrada no existe:"
    echo "$INPUT_DIR"
    exit 1
fi

if ! ls "$INPUT_DIR"/*.fa >/dev/null 2>&1; then
    echo "❌ No se encontraron archivos .fa en:"
    echo "$INPUT_DIR"
    exit 1
fi

mkdir -p "$CHECKM_OUT"
mkdir -p "$CHECKM2_OUT"

#############################################
#              CHECKM1
#############################################

echo "========================================"
echo ">>> Ejecutando CheckM1"
echo "========================================"

conda run --no-capture-output -n "$ENV_CHECKM" \
    checkm lineage_wf \
    -x fa \
    -t "$CORES" \
    --pplacer_threads "$CORES" \
    "$INPUT_DIR" "$CHECKM_OUT"

conda run --no-capture-output -n "$ENV_CHECKM" \
    checkm qa \
    "$CHECKM_OUT/lineage.ms" \
    "$CHECKM_OUT" \
    -o 1 \
    --tab_table \
    -f "$CHECKM_OUT/checkm_results.tsv"

echo "✅ CheckM1 finalizado"

#############################################
#              CHECKM2
#############################################

echo "========================================"
echo ">>> Ejecutando CheckM2"
echo "========================================"

conda run --no-capture-output -n "$ENV_CHECKM2" \
    checkm2 predict \
    --threads "$CORES" \
    --input "$INPUT_DIR" \
    --output-directory "$CHECKM2_OUT" \
    -x fa \
    --force

echo "✅ CheckM2 finalizado"

echo "========================================"
echo ">>> Evaluación completada correctamente"
echo "========================================"