#!/bin/bash

# Script para Bracken - REQUIERE ambiente activado manualmente
# build_bracken_manual.sh

KRAKEN_DB="./CustomDB"

echo "=== CONSTRUCCIÓN DE BRACKEN ==="
echo "⚠️  DEBES activar el ambiente manualmente primero:"
echo "   conda activate bracken2"
echo ""

# Verificar que el ambiente está activo
if [[ -z "$CONDA_DEFAULT_ENV" ]]; then
    echo "❌ ERROR: No hay ambiente conda activo"
    echo "   Ejecuta primero: conda activate bracken2"
    exit 1
fi

echo "✅ Ambiente activo: $CONDA_DEFAULT_ENV"

# Verificar bracken-build
if ! command -v bracken-build &> /dev/null; then
    echo "❌ ERROR: bracken-build no disponible"
    echo "   Asegúrate de estar en el ambiente correcto"
    exit 1
fi

echo "✅ bracken-build: $(which bracken-build)"

# Verificar base de datos
if [ ! -d "$KRAKEN_DB" ]; then
    echo "❌ ERROR: No se encuentra $KRAKEN_DB"
    exit 1
fi

echo "✅ Base de datos encontrada"

# Parámetros
READ_LEN=150
KMER_LEN=40
THREADS=30

echo ""
echo "🎯 PARÁMETROS:"
echo "   • READ_LEN: $READ_LEN"
echo "   • KMER_LEN: $KMER_LEN"
echo "   • THREADS: $THREADS"

# Construir
echo ""
echo "🏗️  Construyendo Bracken..."
bracken-build -d "$KRAKEN_DB" -k $KMER_LEN -l $READ_LEN -t $THREADS

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ✅ ✅ BRACKEN CONSTRUIDO EXITOSAMENTE ✅ ✅ ✅"
    
    # Verificar archivo generado
    if [ -f "$KRAKEN_DB/database${READ_LEN}mers.kmer_distrib" ]; then
        size=$(du -h "$KRAKEN_DB/database${READ_LEN}mers.kmer_distrib" | cut -f1)
        echo "📄 Archivo generado: database${READ_LEN}mers.kmer_distrib ($size)"
    fi
    
else
    echo ""
    echo "❌ Error en la construcción"
    exit 1
fi
