#!/bin/bash

# Configuración de rutas - MÚLTIPLES MUESTRAS
BASE_DB="/media/pinguicula/Braulio2232/Base_Chile_28_02_2026/CustomDB"
INPUT_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/004_quality_clean4"
OUTPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results"

# Lista de muestras a procesar (ahora con el prefijo A y formato)
SAMPLES=(
    "A01_P1-1" "A01_P2-1" "A01_P4-1" "A02_P2-2" "A02_P4-2" "A03_P1-3" "A03_P2-3" "A03_P4-3"
    "A04_P1-4" "A04_P2-4" "A04_P4-4" "A05_P1-5" "A05_P2-5" "A05_P4-5" "A06_P1-6" "A06_P2-6"
    "A06_P4-6" "A07_P1-7" "A07_P2-7" "A07_P4-7" "A08_P1-8" "A08_P4-8" "A09_P1-9" "A09_P2-9"
    "A09_P4-9" "A10_P1-10" "A10_P2-10" "A11_P1-11" "A11_P2-11" "A12_P1-12" "A13_P1-13" "A14_P1-14"
)

# Crear directorio de salida si no existe
mkdir -p "$OUTPUT_DIR"

echo "=== CLASIFICACIÓN DE MÚLTIPLES MUESTRAS CON KRAKEN2 ==="
echo "Base de datos: $BASE_DB"
echo "Directorio entrada: $INPUT_DIR"
echo "Muestras a procesar: ${#SAMPLES[@]} muestras"
echo "Directorio salida: $OUTPUT_DIR"
echo "Hilos utilizados: 31"
echo ""

# Verificar que existe la base de datos
if [ ! -f "$BASE_DB/hash.k2d" ]; then
    echo "ERROR: No se encuentra la base de datos en $BASE_DB"
    exit 1
fi

# Procesar cada muestra
for SAMPLE in "${SAMPLES[@]}"; do
    echo "🔬 Procesando muestra: $SAMPLE"
    echo "=========================================="
    
    # Directorio específico de la muestra
    SAMPLE_DIR="$INPUT_DIR/$SAMPLE"
    
    # Verificar que existe el directorio
    if [ ! -d "$SAMPLE_DIR" ]; then
        echo "❌ ERROR: No se encuentra el directorio $SAMPLE_DIR"
        continue
    fi
    
    # Archivos de entrada (nuevo formato: dentro de carpeta con sufijo _nonhuman_unmapped.1.gz)
    R1_FILE="$SAMPLE_DIR/${SAMPLE}_nonhuman_unmapped.1.gz"
    R2_FILE="$SAMPLE_DIR/${SAMPLE}_nonhuman_unmapped.2.gz"
    
    # Verificar que existen los archivos
    if [ ! -f "$R1_FILE" ]; then
        echo "❌ ERROR: No se encuentra $R1_FILE"
        continue
    fi
if [ ! -f "$R2_FILE" ]; then
    echo "❌ ERROR: No se encuentra $R2_FILE"
    continue
fi
    
    # Nombres de archivos de salida
    OUTPUT_FILE="$OUTPUT_DIR/${SAMPLE}_reads_clasificado.kraken"
    REPORT_FILE="$OUTPUT_DIR/${SAMPLE}_reads_report.txt"
    SUMMARY_FILE="$OUTPUT_DIR/${SAMPLE}_reads_summary.txt"
    
    # Obtener información de los archivos
    R1_SIZE=$(du -h "$R1_FILE" | cut -f1)
    R2_SIZE=$(du -h "$R2_FILE" | cut -f1)
    
    echo "📊 Archivos encontrados:"
    echo "   R1: $(basename $R1_FILE) ($R1_SIZE)"
    echo "   R2: $(basename $R2_FILE) ($R2_SIZE)"
    
    # Comando de clasificación
    echo "⏳ Ejecutando Kraken2 para $SAMPLE..."
    kraken2 --db "$BASE_DB" \
            --threads 31 \
            --paired \
            --gzip-compressed \
            --report "$REPORT_FILE" \
            --output "$OUTPUT_FILE" \
            --confidence 0.1 \
            --memory-mapping \
            "$R1_FILE" \
            "$R2_FILE"
    
    # Verificar éxito
    if [ $? -eq 0 ]; then
        echo "✅ $SAMPLE - Clasificación completada"
        
        # Generar resumen rápido
        if [ -f "$OUTPUT_FILE" ]; then
            CLASSIFIED=$(grep -c "^C" "$OUTPUT_FILE" 2>/dev/null || echo "0")
            UNCLASSIFIED=$(grep -c "^U" "$OUTPUT_FILE" 2>/dev/null || echo "0")
            TOTAL=$((CLASSIFIED + UNCLASSIFIED))
            
            if [ $TOTAL -gt 0 ]; then
                PERCENT=$(echo "scale=2; $CLASSIFIED * 100 / $TOTAL" | bc 2>/dev/null || echo "0")
                echo "📈 $SAMPLE - Clasificados: $CLASSIFIED/$TOTAL ($PERCENT%)"
            fi
            
            # Guardar resumen en archivo
            {
                echo "RESUMEN DE CLASIFICACIÓN - $SAMPLE"
                echo "===================================="
                echo "Archivo R1: $(basename $R1_FILE) ($R1_SIZE)"
                echo "Archivo R2: $(basename $R2_FILE) ($R2_SIZE)"
                echo "Total reads procesados: $TOTAL"
                echo "Reads clasificados: $CLASSIFIED"
                echo "Reads no clasificados: $UNCLASSIFIED"
                if [ $TOTAL -gt 0 ]; then
                    echo "Porcentaje clasificación: $PERCENT%"
                fi
                echo "Fecha: $(date)"
            } > "$SUMMARY_FILE"
            echo "📝 Resumen guardado en: $SUMMARY_FILE"
        fi
    else
        echo "❌ $SAMPLE - Error en clasificación"
    fi
    
    echo ""
done

echo "🎯 ¡Procesamiento de todas las muestras completado!"
echo "📁 Resultados en: $OUTPUT_DIR"

# Mostrar resumen final
echo ""
echo "=== RESUMEN FINAL ==="
echo "Muestras procesadas: ${#SAMPLES[@]}"
echo "Resultados disponibles:"
ls -lh "$OUTPUT_DIR" | grep -E "\.(kraken|txt)$" | sed 's/^/  /'