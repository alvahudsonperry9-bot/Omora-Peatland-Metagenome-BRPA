#!/bin/bash

TAXA_FILE="Taxa.tsv"
GENOME_SUBSPECIES_FILE="genome_subspecies_map.txt"
NODES_FILE="nodes.txt"
NAMES_FILE="names.txt"

echo "=== GENERANDO MAPEO GENOMA → SUBSPECIES Y TAXONOMÍA COMPLETA ==="

# Verificar que el archivo existe
if [ ! -f "$TAXA_FILE" ]; then
    echo "❌ ERROR: No se encuentra $TAXA_FILE"
    exit 1
fi

# Inicializar archivos de salida
echo "🔄 Inicializando archivos..."
> "$GENOME_SUBSPECIES_FILE"
> "$NODES_FILE"
> "$NAMES_FILE"

# Agregar root a la taxonomía
echo -e "1\t|\t1\t|\tno rank\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
echo -e "1\t|\troot\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"

# Variables para taxonomía
declare -A TAXID_ASSIGNED
declare -A TAXON_COUNTS
declare -A GENOME_TO_SUBSPECIES
TAXID_ASSIGNED["root"]=1
NEXT_TAXID=100000
LINE_NUMBER=0
GENOME_COUNT=0

echo "📊 Procesando Taxa.tsv..."
echo ""

