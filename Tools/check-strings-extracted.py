#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-strings-extracted.py — is every user-facing string actually in the catalogue?

`docs/scripts/check-translations.py` asks whether every key in `Localizable.xcstrings` has been
translated into all nineteen languages. It cannot see a string that is not in the catalogue at all —
and a `String(localized:)` only gets there when somebody remembers to run `Tools/extract-strings.sh`.

So a new message shipped untranslated, in every language, with the coverage gate green. That happened:
the "%lld file(s) were not renamed" message went in with the batch-rename fix and nothing noticed until
the next extraction run, several commits later.

This reads the source instead. Only plain literals are considered — a string with interpolation in it
becomes a format key that cannot be matched textually, and guessing would produce false alarms nobody
would trust. That is enough to catch the case that actually happens: a plainly written new message.

Usage: Tools/check-strings-extracted.py
Exit 1 if any literal is missing from the catalogue.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources/PCApp/Localizable.xcstrings"
SOURCES = REPO / "Sources/PCApp"

# String(localized: "…") with no interpolation: the literal may contain escaped quotes.
LITERAL = re.compile(r'String\(localized:\s*"((?:[^"\\\n]|\\.)*)"\s*[,)]')


def unescape(literal: str) -> str:
    """Swift source escapes → the text the catalogue stores."""
    return (literal.replace('\\"', '"').replace("\\n", "\n")
            .replace("\\t", "\t").replace("\\\\", "\\"))


def main() -> int:
    keys = set(json.loads(CATALOG.read_text(encoding="utf-8"))["strings"])
    missing: dict[str, list[str]] = {}
    scanned = 0

    for path in sorted(SOURCES.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            raw = match.group(1)
            if "\\(" in raw:            # interpolation: becomes a format key, not this text
                continue
            scanned += 1
            value = unescape(raw)
            if value not in keys:
                missing.setdefault(value, []).append(str(path.relative_to(REPO)))

    for value, files in sorted(missing.items()):
        print(f"  ⚠️  not in the catalogue: {value!r}  ({files[0]})")
    if missing:
        print("      run Tools/extract-strings.sh, then Tools/apply-translations.py with the new values")

    print(f"literals={scanned} missing={len(missing)}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
