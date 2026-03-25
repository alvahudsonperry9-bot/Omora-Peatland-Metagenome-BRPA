#!/bin/bash


# Directorios con rutas absolutas
INPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken"
OUTPUT_BIOM_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken/biom"

echo "=== CREANDO BIOM DESDE ARCHIVOS BRACKEN ==="
echo "📂 Directorio entrada: $INPUT_DIR"
echo "📂 Directorio salida: $OUTPUT_BIOM_DIR"
echo ""

# Verificar que existe el directorio de entrada
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ ERROR: No se encuentra el directorio: $INPUT_DIR"
    exit 1
fi

# Buscar archivos Bracken (adaptado a tus nombres de archivo)
echo "🔍 Buscando archivos Bracken..."
bracken_files=$(find "$INPUT_DIR" -maxdepth 1 -name "*_bracken_report.txt" | sort)

if [ -z "$bracken_files" ]; then
    echo "❌ No se encontraron archivos *_bracken.txt en $INPUT_DIR"
    echo "   Buscando también *_reads_report_bracken_species.txt..."
    bracken_files=$(find "$INPUT_DIR" -maxdepth 1 -name "*_reads_report_bracken_species.txt" | sort)
fi

if [ -z "$bracken_files" ]; then
    echo "❌ ERROR: No se encontraron archivos Bracken para procesar"
    echo "   Formatos buscados: *_bracken.txt o *_reads_report_bracken_species.txt"
    exit 1
fi

# Contar archivos encontrados
file_count=$(echo "$bracken_files" | wc -l)
echo "✅ Encontrados $file_count archivos Bracken:"
echo "$bracken_files" | head -5 | while read file; do
    echo "   📄 $(basename $file)"
done
if [ $file_count -gt 5 ]; then
    echo "   ... y $((file_count - 5)) archivos más"
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_BIOM_DIR"

# Crear archivo temporal para lista de archivos
file_list="$OUTPUT_BIOM_DIR/bracken_files_list.txt"
echo "$bracken_files" > "$file_list"

echo ""
echo "🏗️  GENERANDO BIOM DESDE ARCHIVOS BRACKEN..."
echo "   Archivos a procesar: $file_count"

# Verificar que los archivos no están vacíos
empty_files=0
for file in $bracken_files; do
    if [ ! -s "$file" ]; then
        echo "⚠️  Archivo vacío: $(basename $file)"
        ((empty_files++))
    fi
done

if [ $empty_files -gt 0 ]; then
    echo "⚠️  Atención: $empty_files archivos están vacíos"
fi

# Usar bracken-biom si está disponible, o kraken-biom con formato específico
output_biom="$OUTPUT_BIOM_DIR/table_bracken_reads.biom"

if command -v bracken-biom &> /dev/null; then
    echo "🔧 Usando bracken-biom..."
    bracken-biom --files $bracken_files --fmt "json" -o "$output_biom"
elif command -v kraken-biom &> /dev/null; then
    echo "🔧 Usando kraken-biom con archivos Bracken..."
    kraken-biom $bracken_files --fmt "json" -o "$output_biom"
else
    echo "❌ ERROR: No se encuentra bracken-biom ni kraken-biom"
    echo "   Instala con: pip install kraken-biom o bracken-biom"
    exit 1
fi

# Verificar resultado
if [ $? -eq 0 ] && [ -f "$output_biom" ]; then
    size=$(du -h "$output_biom" | cut -f1)
    echo "✅ BIOM generado exitosamente:"
    echo "   📁 Ruta: $output_biom"
    echo "   📦 Tamaño: $size"
    
    # Verificar contenido del BIOM
    echo ""
    echo "📊 RESUMEN DEL BIOM:"
    if command -v biom &> /dev/null; then
        biom summarize-table -i "$output_biom" 2>/dev/null | head -20
    else
        echo "   ℹ️  Instala biom-format para ver resumen: pip install biom-format"
        echo "   📊 Número de muestras: $file_count"
        echo "   📊 Archivo generado: $(basename $output_biom)"
    fi
    
    # Crear un pequeño reporte
    report_file="$OUTPUT_BIOM_DIR/biom_creation_report.txt"
    {
        echo "REPORTE DE CREACIÓN DE BIOM"
        echo "=========================="
        echo "Fecha: $(date)"
        echo "Directorio entrada: $INPUT_DIR"
        echo "Directorio salida: $OUTPUT_BIOM_DIR"
        echo "Archivos Bracken encontrados: $file_count"
        echo "Archivos vacíos detectados: $empty_files"
        echo "Archivo BIOM generado: $output_biom"
        echo "Tamaño BIOM: $size"
        echo ""
        echo "Archivos procesados:"
        echo "$bracken_files" | while read file; do
            if [ -f "$file" ]; then
                lines=$(wc -l < "$file")
                sample=$(basename "$file" | sed 's/_bracken.txt//' | sed 's/_reads_report_bracken_species.txt//')
                echo "  • $sample: $(basename $file) ($lines líneas)"
            fi
        done
    } > "$report_file"
    echo "📝 Reporte guardado: $report_file"
    
else
    echo "❌ Error generando BIOM"
    exit 1
fi

# Limpiar archivo temporal
rm -f "$file_list"

echo ""
echo "🎯 ¡BIOM creado exitosamente desde archivos Bracken!"
echo "📁 Ruta completa: $output_biom"
echo ""
echo "💡 Para usar el BIOM en R/Python:"
echo "   R: library(biomformat); biom <- read_biom('$output_biom')"
echo "   Python: import biom; table = biom.load_table('$output_biom')"