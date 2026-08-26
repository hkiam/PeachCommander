#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-all-plugins.sh — build every shipping plugin bundle into a target directory.
#
# Default target is the user plugins dir; make-dmg.sh passes the app bundle's
# Contents/PlugIns so a DMG install ships with all plugins present (and, being
# enabled by default, active) out of the box.
#
# Sample/demo plugins (Tools/build-sample-*.sh) are intentionally excluded — they are
# SDK examples, not product. The CSV lister used to be one and is now shipped.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-$HOME/Library/Application Support/PeachCommander/plugins}"
mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"   # absolute: the per-plugin scripts cd into the repo root

echo "==> Building all shipping plugins into: $OUT_DIR"
SCRIPTS=(
  build-archive-plugin
  build-fsimage-plugin
  build-csvlister-plugin
  # Not optional in the way the others are: the application has no Markdown or HTML renderer of
  # its own any more, so a run that skips this one produces a build where F3 on a README shows
  # source. The script fails loudly rather than warning, for the same reason.
  build-markdown-plugin
  build-javadecompiler-plugin
  build-netdecompiler-plugin
  build-git-plugin
  build-logviewer-plugin
  build-notes-plugin
  build-systemmonitor-plugin
  build-treemap-plugin
  build-uninstaller-plugin
  build-taskmanager-plugin
  build-terminal-plugin
  build-ai-plugin
  build-ailocal-plugin
  build-aicolumn-plugin
  build-pfx-plugins
  build-s3-plugin
)
# Rebuild only what changed. Building all seventeen is the slowest part of a build and most changes
# are not to a plugin at all; the stamp is a content hash of everything the script reads, so a branch
# switch that rewrites mtimes without changing bytes rebuilds nothing. PC_FORCE_PLUGINS=1 rebuilds
# regardless.
#
# A stamp records the outputs as well as the inputs, and a script whose outputs are no longer there
# is rebuilt whatever its inputs say. That case is not hypothetical: the usual OUT_DIR is the app
# bundle's Contents/PlugIns, and Xcode replacing the .app takes the plugins with it. Skipping then
# would leave a bundle with no plugins in it that looked freshly built — the exact failure the
# unconditional rebuild was there to prevent.
STAMPS="$OUT_DIR/.build-stamps"
mkdir -p "$STAMPS"
BUILT=0
SKIPPED=0

# "<mtime> <bundle>" for every plugin bundle, so that a *replaced* bundle is distinguishable from
# an untouched one. Each build script does `rm -rf "$BUNDLE"; mkdir -p …`, so producing a bundle
# always moves its mtime; comparing names alone would record nothing for a script that only ever
# replaces bundles it made before, which is every script after the first run.
plugins_snapshot() {
  (cd "$OUT_DIR" && for bundle in *plugin; do
     [ -d "$bundle" ] && stat -f "%m %N" "$bundle"
   done 2>/dev/null | sort) || true
}

for script in "${SCRIPTS[@]}"; do
  STAMP="$(python3 Tools/plugin-build-stamp.py "Tools/$script.sh")"
  if [ "${PC_FORCE_PLUGINS:-0}" != "1" ] && [ -f "$STAMPS/$script" ]; then
    RECORDED_STAMP="$(head -n1 "$STAMPS/$script")"
    MISSING=0
    while IFS= read -r bundle; do
      [ -z "$bundle" ] && continue
      [ -d "$OUT_DIR/$bundle" ] || MISSING=1
    done < <(tail -n +2 "$STAMPS/$script")
    if [ "$RECORDED_STAMP" = "$STAMP" ] && [ "$MISSING" = "0" ]; then
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
  fi
  echo "--> $script"
  BEFORE="$(plugins_snapshot)"
  bash "Tools/$script.sh" "$OUT_DIR"
  # Whatever this script added or replaced is what it owns; a script can produce several bundles
  # (build-pfx-plugins.sh produces three), so this is taken from the directory rather than configured.
  { echo "$STAMP"
    comm -13 <(echo "$BEFORE") <(plugins_snapshot) | cut -d' ' -f2-
  } > "$STAMPS/$script"
  BUILT=$((BUILT + 1))
done
echo "==> $BUILT built, $SKIPPED unchanged"
echo "==> Done. Plugins in $OUT_DIR:"
ls -1 "$OUT_DIR"
