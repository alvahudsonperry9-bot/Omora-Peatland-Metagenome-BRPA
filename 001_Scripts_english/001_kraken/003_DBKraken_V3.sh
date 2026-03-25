#!/bin/bash

# Path configuration
BASE_DIR="."
GENOMES_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/007_MAGs_27_02_2026"  # Unified genomes folder
CUSTOM_DB="$BASE_DIR/CustomDB"
TAXONOMY_DIR="$BASE_DIR"
GENOME_MAP="$BASE_DIR/genome_subspecies_map.txt"

echo "=== BUILDING KRAKEN2 DATABASE WITH FULL TAXONOMY ==="
echo "Base directory: $BASE_DIR"
echo "Genomes directory: $GENOMES_DIR (ALL genomes here)"
echo "Database: $CUSTOM_DB"
echo "Taxonomy: $TAXONOMY_DIR"
echo ""

# Step 0: Navigate to base directory
cd "$BASE_DIR"

# Step 1: Clean and create directory structure
echo "🔄 Step 1: Creating directory structure..."
rm -rf "$CUSTOM_DB"
mkdir -p "$CUSTOM_DB/taxonomy"
mkdir -p "$CUSTOM_DB/library"

# Step 2: Copy taxonomy files
echo "📊 Step 2: Copying taxonomy files..."
if [ -f "nodes.txt" ] && [ -f "names.txt" ]; then
    cp "nodes.txt" "$CUSTOM_DB/taxonomy/nodes.dmp"
    cp "names.txt" "$CUSTOM_DB/taxonomy/names.dmp"
    echo "✅ Taxonomy copied:"
    echo "   - nodes.dmp: $(wc -l < "$CUSTOM_DB/taxonomy/nodes.dmp") lines"
    echo "   - names.dmp: $(wc -l < "$CUSTOM_DB/taxonomy/names.dmp") lines"
else
    echo "❌ ERROR: nodes.txt and/or names.txt not found"
    exit 1
fi

# Step 3: Load taxid mapping from names.dmp
echo "🗺️  Step 3: Loading taxid mapping..."
declare -A TAXID_MAP

