#!/bin/bash

# Script for Bracken - REQUIRES environment activated manually
# build_bracken_manual.sh

KRAKEN_DB="./CustomDB"

echo "=== BUILDING BRACKEN ==="
echo "⚠️  YOU MUST activate the environment manually first:"
echo "   conda activate bracken2"
echo ""

# Check that the environment is active
if [[ -z "$CONDA_DEFAULT_ENV" ]]; then
    echo "❌ ERROR: No active conda environment"
    echo "   Run first: conda activate bracken2"
    exit 1
fi

echo "✅ Active environment: $CONDA_DEFAULT_ENV"

# Check bracken-build
if ! command -v bracken-build &> /dev/null; then
    echo "❌ ERROR: bracken-build not available"
    echo "   Make sure you are in the correct environment"
    exit 1
fi

echo "✅ bracken-build: $(which bracken-build)"

# Check database
if [ ! -d "$KRAKEN_DB" ]; then
    echo "❌ ERROR: $KRAKEN_DB not found"
    exit 1
fi

echo "✅ Database found"

# Parameters
READ_LEN=150
KMER_LEN=40
THREADS=30

echo ""
echo "🎯 PARAMETERS:"
echo "   • READ_LEN: $READ_LEN"
echo "   • KMER_LEN: $KMER_LEN"
echo "   • THREADS: $THREADS"

# Build
echo ""
echo "🏗️  Building Bracken..."
bracken-build -d "$KRAKEN_DB" -k $KMER_LEN -l $READ_LEN -t $THREADS

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ✅ ✅ BRACKEN BUILT SUCCESSFULLY ✅ ✅ ✅"
    
    # Check generated file
    if [ -f "$KRAKEN_DB/database${READ_LEN}mers.kmer_distrib" ]; then
        size=$(du -h "$KRAKEN_DB/database${READ_LEN}mers.kmer_distrib" | cut -f1)
        echo "📄 File generated: database${READ_LEN}mers.kmer_distrib ($size)"
    fi
    
else
    echo ""
    echo "❌ Error during build"
    exit 1
fi
