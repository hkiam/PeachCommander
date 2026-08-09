#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-terminal-plugin.sh — build Terminal.ptxplugin (embedded terminal, F-381).
#
# Stage one carries no emulator: see docs/analysis/terminal-plugin-plan.md §11, which puts the
# skeleton first so that removability is proved before there is a pseudo-terminal to lose. SwiftTerm
# gets vendored into Plugins/Terminal/SwiftTerm and added to the source list below; measured, that is
# 61 more files, about 32 s per architecture slice and 2.4 MB.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Terminal.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Terminal/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O -module-name Terminal -target "$TARGET" \
  -framework AppKit \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -import-objc-header "$ROOT/Plugins/Terminal/TerminalBridging.h" \
  -o "$BUNDLE/Contents/MacOS/Terminal" \
  "$ROOT/Plugins/Terminal/terminal.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/Terminal/Resources" ]; then
  cp -R "$ROOT/Plugins/Terminal/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
