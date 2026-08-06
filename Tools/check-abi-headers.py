#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-abi-headers.py — are the two copies of each plugin ABI header still identical?

The plugin ABI headers exist twice: once as the SDK a plugin author compiles against
(`Plugins/SDK/*.h`) and once inside the app so the host can import them
(`Sources/C*/include/*.h`). Nothing kept them in step. Adding a callback to one copy
and not the other compiles cleanly on both sides and fails at *runtime*: the host
writes a function pointer at an offset the plugin reads as something else, or the
plugin calls a field the host never filled. That is the worst kind of drift — a
struct layout mismatch, in C, across a dynamic-library boundary.

So: byte-identical, or this fails. When a header legitimately needs a host-only or
SDK-only line, that is the moment to reconsider — not to add an exception here.

Usage: Tools/check-abi-headers.py
"""

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# SDK copy → the copy compiled into the app.
PAIRS = [
    ("Plugins/SDK/contrib.h", "Sources/CContrib/include/contrib.h"),
    ("Plugins/SDK/pdx.h", "Sources/CPDX/include/pdx.h"),
    ("Plugins/SDK/pcx.h", "Sources/CPCX/include/pcx.h"),
    ("Plugins/SDK/plx.h", "Sources/CPLX/include/plx.h"),
    ("Plugins/SDK/pfx.h", "Sources/CPFX/include/pfx.h"),
    ("Plugins/SDK/pc_common.h", "Sources/CPDX/include/pc_common.h"),
]


def main() -> int:
    problems, checked, skipped = [], 0, []
    for sdk, host in PAIRS:
        a, b = REPO / sdk, REPO / host
        if not a.exists() or not b.exists():
            # Reported, not ignored: a pair that has moved is a pair nobody is checking.
            skipped.append(f"{sdk} ↔ {host} (missing: "
                           + ", ".join(p for p, e in ((sdk, a.exists()), (host, b.exists())) if not e)
                           + ")")
            continue
        checked += 1
        if a.read_bytes() != b.read_bytes():
            problems.append(f"{sdk} and {host} differ — the plugin ABI would not match at runtime")

    for line in skipped:
        print(f"  note: no such pair: {line}")
    for line in problems:
        print(f"  ⚠️  {line}")
    print(f"pairs={checked} skipped={len(skipped)} problems={len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
