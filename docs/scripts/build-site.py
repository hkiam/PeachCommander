#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""build-site.py — build the documentation website(s) with MkDocs Material.

Single-source: the same Markdown that feeds the in-app Help Book renders here into a
static, offline-capable site. English is the full site (user guide + tutorials +
developer/SDK/plugin docs + homepage) from docs/content/**. German is the translated
Help, published as a subsite at /de/ with a Material language switcher between them.

Strategy: stage each language's pages FLAT into its own MkDocs workspace (slugs are
unique, so the bare `slug.md` cross-links resolve); rewrite `screenshots/<id>.png`
image refs to `assets/screenshots/`; generate nav from each page's `group` + `section`
+ `order`.

Navigation is TWO levels on the English site: `group:` is the tab bar, `section:` the
collapsible sidebar group beneath it. `group:` is a website-only key — the Help Book
generator does not read it, so the shipped in-app help keeps its own one-level
`section`/`order` structure untouched (F-437).

Group order comes from GROUP_ORDER below, deliberately explicit. It used to be
`min(order)` across a section's pages, which made the top level an accident: four
sections tied at `order: 10` and the tie fell to alphabetical directory order, so
`developer-guide/` outranked `help/` and the generated `order: 5` of the API reference
put a symbol dump first on a page meant to welcome newcomers.

Pages carrying no `group:` (every translated Help subsite) keep the old one-level nav,
and only the grouped site gets `navigation.tabs` — so the 18 subsites render exactly as
they did before.

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
# Third-party engines the repository vendors once and two things consume: this site, and the
# Markdown lister plugin, which ships the same Mermaid build. One copy, because it is 3.2 MB.
VENDOR = REPO / "Vendor"
BUILD = REPO / "build/site"
SITE = BUILD / "site"
REPO_SLUG = "hkiam/PeachCommander"
REPO_URL = f"https://github.com/{REPO_SLUG}"
FRONT_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)
IMG_RE = re.compile(r'(!\[[^\]]*\]\()screenshots/([^)]+)(\))')

# The tab bar, in reading order: what the app is, then using it, then bending it to your
# will, then the deep end. A newcomer needs the first two; the API reference lives in the
# last one and is reached on purpose rather than by accident.
GROUP_ORDER = [
    "Get started",
    "Using Peach Commander",
    "Customise",
    "Plugins",
    "Tutorials",
    "Reference & help",
    "Develop",
]

SECTION_LABEL = {
    "user-guide": "Install & migrate", "troubleshooting": "Troubleshooting & FAQ",
}


def group_labels() -> dict[str, dict[str, str]]:
    """Umbrella-group labels per language, from docs/metadata/nav-groups.yml.

    Only groups that hold more than one section are in there — see that file for why.
    """
    ymlp = REPO / "docs/metadata/nav-groups.yml"
    if not ymlp.exists():
        return {}
    data = yaml.safe_load(ymlp.read_text(encoding="utf-8")) or {}
    return {g["id"]: (g.get("labels") or {}) for g in (data.get("groups") or [])}


GROUP_LABELS = group_labels()


def group_label(grp: str, sections: dict, lang: str, warn: set) -> str:
    """The tab label for a group, in the reader's language.

    English shows the id, which is written to be the label. For a translated subsite a group
    holding exactly one section IS that section, and the translators already named it — so it
    is derived rather than repeated in a table that could fall out of date the moment somebody
    renames a section. Only the umbrella group needs a translation of its own.
    """
    if lang == "en":
        return grp
    if len(sections) == 1:
        return section_label(next(iter(sections)))
    label = GROUP_LABELS.get(grp, {}).get(lang)
    if not label:
        warn.add(f"{lang}: no label for group '{grp}' — showing the English id")
        return grp
    return label


def section_label(sec: str) -> str:
    """Human label for a `section:` value.

    Only slug-shaped sections get prettified. The old rule ran `sec[:1].upper()` over
    everything, which is why the site said "MacOS & privacy" while the Help Book — which
    never touched the string — said "macOS & privacy" correctly.
    """
    if sec in SECTION_LABEL:
        return SECTION_LABEL[sec]
    return sec.replace("-", " ").capitalize() if sec.islower() else sec

MKDOCS_YML = """site_name: {site_name}
site_description: A fast, keyboard-driven, dual-panel file manager for macOS.
theme:
  name: material
  # Two remote requests removed, both of them Material's defaults rather than choices of ours.
  #
  # `font: false` stops the <link> to fonts.googleapis.com (and the preconnect to fonts.gstatic.com)
  # that Material emits unless the key is set. Nothing has to replace Roboto: Material's own CSS reads
  # `var(--md-text-font,_),-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif`, so with the
  # variable unset the page falls through to the system stack — on a Mac, the same face the
  # application itself uses. Checked in the stylesheet rather than assumed.
  #
  # `custom_dir` overrides partials/source.html to drop one attribute, which is what makes the bundle
  # fetch api.github.com for the star and fork counts. See that file for the trade.
  #
  # DOCUMENTATION.md:100 gives "fully offline output" as the reason this generator was chosen. It was
  # not true: opening any page told Google and GitHub that somebody had.
  font: false
  custom_dir: overrides
  logo: assets/peachcommander-icon.png
  favicon: assets/peachcommander-icon.png
  palette:
    - media: "(prefers-color-scheme: light)"
      scheme: default
      toggle: {{ icon: material/weather-night, name: Switch to dark mode }}
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      toggle: {{ icon: material/weather-sunny, name: Switch to light mode }}
  features: [{features}]
use_directory_urls: false
extra_css:
  - assets/website/peach.css
extra_javascript:
{extra_js}
extra:
  social:
    - icon: fontawesome/brands/github
      link: {repo_url}
      name: Peach Commander on GitHub
  alternate:
{alternate}
repo_url: {repo_url}
repo_name: {repo_slug}
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



def parse(md: str):
    m = FRONT_RE.match(md)
    meta = yaml.safe_load(m.group(1)) if m else {}
    body = md[m.end():] if m else md
    return meta or {}, body


def build_one(*, workspace: str, out_dir: Path, site_name: str, sources: Path,
              recursive: bool, home_from_website: bool,
              alternate: list[tuple[str, str, str]], mkdocs: str, strict: bool,
              mermaid: bool = False,
              lang: str = "en", group_by_slug: dict[str, str] | None = None,
              synth_title: str | None = None, synth_lead: str = ""):
    """Stage one language's pages into build/<workspace> and render to out_dir."""
    work = BUILD / workspace
    docs = work / "docs"
    if work.exists():
        shutil.rmtree(work)
    docs.mkdir(parents=True)
    (docs / "assets").mkdir()
    if (ASSETS / "screenshots").exists():
        shutil.copytree(ASSETS / "screenshots", docs / "assets/screenshots")
    # Website theme (peach.css) + the release-aware download button (download.js),
    # wired up through extra_css/extra_javascript, plus the icon used as logo/favicon.
    if (ASSETS / "website").exists():
        shutil.copytree(ASSETS / "website", docs / "assets/website")
    # Theme overrides, beside mkdocs.yml rather than under docs/: `custom_dir` is resolved relative to
    # the configuration file, and a template staged into the docs tree would also be *published* as a
    # page of the site.
    if (ASSETS / "mkdocs-overrides").exists():
        shutil.copytree(ASSETS / "mkdocs-overrides", work / "overrides")
    if (ASSETS / "peachcommander-icon.png").exists():
        shutil.copy2(ASSETS / "peachcommander-icon.png", docs / "assets")
    # The Mermaid engine, and only for the site that draws diagrams. Material renders the
    # ```mermaid fences itself but fetches the engine from unpkg.com unless a `mermaid` global
    # is already there — so the diagrams used to need a network, on a site whose whole point is
    # to work without one. Vendored (MIT), listed in extra_javascript below, and copied here
    # rather than into docs/assets/website/ because that directory goes to all 19 languages
    # while every one of the 34 fences is English: 3.2 MB of engine, eighteen times, for pages
    # that have no diagram in them.
    if mermaid and (VENDOR / "mermaid/mermaid.min.js").exists():
        (docs / "assets/vendor").mkdir(parents=True, exist_ok=True)
        shutil.copy2(VENDOR / "mermaid/mermaid.min.js", docs / "assets/vendor")
        shutil.copy2(VENDOR / "mermaid/LICENSE", docs / "assets/vendor/mermaid-LICENSE.txt")

    md_files = sorted(sources.rglob("*.md")) if recursive else sorted(sources.glob("*.md"))
    pages = []  # (group, section, order, title, out_name)
    staged: dict[str, Path] = {}
    have_index = False
    for md_path in md_files:
        if md_path.name.startswith("."):
            continue
        meta, body = parse(md_path.read_text(encoding="utf-8"))
        slug = meta.get("slug") or md_path.stem
        is_home = home_from_website and md_path.parent.name == "website" and md_path.stem == "index"
        out_name = "index.md" if is_home else f"{slug}.md"
        # Staging is flat, so two pages with the same slug used to overwrite each other in
        # silence while BOTH kept a nav entry — that is how the user-facing Filesystem Images
        # help page vanished from the site behind the developer page of the same slug, with a
        # green build the whole time. Refuse it instead (F-437).
        if out_name in staged:
            sys.exit(f"slug collision: {md_path.relative_to(REPO)} and {staged[out_name]} both "
                     f"stage as {out_name} — one would silently overwrite the other")
        staged[out_name] = md_path.relative_to(REPO)
        if out_name == "index.md":
            have_index = True
        body = IMG_RE.sub(r"\1assets/screenshots/\2\3", body)
        fm = {k: meta[k] for k in ("title", "description") if k in meta}
        fm_text = "---\n" + yaml.safe_dump(fm, sort_keys=False, allow_unicode=True) + "---\n\n" if fm else ""
        (docs / out_name).write_text(fm_text + body, encoding="utf-8")
        if not is_home:
            # A translated topic carries no `group:` of its own — the key is website-only, so
            # adding it to 918 files would buy nothing the slug parity gate does not already
            # give us. Its English counterpart's group is looked up by slug instead.
            grp = meta.get("group") or (group_by_slug or {}).get(slug)
            pages.append((grp, meta.get("section", "Other"),
                          meta.get("order", 999), meta.get("title", slug), out_name))
    # group -> section -> pages, with anything ungrouped kept on one level as before.
    grouped: dict[str, dict[str, list]] = {}
    flat: dict[str, list] = {}
    for grp, sec, order, title, name in pages:
        entry = (order, title, name)
        if grp:
            grouped.setdefault(grp, {}).setdefault(sec, []).append(entry)
        else:
            flat.setdefault(sec, []).append(entry)

    def by_min_order(bucket: dict[str, list]) -> list[str]:
        return sorted(bucket, key=lambda s: min(o for o, _, _ in bucket[s]))

    nav_lines = ["  - Home: index.md"]
    toc: list[str] = []          # the same structure again, as a page (synthesised index)
    label_warnings: set[str] = set()
    # GROUP_ORDER first and in its stated order; a group nobody listed still appears, at the
    # end and named, rather than disappearing from the site without a word.
    for grp in [g for g in GROUP_ORDER if g in grouped] + sorted(g for g in grouped
                                                                 if g not in GROUP_ORDER):
        secs = grouped[grp]
        label = group_label(grp, secs, lang, label_warnings)
        nav_lines.append(f"  - {label}:")
        toc.append(f"\n## {label}\n")
        if len(secs) == 1:
            # One section in the group: its label would only repeat the tab ("Plugins > Plugins",
            # "Tutorials > Tutorials"), so the pages hang directly off the tab.
            for _, title, name in sorted(next(iter(secs.values()))):
                nav_lines.append(f'    - "{title}": {name}')
                toc.append(f"- [{title}]({name})")
            continue
        for sec in by_min_order(secs):
            nav_lines.append(f"    - {section_label(sec)}:")
            toc.append(f"\n**{section_label(sec)}**\n")
            for _, title, name in sorted(secs[sec]):
                nav_lines.append(f'      - "{title}": {name}')
                toc.append(f"- [{title}]({name})")
    for sec in by_min_order(flat):
        nav_lines.append(f"  - {section_label(sec)}:")
        toc.append(f"\n## {section_label(sec)}\n")
        for _, title, name in sorted(flat[sec]):
            nav_lines.append(f'    - "{title}": {name}')
            toc.append(f"- [{title}]({name})")

    for w in sorted(label_warnings):
        print(f"  ⚠️  {w}")

    # A subsite has no homepage of its own — docs/help-<code>/ holds topics only. It used to get
    # a three-line stub, which is what 17 of the 18 languages had as their front page. Build a
    # real one instead: a lead paragraph taken from that language's own translated introduction
    # (reviewed prose, not something invented here) followed by the same grouping the tabs show.
    if not have_index and synth_title is not None:
        lead = f"{synth_lead}\n" if synth_lead else ""
        # Collapse runs of blank lines rather than tuning every emitted fragment: the group and
        # section headings each carry their own spacing, and where they meet that adds up.
        body: list[str] = []
        for line in "\n".join(toc).split("\n"):
            if line == "" and body and body[-1] == "":
                continue
            body.append(line)
        (docs / "index.md").write_text(
            f"---\ntitle: {synth_title}\n---\n\n# {synth_title}\n\n{lead}"
            + "\n".join(body).strip("\n") + "\n",
            encoding="utf-8")

    # Tabs only where there is a tab bar to show. Turning them on for the flat Help subsites
    # would promote their twelve sections to twelve tabs and change 18 sites nobody asked to
    # change; those keep `navigation.sections` exactly as before.
    features = ["navigation.instant", "navigation.tracking", "navigation.top"]
    features += ["navigation.tabs", "navigation.indexes"] if grouped else ["navigation.sections"]
    features += ["search.suggest", "search.highlight", "content.code.copy", "toc.follow"]

    alt_lines = "\n".join(
        f"    - name: {n}\n      link: {link}\n      lang: {lang}" for n, link, lang in alternate)
    # Order matters and is the reason this is not `defer`: extra_javascript emits classic
    # scripts, which run before DOMContentLoaded, and DOMContentLoaded is when Material mounts
    # the diagram components that look for the global.
    extra_js = ["  - assets/website/download.js"]
    if mermaid and (docs / "assets/vendor/mermaid.min.js").exists():
        extra_js.insert(0, "  - assets/vendor/mermaid.min.js")

    (work / "mkdocs.yml").write_text(
        MKDOCS_YML.format(site_name=site_name, nav="\n".join(nav_lines), alternate=alt_lines,
                          features=", ".join(features), extra_js="\n".join(extra_js),
                          repo_url=REPO_URL, repo_slug=REPO_SLUG),
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


def english_help_groups() -> dict[str, str]:
    """slug -> `group:` for the English help topics.

    The translated subsites hold the same slugs — check-translations.py gates that both ways —
    so this is enough to place a translated topic under the right tab without touching any of
    the 918 translated files.
    """
    out: dict[str, str] = {}
    for md in sorted((CONTENT / "help").glob("*.md")):
        meta, _ = parse(md.read_text(encoding="utf-8"))
        if meta.get("group"):
            out[meta.get("slug") or md.stem] = meta["group"]
    return out


def lead_paragraph(src: Path) -> str:
    """The first real paragraph of a language's `introduction.md`.

    Used as the lead on that language's front page. Deliberately not written here: this is
    prose a translator already produced and reviewed, and inventing a welcome sentence in
    eighteen languages is exactly the kind of text nobody would ever check.
    """
    intro = src / "introduction.md"
    if not intro.exists():
        return ""
    _, body = parse(intro.read_text(encoding="utf-8"))
    for para in (p.strip() for p in body.split("\n\n")):
        if para and not para.startswith(("#", "!", "|", ">", "-", "*", "```")):
            return para
    return ""


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
        sources=CONTENT, recursive=True, home_from_website=True,
        alternate=alt("en", langs), mkdocs=mkdocs, strict=not args.serve, mermaid=True)
    if args.serve:
        subprocess.run([mkdocs, "serve", "-f", str(BUILD / "site-en" / "mkdocs.yml")])
        return

    # Each other language — its translated Help, published under /<code>/.
    results = {"en": (rc_en, out_en, n_en)}
    en_groups = english_help_groups()
    for code, native in langs:
        if code == "en":
            continue
        src = REPO / "docs" / f"help-{code}"
        results[code] = build_one(
            workspace=f"site-{code}", out_dir=SITE / code,
            site_name=f"Peach Commander – {native}",
            sources=src, recursive=False, home_from_website=False,
            alternate=alt(code, langs), mkdocs=mkdocs, strict=True,
            lang=code, group_by_slug=en_groups,
            synth_title=f"Peach Commander – {native}", synth_lead=lead_paragraph(src))

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