while IFS=$'\t' read -r genome domain phylum class order family genus species subspecies; do
    ((LINE_NUMBER++))
    
    # Saltar header
    if [ $LINE_NUMBER -eq 1 ]; then
        echo "📋 HEADER: $genome | $domain | $phylum | $class | $order | $family | $genus | $species | $subspecies"
        echo ""
        continue
    fi
    
    # Saltar líneas vacías
    if [ -z "$genome" ]; then
        continue
    fi
    
    ((GENOME_COUNT++))
    
    # Mostrar progreso cada 100 genomas
    if [ $((GENOME_COUNT % 100)) -eq 0 ]; then
        echo "📊 Procesados $GENOME_COUNT genomas..."
    fi
    
    # Guardar relación genoma → subspecies
    if [ "$subspecies" != "NA" ] && [ -n "$subspecies" ]; then
        GENOME_TO_SUBSPECIES["$genome"]="$subspecies"
        echo -e "$genome\t$subspecies" >> "$GENOME_SUBSPECIES_FILE"
    else
        # Si no hay subspecies, usar species como fallback
        if [ "$species" != "NA" ] && [ -n "$species" ]; then
            GENOME_TO_SUBSPECIES["$genome"]="$species"
            echo -e "$genome\t$species" >> "$GENOME_SUBSPECIES_FILE"
        else
            # Si no hay species, usar genus como fallback
            if [ "$genus" != "NA" ] && [ -n "$genus" ]; then
                GENOME_TO_SUBSPECIES["$genome"]="$genus"
                echo -e "$genome\t$genus" >> "$GENOME_SUBSPECIES_FILE"
            else
                echo "⚠️  Genoma $genome sin subspecies, species o genus definido"
            fi
        fi
    fi
    
    # Procesar cada nivel taxonómico
    current_parent=1  # root
    
    # DOMAIN
    if [ "$domain" != "NA" ] && [ -n "$domain" ]; then
        if [ -z "${TAXID_ASSIGNED[$domain]}" ]; then
            TAXID_ASSIGNED["$domain"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tsuperkingdom\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${domain}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["domain"]=$((TAXON_COUNTS["domain"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$domain]}"
    fi
    
    # PHYLUM
    if [ "$phylum" != "NA" ] && [ -n "$phylum" ]; then
        if [ -z "${TAXID_ASSIGNED[$phylum]}" ]; then
            TAXID_ASSIGNED["$phylum"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tphylum\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${phylum}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["phylum"]=$((TAXON_COUNTS["phylum"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$phylum]}"
    fi
    
    # CLASS
    if [ "$class" != "NA" ] && [ -n "$class" ]; then
        if [ -z "${TAXID_ASSIGNED[$class]}" ]; then
            TAXID_ASSIGNED["$class"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tclass\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${class}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["class"]=$((TAXON_COUNTS["class"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$class]}"
    fi
    
    # ORDER
    if [ "$order" != "NA" ] && [ -n "$order" ]; then
        if [ -z "${TAXID_ASSIGNED[$order]}" ]; then
            TAXID_ASSIGNED["$order"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\torder\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${order}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["order"]=$((TAXON_COUNTS["order"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$order]}"
    fi
    
    # FAMILY
    if [ "$family" != "NA" ] && [ -n "$family" ]; then
        if [ -z "${TAXID_ASSIGNED[$family]}" ]; then
            TAXID_ASSIGNED["$family"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tfamily\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${family}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["family"]=$((TAXON_COUNTS["family"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$family]}"
    fi
    
    # GENUS
    if [ "$genus" != "NA" ] && [ -n "$genus" ]; then
        if [ -z "${TAXID_ASSIGNED[$genus]}" ]; then
            TAXID_ASSIGNED["$genus"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tgenus\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${genus}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["genus"]=$((TAXON_COUNTS["genus"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$genus]}"
    fi
    
    # SPECIES
    if [ "$species" != "NA" ] && [ -n "$species" ]; then
        if [ -z "${TAXID_ASSIGNED[$species]}" ]; then
            TAXID_ASSIGNED["$species"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tspecies\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${species}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["species"]=$((TAXON_COUNTS["species"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$species]}"
    fi
    
    # SUBSPECIES
    if [ "$subspecies" != "NA" ] && [ -n "$subspecies" ] && [ "$subspecies" != "$species" ]; then
        if [ -z "${TAXID_ASSIGNED[$subspecies]}" ]; then
            TAXID_ASSIGNED["$subspecies"]=$NEXT_TAXID
            echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tsubspecies\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
            echo -e "${NEXT_TAXID}\t|\t${subspecies}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
            ((NEXT_TAXID++))
            TAXON_COUNTS["subspecies"]=$((TAXON_COUNTS["subspecies"] + 1))
        fi
        current_parent="${TAXID_ASSIGNED[$subspecies]}"
    fi
    
    # GENOMA (nivel final) - vincular al nivel más específico disponible
    if [ -z "${TAXID_ASSIGNED[$genome]}" ]; then
        TAXID_ASSIGNED["$genome"]=$NEXT_TAXID
        echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tno rank\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
        echo -e "${NEXT_TAXID}\t|\t${genome}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
        ((NEXT_TAXID++))
        TAXON_COUNTS["genome"]=$((TAXON_COUNTS["genome"] + 1))
    fi
    
done < "$TAXA_FILE"

# Resumen final
echo ""
echo "✅ PROCESAMIENTO COMPLETADO"
echo "================================"
echo "📊 ESTADÍSTICAS:"
echo "   • Líneas procesadas: $((LINE_NUMBER - 1))"
echo "   • Genomas únicos: $GENOME_COUNT"
echo "   • Relaciones genoma→subspecies: $(wc -l < "$GENOME_SUBSPECIES_FILE")"
echo "   • TaxIDs asignados: $((NEXT_TAXID - 100000))"
echo "   • Archivos generados:"
echo "     - $GENOME_SUBSPECIES_FILE (mapeo genoma→subspecies)"
echo "     - $NODES_FILE (taxonomía)"
echo "     - $NAMES_FILE (nombres taxonómicos)"

echo ""
echo "📈 DESGLOSE POR NIVEL TAXONÓMICO:"
for level in domain phylum class order family genus species subspecies genome; do
    if [ -n "${TAXON_COUNTS[$level]}" ]; then
        echo "   • $level: ${TAXON_COUNTS[$level]}"
    fi
done

# Mostrar primeras líneas de cada archivo
echo ""
echo "🔍 PRIMERAS 5 RELACIONES GENOMA → SUBSPECIES:"
head -5 "$GENOME_SUBSPECIES_FILE"

echo ""
echo "🔍 PRIMERAS 3 LÍNEAS DE nodes.txt:"
head -3 "$NODES_FILE"

echo ""
echo "🔍 PRIMERAS 3 LÍNEAS DE names.txt:"
head -3 "$NAMES_FILE"

# Verificar archivos generados
echo ""
echo "📁 ARCHIVOS GENERADOS:"
echo "   • $GENOME_SUBSPECIES_FILE: $(wc -l < "$GENOME_SUBSPECIES_FILE") líneas"
echo "   • $NODES_FILE: $(wc -l < "$NODES_FILE") líneas"
echo "   • $NAMES_FILE: $(wc -l < "$NAMES_FILE") líneas"

# Análisis de las relaciones genoma→subspecies
echo ""
echo "🔎 ANÁLISIS DE RELACIONES GENOMA → SUBSPECIES:"

# Contar genomas por subspecies
echo "📊 Distribución de genomas por subspecies:"
cut -f2 "$GENOME_SUBSPECIES_FILE" | sort | uniq -c | sort -nr | head -10 | while read count subspecies; do
    echo "   • $subspecies: $count genomas"
done

# Verificar genomas sin subspecies
genomes_with_subspecies=$(cut -f1 "$GENOME_SUBSPECIES_FILE" | wc -l)
if [ "$genomes_with_subspecies" -eq "$GENOME_COUNT" ]; then
    echo "✅ Todos los genomas tienen subspecies asociado"
else
    echo "⚠️  $((GENOME_COUNT - genomes_with_subspecies)) genomas sin subspecies"
fi

echo ""
echo "🎯 ¡Archivos generados exitosamente!"
echo "💡 Usa estos archivos para:"
echo "   - genome_subspecies_map.txt: Relacionar genomas con subspecies"
echo "   - nodes.txt y names.txt: Construir la base de datos Kraken2"
