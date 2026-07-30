#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""apply-translations.py - Merge translation dictionaries into the String Catalog.

Reads Tools/translations/<lang>.json ({ english_key: translated_value }) for each
language and writes the corresponding `localizations.<lang>` entry into
Sources/PCApp/Localizable.xcstrings. Keys not present in the catalog are reported
(stale); catalog keys without a translation are left to fall back to the source
(English). Idempotent.

Usage: Tools/apply-translations.py [lang ...]   (default: every *.json in translations/)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "Sources/PCApp/Localizable.xcstrings")
TRANS_DIR = os.path.join(ROOT, "Tools/translations")


def apply(lang, catalog):
    path = os.path.join(TRANS_DIR, f"{lang}.json")
    trans = json.load(open(path, encoding="utf-8"))
    applied = stale = 0
    for key, value in trans.items():
        if not value:
            continue
        entry = catalog["strings"].get(key)
        if entry is None:
            stale += 1
            print(f"  [stale] {lang}: {key!r} not in catalog")
            continue
        loc = entry.setdefault("localizations", {})
        loc[lang] = {"stringUnit": {"state": "translated", "value": value}}
        applied += 1
    total = len(catalog["strings"])
    print(f"==> {lang}: {applied}/{total} translated ({stale} stale, "
          f"{total - applied} still source-language).")


def main():
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    langs = sys.argv[1:] or sorted(
        f[:-5] for f in os.listdir(TRANS_DIR) if f.endswith(".json"))
    for lang in langs:
        apply(lang, catalog)
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
