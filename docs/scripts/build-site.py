#!/usr/bin/env python3
"""build-site.py — build the documentation website(s) with MkDocs Material.

Single-source: the same Markdown that feeds the in-app Help Book renders here into a
static, offline-capable site. English is the full site (user guide + tutorials +
developer/SDK/plugin docs + homepage) from docs/content/**. German is the translated
Help, published as a subsite at /de/ with a Material language switcher between them.

Strategy: stage each language's pages FLAT into its own MkDocs workspace (slugs are
unique, so the bare `slug.md` cross-links resolve); rewrite `screenshots/<id>.png`
image refs to `assets/screenshots/`; generate nav from each page's `section` + `order`.

Usage: python3 docs/scripts/build-site.py [--serve]
"""
from __future__ import annotations
import argparse, re, shutil, subprocess, sys
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "docs/content"
HELP_DE = REPO / "docs/help-de"
ASSETS = REPO / "docs/assets"
BUILD = REPO / "build/site"
SITE = BUILD / "site"
FRONT_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)
IMG_RE = re.compile(r'(!\[[^\]]*\]\()screenshots/([^)]+)(\))')

SECTION_LABEL = {
    "user-guide": "Guide", "tutorials": "Tutorials", "troubleshooting": "Troubleshooting & FAQ",
}

MKDOCS_YML = """site_name: {site_name}
site_description: A fast, keyboard-driven, dual-panel file manager for macOS.
theme:
  name: material
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle: {{ icon: material/weather-night, name: Switch to dark mode }}
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle: {{ icon: material/weather-sunny, name: Switch to light mode }}
  features: [navigation.instant, navigation.tracking, navigation.top, navigation.sections,
             search.suggest, search.highlight, content.code.copy, toc.follow]
use_directory_urls: false
extra:
  alternate:
{alternate}
markdown_extensions:
  - admonition
  - attr_list
  - md_in_html
  - tables
  - toc: {{ permalink: true }}
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - pymdownx.highlight
  - pymdownx.keys
plugins:
  - search
nav:
{nav}
"""

DE_INDEX = """---
title: Peach Commander – Hilfe
---

# Peach Commander – Hilfe

Willkommen bei der deutschen Hilfe zu **Peach Commander** — einem schnellen,
tastaturorientierten Dateimanager mit zwei Panels für macOS. Wählen Sie links ein
Thema oder nutzen Sie die Suche oben. Über den Sprachumschalter oben rechts gelangen
Sie zur vollständigen englischen Dokumentation.
"""


def parse(md: str):
    m = FRONT_RE.match(md)
    meta = yaml.safe_load(m.group(1)) if m else {}
    body = md[m.end():] if m else md
    return meta or {}, body


def build_one(*, workspace: str, out_dir: Path, site_name: str, sources: Path,
              recursive: bool, home_from_website: bool, synth_index: str | None,
              alternate: list[tuple[str, str, str]], mkdocs: str, strict: bool):
    """Stage one language's pages into build/<workspace> and render to out_dir."""
    work = BUILD / workspace
    docs = work / "docs"
    if work.exists():
        shutil.rmtree(work)
    docs.mkdir(parents=True)
    (docs / "assets").mkdir()
    if (ASSETS / "screenshots").exists():
        shutil.copytree(ASSETS / "screenshots", docs / "assets/screenshots")

    md_files = sorted(sources.rglob("*.md")) if recursive else sorted(sources.glob("*.md"))
    pages = []  # (section, order, title, out_name)
    have_index = False
    for md_path in md_files:
        if md_path.name.startswith("."):
            continue
        meta, body = parse(md_path.read_text(encoding="utf-8"))
        slug = meta.get("slug") or md_path.stem
        is_home = home_from_website and md_path.parent.name == "website" and md_path.stem == "index"
        out_name = "index.md" if is_home else f"{slug}.md"
        if out_name == "index.md":
            have_index = True
        body = IMG_RE.sub(r"\1assets/screenshots/\2\3", body)
        fm = {k: meta[k] for k in ("title", "description") if k in meta}
        fm_text = "---\n" + yaml.safe_dump(fm, sort_keys=False, allow_unicode=True) + "---\n\n" if fm else ""
        (docs / out_name).write_text(fm_text + body, encoding="utf-8")
        if not is_home:
            pages.append((meta.get("section", "Other"), meta.get("order", 999),
                          meta.get("title", slug), out_name))
    if not have_index and synth_index is not None:
        (docs / "index.md").write_text(synth_index, encoding="utf-8")

    groups: dict[str, list] = {}
    for sec, order, title, name in pages:
        groups.setdefault(sec, []).append((order, title, name))
    ordered_secs = sorted(groups, key=lambda s: min(o for o, _, _ in groups[s]))
    nav_lines = ["  - Home: index.md"]
    for sec in ordered_secs:
        label = SECTION_LABEL.get(sec, sec[:1].upper() + sec[1:])
        nav_lines.append(f"  - {label}:")
        for _, title, name in sorted(groups[sec]):
            nav_lines.append(f'    - "{title}": {name}')

    alt_lines = "\n".join(
        f"    - name: {n}\n      link: {link}\n      lang: {lang}" for n, link, lang in alternate)
    (work / "mkdocs.yml").write_text(
        MKDOCS_YML.format(site_name=site_name, nav="\n".join(nav_lines), alternate=alt_lines),
        encoding="utf-8")

    cmd = [mkdocs, "build", "-f", str(work / "mkdocs.yml"), "-d", str(out_dir)]
    r = subprocess.run(cmd + (["--strict"] if strict else []), capture_output=True, text=True)
    if r.returncode != 0 and strict:
        subprocess.run(cmd, capture_output=True, text=True)  # non-strict fallback so a site still exists
    return r.returncode, (r.stdout + r.stderr), len(pages) + 1


