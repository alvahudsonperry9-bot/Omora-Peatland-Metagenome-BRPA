#!/bin/bash
set -euo pipefail

# 006_gtdbtk.sh
# Ejecuta GTDB-Tk sobre todos los MAGs (.fa) ubicados en:
# /media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs
# (puede ser enlace simbólico)

MAG_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026"
OUT_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/007_MAGs_15_03_2026/002_gtdbtk"
CPUS=31

usage() {
    echo "Uso: $0 [-i MAG_DIR] [-o OUT_DIR] [-t CPUS]"
    exit 1
}

while getopts ":i:o:t:" opt; do
    case $opt in
        i) MAG_DIR="$OPTARG" ;;
        o) OUT_DIR="$OPTARG" ;;
        t) CPUS="$OPTARG" ;;
        *) usage ;;
    esac
done

mkdir -p "$OUT_DIR"

if [[ ! -d "$MAG_DIR" ]]; then
    echo "Directorio de MAGs no encontrado: $MAG_DIR"
    exit 1
fi

shopt -s nullglob
mag_files=("$MAG_DIR"/*.fa "$MAG_DIR"/*.fasta)
shopt -u nullglob

if (( ${#mag_files[@]} == 0 )); then
    echo "No se encontraron archivos .fa/.fasta en: $MAG_DIR"
    exit 1
fi

echo ">>> Ejecutando GTDB-Tk"
echo "    MAG_DIR: $MAG_DIR"
echo "    OUT_DIR: $OUT_DIR"
echo "    CPUS:    $CPUS"
echo "    MAGs:    ${#mag_files[@]}"
echo "[CMD] gtdbtk classify_wf --genome_dir $MAG_DIR --out_dir $OUT_DIR --cpus $CPUS --force --extension fa"

gtdbtk classify_wf \
    --genome_dir "$MAG_DIR" \
    --out_dir "$OUT_DIR" \
    --cpus "$CPUS" \
    --force \
    --skip_ani_screen \
    --extension fa

echo ">>> GTDB-Tk completado"
