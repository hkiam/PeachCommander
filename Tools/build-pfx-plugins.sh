#!/usr/bin/env bash
# build-pfx-plugins.sh — build the external PFX file-system plugin bundles
# (WebDAV, iCloud Drive). Installs into the app's plugins dir by default; pass an
# output dir to build elsewhere.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

build() {  # name  srcfile  bridging  bundlename
  local name="$1" src="$2" bridge="$3" bundleName="$4"
  local bundle="$OUT_DIR/$bundleName"
  rm -rf "$bundle"
  mkdir -p "$bundle/Contents/MacOS"
  cp "$ROOT/$(dirname "$src")/Info.plist" "$bundle/Contents/Info.plist"
  pc_swiftc -emit-library -O \
    -module-name "$name" \
    -target "$TARGET" \
    -framework AppKit \
    -import-objc-header "$ROOT/$bridge" \
    -Xcc -I"$ROOT/Plugins/SDK" \
    -o "$bundle/Contents/MacOS/$name" \
    "$ROOT/$src" \
    "$ROOT/Plugins/SDK/PluginLoc.swift"
  # Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
  local res="$ROOT/$(dirname "$src")/Resources"
  if [ -d "$res" ]; then
    cp -R "$res/." "$bundle/Contents/Resources/"
  fi
  echo "Built $bundle"
}

build WebDAV      Plugins/WebDAV/webdav.swift Plugins/WebDAV/WebDAVBridging.h WebDAV.pfxplugin
build ICloudDrive Plugins/ICloud/icloud.swift Plugins/ICloud/ICloudBridging.h ICloudDrive.pfxplugin
