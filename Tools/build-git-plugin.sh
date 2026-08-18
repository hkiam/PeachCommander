#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-git-plugin.sh — build Git.pdxplugin (PDX content plugin adding Git Status
# and Branch columns via the system git). Installs into the app's plugins dir.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Git.pdxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Git/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O -module-name Git -target "$TARGET" -framework AppKit \
  -import-objc-header "$ROOT/Plugins/Git/GitBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Git" \
  "$ROOT/Plugins/Git/git.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift" \
  "$ROOT/Plugins/SDK/PluginGit.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/Git/Resources" ]; then
  cp -R "$ROOT/Plugins/Git/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
