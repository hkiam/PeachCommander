#!/usr/bin/env bash
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
ARCH="$(uname -m)"; TARGET="${ARCH}-apple-macos13.0"

BUNDLE="$OUT_DIR/TaskManager.pfxplugin"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/TaskManager/Info.plist" "$BUNDLE/Contents/Info.plist"
clang -dynamiclib -std=c11 -O2 -Wall \
  -target "$TARGET" \
  -I "$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/TaskManager" \
  "$ROOT/Plugins/TaskManager/taskmanager.c"
echo "Built $BUNDLE"
