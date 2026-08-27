#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build Scripting.ptxplugin — running AppleScript and JXA from inside the file manager (F-477).
#
# Ships DISABLED (PCPluginEnabledByDefault=false) and its run tools carry the `script` capability,
# which PermissionPolicy.standard withholds: running a program of somebody's choosing is a decision
# taken once in Settings, not one taken in a dialog. Links the host's PCAutomation.framework for
# ScriptStore and the capability model; OSAKit comes from the system and stays out of the app binary.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Scripting.ptxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"
source "$ROOT/Tools/lib/pc-automation-fw.sh"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Scripting/Info.plist" "$BUNDLE/Contents/Info.plist"

pc_swiftc -emit-library -O \
  -module-name Scripting \
  -target "$TARGET" \
  -framework AppKit -framework OSAKit \
  -F "$FWDIR" -framework PCAutomation \
  `# The HOST's copy first, then the build directory. Order matters and cost a run to find: a dev
   # build leaves two distinct PCAutomation.framework files — one in the app bundle, one in the
   # build-products directory — and with the build directory first, dlopen inside the app loads a
   # SECOND copy of the same Swift module. The plugin then fails to open, silently, and contributes
   # nothing. Preferring @executable_path means the plugin always shares the host's framework when it
   # is loaded into the host, and still resolves standalone.` \
  -Xlinker -rpath -Xlinker "@executable_path/../Frameworks" \
  -Xlinker -rpath -Xlinker "$FWDIR" \
  -import-objc-header "$ROOT/Plugins/Scripting/ScriptingBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/Scripting" \
  "$ROOT/Plugins/Scripting/scripting.swift" \
  "$ROOT/Plugins/Scripting/ScriptRunner.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift"

if [ -d "$ROOT/Plugins/Scripting/Resources" ]; then
  mkdir -p "$BUNDLE/Contents/Resources"
  cp -R "$ROOT/Plugins/Scripting/Resources/." "$BUNDLE/Contents/Resources/"
fi

echo "Built $BUNDLE"
echo "  linked PCAutomation from: $FWDIR"
