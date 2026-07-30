#!/usr/bin/env bash
# Build AIColumn.pdxplugin — an on-device ML panel column (dominant language via
# NaturalLanguage). A content-field (PDX) plugin; no host frameworks needed.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/AIColumn.pdxplugin"
ARCH="$(uname -m)"; TARGET="${ARCH}-apple-macos13.0"

rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/AIColumn/Info.plist" "$BUNDLE/Contents/Info.plist"
swiftc -emit-library -O -module-name AIColumn -target "$TARGET" \
  -framework Foundation -framework NaturalLanguage \
  -o "$BUNDLE/Contents/MacOS/AIColumn" \
  "$ROOT/Plugins/AIColumn/aicolumn.swift"
echo "Built $BUNDLE"
