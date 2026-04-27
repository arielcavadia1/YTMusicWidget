#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  YTMusic Floating Widget — Build & Run
#  Uso: ./run.sh
# ─────────────────────────────────────────────────────────────

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/floating-widget"

echo "🔨 Compilando YTMusic Widget..."
swift build -c release 2>&1

BINARY=".build/release/YTMusicWidget"

if [ ! -f "$BINARY" ]; then
  echo "❌ Error: no se encontró el binario compilado."
  exit 1
fi

echo "✅ Compilado. Iniciando app..."
echo "   → Busca el ícono de nota musical 🎵 en tu barra de menú."
echo "   → Deja YouTube Music abierto en Chrome con la extensión cargada."
echo ""
"$BINARY"
