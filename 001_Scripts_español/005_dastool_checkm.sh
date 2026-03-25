#!/bin/bash
set -euo pipefail

# 005_dastool_checkm.sh
# Integra bins de MetaBAT2, MaxBin2 y SemiBin2 con DAS Tool
# y evalúa con CheckM/CheckM2.

#############################################
#      CONFIGURACIÓN GENERAL
#############################################

DISK_A="/media/pinguicula/8T_BRPA"
DISK_B="/media/pinguicula/8T2_BRPA"
BASE_REL="Muestras"
SAMPLE_TYPE="001_Chile"
MEGAHIT_SUBDIR="005_megahit"

# Salidas centralizadas solicitadas
# DAS Tool en 8T_BRPA, CheckM y CheckM2 en 8T2_BRPA
DASTOOL_ROOT="/media/pinguicula/8T_BRPA/Muestras/001_Chile/006_dastool"
CHECKM_ROOT="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/006_dastool/001_CheckM"
CHECKM2_ROOT="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/006_dastool/001_CheckM2"

CORES=30

ENV_DASTOOL="dastool"
ENV_CHECKM="checkm"
ENV_CHECKM2="checkm2"

# 1=scaffolds2bin, 2=dastool, 3=checkm, 4=checkm2
START_MODULE=3
END_MODULE=3

# Si no pasas -L, usa esta lista por defecto (visible y editable)
muestras=(
    A00_Co A02_P4-2 A04_P2-4 A06_P1-6 A07_P4-7 A09_P4-9 A12_P1-12
    A01_P1-1 A03_P1-3 A04_P4-4 A06_P2-6 A08_P1-8 A10_P1-10 A13_P1-13
    A01_P2-1 A03_P2-3 A05_P1-5 A06_P4-6 A08_P4-8 A10_P2-10 A14_P1-14
    A01_P4-1 A03_P4-3 A05_P2-5 A07_P1-7 A09_P1-9 A11_P1-11
    A02_P2-2 A04_P1-4 A05_P4-5 A07_P2-7 A09_P2-9 A11_P2-11
)

usage() {
    echo "Uso: $0 [-a DISK_A] [-b DISK_B] [-s SAMPLE_TYPE] [-t CORES] [-m START_MODULE] [-e END_MODULE] [-L muestra1,muestra2,...]"
    echo "  START_MODULE: 1|scaffolds, 2|dastool, 3|checkm, 4|checkm2"
    echo "  END_MODULE:   1|scaffolds, 2|dastool, 3|checkm, 4|checkm2"
    exit 1
}

while getopts ":a:b:s:t:m:e:L:" opt; do
    case $opt in
        a) DISK_A="$OPTARG" ;;
        b) DISK_B="$OPTARG" ;;
        s) SAMPLE_TYPE="$OPTARG" ;;
        t) CORES="$OPTARG" ;;
        m) START_MODULE="$OPTARG" ;;
        e) END_MODULE="$OPTARG" ;;
        L) MANUAL_SAMPLES="$OPTARG" ;;
        *) usage ;;
    esac
done

normalize_module() {
    case "$1" in
        1|scaffolds) echo 1 ;;
        2|dastool) echo 2 ;;
        3|checkm) echo 3 ;;
        4|checkm2) echo 4 ;;
        *) return 1 ;;
    esac
}

START_MODULE_NUM="$(normalize_module "$START_MODULE" || true)"
END_MODULE_NUM="$(normalize_module "$END_MODULE" || true)"

if [[ -z "$START_MODULE_NUM" ]]; then
    echo "START_MODULE inválido: $START_MODULE"
    usage
fi
if [[ -z "$END_MODULE_NUM" ]]; then
    echo "END_MODULE inválido: $END_MODULE"
    usage
fi

START_MODULE="$START_MODULE_NUM"
END_MODULE="$END_MODULE_NUM"

if (( END_MODULE < START_MODULE )); then
    echo "END_MODULE ($END_MODULE) no puede ser menor que START_MODULE ($START_MODULE)"
    exit 1
fi

if [[ -n "${MANUAL_SAMPLES:-}" ]]; then
    IFS=',' read -r -a muestras <<< "${MANUAL_SAMPLES}"
fi

mkdir -p "$DASTOOL_ROOT" "$CHECKM_ROOT" "$CHECKM2_ROOT"

