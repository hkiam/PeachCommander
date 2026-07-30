#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-uninstaller-plugin.sh — build the Uninstaller.ptxplugin bundle (external
# PTX tool plugin). Installs into the app's plugins dir by default; pass an
# output dir to build elsewhere.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Uninstaller.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Uninstaller/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O \
  -module-name Uninstaller \
  -target "$TARGET" \
  -framework AppKit \
  -import-objc-header "$ROOT/Plugins/Uninstaller/UninstallerBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Uninstaller" \
  "$ROOT/Plugins/Uninstaller/uninstaller.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (Resources/<lang>.lproj/Localizable.strings).
if [ -d "$ROOT/Plugins/Uninstaller/Resources" ]; then
  cp -R "$ROOT/Plugins/Uninstaller/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
