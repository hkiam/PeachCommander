#!/usr/bin/env bash
# build-systemmonitor-plugin.sh — build SystemMonitor.ptxplugin (titlebar system
# monitor: CPU/Memory/Network/Battery/Disk chips + detail popovers).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/SystemMonitor.ptxplugin"
ARCH="$(uname -m)"; TARGET="${ARCH}-apple-macos13.0"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/SystemMonitor/Info.plist" "$BUNDLE/Contents/Info.plist"
swiftc -emit-library -O -module-name SystemMonitor -target "$TARGET" \
  -framework AppKit -framework IOKit \
  -import-objc-header "$ROOT/Plugins/SystemMonitor/SystemMonitorBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/SystemMonitor" \
  "$ROOT/Plugins/SystemMonitor/systemmonitor.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/SystemMonitor/Resources" ]; then
  cp -R "$ROOT/Plugins/SystemMonitor/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