run_conda_verbose() {
    local env_name="$1"
    shift

    echo "[CMD] conda run --no-capture-output -n ${env_name} $*"
    conda run --no-capture-output -n "$env_name" "$@"
}

should_run() {
    local mod="$1"
    (( mod >= START_MODULE && mod <= END_MODULE ))
}

#############################################
#      FUNCIONES BÁSICAS
#############################################

check_file() {
    [[ -f "$1" && -s "$1" ]]
}

check_dir_nonempty() {
    [[ -d "$1" && -n "$(ls -A "$1" 2>/dev/null)" ]]
}

find_component_dir() {
    local muestra="$1"
    local rel_component="$2"
    local d

    for d in "$DISK_A" "$DISK_B"; do
        local candidate="${d}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${muestra}/${rel_component}"
        if check_dir_nonempty "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

find_contigs_file() {
    local muestra="$1"
    local contigs_name
    local d

    # Caso especial solicitado para coensamble
    if [[ "$muestra" == "A00_Co" ]]; then
        contigs_name="A00_Co_contigs_renamed.fasta"
    else
        contigs_name="${muestra}_contigs.fasta"
    fi

    for d in "$DISK_A" "$DISK_B"; do
        local candidate="${d}/${BASE_REL}/${SAMPLE_TYPE}/${MEGAHIT_SUBDIR}/${muestra}/${contigs_name}"
        if check_file "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

resolve_dastool_bin_dir() {
    local muestra="$1"
    local sample_out_dir="$2"

    local expected="${sample_out_dir}/${muestra}_dastool_DASTool_bins"
    if check_dir_nonempty "$expected"; then
        echo "$expected"
        return 0
    fi

    local found
    found="$(find "$sample_out_dir" -maxdepth 1 -type d -name "*_DASTool_bins" | head -n 1 || true)"
    if [[ -n "$found" ]] && check_dir_nonempty "$found"; then
        echo "$found"
        return 0
    fi

    return 1
}

#############################################
#   DESCOMPRIMIR BINS DE SEMIBIN
#############################################

descomprimir_semibin_bins() {
    local semibin_bins_dir="$1"

    find "$semibin_bins_dir" -name "*.fa.gz" -type f -print0 |
    while IFS= read -r -d '' f; do
        gunzip -f "$f"
    done
}

normalizar_metabat_scaffolds2bin() {
    local tsv="$1"
    local tmp="${tsv}.tmp"

    awk -F '\t' 'BEGIN{OFS="\t"} NF>=4 {print $1, $4}' "$tsv" > "$tmp"
    mv "$tmp" "$tsv"
}

#############################################
#   GENERAR SCAFFOLDS2BIN
#############################################

generar_scaffolds2bin() {
    local muestra="$1"
    local tipo="$2"
    local sample_out_dir="$3"
    local in_dir ext out

    case "$tipo" in
        metabat)
            in_dir="$(find_component_dir "$muestra" "001_Metabat2" || true)"
            ext="fa"
            out="${sample_out_dir}/metabat_scaffolds2bin.tsv"
            ;;
        maxbin)
            in_dir="$(find_component_dir "$muestra" "001_Maxbin2" || true)"
            ext="fasta"
            out="${sample_out_dir}/maxbin_scaffolds2bin.tsv"
            ;;
        semibin)
            in_dir="$(find_component_dir "$muestra" "001_SemiBin2/output_bins" || true)"
            ext="fa"
            out="${sample_out_dir}/semibin_scaffolds2bin.tsv"
            ;;
        *)
            echo "Tipo de binning no reconocido: $tipo"
            return 1
            ;;
    esac

    if [[ -z "$in_dir" ]]; then
        echo "No se encontró carpeta de bins para $tipo en muestra $muestra"
        return 1
    fi

    if [[ "$tipo" == "semibin" ]]; then
        descomprimir_semibin_bins "$in_dir"
    fi

    echo "[CMD] conda run -n ${ENV_DASTOOL} Fasta_to_Contig2Bin.sh -i ${in_dir} -e ${ext} > ${out}"
    conda run -n "$ENV_DASTOOL" \
        Fasta_to_Contig2Bin.sh -i "$in_dir" -e "$ext" > "$out"

    if [[ "$tipo" == "metabat" ]]; then
        normalizar_metabat_scaffolds2bin "$out"
    fi

    check_file "$out" || {
        echo "No se pudo generar $out"
        return 1
    }
}

