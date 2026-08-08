#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-format-specifiers.py — do the translations take the same arguments as the English?

Every localized message with a placeholder is a *format string*: the code passes values and
`String(format:)` reads them according to what the translation says. So a translation is the one piece of
this app where a text file decides how memory is interpreted. `%@` where the code passes an integer does
not print the wrong thing — it treats the number as a pointer.

`check-translations.py` cannot see this: it asks whether a string is translated, not whether the
translation still takes the same arguments. With 19 languages and ~2300 translated values, that is a lot
of surface for a class of defect that only appears when the message is finally shown.

What is compared is the *multiset of argument types*, not the literal text:

  * `%1$@` and `%@` are the same argument, and Xcode writes the positional form into the English value
    itself, so comparing spellings would report every multi-argument string in the catalogue;
  * a reordered translation (`%2$@ … %1$@`) is correct and common — German and English disagree about
    word order far more often than about how many things are being named.

`% l` and friends — a percent followed by a space — are treated as prose, not as a specifier. No format
string in this project uses the space flag, while several translations legitimately end in "% littéral"
or "% letterale".

Usage: Tools/check-format-specifiers.py
"""
from __future__ import annotations

import collections
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
CATALOG = REPO / "Sources/PCApp/Localizable.xcstrings"

# A conversion, with an optional positional prefix. The flags deliberately exclude a space, so that
# "% littéral" in a translation is read as prose rather than as a space-flagged conversion.
SPEC = re.compile(r"%(?:(\d+)\$)?[-+#0]*[\d*]*(?:\.\d+)?(hh|h|ll|l|q|L|z|j|t)?([@dioufFeEgGxXcsSp])")


def argument_types(text: str) -> collections.Counter:
    """The conversions in `text` as a multiset of (length, conversion), ignoring order and position."""
    types = collections.Counter()
    for match in SPEC.finditer(text):
        types[(match.group(2) or "", match.group(3))] += 1
    return types


def describe(types: collections.Counter) -> str:
    return ", ".join(f"%{length}{conv}" + (f" ×{count}" if count > 1 else "")
                     for (length, conv), count in sorted(types.items())) or "none"


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    problems = 0
    compared = 0

    for key, entry in catalog.get("strings", {}).items():
        source = argument_types(key)
        if not source:
            continue
        for language, localization in entry.get("localizations", {}).items():
            unit = localization.get("stringUnit")
            if not unit:
                continue
            value = unit.get("value", "")
            compared += 1
            translated = argument_types(value)
            if translated == source:
                continue
            problems += 1
            print(f"  ⚠️  {language}: {key!r}")
            print(f"        English takes {describe(source)}")
            print(f"        {language} takes {describe(translated)}")

    print(f"format_strings_checked={compared} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
