#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build AIAssistant.ptxplugin — the removable AI assistant plugin. Links the host's
# PCAutomation.framework (the AI brain: AgentSession, providers, native tool-calling);
# the file-manager access goes through the contrib C-ABI (RemoteAutomationCore).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/AIAssistant.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

source "$ROOT/Tools/lib/pc-automation-fw.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/AIAssistant/Info.plist" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
  -module-name AIAssistant \
  -target "$TARGET" \
  -framework AppKit \
  -F "$FWDIR" -framework PCAutomation \
  -Xlinker -rpath -Xlinker "$FWDIR" \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
  -import-objc-header "$ROOT/Plugins/AIAssistant/AIBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/AIAssistant" \
  "$ROOT/Plugins/AIAssistant/aiplugin.swift" \
  "$ROOT/Plugins/SDK/PluginAIRemoteCore.swift" \
  "$ROOT/Plugins/AIAssistant/AIChatViewController.swift" \
  "$ROOT/Plugins/AIAssistant/ChatMarkdown.swift" \
  "$ROOT/Plugins/AIAssistant/AISettings.swift" \
  "$ROOT/Plugins/SDK/PluginAIHost.swift" \
  "$ROOT/Plugins/SDK/PluginTheme.swift"

if [ -d "$ROOT/Plugins/AIAssistant/Resources" ]; then
  cp -R "$ROOT/Plugins/AIAssistant/Resources/." "$BUNDLE/Contents/Resources/"
fi

echo "Built $BUNDLE"
echo "  linked PCAutomation from: $FWDIR"
