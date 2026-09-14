#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-docker-plugin.sh — build the Docker PFX file-system plugin bundle.
# Installs into the app's plugins dir by default; pass an output dir to build elsewhere.
#
# Kept out of build-pfx-plugins.sh because this one has several source files and that script's
# `build` helper takes exactly one. Tools/check-plugin-sources.py holds the list below against
# what is actually in Plugins/Docker/, so a file added there and forgotten here is caught.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

BUNDLE="$OUT_DIR/Docker.pfxplugin"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Docker/Info.plist" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
  -module-name Docker \
  -target "$TARGET" \
  -framework AppKit \
  -import-objc-header "$ROOT/Plugins/Docker/DockerBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Docker" \
  "$ROOT/Plugins/Docker/docker.swift" \
  "$ROOT/Plugins/Docker/DockerEngine.swift" \
  "$ROOT/Plugins/Docker/DockerAPI.swift" \
  "$ROOT/Plugins/Docker/DockerTar.swift" \
  "$ROOT/Plugins/Docker/DockerTree.swift" \
  "$ROOT/Plugins/Docker/DockerFS.swift" \
  "$ROOT/Plugins/Docker/DockerWrite.swift" \
  "$ROOT/Plugins/Docker/DockerSettings.swift" \
  "$ROOT/Plugins/Docker/DockerConnectDialog.swift" \
  "$ROOT/Plugins/Docker/DockerCommands.swift" \
  "$ROOT/Plugins/Docker/DockerTextWindow.swift" \
  "$ROOT/Plugins/Docker/DockerSettingsView.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
RES="$ROOT/Plugins/Docker/Resources"
if [ -d "$RES" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp -R "$RES/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
