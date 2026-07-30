#!/usr/bin/env bash
# build-treemap-plugin.sh — build the Treemap.ptxplugin bundle (external view
# contribution). Installs into the app's plugins dir by default.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Treemap.ptxplugin"
ARCH="$(uname -m)"; TARGET="${ARCH}-apple-macos13.0"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Treemap/Info.plist" "$BUNDLE/Contents/Info.plist"
swiftc -emit-library -O \
  -module-name Treemap \
  -target "$TARGET" \
  -framework AppKit \
  -import-objc-header "$ROOT/Plugins/Treemap/TreemapBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Treemap" \
  "$ROOT/Plugins/Treemap/treemap.swift" \
  "$ROOT/Plugins/Treemap/ScanEngine.swift" \
  "$ROOT/Plugins/Treemap/Renderers.swift" \
  "$ROOT/Plugins/Treemap/TreemapConfig.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/Treemap/Resources" ]; then
  cp -R "$ROOT/Plugins/Treemap/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
