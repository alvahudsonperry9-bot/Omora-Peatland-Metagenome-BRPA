#!/bin/bash


# Directories with absolute paths
INPUT_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken"
OUTPUT_BIOM_DIR="/media/pinguicula/8T_BRPA/Muestras/001_Chile/011_kraken2/results/008_bracken/biom"

echo "=== CREATING BIOM FROM BRACKEN FILES ==="
echo "📂 Input directory: $INPUT_DIR"
echo "📂 Output directory: $OUTPUT_BIOM_DIR"
echo ""

# Check that the input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ ERROR: Directory not found: $INPUT_DIR"
    exit 1
fi

# Search for Bracken files (adapted to your file naming)
echo "🔍 Searching for Bracken files..."
bracken_files=$(find "$INPUT_DIR" -maxdepth 1 -name "*_bracken_report.txt" | sort)

if [ -z "$bracken_files" ]; then
    echo "❌ No *_bracken.txt files found in $INPUT_DIR"
    echo "   Also searching for *_reads_report_bracken_species.txt..."
    bracken_files=$(find "$INPUT_DIR" -maxdepth 1 -name "*_reads_report_bracken_species.txt" | sort)
fi

if [ -z "$bracken_files" ]; then
    echo "❌ ERROR: No Bracken files found to process"
    echo "   Formats searched: *_bracken.txt or *_reads_report_bracken_species.txt"
    exit 1
fi

# Count files found
file_count=$(echo "$bracken_files" | wc -l)
echo "✅ Found $file_count Bracken files:"
echo "$bracken_files" | head -5 | while read file; do
    echo "   📄 $(basename $file)"
done
if [ $file_count -gt 5 ]; then
    echo "   ... and $((file_count - 5)) more files"
fi

# Create output directory
mkdir -p "$OUTPUT_BIOM_DIR"

# Create temporary file for file list
file_list="$OUTPUT_BIOM_DIR/bracken_files_list.txt"
echo "$bracken_files" > "$file_list"

echo ""
echo "🏗️  GENERATING BIOM FROM BRACKEN FILES..."
echo "   Files to process: $file_count"

# Check that files are not empty
empty_files=0
for file in $bracken_files; do
    if [ ! -s "$file" ]; then
        echo "⚠️  Empty file: $(basename $file)"
        ((empty_files++))
    fi
done

if [ $empty_files -gt 0 ]; then
    echo "⚠️  Warning: $empty_files files are empty"
fi

# Use bracken-biom if available, otherwise kraken-biom with specific format
output_biom="$OUTPUT_BIOM_DIR/table_bracken_reads.biom"

if command -v bracken-biom &> /dev/null; then
    echo "🔧 Using bracken-biom..."
    bracken-biom --files $bracken_files --fmt "json" -o "$output_biom"
elif command -v kraken-biom &> /dev/null; then
    echo "🔧 Using kraken-biom with Bracken files..."
    kraken-biom $bracken_files --fmt "json" -o "$output_biom"
else
    echo "❌ ERROR: Neither bracken-biom nor kraken-biom found"
    echo "   Install with: pip install kraken-biom or bracken-biom"
    exit 1
fi

# Check result
if [ $? -eq 0 ] && [ -f "$output_biom" ]; then
    size=$(du -h "$output_biom" | cut -f1)
    echo "✅ BIOM generated successfully:"
    echo "   📁 Path: $output_biom"
    echo "   📦 Size: $size"
    
    # Check BIOM content
    echo ""
    echo "📊 BIOM SUMMARY:"
    if command -v biom &> /dev/null; then
        biom summarize-table -i "$output_biom" 2>/dev/null | head -20
    else
        echo "   ℹ️  Install biom-format to see summary: pip install biom-format"
        echo "   📊 Number of samples: $file_count"
        echo "   📊 Generated file: $(basename $output_biom)"
    fi
    
    # Create a short report
    report_file="$OUTPUT_BIOM_DIR/biom_creation_report.txt"
    {
        echo "BIOM CREATION REPORT"
        echo "=========================="
        echo "Date: $(date)"
        echo "Input directory: $INPUT_DIR"
        echo "Output directory: $OUTPUT_BIOM_DIR"
        echo "Bracken files found: $file_count"
        echo "Empty files detected: $empty_files"
        echo "BIOM file generated: $output_biom"
        echo "BIOM size: $size"
        echo ""
        echo "Files processed:"
        echo "$bracken_files" | while read file; do
            if [ -f "$file" ]; then
                lines=$(wc -l < "$file")
                sample=$(basename "$file" | sed 's/_bracken.txt//' | sed 's/_reads_report_bracken_species.txt//')
                echo "  • $sample: $(basename $file) ($lines lines)"
            fi
        done
    } > "$report_file"
    echo "📝 Report saved: $report_file"
    
else
    echo "❌ Error generating BIOM"
    exit 1
fi

# Remove temporary file
rm -f "$file_list"

echo ""
echo "🎯 BIOM created successfully from Bracken files!"
echo "📁 Full path: $output_biom"
echo ""
echo "💡 To use the BIOM in R/Python:"
echo "   R: library(biomformat); biom <- read_biom('$output_biom')"
echo "   Python: import biom; table = biom.load_table('$output_biom')"
