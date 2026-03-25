#!/bin/bash

TAXA_FILE="Taxa.tsv"
GENOME_SUBSPECIES_FILE="genome_subspecies_map.txt"
NODES_FILE="nodes.txt"
NAMES_FILE="names.txt"

echo "=== GENERATING GENOME → SUBSPECIES MAPPING AND FULL TAXONOMY ==="

# Check that the file exists
if [ ! -f "$TAXA_FILE" ]; then
    echo "❌ ERROR: File $TAXA_FILE not found"
    exit 1
fi

# Initialize output files
echo "🔄 Initializing files..."
> "$GENOME_SUBSPECIES_FILE"
> "$NODES_FILE"
> "$NAMES_FILE"

# Add root to taxonomy
echo -e "1\t|\t1\t|\tno rank\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
echo -e "1\t|\troot\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"

# Variables for taxonomy
declare -A TAXID_ASSIGNED
declare -A TAXON_COUNTS
declare -A GENOME_TO_SUBSPECIES
TAXID_ASSIGNED["root"]=1
NEXT_TAXID=100000
LINE_NUMBER=0
GENOME_COUNT=0

echo "📊 Processing Taxa.tsv..."
echo ""

while IFS=$'\t' read -r genome domain phylum class order family genus species subspecies; do
    ((LINE_NUMBER++))
    
    # Skip header
    if [ $LINE_NUMBER -eq 1 ]; then
        echo "📋 HEADER: $genome | $domain | $phylum | $class | $order | $family | $genus | $species | $subspecies"
        echo ""
        continue
    fi
    
    # Skip empty lines
    if [ -z "$genome" ]; then
        continue
    fi
    
    ((GENOME_COUNT++))
    
    # Show progress every 100 genomes
    if [ $((GENOME_COUNT % 100)) -eq 0 ]; then
        echo "📊 Processed $GENOME_COUNT genomes..."
    fi
    
    # Save genome → subspecies relationship
    if [ "$subspecies" != "NA" ] && [ -n "$subspecies" ]; then
        GENOME_TO_SUBSPECIES["$genome"]="$subspecies"
        echo -e "$genome\t$subspecies" >> "$GENOME_SUBSPECIES_FILE"
    else
        # If no subspecies, use species as fallback
        if [ "$species" != "NA" ] && [ -n "$species" ]; then
            GENOME_TO_SUBSPECIES["$genome"]="$species"
            echo -e "$genome\t$species" >> "$GENOME_SUBSPECIES_FILE"
        else
            # If no species either, use genus as fallback
            if [ "$genus" != "NA" ] && [ -n "$genus" ]; then
                GENOME_TO_SUBSPECIES["$genome"]="$genus"
                echo -e "$genome\t$genus" >> "$GENOME_SUBSPECIES_FILE"
            else
                echo "⚠️  Genome $genome has no subspecies, species, or genus defined"
            fi
        fi
    fi
    
    # Process each taxonomic level
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
    
    # GENOME (final level) - link to the most specific level available
    if [ -z "${TAXID_ASSIGNED[$genome]}" ]; then
        TAXID_ASSIGNED["$genome"]=$NEXT_TAXID
        echo -e "${NEXT_TAXID}\t|\t${current_parent}\t|\tno rank\t|\t\t|\t0\t|\t0\t|\t1\t|\t0\t|\t0\t|\t0\t|\t0\t|\t0\t|\t\t|" >> "$NODES_FILE"
        echo -e "${NEXT_TAXID}\t|\t${genome}\t|\t\t|\tscientific name\t|" >> "$NAMES_FILE"
        ((NEXT_TAXID++))
        TAXON_COUNTS["genome"]=$((TAXON_COUNTS["genome"] + 1))
    fi
    
done < "$TAXA_FILE"

# Final summary
echo ""
echo "✅ PROCESSING COMPLETED"
echo "================================"
echo "📊 STATISTICS:"
echo "   • Lines processed: $((LINE_NUMBER - 1))"
echo "   • Unique genomes: $GENOME_COUNT"
echo "   • Genome→subspecies relationships: $(wc -l < "$GENOME_SUBSPECIES_FILE")"
echo "   • TaxIDs assigned: $((NEXT_TAXID - 100000))"
echo "   • Files generated:"
echo "     - $GENOME_SUBSPECIES_FILE (genome→subspecies mapping)"
echo "     - $NODES_FILE (taxonomy)"
echo "     - $NAMES_FILE (taxonomic names)"

echo ""
echo "📈 BREAKDOWN BY TAXONOMIC LEVEL:"
for level in domain phylum class order family genus species subspecies genome; do
    if [ -n "${TAXON_COUNTS[$level]}" ]; then
        echo "   • $level: ${TAXON_COUNTS[$level]}"
    fi
done

# Show first lines of each file
echo ""
echo "🔍 FIRST 5 GENOME → SUBSPECIES RELATIONSHIPS:"
head -5 "$GENOME_SUBSPECIES_FILE"

echo ""
echo "🔍 FIRST 3 LINES OF nodes.txt:"
head -3 "$NODES_FILE"

echo ""
echo "🔍 FIRST 3 LINES OF names.txt:"
head -3 "$NAMES_FILE"

# Check generated files
echo ""
echo "📁 GENERATED FILES:"
echo "   • $GENOME_SUBSPECIES_FILE: $(wc -l < "$GENOME_SUBSPECIES_FILE") lines"
echo "   • $NODES_FILE: $(wc -l < "$NODES_FILE") lines"
echo "   • $NAMES_FILE: $(wc -l < "$NAMES_FILE") lines"

# Analysis of genome→subspecies relationships
echo ""
echo "🔎 ANALYSIS OF GENOME → SUBSPECIES RELATIONSHIPS:"

# Count genomes per subspecies
echo "📊 Distribution of genomes per subspecies:"
cut -f2 "$GENOME_SUBSPECIES_FILE" | sort | uniq -c | sort -nr | head -10 | while read count subspecies; do
    echo "   • $subspecies: $count genomes"
done

# Check genomes without subspecies
genomes_with_subspecies=$(cut -f1 "$GENOME_SUBSPECIES_FILE" | wc -l)
if [ "$genomes_with_subspecies" -eq "$GENOME_COUNT" ]; then
    echo "✅ All genomes have an associated subspecies"
else
    echo "⚠️  $((GENOME_COUNT - genomes_with_subspecies)) genomes without subspecies"
fi

echo ""
echo "🎯 Files generated successfully!"
echo "💡 Use these files for:"
echo "   - genome_subspecies_map.txt: Link genomes to subspecies"
echo "   - nodes.txt and names.txt: Build the Kraken2 database"
