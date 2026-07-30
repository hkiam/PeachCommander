#!/usr/bin/env bash
# build-archive-plugin.sh — build Archive.pcxplugin (read-only PCX packer backed
# by the system libarchive via /usr/bin/tar). Installs into the app's plugins dir.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Archive.pcxplugin"
ARCH="$(uname -m)"; TARGET="${ARCH}-apple-macos13.0"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Archive/Info.plist" "$BUNDLE/Contents/Info.plist"
swiftc -emit-library -O -module-name Archive -target "$TARGET" \
  -import-objc-header "$ROOT/Plugins/Archive/ArchiveBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Archive" \
  "$ROOT/Plugins/Archive/archive.swift"
echo "Built $BUNDLE"