#############################################
#   EJECUTAR DAS TOOL
#############################################

ejecutar_dastool() {
    local muestra="$1"
    local sample_out_dir="$2"
    local contigs="$3"

    local mb="${sample_out_dir}/metabat_scaffolds2bin.tsv"
    local xb="${sample_out_dir}/maxbin_scaffolds2bin.tsv"
    local sb="${sample_out_dir}/semibin_scaffolds2bin.tsv"
    local out_prefix="${sample_out_dir}/${muestra}_dastool"

    check_file "$contigs"
    check_file "$mb"
    check_file "$xb"
    check_file "$sb"

    echo ">>> Ejecutando DAS Tool para $muestra"

    run_conda_verbose "$ENV_DASTOOL" DAS_Tool \
        -i "$xb,$mb,$sb" \
        -l "maxbin,metabat,semibin" \
        -c "$contigs" \
        -o "$out_prefix" \
        -t "$CORES" \
        --search_engine diamond \
        --write_bins \
        --score_threshold 0.2

    echo "${out_prefix}_DASTool_bins"
}

#############################################
#   EJECUTAR CHECKM1
#############################################

ejecutar_checkm() {
    local muestra="$1"
    local bin_dir="$2"

    local out="${CHECKM_ROOT}/${muestra}"

    check_dir_nonempty "$bin_dir" || {
        echo "No hay bins DAS Tool en $bin_dir"
        return 1
    }
    mkdir -p "$out"

    echo ">>> Ejecutando CheckM1 para $muestra"

    run_conda_verbose "$ENV_CHECKM" checkm lineage_wf \
        -x fa \
        -t "$CORES" \
        --pplacer_threads "$CORES" \
        "$bin_dir" "$out"

    run_conda_verbose "$ENV_CHECKM" checkm qa \
        "$out/lineage.ms" \
        "$out" \
        -o 1 \
        --tab_table \
        -f "$out/checkm_results.tsv"
}

#############################################
#   EJECUTAR CHECKM2
#############################################

ejecutar_checkm2() {
    local muestra="$1"
    local bin_dir="$2"

    local out="${CHECKM2_ROOT}/${muestra}"

    check_dir_nonempty "$bin_dir" || {
        echo "No hay bins DAS Tool en $bin_dir"
        return 1
    }
    mkdir -p "$out"

    echo ">>> Ejecutando CheckM2 para $muestra"

    run_conda_verbose "$ENV_CHECKM2" checkm2 predict \
        --threads "$CORES" \
        --input "$bin_dir" \
        --output-directory "$out" \
        -x fa \
        --force
}

#############################################
#              PIPELINE
#############################################

for m in "${muestras[@]}"; do
    echo "========================================"
    echo ">>> REFINANDO MUESTRA: $m"
    echo "========================================"

    {
        sample_out_dir="${DASTOOL_ROOT}/${m}"
        mkdir -p "$sample_out_dir"

        if should_run 2; then
            contigs="$(find_contigs_file "$m" || true)"
            if [[ -z "$contigs" ]]; then
                echo "No se encontró archivo de contigs para $m"
                continue
            fi
        fi

        if should_run 1; then
            generar_scaffolds2bin "$m" metabat "$sample_out_dir"
            generar_scaffolds2bin "$m" maxbin "$sample_out_dir"
            generar_scaffolds2bin "$m" semibin "$sample_out_dir"
        fi

        if should_run 2; then
            dastool_bin_dir="$(ejecutar_dastool "$m" "$sample_out_dir" "$contigs" | tail -n 1)"
        else
            dastool_bin_dir="$(resolve_dastool_bin_dir "$m" "$sample_out_dir" || true)"
            if [[ -z "$dastool_bin_dir" ]]; then
                echo "No se encontró carpeta de bins de DAS Tool para $m en $sample_out_dir"
                continue
            fi
        fi

        if should_run 3; then
            ejecutar_checkm "$m" "$dastool_bin_dir"
        fi

        if should_run 4; then
            ejecutar_checkm2 "$m" "$dastool_bin_dir"
        fi

        echo ">>> MUESTRA $m COMPLETADA CORRECTAMENTE"
        echo ""
    } || {
        echo "⚠️ ERROR en muestra $m — se continúa con la siguiente"
        echo ""
        continue
    }
done

echo "========================================"
echo ">>> REFINAMIENTO Y EVALUACIÓN FINALIZADOS"
echo "========================================"
