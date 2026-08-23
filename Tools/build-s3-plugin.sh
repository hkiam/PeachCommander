#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-s3-plugin.sh — build S3.pfxplugin (Amazon S3 and S3-compatible storage as a drive).
# Installs into the app's plugins dir by default; pass an output dir to build elsewhere.
#
# Its own script rather than a third `build` call in Tools/build-pfx-plugins.sh: that script's helper
# takes exactly one source file, and this plugin is seven. Tools/verify-shipping.sh is satisfied
# either way, as long as build-all-plugins.sh lists this script.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/S3.pfxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/S3/Info.plist" "$BUNDLE/Contents/Info.plist"

# CryptoKit needs no -framework flag: it is a Swift module in the SDK and `import CryptoKit` links it.
pc_swiftc -emit-library -O -module-name S3 -target "$TARGET" -framework AppKit \
  -import-objc-header "$ROOT/Plugins/S3/S3Bridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/S3" \
  "$ROOT/Plugins/S3/s3.swift" \
  "$ROOT/Plugins/S3/S3Signer.swift" \
  "$ROOT/Plugins/S3/S3XML.swift" \
  "$ROOT/Plugins/S3/S3Client.swift" \
  "$ROOT/Plugins/S3/S3Transfer.swift" \
  "$ROOT/Plugins/S3/S3Write.swift" \
  "$ROOT/Plugins/S3/S3Profiles.swift" \
  "$ROOT/Plugins/S3/S3AWSConfig.swift" \
  "$ROOT/Plugins/S3/S3ConnectDialog.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/S3/Resources" ]; then
  cp -R "$ROOT/Plugins/S3/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE"
