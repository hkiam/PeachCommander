#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-sdk-headers.sh — verify the plugin SDK C headers compile standalone (I14 T01).
# Each header must be self-contained C11 with no missing includes.

set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
for hdr in Plugins/SDK/*.h; do
  if clang -std=c11 -fsyntax-only -Wall -Wextra -x c "$hdr" 2>/tmp/sdkhdr.err; then
    echo "OK: $hdr"
  else
    echo "FAIL: $hdr"; cat /tmp/sdkhdr.err; fail=1
  fi
done

# The C ABI build modules keep copies of the SDK headers; they must not drift.
for base in pc_common.h pcx.h; do
  if ! cmp -s "Plugins/SDK/$base" "Sources/CPCX/include/$base"; then
    echo "DRIFT: Sources/CPCX/include/$base differs from Plugins/SDK/$base"; fail=1
  fi
done
for base in pc_common.h pdx.h; do
  if ! cmp -s "Plugins/SDK/$base" "Sources/CPDX/include/$base"; then
    echo "DRIFT: Sources/CPDX/include/$base differs from Plugins/SDK/$base"; fail=1
  fi
done
for base in pc_common.h plx.h; do
  if ! cmp -s "Plugins/SDK/$base" "Sources/CPLX/include/$base"; then
    echo "DRIFT: Sources/CPLX/include/$base differs from Plugins/SDK/$base"; fail=1
  fi
done
for base in pc_common.h pfx.h; do
  if ! cmp -s "Plugins/SDK/$base" "Sources/CPFX/include/$base"; then
    echo "DRIFT: Sources/CPFX/include/$base differs from Plugins/SDK/$base"; fail=1
  fi
done

for base in pc_common.h contrib.h; do
  if ! cmp -s "Plugins/SDK/$base" "Sources/CContrib/include/$base"; then
    echo "DRIFT: Sources/CContrib/include/$base differs from Plugins/SDK/$base"; fail=1
  fi
done

# The distributable SwiftPM package carries its own copy, refreshed by sync-plugin-sdk.sh. It was
# a full licence-header behind for months because nothing checked it: an out-of-date SDK package
# means third-party plugin authors compile against an ABI the host no longer has.
for base in pc_common.h pcx.h pdx.h pfx.h plx.h contrib.h; do
  if ! cmp -s "Plugins/SDK/$base" "PluginSDK/Sources/CPeachCommanderPlugin/include/$base"; then
    echo "DRIFT: PluginSDK/Sources/CPeachCommanderPlugin/include/$base differs from Plugins/SDK/$base — run Tools/sync-plugin-sdk.sh"; fail=1
  fi
done

exit $fail
