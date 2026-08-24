#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# sync-plugin-sdk.sh - Refresh every copy of the plugin ABI headers (F-236).
#
# Plugins/SDK/ is canonical. Six other places carry copies, and
# Tools/check-sdk-headers.sh fails when any of them drifts:
#
#   * the five C ABI shim modules the host compiles against (Sources/C*/include),
#   * the distributable SwiftPM package third-party plugin authors build against.
#
# This script used to refresh only the last one, so an ABI change meant one
# `cp` here and five by hand — and the gate that catches a missed one runs after
# the build, not before it. Run this after any change to a header in Plugins/SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Plugins/SDK"

# Which headers each destination carries — exactly the sets check-sdk-headers.sh
# compares, so "synced" and "not drifted" cannot mean different things.
sync_to() {
    local dst="$1"; shift
    mkdir -p "$dst"
    for h in "$@"; do
        cp "$SRC/$h" "$dst/$h"
        echo "  $h -> ${dst#"$ROOT"/}"
    done
}

sync_to "$ROOT/Sources/CPCX/include"     pc_common.h pcx.h
sync_to "$ROOT/Sources/CPDX/include"     pc_common.h pdx.h
sync_to "$ROOT/Sources/CPLX/include"     pc_common.h plx.h
sync_to "$ROOT/Sources/CPFX/include"     pc_common.h pfx.h
sync_to "$ROOT/Sources/CContrib/include" pc_common.h contrib.h
sync_to "$ROOT/PluginSDK/Sources/CPeachCommanderPlugin/include" \
        pc_common.h pcx.h pdx.h pfx.h plx.h contrib.h

echo "Plugin ABI headers synced from Plugins/SDK into 6 destinations"
