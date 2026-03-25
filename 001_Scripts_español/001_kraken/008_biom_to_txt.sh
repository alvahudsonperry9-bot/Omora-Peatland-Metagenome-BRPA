#!/bin/bash
# convert_biom_to_txt.sh

# Directorio con archivos BIOM
biom_dir="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken/biom"
output_dir="$biom_dir"

echo "=== CONVERSIÓN BIOM A TXT ==="

# Convertir cada archivo .biom a .txt
for biom_file in "$biom_dir"/*.biom; do
    if [ ! -f "$biom_file" ]; then
        echo "❌ No se encontraron archivos .biom en $biom_dir"
        exit 1
    fi
    
    filename=$(basename "$biom_file" .biom)
    txt_file="$output_dir/${filename}.txt"
    
    echo "🔧 Convirtiendo: $filename.biom"
    
    # Convertir a TSV
    biom convert -i "$biom_file" -o "$txt_file" --to-tsv --header-key taxonomy
    
    if [ $? -eq 0 ] && [ -f "$txt_file" ]; then
        line_count=$(wc -l < "$txt_file")
        echo "✅ $filename.txt ($line_count líneas)"
    else
        echo "❌ Error convirtiendo $filename.biom"
    fi
done

echo ""
echo "🎯 Conversión completada!"
echo "📁 Archivos TXT en: $output_dir"
