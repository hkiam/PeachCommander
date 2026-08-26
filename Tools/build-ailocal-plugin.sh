#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build AILocal.ptxplugin — the on-device half of the assistant: five actions that run without a
# chat and offer the model no tools at all. Links the host's PCAutomation.framework for the
# generation itself; file-manager access goes through the contrib C-ABI (PluginAIRemoteCore).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/AILocal.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

source "$ROOT/Tools/lib/pc-automation-fw.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/AILocal/Info.plist" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
  -module-name AILocal \
  -target "$TARGET" \
  -framework AppKit \
  -F "$FWDIR" -framework PCAutomation \
  -Xlinker -rpath -Xlinker "$FWDIR" \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
  -import-objc-header "$ROOT/Plugins/AILocal/AILocalBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/AILocal" \
  "$ROOT/Plugins/AILocal/ailocal.swift" \
  "$ROOT/Plugins/AILocal/AIDirectActions.swift" \
  "$ROOT/Plugins/AILocal/AISheets.swift" \
  "$ROOT/Plugins/SDK/PluginAIRemoteCore.swift" \
  "$ROOT/Plugins/SDK/PluginAIHost.swift"

if [ -d "$ROOT/Plugins/AILocal/Resources" ]; then
  cp -R "$ROOT/Plugins/AILocal/Resources/." "$BUNDLE/Contents/Resources/"
fi

echo "Built $BUNDLE"
echo "  linked PCAutomation from: $FWDIR"
