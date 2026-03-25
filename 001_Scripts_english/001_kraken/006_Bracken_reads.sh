#!/bin/bash

# Directories and files - ALL ABSOLUTE PATHS
INPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results"
OUTPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken"
DB_PATH="/media/pinguicula/Braulio2232/Base_Chile_20_02_2026/CustomDB"
LEVEL="S"  # Level for abundance estimation (Species)

# List of samples to process (UPDATED with correct names matching your structure)
SAMPLES=(
    "A01_P1-1" "A01_P2-1" "A01_P4-1" "A02_P2-2" "A02_P4-2" "A03_P1-3" "A03_P2-3" "A03_P4-3"
    "A04_P1-4" "A04_P2-4" "A04_P4-4" "A05_P1-5" "A05_P2-5" "A05_P4-5" "A06_P1-6" "A06_P2-6"
    "A06_P4-6" "A07_P1-7" "A07_P2-7" "A07_P4-7" "A08_P1-8" "A08_P4-8" "A09_P1-9" "A09_P2-9"
    "A09_P4-9" "A10_P1-10" "A10_P2-10" "A11_P1-11" "A11_P2-11" "A12_P1-12" "A13_P1-13" "A14_P1-14"
)

# Create output directory if it does not exist
mkdir -p "$OUTPUT_DIR"

echo "=== ABUNDANCE ESTIMATION WITH BRACKEN ==="
echo "📁 Database: $DB_PATH"
echo "📂 Input directory: $INPUT_DIR"
echo "📂 Output directory: $OUTPUT_DIR"
echo "🔬 Samples to process: ${#SAMPLES[@]}"
echo "📊 Taxonomic level: $LEVEL"
echo "📏 Read length: 150"
echo ""

# Check that the database exists
if [ ! -f "$DB_PATH/hash.k2d" ]; then
    echo "❌ ERROR: Database not found at $DB_PATH"
    exit 1
fi

# Check that the kmer distribution file exists
KMER_DISTRIB="$DB_PATH/database150mers.kmer_distrib"
if [ ! -f "$KMER_DISTRIB" ]; then
    echo "❌ ERROR: database150mers.kmer_distrib not found in $DB_PATH"
    echo "   Run first: bracken-build -d $DB_PATH -k 35 -l 150 -t 8"
    exit 1
fi

# Check that the input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Process each sample
PROCESSED_COUNT=0
ERROR_COUNT=0

for SAMPLE in "${SAMPLES[@]}"; do
    echo "🔬 Processing sample: $SAMPLE"
    echo "=========================================="
    
    # Input file (Kraken2 report) - ABSOLUTE PATH
    REPORT_FILE="$INPUT_DIR/${SAMPLE}_reads_report.txt"
    
    # Check that the Kraken2 report exists
    if [ ! -f "$REPORT_FILE" ]; then
        echo "❌ ERROR: File not found: $REPORT_FILE"
        echo "   Make sure Kraken2 has already processed this sample"
        ((ERROR_COUNT++))
        continue
    fi
    
    # Bracken output file names - ABSOLUTE PATH
    BRACKEN_OUTPUT="$OUTPUT_DIR/${SAMPLE}_bracken.txt"
    BRACKEN_REPORT="$OUTPUT_DIR/${SAMPLE}_bracken_report.txt"
    
    # Get file information
    REPORT_SIZE=$(du -h "$REPORT_FILE" | cut -f1)
    REPORT_LINES=$(wc -l < "$REPORT_FILE")
    echo "📊 Input file: $(basename $REPORT_FILE)"
    echo "   Size: $REPORT_SIZE | Lines: $REPORT_LINES"
    
    # Bracken command (using absolute paths)
    echo "⏳ Running Bracken for $SAMPLE..."
    bracken -d "$DB_PATH" \
            -i "$REPORT_FILE" \
            -o "$BRACKEN_OUTPUT" \
            -w "$BRACKEN_REPORT" \
            -r 150 \
            -l "$LEVEL" \
            -t 30
    
    # Check success
    if [ $? -eq 0 ]; then
        echo "✅ $SAMPLE - Bracken completed"
        ((PROCESSED_COUNT++))
        
        # Generate quick summary
        if [ -f "$BRACKEN_OUTPUT" ]; then
            LINE_COUNT=$(wc -l < "$BRACKEN_OUTPUT")
            # Subtract 1 to exclude the header
            TAXA_COUNT=$((LINE_COUNT - 1))
            
            # Output file size
            OUTPUT_SIZE=$(du -h "$BRACKEN_OUTPUT" | cut -f1)
            
            echo "📈 $SAMPLE - Results:"
            echo "   • Taxa identified: $TAXA_COUNT"
            echo "   • Output file size: $OUTPUT_SIZE"
            
            # Show top 5 most abundant taxa
            if [ $TAXA_COUNT -gt 0 ]; then
                echo "🔝 Top 5 most abundant taxa:"
                head -6 "$BRACKEN_OUTPUT" | tail -5 | while IFS=$'\t' read -r name taxid level fraction reads; do
                    if [ -n "$name" ] && [ "$name" != "name" ]; then
                        echo "   • $name: $fraction%"
                    fi
                done
            fi
        fi
        
    else
        echo "❌ $SAMPLE - Bracken error"
        ((ERROR_COUNT++))
    fi
    
    echo ""
done

# Final summary
echo "=== FINAL SUMMARY ==="
echo "✅ Samples processed successfully: $PROCESSED_COUNT"
echo "❌ Samples with error: $ERROR_COUNT"
echo "📁 Results saved to: $OUTPUT_DIR"

# Check generated files
echo ""
echo "📋 GENERATED FILES:"
if [ -d "$OUTPUT_DIR" ]; then
    ls -lh "$OUTPUT_DIR" | grep -E "\.txt$" | sed 's/^/   /' | head -10
    TOTAL_FILES=$(find "$OUTPUT_DIR" -name "*.txt" | wc -l)
    echo "   ... and $((TOTAL_FILES - 10)) more files (total: $TOTAL_FILES)"
else
    echo "   ⚠️ No files were generated"
fi

echo ""
echo "🎯 Bracken processing completed!"
echo "📁 Full results path: $OUTPUT_DIR"
echo ""
echo "💡 To view results for a specific sample:"
echo "   head -10 $OUTPUT_DIR/A01_P1-1_bracken.txt"
