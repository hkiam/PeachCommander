#!/usr/bin/env bash
# build-sample-csv-lister.sh — build the SampleCSVLister.plxplugin bundle (I16 T02).
#
# This PLX plugin is written in Swift and returns a real NSView (an NSTableView),
# so F3 on a .csv embeds the plugin's view in the Lister. By default it installs
# into the app's plugins directory so it is discovered on next launch; pass an
# output dir to build elsewhere (e.g. Tools/build-sample-csv-lister.sh build/plugins).

set -euo pipefail
cd "$(dirname "$0")/.."

DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/SampleCSVLister.plxplugin"
SRC="Plugins/SampleCSVLister/sample_csv_lister.swift"
PLIST="Plugins/SampleCSVLister/Info.plist"

ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos13.0"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$PLIST" "$BUNDLE/Contents/Info.plist"

swiftc -emit-library -O \
       -module-name SampleCSVLister \
       -target "$TARGET" \
       -framework AppKit \
       -o "$BUNDLE/Contents/MacOS/SampleCSVLister" \
       "$SRC"

echo "Built $BUNDLE"
echo "Restart Peach Commander, then press F3 on a .csv file to see the plugin view."
