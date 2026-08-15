#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-fsimage-plugin.sh — build FSImage.pcxplugin (read-only PCX reader for Linux
# filesystem images: SquashFS, ext2/3/4, JFFS2, cramfs, initramfs, Btrfs).
# Installs into the app's plugins dir.
#
# The source list is explicit rather than a glob: a driver that is written but not
# yet listed here would compile nowhere and be silently absent, which is the same
# failure Tools/check-tests-registered.py exists to catch for tests.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/FSImage.pcxplugin"
# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"

SOURCES=(
  "Plugins/FSImage/fsimage.swift"
  "Plugins/FSImage/Support/ImageReader.swift"
  "Plugins/FSImage/Support/ImageEntry.swift"
  "Plugins/FSImage/Support/Decompressors.swift"
  "Plugins/FSImage/Support/DriverRegistry.swift"
  "Plugins/FSImage/Support/ImageCache.swift"
  "Plugins/FSImage/Drivers/CpioDriver.swift"
  "Plugins/FSImage/Drivers/SquashFSMetadata.swift"
  "Plugins/FSImage/Drivers/SquashFSDriver.swift"
  "Plugins/FSImage/Drivers/ExtLayout.swift"
  "Plugins/FSImage/Drivers/ExtDriver.swift"
  "Plugins/FSImage/Drivers/CramFSDriver.swift"
  "Plugins/FSImage/Drivers/JFFS2Compression.swift"
  "Plugins/FSImage/Drivers/JFFS2Driver.swift"
  "Plugins/FSImage/Drivers/BtrfsChunkMap.swift"
  "Plugins/FSImage/Drivers/BtrfsDriver.swift"
)

rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/FSImage/Info.plist" "$BUNDLE/Contents/Info.plist"

# Zstandard comes from a vendored single-file decoder, so one C translation unit has to
# be compiled and linked alongside the Swift. clang emits a fat object from several
# -arch flags in one go, and the linker takes a fat object directly — so this stays one
# step rather than shadowing pc_swiftc's per-slice loop.
#
# -mmacosx-version-min is not optional here. pc_clang sets the architectures but not
# the deployment target, so the object defaults to the SDK's — macOS 26 — while the
# Swift half and the app itself target 13.0. The linker only warns, and the result
# runs fine on the machine that built it: the failure surfaces on a user's older
# system, which is the worst place to find it.
ZSTD_OBJ="$(mktemp -d)/zstddeclib.o"
trap 'rm -rf "$(dirname "$ZSTD_OBJ")"' EXIT
pc_clang -O2 -c -mmacosx-version-min="$PC_PLUGIN_DEPLOY" \
  -o "$ZSTD_OBJ" "$ROOT/Plugins/FSImage/Vendor/zstddeclib.c"

pc_swiftc -emit-library -O -module-name FSImage -target "$TARGET" \
  -import-objc-header "$ROOT/Plugins/FSImage/FSImageBridging.h" \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -o "$BUNDLE/Contents/MacOS/FSImage" \
  "${SOURCES[@]/#/$ROOT/}" "$ZSTD_OBJ"
echo "Built $BUNDLE"
