#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-plugin-translations.py — are the plugins' own strings translated, and honestly so?

The app's coverage gate reads the String Catalog and never sees a plugin: a plugin ships its strings
in its own bundle. That is how every plugin came to be localized into German and nothing else while
the app itself is in nineteen languages, with every gate green — the interface a user sees is part
app, part plugin, and only one half was being counted.

Two different things are wrong in two different ways, so this reports them differently:

  * **A language that is missing entirely** is a known gap. `L` falls back to the English key, so the
    plugin is in English rather than broken. Counted and listed, not failed — otherwise this could
    never be introduced without translating 7,000 strings on the same day.
  * **A language that is present but incomplete** is the dangerous one, and fails the run. A half
    filled .lproj reads as "translated" from the outside while some of its dialog is in another
    language, and nothing else will ever point at it.

A stale key — one in a .lproj that no longer exists in en.lproj — fails too: it is a translation of
something the plugin no longer says.

Usage: Tools/check-plugin-translations.py [--list-missing]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = os.path.join(ROOT, "Plugins")
LANGUAGES_YML = os.path.join(ROOT, "docs/metadata/languages.yml")

KEY_RE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=', re.M)


def shipped_languages():
    """The languages the app ships, read from the same metadata the docs gates use."""
    codes = []
    with open(LANGUAGES_YML, encoding="utf-8") as handle:
        for line in handle:
            # The list is written in YAML flow style: `- { code: en, name: English, … }`.
            match = re.match(r'\s*-\s*\{?\s*code:\s*"?([\w-]+)"?', line)
            if match:
                codes.append(match.group(1))
    return codes


def keys_of(path):
    with open(path, encoding="utf-8") as handle:
        return KEY_RE.findall(handle.read())


def main():
    languages = shipped_languages()
    if not languages:
        print("!! could not read the language list", file=sys.stderr)
        return 1

    problems = 0
    missing_total = 0
    plugin_count = 0
    for plugin in sorted(os.listdir(PLUGINS)):
        english = os.path.join(PLUGINS, plugin, "Resources/en.lproj/Localizable.strings")
        if not os.path.exists(english):
            continue
        plugin_count += 1
        expected = set(keys_of(english))
        absent = []
        for lang in languages:
            if lang == "en":
                continue
            path = os.path.join(PLUGINS, plugin, "Resources", f"{lang}.lproj/Localizable.strings")
            if not os.path.exists(path):
                absent.append(lang)
                missing_total += len(expected)
                continue
            have = set(keys_of(path))
            for key in sorted(expected - have):
                print(f"  ✗ {plugin}/{lang}: not translated: {key!r}")
                problems += 1
            for key in sorted(have - expected):
                print(f"  ✗ {plugin}/{lang}: stale, not in en.lproj: {key!r}")
                problems += 1
        if absent and "--list-missing" in sys.argv:
            print(f"  · {plugin}: no translation at all for {', '.join(absent)}")

    print(f"plugins={plugin_count} languages={len(languages)} "
          f"incomplete_or_stale={problems} untranslated_strings={missing_total}")
    if problems:
        print("A present-but-incomplete .lproj shows part of a dialog in the wrong language.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
