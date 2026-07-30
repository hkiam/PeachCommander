#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-sample-packer.sh — assemble the SamplePacker.pcxplugin bundle (I14 T04).
# Usage: Tools/build-sample-packer.sh [output-dir]   (default: build/plugins)

set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-build/plugins}"
BUNDLE="$OUT_DIR/SamplePacker.pcxplugin"
SRC="Plugins/SamplePacker/sample_packer.c"
PLIST="Plugins/SamplePacker/Info.plist"
SDK="Plugins/SDK"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$PLIST" "$BUNDLE/Contents/Info.plist"

# Universal binary (arm64 + x86_64) so it loads on any host.
clang -dynamiclib -std=c11 -O2 -Wall \
      -arch arm64 -arch x86_64 \
      -I "$SDK" \
      -o "$BUNDLE/Contents/MacOS/SamplePacker" \
      "$SRC"

echo "Built $BUNDLE"
