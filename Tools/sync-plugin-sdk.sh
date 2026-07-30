#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# sync-plugin-sdk.sh - Refresh the distributable SwiftPM SDK headers (F-236).
#
# Copies the canonical plugin ABI headers from Plugins/SDK/ into the
# PeachCommanderPluginSDK SwiftPM package so the two never drift. Run after any
# change to the plugin C ABI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Plugins/SDK"
DST="$ROOT/PluginSDK/Sources/CPeachCommanderPlugin/include"
mkdir -p "$DST"
for h in pc_common.h pcx.h pdx.h pfx.h plx.h contrib.h; do
    cp "$SRC/$h" "$DST/$h"
    echo "synced $h"
done
echo "Plugin SDK headers synced into $DST"
