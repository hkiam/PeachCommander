#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-javadecompiler-plugin.sh — build the JavaDecompiler.plxplugin bundle (F-345).
#
# A PLX lister that shows a .class file as Java source. It bundles no decompiler: it drives
# an engine the user installs (CFR, Vineflower, Procyon or javap), through the shared runner
# in Plugins/SDK/PluginDecompiler.swift. Ships disabled — see PCPluginEnabledByDefault.
#
# Installs into the app's plugins directory by default so it is discovered on next launch;
# pass an output dir to build elsewhere. make-dmg.sh builds it through
# build-all-plugins.sh into the app bundle's Contents/PlugIns.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/JavaDecompiler.plxplugin"
SRC="Plugins/JavaDecompiler/java_decompiler.swift"
PLIST="Plugins/JavaDecompiler/Info.plist"

# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh. Required now
# that this ships: a host-only slice would be the one plugin a universal DMG could not
# load on the other architecture.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$PLIST" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
       -module-name JavaDecompiler \
       -target "$TARGET" \
       -framework AppKit \
       -o "$BUNDLE/Contents/MacOS/JavaDecompiler" \
       "$SRC" \
       "$ROOT/Plugins/SDK/PluginLoc.swift" \
       "$ROOT/Plugins/SDK/PluginDecompiler.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/JavaDecompiler/Resources" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp -R "$ROOT/Plugins/JavaDecompiler/Resources/." "$BUNDLE/Contents/Resources/"
fi

echo "Built $BUNDLE"
