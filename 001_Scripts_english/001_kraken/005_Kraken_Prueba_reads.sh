#!/bin/bash

# Path configuration - MULTIPLE SAMPLES
BASE_DB="/media/pinguicula/Braulio2232/Base_Chile_28_02_2026/CustomDB"
INPUT_DIR="/media/pinguicula/8T2_BRPA/Muestras/001_Chile/004_quality_clean4"
OUTPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results"

# List of samples to process (with the A prefix and format)
SAMPLES=(
    "A01_P1-1" "A01_P2-1" "A01_P4-1" "A02_P2-2" "A02_P4-2" "A03_P1-3" "A03_P2-3" "A03_P4-3"
    "A04_P1-4" "A04_P2-4" "A04_P4-4" "A05_P1-5" "A05_P2-5" "A05_P4-5" "A06_P1-6" "A06_P2-6"
    "A06_P4-6" "A07_P1-7" "A07_P2-7" "A07_P4-7" "A08_P1-8" "A08_P4-8" "A09_P1-9" "A09_P2-9"
    "A09_P4-9" "A10_P1-10" "A10_P2-10" "A11_P1-11" "A11_P2-11" "A12_P1-12" "A13_P1-13" "A14_P1-14"
)

# Create output directory if it does not exist
mkdir -p "$OUTPUT_DIR"

echo "=== MULTI-SAMPLE CLASSIFICATION WITH KRAKEN2 ==="
echo "Database: $BASE_DB"
echo "Input directory: $INPUT_DIR"
echo "Samples to process: ${#SAMPLES[@]} samples"
echo "Output directory: $OUTPUT_DIR"
echo "Threads used: 31"
echo ""

# Check that the database exists
if [ ! -f "$BASE_DB/hash.k2d" ]; then
    echo "ERROR: Database not found at $BASE_DB"
    exit 1
fi

# Process each sample
for SAMPLE in "${SAMPLES[@]}"; do
    echo "🔬 Processing sample: $SAMPLE"
    echo "=========================================="
    
    # Sample-specific directory
    SAMPLE_DIR="$INPUT_DIR/$SAMPLE"
    
    # Check that the directory exists
    if [ ! -d "$SAMPLE_DIR" ]; then
        echo "❌ ERROR: Directory not found: $SAMPLE_DIR"
        continue
    fi
    
    # Input files (new format: inside folder with suffix _nonhuman_unmapped.1.gz)
    R1_FILE="$SAMPLE_DIR/${SAMPLE}_nonhuman_unmapped.1.gz"
    R2_FILE="$SAMPLE_DIR/${SAMPLE}_nonhuman_unmapped.2.gz"
    
    # Check that the files exist
    if [ ! -f "$R1_FILE" ]; then
        echo "❌ ERROR: File not found: $R1_FILE"
        continue
    fi
if [ ! -f "$R2_FILE" ]; then
    echo "❌ ERROR: File not found: $R2_FILE"
    continue
fi
    
    # Output file names
    OUTPUT_FILE="$OUTPUT_DIR/${SAMPLE}_reads_clasificado.kraken"
    REPORT_FILE="$OUTPUT_DIR/${SAMPLE}_reads_report.txt"
    SUMMARY_FILE="$OUTPUT_DIR/${SAMPLE}_reads_summary.txt"
    
    # Get file information
    R1_SIZE=$(du -h "$R1_FILE" | cut -f1)
    R2_SIZE=$(du -h "$R2_FILE" | cut -f1)
    
    echo "📊 Files found:"
    echo "   R1: $(basename $R1_FILE) ($R1_SIZE)"
    echo "   R2: $(basename $R2_FILE) ($R2_SIZE)"
    
    # Classification command
    echo "⏳ Running Kraken2 for $SAMPLE..."
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
    
    # Check success
    if [ $? -eq 0 ]; then
        echo "✅ $SAMPLE - Classification completed"
        
        # Generate quick summary
        if [ -f "$OUTPUT_FILE" ]; then
            CLASSIFIED=$(grep -c "^C" "$OUTPUT_FILE" 2>/dev/null || echo "0")
            UNCLASSIFIED=$(grep -c "^U" "$OUTPUT_FILE" 2>/dev/null || echo "0")
            TOTAL=$((CLASSIFIED + UNCLASSIFIED))
            
            if [ $TOTAL -gt 0 ]; then
                PERCENT=$(echo "scale=2; $CLASSIFIED * 100 / $TOTAL" | bc 2>/dev/null || echo "0")
                echo "📈 $SAMPLE - Classified: $CLASSIFIED/$TOTAL ($PERCENT%)"
            fi
            
            # Save summary to file
            {
                echo "CLASSIFICATION SUMMARY - $SAMPLE"
                echo "===================================="
                echo "R1 file: $(basename $R1_FILE) ($R1_SIZE)"
                echo "R2 file: $(basename $R2_FILE) ($R2_SIZE)"
                echo "Total reads processed: $TOTAL"
                echo "Classified reads: $CLASSIFIED"
                echo "Unclassified reads: $UNCLASSIFIED"
                if [ $TOTAL -gt 0 ]; then
                    echo "Classification percentage: $PERCENT%"
                fi
                echo "Date: $(date)"
            } > "$SUMMARY_FILE"
            echo "📝 Summary saved to: $SUMMARY_FILE"
        fi
    else
        echo "❌ $SAMPLE - Classification error"
    fi
    
    echo ""
done

echo "🎯 Processing of all samples completed!"
echo "📁 Results in: $OUTPUT_DIR"

# Show final summary
echo ""
echo "=== FINAL SUMMARY ==="
echo "Samples processed: ${#SAMPLES[@]}"
echo "Available results:"
ls -lh "$OUTPUT_DIR" | grep -E "\.(kraken|txt)$" | sed 's/^/  /'
