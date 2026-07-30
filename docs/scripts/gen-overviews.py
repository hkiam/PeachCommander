#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""gen-overviews.py — generate derived overview docs from the metadata.

Outputs (regenerable, never hand-edited):
  FEATURES.md                          — feature overview grouped by category (from features.yml)
  docs/content/reference/glossary.md   — glossary page (from terminology.yml)

Usage: python3 docs/scripts/gen-overviews.py
"""
from __future__ import annotations
import sys
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit("need pyyaml")

REPO = Path(__file__).resolve().parents[2]
FEATURES = yaml.safe_load((REPO / "docs/metadata/features.yml").read_text())["features"]
TERMS = yaml.safe_load((REPO / "docs/metadata/terminology.yml").read_text())["terms"]

CAT_LABEL = {
    "navigation": "Navigation", "panels": "Panels", "file-ops": "File operations",
    "archive": "Archives", "search": "Search", "network": "Network & remote",
    "viewer": "Viewers & editors", "customization": "Customization", "settings": "Settings",
    "plugins": "Plugins", "sdk": "SDK", "developer": "Developer", "distribution": "Distribution",
}
STATUS_MARK = {"stable": "✅", "beta": "🅱️", "planned": "🔜", "experimental": "🧪"}


def gen_features():
    by_cat = {}
    for f in FEATURES:
        by_cat.setdefault(f["category"], []).append(f)
    lines = ["# Peach Commander — feature overview", "",
             "_Generated from `docs/metadata/features.yml` by `docs/scripts/gen-overviews.py`. "
             "Do not edit by hand._", "",
             f"**{len(FEATURES)} features** across {len(by_cat)} categories. "
             "AI ships as an optional, removable plugin (on-device Apple Intelligence, "
             "optional cloud model). Auto-update (Sparkle) is planned but not yet integrated.", ""]
    order = [c for c in CAT_LABEL if c in by_cat] + [c for c in by_cat if c not in CAT_LABEL]
    for cat in order:
        lines.append(f"## {CAT_LABEL.get(cat, cat.title())}")
        lines.append("")
        lines.append("| Feature | Audiences | Shortcut(s) | Status |")
        lines.append("|---|---|---|---|")
        for f in sorted(by_cat[cat], key=lambda x: x["name_en"]):
            sc = ", ".join((f.get("ui") or {}).get("shortcuts") or []) or "—"
            aud = ", ".join(f.get("audiences") or [])
            mark = STATUS_MARK.get(f.get("status", ""), f.get("status", ""))
            lines.append(f"| {f['name_en']} | {aud} | {sc} | {mark} |")
        lines.append("")
    (REPO / "FEATURES.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"✓ FEATURES.md ({len(FEATURES)} features)")


def gen_glossary():
    lines = ["---", "title: Glossary", "slug: glossary", "section: Reference", "order: 100",
             "related: [introduction]", "---", "",
             "_Generated from `docs/metadata/terminology.yml`. These are the canonical terms "
             "used throughout the documentation._", ""]
    for t in sorted(TERMS, key=lambda x: x["term"].lower()):
        lines.append(f"**{t['term']}**")
        lines.append(f": {t.get('definition','')}")
        if t.get("avoid"):
            lines.append(f"  <br>*(not: {', '.join(t['avoid'])})*")
        lines.append("")
    out = REPO / "docs/content/reference/glossary.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"✓ glossary.md ({len(TERMS)} terms)")


if __name__ == "__main__":
    gen_features()
    gen_glossary()
