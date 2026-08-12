#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-taskmanager-plugin.sh — build the external TaskManager PFX plugin bundle.
#
# TaskManager is a plain C plugin (libproc/sysctl), so it compiles with clang
# rather than swiftc. Installs into the app's plugins dir by default; pass an
# output dir to build into an isolated ConfigRoot for testing, e.g.:
#   Tools/build-taskmanager-plugin.sh /tmp/pc-cfg/plugins
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

BUNDLE="$OUT_DIR/TaskManager.pfxplugin"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/TaskManager/Info.plist" "$BUNDLE/Contents/Info.plist"
# Security + CoreFoundation: the "Signed" column reads each binary's code
# signature (F-393). Nothing else here links a framework.
pc_clang -dynamiclib -std=c11 -O2 -Wall \
  -target "$TARGET" \
  -I "$ROOT/Plugins/SDK" \
  -framework CoreFoundation -framework Security \
  -o "$BUNDLE/Contents/MacOS/TaskManager" \
  "$ROOT/Plugins/TaskManager/taskmanager.c"
echo "Built $BUNDLE"
