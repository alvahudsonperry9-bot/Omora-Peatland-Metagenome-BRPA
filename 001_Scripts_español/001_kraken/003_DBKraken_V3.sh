#!/bin/bash

# Configuración de rutas
BASE_DIR="."
GENOMES_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026"  # Nueva carpeta unificada
CUSTOM_DB="$BASE_DIR/CustomDB"
TAXONOMY_DIR="$BASE_DIR"
GENOME_MAP="$BASE_DIR/genome_subspecies_map.txt"

echo "=== CONSTRUYENDO BASE DE DATOS KRAKEN2 CON TAXONOMÍA COMPLETA ==="
echo "Directorio base: $BASE_DIR"
echo "Directorio de genomas: $GENOMES_DIR (TODOS los genomas aquí)"
echo "Base de datos: $CUSTOM_DB"
echo "Taxonomía: $TAXONOMY_DIR"
echo ""

# Paso 0: Navegar al directorio base
cd "$BASE_DIR"

# Paso 1: Limpiar y crear estructura
echo "🔄 Paso 1: Creando estructura de directorios..."
rm -rf "$CUSTOM_DB"
mkdir -p "$CUSTOM_DB/taxonomy"
mkdir -p "$CUSTOM_DB/library"

# Paso 2: Copiar archivos de taxonomía
echo "📊 Paso 2: Copiando archivos de taxonomía..."
if [ -f "nodes.txt" ] && [ -f "names.txt" ]; then
    cp "nodes.txt" "$CUSTOM_DB/taxonomy/nodes.dmp"
    cp "names.txt" "$CUSTOM_DB/taxonomy/names.dmp"
    echo "✅ Taxonomía copiada:"
    echo "   - nodes.dmp: $(wc -l < "$CUSTOM_DB/taxonomy/nodes.dmp") líneas"
    echo "   - names.dmp: $(wc -l < "$CUSTOM_DB/taxonomy/names.dmp") líneas"
else
    echo "❌ ERROR: No se encuentran nodes.txt y/o names.txt"
    exit 1
fi

# Paso 3: Cargar mapeo de taxids desde names.dmp
echo "🗺️  Paso 3: Cargando mapeo de taxids..."
declare -A TAXID_MAP

