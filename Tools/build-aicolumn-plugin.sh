#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build AIColumn.pdxplugin — an on-device ML panel column (dominant language via
# NaturalLanguage). A content-field (PDX) plugin; no host frameworks needed.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/AIColumn.pdxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/AIColumn/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O -module-name AIColumn -target "$TARGET" \
  -framework Foundation -framework NaturalLanguage \
  -o "$BUNDLE/Contents/MacOS/AIColumn" \
  "$ROOT/Plugins/AIColumn/aicolumn.swift"
echo "Built $BUNDLE"