while IFS=$'|\t' read -r taxid name rest; do
    # Strip whitespace
    taxid=$(echo "$taxid" | sed 's/^[ \t]*//;s/[ \t]*$//')
    name=$(echo "$name" | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    if [[ "$taxid" =~ ^[0-9]+$ ]] && [[ -n "$name" ]]; then
        TAXID_MAP["$name"]=$taxid
    fi
done < "$CUSTOM_DB/taxonomy/names.dmp"

echo "✅ Loaded ${#TAXID_MAP[@]} taxids"

# Step 4: Load genome -> subspecies mapping
echo "🔗 Step 4: Loading genome -> subspecies mapping..."
declare -A GENOME_SUBSPECIES_MAP

if [ -f "$GENOME_MAP" ]; then
    while IFS=$'\t' read -r genome subspecies; do
        if [[ -n "$genome" && -n "$subspecies" ]]; then
            GENOME_SUBSPECIES_MAP["$genome"]="$subspecies"
        fi
    done < "$GENOME_MAP"
    echo "✅ Loaded ${#GENOME_SUBSPECIES_MAP[@]} genome->subspecies relationships"
else
    echo "❌ ERROR: File $GENOME_MAP not found"
    exit 1
fi

# Function to find FASTA file (searches only in one folder)
find_fasta_file() {
    local genome_name="$1"
    
    # Search in the unified directory
    local genome_file="$GENOMES_DIR/${genome_name}.fa"
    if [ -f "$genome_file" ]; then
        echo "$genome_file"
        return
    fi
    
    # Search recursively in subdirectories (just in case)
    local found_file=$(find "$GENOMES_DIR" -name "${genome_name}.fa" -type f 2>/dev/null | head -1)
    if [ -n "$found_file" ]; then
        echo "$found_file"
        return
    fi
    
    echo ""
}

# Function to convert FASTA format to Kraken2-compatible format
convert_fasta_for_kraken2() {
    local input_file="$1"
    local taxid="$2"
    local output_file="$3"
    
    # Convert MEGAHIT/SPAdes format to Kraken2 format
    awk -v taxid="$taxid" '
    /^>/ {
        # For headers like ">100488 k141_51745 flag=1 multi=61.0000 len=3573"
        # or ">k141_51745"
        if ($0 ~ /^>[0-9]+\s+/) {
            # Format with taxid at the start: extract the contig ID
            contig_id = $2
            print ">|kraken:taxid|" taxid " " contig_id
        } else if ($0 ~ /^>k141_/) {
            # SPAdes format: add taxid
            contig_id = substr($0, 2)
            print ">|kraken:taxid|" taxid " " contig_id
        } else {
            # Other format: add taxid keeping the original header
            original_header = substr($0, 2)
            print ">|kraken:taxid|" taxid " " original_header
        }
    }
    !/^>/ {
        print
    }
    ' "$input_file" > "$output_file"
}

# Step 5: Process genomes with specific taxonomy
echo "🧬 Step 5: Processing genomes with specific taxonomy..."
PROCESSED_COUNT=0
MISSING_COUNT=0
ERROR_COUNT=0

for genome in "${!GENOME_SUBSPECIES_MAP[@]}"; do
    subspecies="${GENOME_SUBSPECIES_MAP[$genome]}"
    
    # Look up taxid for the subspecies
    if [ -n "${TAXID_MAP[$subspecies]}" ]; then
        taxid="${TAXID_MAP[$subspecies]}"
    else
        # If subspecies not found, look up by genome name
        if [ -n "${TAXID_MAP[$genome]}" ]; then
            taxid="${TAXID_MAP[$genome]}"
            echo "⚠️  Using genome taxid for $genome (subspecies not found: $subspecies)"
        else
            echo "❌ No taxid found for $genome (subspecies: $subspecies)"
            ((ERROR_COUNT++))
            continue
        fi
    fi
    
    echo "  🔍 Looking up: $genome.fa → subspecies: $subspecies → taxid: $taxid"
    
    # Find FASTA file in the unified directory
    fasta_file=$(find_fasta_file "$genome")
    
    if [[ -n "$fasta_file" && -f "$fasta_file" ]]; then
        echo "    📁 Found: $(basename "$fasta_file")"
        
        # Convert to Kraken2 format
        temp_fasta="$CUSTOM_DB/library/${genome}_with_taxid.fna"
        convert_fasta_for_kraken2 "$fasta_file" "$taxid" "$temp_fasta"
        
        # Verify conversion
        if [[ -s "$temp_fasta" ]]; then
            # Check that headers have the correct format
            if grep -q "kraken:taxid|$taxid" "$temp_fasta"; then
                echo "    ✅ Converted correctly"
                
                # Add to Kraken2 library
                kraken2-build --add-to-library "$temp_fasta" --db "$CUSTOM_DB" > /dev/null 2>&1
                
                if [[ $? -eq 0 ]]; then
                    ((PROCESSED_COUNT++))
                    echo "    📚 Added to library"
                    
                    # Remove temporary file
                    rm -f "$temp_fasta"
                else
                    echo "    ❌ Error adding to library"
                    ((ERROR_COUNT++))
                fi
            else
                echo "    ❌ Error: taxid not detected in headers"
                ((ERROR_COUNT++))
            fi
        else
            echo "    ❌ Error: converted file is empty"
            ((ERROR_COUNT++))
        fi
    else
        echo "    ❌ NOT found: $genome.fa"
        ((MISSING_COUNT++))
    fi
    
    # Show progress every 50 genomes
    if [[ $((PROCESSED_COUNT % 50)) -eq 0 ]] && [[ $PROCESSED_COUNT -ne 0 ]]; then
        echo "    📊 Progress: $PROCESSED_COUNT genomes processed..."
    fi
done

# Step 6: Build database
echo ""
echo "🏗️  Step 6: Building database..."
echo "  ================================="
echo "  📊 STATISTICS:"
echo "  • Genomes in mapping: ${#GENOME_SUBSPECIES_MAP[@]}"
echo "  • Genomes processed: $PROCESSED_COUNT"
echo "  • Genomes not found: $MISSING_COUNT"
echo "  • Genomes with error: $ERROR_COUNT"
echo "  ================================="

# Check that there are files in the library
library_files=$(find "$CUSTOM_DB/library" -name "*.fna" 2>/dev/null | wc -l)
if [[ $library_files -eq 0 ]]; then
    echo "❌ ERROR: No files in the library"
    exit 1
fi

echo "📚 Files in library: $library_files"

if [[ $PROCESSED_COUNT -gt 0 ]]; then
    echo "🚀 Starting build with 30 threads..."
    
    # Build database
    kraken2-build --build --db "$CUSTOM_DB" --threads 30
    
    if [[ $? -eq 0 ]]; then
        echo ""
        echo "✅ ✅ ✅ DATABASE BUILT SUCCESSFULLY ✅ ✅ ✅"
        echo ""
        echo "=== FINAL SUMMARY ==="
        echo "📁 Location: $CUSTOM_DB"
        echo "📊 Taxa in taxonomy: $(wc -l < "$CUSTOM_DB/taxonomy/nodes.dmp")"
        echo "🧬 Genomes processed: $PROCESSED_COUNT/${#GENOME_SUBSPECIES_MAP[@]}"
        echo "❌ Genomes not found: $MISSING_COUNT"
        echo "❌ Genomes with error: $ERROR_COUNT"
        echo ""
        
        # Show generated files
        echo "=== FILES IN THE DATABASE ==="
        find "$CUSTOM_DB" -type f -name "*.k2d" | while read file; do
            size=$(du -h "$file" | cut -f1)
            echo "  📄 $(basename "$file") ($size)"
        done
        
        # Check critical files
        echo ""
        echo "=== CRITICAL FILE VERIFICATION ==="
        for file in "hash.k2d" "opts.k2d" "taxo.k2d"; do
            if [ -f "$CUSTOM_DB/$file" ]; then
                size=$(du -h "$CUSTOM_DB/$file" | cut -f1)
                echo "  ✅ $file ($size)"
            else
                echo "  ❌ $file (NOT FOUND)"
            fi
        done
        
        echo ""
        echo "🎯 Database ready to use!"
        echo "💡 You can test it with:"
        echo "   kraken2 --db $CUSTOM_DB --threads 8 --report report.txt your_file.fastq"
        
    else
        echo "❌ Error building the database"
        echo "💡 Try with fewer threads: --threads 8"
        exit 1
    fi
else
    echo "❌ ERROR: Could not process FASTA files"
    echo "   Verify that:"
    echo "   1. The .fa files exist in $GENOMES_DIR"
    echo "   2. The names in genome_subspecies_map.txt match the .fa files"
    exit 1
fi
