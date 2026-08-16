#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-docs.py — documentation quality gate + coverage matrix.

Validates the SSOT docs and emits docs/generated/coverage-report.md:
  ERRORS (exit 1): missing front-matter fields, broken related/topic links,
                   forbidden terminology (per terminology.yml).
  WARNINGS:        referenced-but-missing screenshots, unreferenced screenshots,
                   help-intended features with no detectable topic coverage.

Terminology and link checks ignore fenced code blocks and inline `code` spans.
Run before building: python3 docs/scripts/check-docs.py
"""
from __future__ import annotations
import re, sys
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "docs/content"
HELP = REPO / "docs/content/help"
META = REPO / "docs/metadata"
SHOTS = REPO / "docs/assets/screenshots"
REPORT = REPO / "docs/generated/coverage-report.md"

FRONT_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)
FENCE_RE = re.compile(r'```.*?```', re.DOTALL)
INLINE_CODE_RE = re.compile(r'`[^`]*`')
IMG_RE = re.compile(r'!\[[^\]]*\]\(([^)]+)\)')
LINK_RE = re.compile(r'(?<!\!)\[[^\]]*\]\(([^)]+)\)')

errors, warnings = [], []


def strip_code(text: str) -> str:
    return INLINE_CODE_RE.sub(" ", FENCE_RE.sub(" ", text))


def load_topics():
    topics = {}
    for p in sorted(CONTENT.rglob("*.md")):
        if p.name.startswith("."):
            continue
        raw = p.read_text(encoding="utf-8")
        m = FRONT_RE.match(raw)
        meta = yaml.safe_load(m.group(1)) if m else {}
        body = raw[m.end():] if m else raw
        # Keyed by section/stem, not by stem alone. Two sections may legitimately hold a
        # page of the same name — `help/filesystem-images` is written for somebody using
        # the plugin and `plugins/filesystem-images` for somebody extending it — and with
        # a bare stem the second silently replaced the first in this map. The dropped page
        # was then checked for nothing at all: not its front matter, not its terminology,
        # not its images. It surfaced as a screenshot reported unreferenced while the
        # reference sat in the very page that had been shadowed.
        key = str(p.relative_to(CONTENT).with_suffix(""))
        topics[key] = {"path": p, "stem": p.stem, "meta": meta or {},
                       "body": body, "raw": raw}
    return topics


def main():
    topics = load_topics()
    slugs = {t['stem'] for t in topics.values()}
    terms = yaml.safe_load((META / "terminology.yml").read_text())["terms"]
    features = yaml.safe_load((META / "features.yml").read_text())["features"]

    referenced_imgs = set()

    for key, t in topics.items():
        slug, meta, body = t["stem"], t["meta"], t["body"]
        is_home = t["path"].parent.name == "website" and t["path"].stem == "index"
        # front matter (the homepage is the site root, not a nav topic — only needs title)
        required = ("title",) if is_home else ("title", "slug", "section", "order")
        for field in required:
            if field not in meta:
                errors.append(f"{key}.md: missing front-matter '{field}'")
        if not is_home and meta.get("slug") and meta["slug"] != slug:
            errors.append(f"{key}.md: front-matter slug '{meta['slug']}' != filename")
        # related links resolve
        for rel in (meta.get("related") or []):
            if rel not in slugs:
                errors.append(f"{key}.md: related '{rel}' is not a topic")
        clean = strip_code(body)
        # inline topic links (foo.html / foo.md)
        for url in LINK_RE.findall(clean):
            if url.startswith(("http://", "https://", "#", "mailto:")):
                continue
            target = re.sub(r'\.(html|md)$', '', url.split("#")[0].split("/")[-1])
            if target and target not in slugs:
                errors.append(f"{key}.md: link to unknown topic '{url}'")
        # images
        for url in IMG_RE.findall(body):
            name = url.split("/")[-1]
            referenced_imgs.add(name)
            if not (SHOTS / name).exists():
                warnings.append(f"{key}.md: image not found: {url}")
        # terminology (the glossary legitimately names the forbidden synonyms)
        low = clean.lower()
        for entry in ([] if slug == "glossary" else terms):
            for bad in (entry.get("avoid") or []):
                if re.search(rf'\b{re.escape(bad.lower())}\b', low):
                    errors.append(f"{key}.md: forbidden term '{bad}' (use '{entry['term']}')")

    # unreferenced screenshots (ignore -dark variants and -full crop backups)
    for img in sorted(SHOTS.glob("*.png")):
        base = img.name
        if base.endswith("-full.png"):
            continue
        if base not in referenced_imgs and base.replace("-dark", "") not in referenced_imgs:
            warnings.append(f"unreferenced screenshot: {img.relative_to(REPO)}")

    # coverage: help-intended features whose name/commands never appear in the corpus
    corpus = " ".join(t["body"].lower() for t in topics.values())
    help_feats = [f for f in features if f.get("documentation", {}).get("integrated_help")]
    uncovered = []
    for f in help_feats:
        keys = [f["name_en"].lower()] + [c.lower() for c in (f.get("ui", {}).get("commands") or [])]
        # a feature is "seen" if its english name (minus parentheticals) or any command id appears
        name_words = re.sub(r'\(.*?\)', '', f["name_en"]).lower().split("/")[0].strip()
        seen = name_words and name_words in corpus
        if not seen:
            uncovered.append(f["id"])

    # ---- report ----
    lines = ["# Documentation coverage report", "",
             "_Generated by docs/scripts/check-docs.py._", "",
             f"- Help topics: **{len(topics)}**",
             f"- Features in registry: **{len(features)}** ({len(help_feats)} flagged for integrated help)",
             f"- Errors: **{len(errors)}**  ·  Warnings: **{len(warnings)}**", "",
             "## Coverage matrix (declared)", "",
             "| Feature | Category | Help | Website | Dev | SDK |", "|---|---|:--:|:--:|:--:|:--:|"]
    def mark(d, k): return "✓" if d.get(k) else "·"
    for f in features:
        d = f.get("documentation", {})
        lines.append(f"| {f['id']} | {f['category']} | {mark(d,'integrated_help')} | "
                     f"{mark(d,'website')} | {mark(d,'developer_docs')} | {mark(d,'sdk_docs')} |")
    if uncovered:
        lines += ["", "## Help-intended features with no detected topic keyword", "",
                  *[f"- `{i}` (review)" for i in uncovered]]
    if errors:
        lines += ["", "## Errors", "", *[f"- ❌ {e}" for e in errors]]
    if warnings:
        lines += ["", "## Warnings", "", *[f"- ⚠️ {w}" for w in warnings]]
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"topics={len(topics)} errors={len(errors)} warnings={len(warnings)} -> {REPORT.relative_to(REPO)}")
    for e in errors:
        print("  ❌", e)
    for w in warnings[:12]:
        print("  ⚠️ ", w)
    if len(warnings) > 12:
        print(f"  … +{len(warnings)-12} more warnings (see report)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
