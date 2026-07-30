#!/usr/bin/env bash
# build-all-plugins.sh — build every shipping plugin bundle into a target directory.
#
# Default target is the user plugins dir; make-dmg.sh passes the app bundle's
# Contents/PlugIns so a DMG install ships with all plugins present (and, being
# enabled by default, active) out of the box.
#
# Sample/demo plugins (Tools/build-sample-*.sh) are intentionally excluded.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-$HOME/Library/Application Support/PeachCommander/plugins}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"   # absolute: the per-plugin scripts cd into the repo root

echo "==> Building all shipping plugins into: $OUT_DIR"
SCRIPTS=(
  build-archive-plugin
  build-git-plugin
  build-logviewer-plugin
  build-notes-plugin
  build-systemmonitor-plugin
  build-treemap-plugin
  build-uninstaller-plugin
  build-taskmanager-plugin
  build-ai-plugin
  build-aicolumn-plugin
  build-pfx-plugins
)
for script in "${SCRIPTS[@]}"; do
  echo "--> $script"
  bash "Tools/$script.sh" "$OUT_DIR"
done
echo "==> Done. Plugins in $OUT_DIR:"
ls -1 "$OUT_DIR"
