#!/usr/bin/env python3
"""Helper for finishing Help translations in-session: for a language <code>, print the
section-name map it already uses (English section -> translated, so new pages stay
consistent) and the ordered list of MISSING slugs (present in English, absent in
docs/help-<code>/), with each slug's English section + title.

Usage: python3 docs/scripts/i18n_help_status.py <code> [--slugs]
"""
import re, sys, pathlib, yaml
FRONT = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)
REPO = pathlib.Path(__file__).resolve().parents[2]
EN = REPO / "docs/content/help"

def meta(p):
    m = FRONT.match(p.read_text(encoding="utf-8"))
    return yaml.safe_load(m.group(1)) if m else {}

def main():
    code = sys.argv[1]
    slugs_only = "--slugs" in sys.argv
    en = {p.stem: meta(p) for p in sorted(EN.glob("*.md"))}
    d = REPO / "docs" / f"help-{code}"
    have = {p.stem: meta(p) for p in d.glob("*.md")} if d.exists() else {}
    # section map from existing translated pages: en-section -> translated-section
    secmap = {}
    for slug, m in have.items():
        en_s = en.get(slug, {}).get("section")
        if en_s and m.get("section"):
            secmap.setdefault(en_s, m["section"])
    missing = [s for s in en if s not in have]
    if slugs_only:
        print(" ".join(missing)); return
    print(f"# {code}: {len(have)}/{len(en)} done, {len(missing)} missing")
    print("## section map (reuse EXACTLY):")
    for k, v in sorted(secmap.items()):
        print(f"  {k!r} -> {v!r}")
    # sections still unseen (no translated page yet uses them)
    unseen = sorted({en[s].get('section') for s in missing} - set(secmap))
    if unseen:
        print("## sections with NO example yet (choose a consistent translation):")
        for s in unseen: print(f"  {s!r}")
    print("## missing slugs (slug | en-section | en-title):")
    for s in missing:
        print(f"  {s} | {en[s].get('section')} | {en[s].get('title')}")

if __name__ == "__main__":
    main()
