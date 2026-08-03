#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-netdecompiler-plugin.sh — build the NetDecompiler.plxplugin bundle (F-353).
#
# A PLX lister that shows a .NET assembly as C# (or as IL). It bundles no decompiler: it drives
# an engine the user installs (ILSpy or monodis), through the same shared runner and views the
# Java plugin uses — the whole plugin is a profile plus its C exports. Ships disabled.
#
# Installs into the app's plugins directory by default so it is discovered on next launch;
# pass an output dir to build elsewhere. make-dmg.sh builds it through
# build-all-plugins.sh into the app bundle's Contents/PlugIns.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/NetDecompiler.plxplugin"
SRC="Plugins/NetDecompiler/net_decompiler.swift"
PLIST="Plugins/NetDecompiler/Info.plist"

# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh. Required now
# that this ships: a host-only slice would be the one plugin a universal DMG could not
# load on the other architecture.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$PLIST" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
       -module-name NetDecompiler \
       -target "$TARGET" \
       -framework AppKit \
       -import-objc-header "$ROOT/Plugins/NetDecompiler/NetDecompilerBridging.h" \
       -Xcc -I"$ROOT/Plugins/SDK" \
       -o "$BUNDLE/Contents/MacOS/NetDecompiler" \
       "$SRC" \
       "$ROOT/Plugins/SDK/PluginLoc.swift" \
       "$ROOT/Plugins/SDK/PluginDecompiler.swift" \
       "$ROOT/Plugins/SDK/PluginDecompilerView.swift" \
       "$ROOT/Plugins/SDK/PluginDecompilerTreeView.swift" \
       "$ROOT/Plugins/SDK/PluginDecompilerPanel.swift" \
       "$ROOT/Plugins/SDK/PluginDecompilerContent.swift" \
       "$ROOT/Plugins/SDK/PluginDecompilerSettings.swift" \
       "$ROOT/Plugins/SDK/PluginSyntax.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/NetDecompiler/Resources" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp -R "$ROOT/Plugins/NetDecompiler/Resources/." "$BUNDLE/Contents/Resources/"
fi

echo "Built $BUNDLE"
