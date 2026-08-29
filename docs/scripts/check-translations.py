#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-translations.py — localization coverage gate for UI + Help.

English (docs/content/help + the base strings in Localizable.xcstrings) is the source
of truth. This verifies every language listed in docs/metadata/languages.yml is kept
in sync, and fails (exit 1) if any language is behind — so CI catches drift the moment
an English string or help page is added without its translations.

Checks, per non-English language <code>:
  • Help:  docs/help-<code>/ has one .md per English help topic (no missing/extra slugs).
  • UI:    Localizable.xcstrings has a state:"translated" value for every source string.

Usage:
  python3 docs/scripts/check-translations.py            # summary + exit 1 if behind
  python3 docs/scripts/check-translations.py --write     # also write the coverage report
"""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = Path(__file__).resolve().parents[2]
LANGS_YML = REPO / "docs/metadata/languages.yml"
HELP_EN = REPO / "docs/content/help"
XCSTRINGS = REPO / "Sources/PCApp/Localizable.xcstrings"
REPORT = REPO / "docs/generated/translation-coverage.md"


def load_languages():
    data = yaml.safe_load(LANGS_YML.read_text())["languages"]
    return [(l["code"], l["name"]) for l in data]


# The CLDR plural categories each language actually distinguishes. A language that is missing one
# does not fail loudly — it silently falls through to `other`, which is why this is checked here
# rather than trusted: Russian read "5 шага" and Czech "2 kroků" in a first attempt at the macro
# heading, and both looked plausible enough in a diff to survive it.
#
# Only the categories the app can hit are required. `many` in Spanish/French/Italian and `other` in
# the Slavic set are fraction rules, and a count of steps is a whole number.
PLURAL_CATEGORIES = {
    "en": {"one", "other"}, "de": {"one", "other"}, "fr": {"one", "other"},
    "es": {"one", "other"}, "it": {"one", "other"}, "nl": {"one", "other"},
    "da": {"one", "other"}, "nb": {"one", "other"}, "sv": {"one", "other"},
    "hu": {"one", "other"},
    "ko": {"other"}, "zh-Hans": {"other"},
    "cs": {"one", "few", "other"}, "sk": {"one", "few", "other"},
    "pl": {"one", "few", "many"}, "ru": {"one", "few", "many"}, "uk": {"one", "few", "many"},
    "sl": {"one", "two", "few", "other"},
    "ro": {"one", "few", "other"},
}


def plural_problems(src: dict) -> list[str]:
    """Every language of a pluralized string must carry the categories its grammar distinguishes."""
    out = []
    for key, entry in src.items():
        for code, loc in entry.get("localizations", {}).items():
            for name, sub in (loc.get("substitutions") or {}).items():
                plural = (sub.get("variations") or {}).get("plural")
                if plural is None:
                    continue
                want = PLURAL_CATEGORIES.get(code)
                if want is None:
                    out.append(f"{code}: no plural categories recorded for this language")
                    continue
                missing = want - set(plural)
                if missing:
                    out.append(f"{code}: “{key[:40]}…” substitution “{name}” is missing the "
                               f"{', '.join(sorted(missing))} form — it would fall back to `other`")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="write docs/generated/translation-coverage.md")
    args = ap.parse_args()

    languages = load_languages()
    en_slugs = {p.stem for p in HELP_EN.glob("*.md") if not p.name.startswith(".")}
    cat = json.loads(XCSTRINGS.read_text())
    src = cat["strings"]
    total_ui = len(src)

    rows, problems = [], []
    problems += plural_problems(src)
    for code, name in languages:
        if code == "en":
            rows.append((code, name, "—", "source", "source"))
            continue
        # Help coverage
        hdir = REPO / "docs" / f"help-{code}"
        have = {p.stem for p in hdir.glob("*.md")} if hdir.exists() else set()
        missing_help = sorted(en_slugs - have)
        extra_help = sorted(have - en_slugs)
        # UI coverage
        missing_ui = [k for k, v in src.items()
                      if v.get("localizations", {}).get(code, {}).get("stringUnit", {}).get("state") != "translated"]
        help_status = "✓" if not missing_help and not extra_help else f"{len(have)}/{len(en_slugs)}"
        ui_status = "✓" if not missing_ui else f"{total_ui - len(missing_ui)}/{total_ui}"
        rows.append((code, name, str(len(have)), help_status, ui_status))
        if missing_help:
            problems.append(f"{code}: {len(missing_help)} help page(s) missing: {', '.join(missing_help[:8])}"
                            + (" …" if len(missing_help) > 8 else ""))
        if extra_help:
            problems.append(f"{code}: {len(extra_help)} help page(s) with no English source: {', '.join(extra_help[:8])}")
        if missing_ui:
            problems.append(f"{code}: {len(missing_ui)} UI string(s) untranslated")

    lines = ["# Translation coverage", "",
             "_English is the source of truth. Generated by docs/scripts/check-translations.py._", "",
             f"- Languages: **{len(languages)}**  ·  Help topics (en): **{len(en_slugs)}**  ·  UI strings: **{total_ui}**", "",
             "| Code | Language | Help pages | Help | UI strings |", "|---|---|--:|:--:|:--:|"]
    for code, name, n, h, u in rows:
        lines.append(f"| {code} | {name} | {n} | {h} | {u} |")
    if problems:
        lines += ["", "## Behind (fix before release)", ""] + [f"- ⚠️ {p}" for p in problems]

    if args.write:
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"languages={len(languages)} help_topics={len(en_slugs)} ui_strings={total_ui} "
          f"behind={len(problems)}")
    for p in problems[:20]:
        print("  ⚠️ ", p)
    if len(problems) > 20:
        print(f"  … +{len(problems)-20} more")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
