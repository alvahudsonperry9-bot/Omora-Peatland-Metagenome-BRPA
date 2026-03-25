#!/bin/bash

# Directorios y archivos - TODAS RUTAS ABSOLUTAS
INPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results"
OUTPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken"
DB_PATH="/media/pinguicula/Braulio2232/Base_Chile_20_02_2026/CustomDB"
LEVEL="S"  # Nivel para la estimación de abundancia (Species)

# Lista de muestras a procesar (ACTUALIZADA con los nombres correctos según tu estructura)
SAMPLES=(
    "A01_P1-1" "A01_P2-1" "A01_P4-1" "A02_P2-2" "A02_P4-2" "A03_P1-3" "A03_P2-3" "A03_P4-3"
    "A04_P1-4" "A04_P2-4" "A04_P4-4" "A05_P1-5" "A05_P2-5" "A05_P4-5" "A06_P1-6" "A06_P2-6"
    "A06_P4-6" "A07_P1-7" "A07_P2-7" "A07_P4-7" "A08_P1-8" "A08_P4-8" "A09_P1-9" "A09_P2-9"
    "A09_P4-9" "A10_P1-10" "A10_P2-10" "A11_P1-11" "A11_P2-11" "A12_P1-12" "A13_P1-13" "A14_P1-14"
)

# Crear directorio de salida si no existe
mkdir -p "$OUTPUT_DIR"

echo "=== ESTIMACIÓN DE ABUNDANCIA CON BRACKEN ==="
echo "📁 Base de datos: $DB_PATH"
echo "📂 Directorio entrada: $INPUT_DIR"
echo "📂 Directorio salida: $OUTPUT_DIR"
echo "🔬 Muestras a procesar: ${#SAMPLES[@]}"
echo "📊 Nivel taxonómico: $LEVEL"
echo "📏 Longitud de lectura: 150"
echo ""

# Verificar que existe la base de datos
if [ ! -f "$DB_PATH/hash.k2d" ]; then
    echo "❌ ERROR: No se encuentra la base de datos en $DB_PATH"
    exit 1
fi

# Verificar que existe el archivo de distribución de k-mers
KMER_DISTRIB="$DB_PATH/database150mers.kmer_distrib"
if [ ! -f "$KMER_DISTRIB" ]; then
    echo "❌ ERROR: No se encuentra database150mers.kmer_distrib en $DB_PATH"
    echo "   Ejecuta primero: bracken-build -d $DB_PATH -k 35 -l 150 -t 8"
    exit 1
fi

# Verificar que existe el directorio de entrada
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ ERROR: No se encuentra el directorio de entrada: $INPUT_DIR"
    exit 1
fi

# Procesar cada muestra
PROCESSED_COUNT=0
ERROR_COUNT=0

for SAMPLE in "${SAMPLES[@]}"; do
    echo "🔬 Procesando muestra: $SAMPLE"
    echo "=========================================="
    
    # Archivo de entrada (reporte de Kraken2) - RUTA ABSOLUTA
    REPORT_FILE="$INPUT_DIR/${SAMPLE}_reads_report.txt"
    
    # Verificar que existe el reporte de Kraken2
    if [ ! -f "$REPORT_FILE" ]; then
        echo "❌ ERROR: No se encuentra $REPORT_FILE"
        echo "   Asegúrate de que Kraken2 ya procesó esta muestra"
        ((ERROR_COUNT++))
        continue
    fi
    
    # Nombres de archivos de salida de Bracken - RUTA ABSOLUTA
    BRACKEN_OUTPUT="$OUTPUT_DIR/${SAMPLE}_bracken.txt"
    BRACKEN_REPORT="$OUTPUT_DIR/${SAMPLE}_bracken_report.txt"
    
    # Obtener información del archivo
    REPORT_SIZE=$(du -h "$REPORT_FILE" | cut -f1)
    REPORT_LINES=$(wc -l < "$REPORT_FILE")
    echo "📊 Archivo de entrada: $(basename $REPORT_FILE)"
    echo "   Tamaño: $REPORT_SIZE | Líneas: $REPORT_LINES"
    
    # Comando de Bracken (usando rutas absolutas)
    echo "⏳ Ejecutando Bracken para $SAMPLE..."
    bracken -d "$DB_PATH" \
            -i "$REPORT_FILE" \
            -o "$BRACKEN_OUTPUT" \
            -w "$BRACKEN_REPORT" \
            -r 150 \
            -l "$LEVEL" \
            -t 30
    
    # Verificar éxito
    if [ $? -eq 0 ]; then
        echo "✅ $SAMPLE - Bracken completado"
        ((PROCESSED_COUNT++))
        
        # Generar resumen rápido
        if [ -f "$BRACKEN_OUTPUT" ]; then
            LINE_COUNT=$(wc -l < "$BRACKEN_OUTPUT")
            # Restar 1 para excluir el header
            TAXA_COUNT=$((LINE_COUNT - 1))
            
            # Tamaño del archivo de salida
            OUTPUT_SIZE=$(du -h "$BRACKEN_OUTPUT" | cut -f1)
            
            echo "📈 $SAMPLE - Resultados:"
            echo "   • Taxones identificados: $TAXA_COUNT"
            echo "   • Archivo salida: $OUTPUT_SIZE"
            
            # Mostrar los 5 taxones más abundantes
            if [ $TAXA_COUNT -gt 0 ]; then
                echo "🔝 Top 5 taxones más abundantes:"
                head -6 "$BRACKEN_OUTPUT" | tail -5 | while IFS=$'\t' read -r name taxid level fraction reads; do
                    if [ -n "$name" ] && [ "$name" != "name" ]; then
                        echo "   • $name: $fraction%"
                    fi
                done
            fi
        fi
        
    else
        echo "❌ $SAMPLE - Error en Bracken"
        ((ERROR_COUNT++))
    fi
    
    echo ""
done

# Resumen final
echo "=== RESUMEN FINAL ==="
echo "✅ Muestras procesadas correctamente: $PROCESSED_COUNT"
echo "❌ Muestras con error: $ERROR_COUNT"
echo "📁 Resultados guardados en: $OUTPUT_DIR"

# Verificar archivos generados
echo ""
echo "📋 ARCHIVOS GENERADOS:"
if [ -d "$OUTPUT_DIR" ]; then
    ls -lh "$OUTPUT_DIR" | grep -E "\.txt$" | sed 's/^/   /' | head -10
    TOTAL_FILES=$(find "$OUTPUT_DIR" -name "*.txt" | wc -l)
    echo "   ... y $((TOTAL_FILES - 10)) archivos más (total: $TOTAL_FILES)"
else
    echo "   ⚠️ No se generaron archivos"
fi

echo ""
echo "🎯 ¡Procesamiento de Bracken completado!"
echo "📁 Ruta completa de resultados: $OUTPUT_DIR"
echo ""
echo "💡 Para ver resultados de una muestra específica:"
echo "   head -10 $OUTPUT_DIR/A01_P1-1_bracken.txt"