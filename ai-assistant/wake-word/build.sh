#!/bin/bash
# Build and install AI Assistant Wake Word package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔨 Building ai-assistant-wake-word-npu package..."
echo

# Clean old packages
rm -f *.pkg.tar.zst

# Build package
makepkg -sf

# Find the built package
PKG_FILE=$(ls -t ai-assistant-wake-word-npu-*.pkg.tar.zst 2>/dev/null | head -1)

if [[ -z "$PKG_FILE" ]]; then
    echo "❌ Package build failed!"
    exit 1
fi

echo
echo "✅ Package built: $PKG_FILE"
echo
echo "Install with:"
echo "  sudo pacman -U $PKG_FILE"
echo
echo "Or build and install in one step:"
echo "  makepkg -sfi"
