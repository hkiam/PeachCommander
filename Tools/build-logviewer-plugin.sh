#!/usr/bin/env bash
# build-logviewer-plugin.sh — build the LogViewer.ptxplugin bundle (external
# contribution: a windowed log viewer). Installs into the app's plugins dir.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/LogViewer.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/LogViewer/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O \
  -module-name LogViewer \
  -target "$TARGET" \
  -framework AppKit \
  -import-objc-header "$ROOT/Plugins/LogViewer/LogViewerBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/LogViewer" \
  "$ROOT/Plugins/LogViewer/logparsing.swift" \
  "$ROOT/Plugins/LogViewer/logstore.swift" \
  "$ROOT/Plugins/LogViewer/logformats.swift" \
  "$ROOT/Plugins/LogViewer/logconfig.swift" \
  "$ROOT/Plugins/LogViewer/logsettings.swift" \
  "$ROOT/Plugins/LogViewer/logviewer.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/LogViewer/Resources" ]; then
  cp -R "$ROOT/Plugins/LogViewer/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
