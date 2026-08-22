#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-nav-order.py — does the website still open where a newcomer can start?

The site's navigation used to be an accident. `build-site.py` derives it from front matter:
`section:` groups the pages, and a section ranked by the *lowest* `order:` among its pages.
Four sections tied at `order: 10`, the tie fell to alphabetical directory order — so
`developer-guide/` outranked `help/` — and the API reference won the whole thing outright
because its generator wrote `order: 5`, the smallest number in the corpus. The result:
**API reference** and **Developer guide** were the first two entries on a documentation site,
and *Getting started* was third. Nobody decided that, nothing was broken, every job was green.

F-437 replaced the top level with an explicit `group:` key and the GROUP_ORDER list in
`build-site.py`. That removes the old failure mode but adds two quiet new ones, and this gate
is here for those:

  1. A page with no `group:` does not vanish and does not fail the build — it falls into the
     one-level fallback that the translated Help subsites rely on, and appears as a stray
     top-level entry *after* all seven tabs. On a site with 88 pages nobody would notice.
  2. A typo'd or invented group name silently becomes an eighth tab, appended at the end.

Plus the rule the whole restructure exists for, stated in the reader's terms rather than as a
number: **the first tab is where you start, the last tab is the deep end.** If a future edit
moves Develop to the front, that is exactly the regression F-437 fixed, and it should be loud.

The translated Help subsites carry no `group:` of their own — build-site.py places a
translated topic by looking up its English counterpart's group by slug, and labels the tab
from the translated `section:` where a group holds exactly one section. That makes two more
things checkable, and both were broken when it was written (F-439):

  3. A group that is one section in English must be one section in every language, or its tab
     cannot be labelled from the translation and falls back to the English id. Sixteen of the
     eighteen languages had the plugin help split in two — seven topics under the translated
     word, six left under the English "Plugins" — so those readers saw a stray English section
     in the shipped in-app help, and nothing anywhere noticed.
  4. An umbrella group (more than one section) needs a label per language in
     docs/metadata/nav-groups.yml, or the tab shows the English id.

Usage: docs/scripts/check-nav-order.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = Path(__file__).resolve().parents[2]
CONTENT = REPO / "docs/content"
FRONT_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)

# The reader's contract, not an implementation detail: whatever the tabs end up being called,
# the newcomer's entry point comes first and the API/SDK end comes last.
FIRST_GROUP = "Get started"
LAST_GROUP = "Develop"


def group_order() -> list[str]:
    """GROUP_ORDER as build-site.py declares it — read, not duplicated.

    Parsed rather than imported: build-site.py runs work at import time only under
    `main()`, but importing it would still pull in its module-level paths, and a checker
    that cannot run without the thing it checks is a checker that gets skipped.
    """
    src = (REPO / "docs/scripts/build-site.py").read_text(encoding="utf-8")
    m = re.search(r"^GROUP_ORDER = \[(.*?)^\]", src, re.S | re.M)
    if not m:
        sys.exit("check-nav-order.py: GROUP_ORDER not found in build-site.py — "
                 "the nav model changed and this check needs updating with it")
    return re.findall(r'"([^"]+)"', m.group(1))


def front_matter(md: Path) -> dict:
    m = FRONT_RE.match(md.read_text(encoding="utf-8"))
    return (yaml.safe_load(m.group(1)) if m else {}) or {}


def english_help() -> tuple[dict, dict]:
    """(slug -> group, group -> set of English sections) for the topics the subsites mirror."""
    by_slug, sections = {}, {}
    for md in sorted((CONTENT / "help").glob("*.md")):
        meta = front_matter(md)
        grp = meta.get("group")
        if not grp:
            continue
        by_slug[meta.get("slug") or md.stem] = grp
        sections.setdefault(grp, set()).add(meta.get("section"))
    return by_slug, sections


def umbrella_labels() -> dict[str, dict[str, str]]:
    ymlp = REPO / "docs/metadata/nav-groups.yml"
    if not ymlp.exists():
        return {}
    data = yaml.safe_load(ymlp.read_text(encoding="utf-8")) or {}
    return {g["id"]: (g.get("labels") or {}) for g in (data.get("groups") or [])}


def check_translated_labels() -> int:
    """Can every tab on every translated subsite be given a name in that language?"""
    by_slug, en_sections = english_help()
    labels = umbrella_labels()
    problems = 0
    for hdir in sorted(REPO.glob("docs/help-*")):
        code = hdir.name[len("help-"):]
        per_group: dict[str, set] = {}
        for md in sorted(hdir.glob("*.md")):
            if md.name.startswith("."):
                continue
            grp = by_slug.get(front_matter(md).get("slug") or md.stem)
            if grp:
                per_group.setdefault(grp, set()).add(front_matter(md).get("section"))
        for grp, secs in sorted(per_group.items()):
            english_secs = en_sections.get(grp, set())
            if len(english_secs) == 1 and len(secs) > 1:
                print(f"docs/help-{code}: group '{grp}' is one section in English but "
                      f"{len(secs)} here ({', '.join(sorted(map(str, secs)))}) — its tab cannot "
                      f"be named from the translation and one of those sections shows up "
                      f"untranslated (F-439)")
                problems += 1
            elif len(english_secs) > 1 and not labels.get(grp, {}).get(code):
                print(f"docs/metadata/nav-groups.yml: no '{code}' label for umbrella group "
                      f"'{grp}' — its tab would show the English id (F-439)")
                problems += 1
    return problems


def main() -> int:
    groups = group_order()
    problems = 0
    pages = 0

    if not groups:
        print("build-site.py: GROUP_ORDER is empty — every page would fall back to the "
              "flat one-level nav")
        problems += 1
    else:
        if groups[0] != FIRST_GROUP:
            print(f"build-site.py: the first tab is '{groups[0]}', expected '{FIRST_GROUP}' — "
                  f"the first thing a visitor sees should be where they can start (F-437)")
            problems += 1
        if groups[-1] != LAST_GROUP:
            print(f"build-site.py: the last tab is '{groups[-1]}', expected '{LAST_GROUP}' — "
                  f"the API/SDK end belongs behind everything a user needs (F-437)")
            problems += 1

    known = set(groups)
    for path in sorted(CONTENT.rglob("*.md")):
        if path.name.startswith("."):
            continue
        meta = front_matter(path)
        rel = path.relative_to(REPO)
        # The homepage is the site root, not a nav entry — build-site.py and check-docs.py
        # both exempt it the same way.
        if path.parent.name == "website" and path.stem == "index":
            continue
        pages += 1
        grp = meta.get("group")
        if not grp:
            print(f"{rel}: no front-matter 'group' — it would land outside the tabs as a "
                  f"stray top-level nav entry (F-437)")
            problems += 1
        elif grp not in known:
            print(f"{rel}: group '{grp}' is not in build-site.py's GROUP_ORDER — it would "
                  f"appear as an extra tab, appended after the others (F-437)")
            problems += 1

    if pages == 0:
        print("found no content pages at all — this check has stopped checking anything")
        problems += 1

    problems += check_translated_labels()

    print(f"pages={pages} groups={len(groups)} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
