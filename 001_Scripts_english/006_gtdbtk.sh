#!/bin/bash
set -euo pipefail

# 006_gtdbtk.sh
# Runs GTDB-Tk on all MAGs (.fa) located in:
# /media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs
# (can be a symbolic link)

MAG_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026"
OUT_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/007_MAGs_15_03_2026/002_gtdbtk"
CPUS=31

usage() {
    echo "Usage: $0 [-i MAG_DIR] [-o OUT_DIR] [-t CPUS]"
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
    echo "MAG directory not found: $MAG_DIR"
    exit 1
fi

shopt -s nullglob
mag_files=("$MAG_DIR"/*.fa "$MAG_DIR"/*.fasta)
shopt -u nullglob

if (( ${#mag_files[@]} == 0 )); then
    echo "No .fa/.fasta files found in: $MAG_DIR"
    exit 1
fi

echo ">>> Running GTDB-Tk"
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

echo ">>> GTDB-Tk completed"