def load_languages():
    """(code, native) for every language, en first, that has a Help source."""
    ymlp = REPO / "docs/metadata/languages.yml"
    langs = [("en", "English")]
    if ymlp.exists():
        for l in yaml.safe_load(ymlp.read_text())["languages"]:
            if l["code"] != "en" and (REPO / "docs" / f"help-{l['code']}").exists():
                langs.append((l["code"], l.get("native", l["code"])))
    return langs


def alternates_for(current: str, langs) -> list[tuple[str, str, str]]:
    """Material `extra.alternate` links from the `current` site to every language."""
    out = []
    for code, native in langs:
        if current == "en":
            link = "./" if code == "en" else f"{code}/"
        elif code == "en":
            link = "../"
        elif code == current:
            link = "./"
        else:
            link = f"../{code}/"
        out.append((native, link, code))
    return out


def synth_index(native: str) -> str:
    return f"---\ntitle: Peach Commander\n---\n\n# Peach Commander\n\n_{native}_\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--serve", action="store_true")
    args = ap.parse_args()

    if BUILD.exists():
        shutil.rmtree(BUILD)
    mkdocs = str(Path.home() / "Library/Python/3.9/bin/mkdocs")
    mkdocs = mkdocs if Path(mkdocs).exists() else "mkdocs"
    langs = load_languages()
    alt = alternates_for  # shorthand

    # English — the full site at the root.
    rc_en, out_en, n_en = build_one(
        workspace="site-en", out_dir=SITE, site_name="Peach Commander",
        sources=CONTENT, recursive=True, home_from_website=True, synth_index=None,
        alternate=alt("en", langs), mkdocs=mkdocs, strict=not args.serve)
    if args.serve:
        subprocess.run([mkdocs, "serve", "-f", str(BUILD / "site-en" / "mkdocs.yml")])
        return

    # Each other language — its translated Help, published under /<code>/.
    results = {"en": (rc_en, out_en, n_en)}
    for code, native in langs:
        if code == "en":
            continue
        results[code] = build_one(
            workspace=f"site-{code}", out_dir=SITE / code,
            site_name=f"Peach Commander – {native}",
            sources=REPO / "docs" / f"help-{code}", recursive=False,
            home_from_website=False, synth_index=DE_INDEX if code == "de" else synth_index(native),
            alternate=alt(code, langs), mkdocs=mkdocs, strict=True)

    failed = [c for c, (rc, _, _) in results.items() if rc != 0]
    summary = " · ".join(f"{c}:{results[c][2]}" for c, _ in langs)
    if not failed:
        print(f"✓ {len(langs)} languages ({summary}) → {SITE.relative_to(REPO)}")
    else:
        for c in failed:
            print(results[c][1], file=sys.stderr)
        print(f"⚠️  built with warnings (strict failed for: {', '.join(failed)}) → {SITE.relative_to(REPO)}")
        sys.exit(1)
        sys.exit(1)


if __name__ == "__main__":
    main()
