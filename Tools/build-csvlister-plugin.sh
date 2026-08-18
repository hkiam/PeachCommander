#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-csvlister-plugin.sh — build the CSVLister.plxplugin bundle (I16 T02).
#
# A PLX lister written in Swift that returns a real NSView (an NSTableView), so F3 on a
# .csv or .tsv embeds the plugin's table in the viewer instead of showing raw text.
#
# Installs into the app's plugins directory by default so it is discovered on next launch;
# pass an output dir to build elsewhere. make-dmg.sh builds it through
# build-all-plugins.sh into the app bundle's Contents/PlugIns.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/CSVLister.plxplugin"
SRC="Plugins/CSVLister/csv_lister.swift"
PLIST="Plugins/CSVLister/Info.plist"

# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh. Required now
# that this ships: a host-only slice would be the one plugin a universal DMG could not
# load on the other architecture.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$PLIST" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
       -module-name CSVLister \
       -target "$TARGET" \
       -framework AppKit \
       -o "$BUNDLE/Contents/MacOS/CSVLister" \
       "$SRC" \
       "Plugins/SDK/PluginCSV.swift"

echo "Built $BUNDLE"
