#!/usr/bin/env bash
# build-notes-plugin.sh — build Notes.pdxplugin (per-path/global notes: indicator
# column + editor/overview windows). Installs into the app's plugins dir.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Notes.pdxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Notes/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O -module-name Notes -target "$TARGET" -framework AppKit \
  -import-objc-header "$ROOT/Plugins/Notes/NotesBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Notes" \
  "$ROOT/Plugins/Notes/notes.swift" \
  "$ROOT/Plugins/Notes/notes_wysiwyg.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/Notes/Resources" ]; then
  cp -R "$ROOT/Plugins/Notes/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