while IFS=$'|\t' read -r taxid name rest; do
    # Limpiar espacios en blanco
    taxid=$(echo "$taxid" | sed 's/^[ \t]*//;s/[ \t]*$//')
    name=$(echo "$name" | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    if [[ "$taxid" =~ ^[0-9]+$ ]] && [[ -n "$name" ]]; then
        TAXID_MAP["$name"]=$taxid
    fi
done < "$CUSTOM_DB/taxonomy/names.dmp"

echo "✅ Cargados ${#TAXID_MAP[@]} taxids"

# Paso 4: Cargar mapeo genoma -> subspecies
echo "🔗 Paso 4: Cargando mapeo genoma -> subspecies..."
declare -A GENOME_SUBSPECIES_MAP

if [ -f "$GENOME_MAP" ]; then
    while IFS=$'\t' read -r genome subspecies; do
        if [[ -n "$genome" && -n "$subspecies" ]]; then
            GENOME_SUBSPECIES_MAP["$genome"]="$subspecies"
        fi
    done < "$GENOME_MAP"
    echo "✅ Cargadas ${#GENOME_SUBSPECIES_MAP[@]} relaciones genoma->subspecies"
else
    echo "❌ ERROR: No se encuentra $GENOME_MAP"
    exit 1
fi

# Función para encontrar archivo FASTA (AHORA SOLO BUSCA EN UNA CARPETA)
find_fasta_file() {
    local genome_name="$1"
    
    # Buscar en el directorio unificado
    local genome_file="$GENOMES_DIR/${genome_name}.fa"
    if [ -f "$genome_file" ]; then
        echo "$genome_file"
        return
    fi
    
    # Buscar recursivamente en subdirectorios (por si acaso)
    local found_file=$(find "$GENOMES_DIR" -name "${genome_name}.fa" -type f 2>/dev/null | head -1)
    if [ -n "$found_file" ]; then
        echo "$found_file"
        return
    fi
    
    echo ""
}

# Función para convertir formato FASTA a compatible con Kraken2
convert_fasta_for_kraken2() {
    local input_file="$1"
    local taxid="$2"
    local output_file="$3"
    
    # Convertir formato MEGAHIT/SPAdes a formato Kraken2
    awk -v taxid="$taxid" '
    /^>/ {
        # Para headers tipo ">100488 k141_51745 flag=1 multi=61.0000 len=3573"
        # o ">k141_51745"
        if ($0 ~ /^>[0-9]+\s+/) {
            # Formato con taxid al inicio: extraer el contig ID
            contig_id = $2
            print ">|kraken:taxid|" taxid " " contig_id
        } else if ($0 ~ /^>k141_/) {
            # Formato SPAdes: agregar taxid
            contig_id = substr($0, 2)
            print ">|kraken:taxid|" taxid " " contig_id
        } else {
            # Otro formato: agregar taxid manteniendo el header original
            original_header = substr($0, 2)
            print ">|kraken:taxid|" taxid " " original_header
        }
    }
    !/^>/ {
        print
    }
    ' "$input_file" > "$output_file"
}

# Paso 5: Procesar genomas con taxonomía específica
echo "🧬 Paso 5: Procesando genomas con taxonomía específica..."
PROCESSED_COUNT=0
MISSING_COUNT=0
ERROR_COUNT=0

for genome in "${!GENOME_SUBSPECIES_MAP[@]}"; do
    subspecies="${GENOME_SUBSPECIES_MAP[$genome]}"
    
    # Buscar taxid para la subspecies
    if [ -n "${TAXID_MAP[$subspecies]}" ]; then
        taxid="${TAXID_MAP[$subspecies]}"
    else
        # Si no encuentra subspecies, buscar por nombre del genoma
        if [ -n "${TAXID_MAP[$genome]}" ]; then
            taxid="${TAXID_MAP[$genome]}"
            echo "⚠️  Usando taxid del genoma para $genome (no se encontró subspecies: $subspecies)"
        else
            echo "❌ No se encontró taxid para $genome (subspecies: $subspecies)"
            ((ERROR_COUNT++))
            continue
        fi
    fi
    
    echo "  🔍 Buscando: $genome.fa → subspecies: $subspecies → taxid: $taxid"
    
    # Buscar archivo FASTA en el directorio unificado
    fasta_file=$(find_fasta_file "$genome")
    
    if [[ -n "$fasta_file" && -f "$fasta_file" ]]; then
        echo "    📁 Encontrado: $(basename "$fasta_file")"
        
        # Convertir a formato Kraken2
        temp_fasta="$CUSTOM_DB/library/${genome}_with_taxid.fna"
        convert_fasta_for_kraken2 "$fasta_file" "$taxid" "$temp_fasta"
        
        # Verificar conversión
        if [[ -s "$temp_fasta" ]]; then
            # Verificar que los headers tengan el formato correcto
            if grep -q "kraken:taxid|$taxid" "$temp_fasta"; then
                echo "    ✅ Convertido correctamente"
                
                # Añadir a la librería de Kraken2
                kraken2-build --add-to-library "$temp_fasta" --db "$CUSTOM_DB" > /dev/null 2>&1
                
                if [[ $? -eq 0 ]]; then
                    ((PROCESSED_COUNT++))
                    echo "    📚 Añadido a la librería"
                    
                    # Limpiar archivo temporal
                    rm -f "$temp_fasta"
                else
                    echo "    ❌ Error al añadir a la librería"
                    ((ERROR_COUNT++))
                fi
            else
                echo "    ❌ Error: No se detectó taxid en los headers"
                ((ERROR_COUNT++))
            fi
        else
            echo "    ❌ Error: Archivo convertido vacío"
            ((ERROR_COUNT++))
        fi
    else
        echo "    ❌ NO encontrado: $genome.fa"
        ((MISSING_COUNT++))
    fi
    
    # Mostrar progreso cada 50 genomas
    if [[ $((PROCESSED_COUNT % 50)) -eq 0 ]] && [[ $PROCESSED_COUNT -ne 0 ]]; then
        echo "    📊 Progreso: $PROCESSED_COUNT genomas procesados..."
    fi
done

# Paso 6: Construir base de datos
echo ""
echo "🏗️  Paso 6: Construyendo base de datos..."
echo "  ================================="
echo "  📊 ESTADÍSTICAS:"
echo "  • Genomas en el mapeo: ${#GENOME_SUBSPECIES_MAP[@]}"
echo "  • Genomas procesados: $PROCESSED_COUNT"
echo "  • Genomas no encontrados: $MISSING_COUNT"
echo "  • Genomas con error: $ERROR_COUNT"
echo "  ================================="

# Verificar que hay archivos en la librería
library_files=$(find "$CUSTOM_DB/library" -name "*.fna" 2>/dev/null | wc -l)
if [[ $library_files -eq 0 ]]; then
    echo "❌ ERROR: No hay archivos en la librería"
    exit 1
fi

echo "📚 Archivos en librería: $library_files"

if [[ $PROCESSED_COUNT -gt 0 ]]; then
    echo "🚀 Iniciando construcción con 30 hilos..."
    
    # Construir base de datos
    kraken2-build --build --db "$CUSTOM_DB" --threads 30
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo "✅ ✅ ✅ BASE DE DATOS CONSTRUIDA EXITOSAMENTE ✅ ✅ ✅"
        echo ""
        echo "=== RESUMEN FINAL ==="
        echo "📁 Ubicación: $CUSTOM_DB"
        echo "📊 Taxones en taxonomía: $(wc -l < "$CUSTOM_DB/taxonomy/nodes.dmp")"
        echo "🧬 Genomas procesados: $PROCESSED_COUNT/${#GENOME_SUBSPECIES_MAP[@]}"
        echo "❌ Genomas no encontrados: $MISSING_COUNT"
        echo "❌ Genomas con error: $ERROR_COUNT"
        echo ""
        
        # Mostrar archivos generados
        echo "=== ARCHIVOS EN LA BASE DE DATOS ==="
        find "$CUSTOM_DB" -type f -name "*.k2d" | while read file; do
            size=$(du -h "$file" | cut -f1)
            echo "  📄 $(basename "$file") ($size)"
        done
        
        # Verificar archivos críticos
        echo ""
        echo "=== VERIFICACIÓN DE ARCHIVOS CRÍTICOS ==="
        for file in "hash.k2d" "opts.k2d" "taxo.k2d"; do
            if [ -f "$CUSTOM_DB/$file" ]; then
                size=$(du -h "$CUSTOM_DB/$file" | cut -f1)
                echo "  ✅ $file ($size)"
            else
                echo "  ❌ $file (NO ENCONTRADO)"
            fi
        done
        
        echo ""
        echo "🎯 ¡Base de datos lista para usar!"
        echo "💡 Puedes probarla con:"
        echo "   kraken2 --db $CUSTOM_DB --threads 8 --report report.txt tu_archivo.fastq"
        
    else
        echo "❌ Error en la construcción de la base de datos"
        echo "💡 Intenta con menos hilos: --threads 8"
        exit 1
    fi
else
    echo "❌ ERROR: No se pudieron procesar archivos FASTA"
    echo "   Verifica que:"
    echo "   1. Los archivos .fa existan en $GENOMES_DIR"
    echo "   2. Los nombres en genome_subspecies_map.txt coincidan con los archivos .fa"
    exit 1
fi
