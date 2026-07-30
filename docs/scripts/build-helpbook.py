#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""build-helpbook.py — render docs/content/help/*.md into an Apple Help Book.

Single-source: the same Markdown topics that feed the website (see DOCUMENTATION.md)
are rendered here into a macOS `.help` bundle that Help Viewer opens from the app's
Help menu (NSApplication.showHelp → CFBundleHelpBookName).

Output layout (Apple Help Book):
  <out>/PeachCommander.help/Contents/
    Info.plist                                  # bundle plist (AppleTitle, etc.)
    Resources/<lang>.lproj/
      index.html                                # TOC landing page (carries AppleTitle meta)
      <slug>.html                               # one page per topic
      shrd/help.css, shrd/*                      # shared assets
      PeachCommander.helpindex                    # built by hiutil (search)

Each topic Markdown file has YAML front matter:
  ---
  title: Copying files
  slug: copying-files            # output filename + help anchor
  section: Files & folders       # TOC grouping
  order: 30                       # sort within section
  anchor: help-copying           # optional AppleHelp anchor for context-sensitive help
  related: [moving-files, deleting-files]
  ---

Includes:  {% include "fragment.md" %}  pulls docs/content/shared/fragment.md.

Usage:  python3 docs/scripts/build-helpbook.py [--out DIR] [--lang en] [--no-index]
"""
from __future__ import annotations
import argparse, html, os, re, shutil, subprocess, sys
from pathlib import Path

try:
    import markdown  # type: ignore
    import yaml       # type: ignore
except ImportError as e:
    sys.exit(f"missing dependency: {e}. Run: python3 -m pip install --user markdown pyyaml pygments")

REPO = Path(__file__).resolve().parents[2]
HELP_SRC = REPO / "docs" / "content" / "help"
SHARED = REPO / "docs" / "content" / "shared"
ASSETS = REPO / "docs" / "assets"
BOOK_NAME = "PeachCommander.help"
APPLE_TITLE = "Peach Commander Help"          # must equal CFBundleHelpBookName in the app
BUNDLE_ID = "com.peachcommander.app.help"

# Per-language UI strings for the generated index + "related" section. English source
# lives in docs/content/help; each other language lives in docs/help-<lang>.
LANG_STRINGS = {
    "en": {
        "welcome": "Welcome to **Peach Commander** — a fast, dual-pane file manager for macOS.\n",
        "browse": "Browse the topics below or use the search field above.\n",
        "related": "Related topics",
    },
    "de": {
        "welcome": "Willkommen bei **Peach Commander** — einem schnellen Dateimanager mit zwei Panels für macOS.\n",
        "browse": "Stöbern Sie in den Themen unten oder nutzen Sie das Suchfeld oben.\n",
        "related": "Verwandte Themen",
    },
}


def lang_str(lang: str, key: str) -> str:
    return LANG_STRINGS.get(lang, LANG_STRINGS["en"]).get(key) or LANG_STRINGS["en"][key]

INCLUDE_RE = re.compile(r'{%\s*include\s+"([^"]+)"\s*%}')
IMG_RE = re.compile(r'!\[[^\]]*\]\(([^)]+)\)')
FRONT_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)


def parse_topic(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    m = FRONT_RE.match(text)
    meta, body = ({}, text)
    if m:
        meta = yaml.safe_load(m.group(1)) or {}
        body = text[m.end():]
    meta.setdefault("slug", path.stem)
    meta.setdefault("title", meta["slug"].replace("-", " ").capitalize())
    meta.setdefault("section", "General")
    meta.setdefault("order", 100)
    return meta, body


def expand_includes(body: str) -> str:
    def repl(m):
        frag = SHARED / m.group(1)
        if not frag.exists():
            print(f"  ! missing include: {m.group(1)}", file=sys.stderr)
            return ""
        return frag.read_text(encoding="utf-8")
    # expand up to 3 levels of nesting
    for _ in range(3):
        new = INCLUDE_RE.sub(repl, body)
        if new == body:
            break
        body = new
    return body


PAGE_TMPL = """<!DOCTYPE html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{apple_meta}<title>{title}</title>
<link rel="stylesheet" href="{root}shrd/help.css">
</head>
<body>
<nav class="pc-help-top"><a href="{root}index.html">&#8592; {book}</a></nav>
<main class="pc-help">
<h1>{title}</h1>
{content}
{related}
</main>
</body>
</html>
"""


def render_related(meta, by_slug, lang="en") -> str:
    rel = meta.get("related") or []
    if not rel:
        return ""
    items = []
    for slug in rel:
        t = by_slug.get(slug)
        if t:
            items.append(f'<li><a href="{slug}.html">{html.escape(t["title"])}</a></li>')
    if not items:
        return ""
    return (f'<section class="pc-related"><h2>{html.escape(lang_str(lang, "related"))}</h2><ul>'
            + "".join(items) + "</ul></section>")


def build_page(meta, body, by_slug, lang, is_index=False) -> str:
    md = markdown.Markdown(extensions=["extra", "toc", "tables", "fenced_code", "codehilite", "sane_lists"],
                           extension_configs={"codehilite": {"guess_lang": False}})
    content = md.convert(body)
    apple_meta = ""
    if is_index:
        apple_meta = (f'<meta name="AppleTitle" content="{html.escape(APPLE_TITLE)}">\n'
                      f'<meta name="robots" content="anchors">\n'
                      f'<meta name="description" content="User help for Peach Commander.">\n')
    elif meta.get("anchor"):
        apple_meta = f'<meta name="AppleTitle" content="{html.escape(str(meta["anchor"]))}">\n'
    return PAGE_TMPL.format(
        lang=lang, title=html.escape(meta["title"]), book=html.escape(APPLE_TITLE),
        apple_meta=apple_meta, root="", content=content,
        related="" if is_index else render_related(meta, by_slug, lang))


def build_index(topics, lang) -> str:
    sections: dict[str, list] = {}
    for meta, _ in topics:
        sections.setdefault(meta["section"], []).append(meta)
    body = [lang_str(lang, "welcome"), lang_str(lang, "browse")]
    for section in sorted(sections, key=lambda s: min(m["order"] for m in sections[s])):
        body.append(f"\n## {section}\n")
        for meta in sorted(sections[section], key=lambda m: (m["order"], m["title"])):
            body.append(f'- [{meta["title"]}]({meta["slug"]}.html)')
    return build_page({"title": APPLE_TITLE, "section": ""}, "\n".join(body), {}, lang, is_index=True)


def copy_assets(out_lproj: Path, referenced: set[str]):
    shrd = out_lproj / "shrd"
    shrd.mkdir(parents=True, exist_ok=True)
    (shrd / "help.css").write_text(HELP_CSS, encoding="utf-8")
    imgdir = out_lproj / "images"
    for ref in referenced:
        src = (ASSETS / ref).resolve() if not ref.startswith("/") else Path(ref)
        # allow refs like "screenshots/foo.png" or "../assets/..."
        cands = [ASSETS / ref, REPO / "docs" / ref, Path(ref)]
        found = next((c for c in cands if c.exists()), None)
        if found:
            imgdir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(found, imgdir / Path(ref).name)


def rewrite_images(body: str) -> tuple[str, set[str]]:
    refs: set[str] = set()
    def repl(m):
        url = m.group(1)
        if url.startswith(("http://", "https://", "images/")):
            return m.group(0)
        refs.add(url)
        return m.group(0).replace(url, f"images/{Path(url).name}")
    return IMG_RE.sub(repl, body), refs


def all_language_codes() -> list[str]:
    """en first, then every other language that has a docs/help-<code>/ source dir."""
    langs_yml = REPO / "docs/metadata/languages.yml"
    codes = ["en"]
    if langs_yml.exists():
        import yaml as _yaml
        for l in _yaml.safe_load(langs_yml.read_text())["languages"]:
            c = l["code"]
            if c != "en" and (REPO / "docs" / f"help-{c}").exists():
                codes.append(c)
    return codes


def build_language(out: str, lang: str, no_index: bool):
    # English is the SSOT under docs/content/help; other languages live in docs/help-<lang>.
    src_dir = HELP_SRC if lang == "en" else (REPO / "docs" / f"help-{lang}")
    if not src_dir.exists() or not any(src_dir.glob("*.md")):
        sys.exit(f"no help topics in {src_dir} — nothing to build")

    book = Path(out) / BOOK_NAME
    lproj = book / "Contents" / "Resources" / f"{lang}.lproj"
    # Multi-language bundle: clear only THIS language's lproj so other languages
    # already built into the book are preserved.
    if lproj.exists():
        shutil.rmtree(lproj)
    lproj.mkdir(parents=True)

    # Info.plist is written once; the development region stays the primary language.
    info = book / "Contents" / "Info.plist"
    if not info.exists():
        info.parent.mkdir(parents=True, exist_ok=True)
        info.write_text(INFO_PLIST.format(
            book=BOOK_NAME, title=APPLE_TITLE, bundle_id=BUNDLE_ID, lang="en"), encoding="utf-8")

    topics = []
    for path in sorted(src_dir.glob("*.md")):
        meta, body = parse_topic(path)
        body = expand_includes(body)
        topics.append((meta, body))
    by_slug = {m["slug"]: m for m, _ in topics}

    all_refs: set[str] = set()
    for meta, body in topics:
        body, refs = rewrite_images(body)
        all_refs |= refs
        (lproj / f'{meta["slug"]}.html').write_text(
            build_page(meta, body, by_slug, lang), encoding="utf-8")
    (lproj / "index.html").write_text(build_index(topics, lang), encoding="utf-8")
    copy_assets(lproj, all_refs)

    print(f"✓ [{lang}] {len(topics)} topics → {book}")

    if not no_index:
        hiutil = subprocess.run(["xcrun", "-f", "hiutil"], capture_output=True, text=True)
        hi = hiutil.stdout.strip() or "/usr/bin/hiutil"
        idx = lproj / "PeachCommander.helpindex"
        r = subprocess.run([hi, "-Caf", str(idx), "-a", str(lproj)], capture_output=True, text=True)
        if r.returncode == 0:
            print(f"✓ [{lang}] search index → {idx.name}")
        else:
            print(f"! hiutil failed: {r.stderr.strip()}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO / "Resources"))
    ap.add_argument("--lang", default="en")
    ap.add_argument("--all", action="store_true",
                    help="build every language that has a docs/help-<code>/ source dir")
    ap.add_argument("--no-index", action="store_true", help="skip hiutil search index")
    args = ap.parse_args()
    langs = all_language_codes() if args.all else [args.lang]
    for lang in langs:
        build_language(args.out, lang, args.no_index)


INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>{lang}</string>
  <key>CFBundleIdentifier</key><string>{bundle_id}</string>
  <key>CFBundleName</key><string>{title}</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleSignature</key><string>hbwr</string>
  <key>HPDBookAccessPath</key><string>index.html</string>
  <key>HPDBookIndexPath</key><string>PeachCommander.helpindex</string>
  <key>HPDBookTitle</key><string>{title}</string>
  <key>HPDBookType</key><string>3</string>
  <key>HPDBookKBProduct</key><string>PeachCommander1.0</string>
</dict>
</plist>
"""

HELP_CSS = """:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { font: 14px/1.6 -apple-system, "SF Pro Text", Helvetica, sans-serif;
  margin: 0; color: #1d1d1f; background: #fff; }
.pc-help-top { padding: 8px 20px; border-bottom: 1px solid #e5e5e7; font-size: 12px; }
.pc-help-top a { color: #0a63c9; text-decoration: none; }
main.pc-help { max-width: 720px; margin: 0 auto; padding: 24px 28px 64px; }
h1 { font-size: 26px; font-weight: 700; margin: 8px 0 16px; }
h2 { font-size: 19px; margin: 28px 0 10px; }
h3 { font-size: 16px; margin: 20px 0 8px; }
img { max-width: 100%; height: auto; border: 1px solid #e0e0e2; border-radius: 8px; margin: 12px 0; }
code { font: 12.5px/1.5 "SF Mono", Menlo, monospace; background: #f2f2f4; padding: 1px 5px; border-radius: 4px; }
pre { background: #f6f6f8; padding: 12px 14px; border-radius: 8px; overflow-x: auto; }
pre code { background: none; padding: 0; }
kbd { font: 12px "SF Mono", Menlo, monospace; background: #eee; border: 1px solid #ccc;
  border-bottom-width: 2px; border-radius: 5px; padding: 1px 6px; }
table { border-collapse: collapse; margin: 14px 0; width: 100%; }
th, td { border: 1px solid #e0e0e2; padding: 6px 10px; text-align: left; font-size: 13px; }
th { background: #f7f7f9; }
.pc-related { margin-top: 40px; padding-top: 16px; border-top: 1px solid #e5e5e7; }
.pc-related h2 { font-size: 15px; }
.pc-related ul { padding-left: 18px; }
a { color: #0a63c9; }
@media (prefers-color-scheme: dark) {
  body { color: #f5f5f7; background: #1e1e1e; }
  .pc-help-top { border-color: #38383a; } .pc-help-top a, a { color: #4aa3ff; }
  code { background: #2c2c2e; } pre { background: #262628; }
  kbd { background: #3a3a3c; border-color: #555; }
  th, td { border-color: #38383a; } th { background: #2c2c2e; }
  img { border-color: #38383a; }
  .pc-related, .pc-related { border-color: #38383a; }
}
"""

if __name__ == "__main__":
    main()
