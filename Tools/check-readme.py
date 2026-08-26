#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-readme.py — the README's checkable claims, checked.

The README is the first thing anybody reads and the only user-facing document no gate looked at. It
went a week contradicting the in-app help it points at — ZIP64, SFTP attributes and a refresh delay
that had never existed — and nothing went red, because prose has nothing to compare against.

Most of it still has nothing to compare against, and this does not pretend otherwise: it makes no
attempt to judge a sentence. What it checks is every claim with a machine-readable counterpart, which
turns out to be most of the ones that rot:

  * links and images resolve, and an in-page anchor matches a real heading
  * the languages badge, and the list of language names, agree with docs/metadata/languages.yml
  * every plugin named in the plugin table exists under Plugins/
  * the platform badge's minimum macOS version matches project.yml's deploymentTarget

A claim that cannot be checked is left alone rather than approximated. The value here is that the
list of *facts* stops drifting; the prose around them is still a human's job.

Usage: Tools/check-readme.py
"""
import os
import re
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
README = os.path.join(ROOT, "README.md")
LANGUAGES = os.path.join(ROOT, "docs/metadata/languages.yml")
PROJECT = os.path.join(ROOT, "project.yml")


def read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def anchor_of(heading):
    """GitHub's slug: lowercase, punctuation dropped, spaces to hyphens. Emoji leave a stray
    hyphen behind, which is why '## 🗺️ Roadmap' anchors as '#-roadmap' and not '#roadmap'."""
    text = heading.rstrip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return "#" + re.sub(r"\s", "-", text)


def check_links(text, problems):
    targets = re.findall(r"\]\(([^)]+)\)", text) + re.findall(r'src="([^"]+)"', text)
    headings = {anchor_of(h) for h in re.findall(r"^#{1,6}\s+(.+)$", text, re.M)}
    for target in sorted(set(targets)):
        if target.startswith(("http://", "https://", "mailto:")):
            continue
        if target.startswith("#"):
            if target not in headings:
                problems.append(f"anchor {target!r} matches no heading")
            continue
        path = urllib.parse.unquote(target.split("#", 1)[0])
        if path and not os.path.exists(os.path.join(ROOT, path)):
            problems.append(f"link/image {path!r} does not exist")


def shipped_languages():
    """(code, native name) for every language the app ships."""
    out = []
    for line in read(LANGUAGES).splitlines():
        match = re.match(r'\s*-\s*\{?\s*code:\s*"?([\w-]+)"?.*native:\s*"?([^,}"]+)"?', line)
        if match:
            out.append((match.group(1), match.group(2).strip()))
    return out


def check_languages(text, problems):
    languages = shipped_languages()
    if not languages:
        problems.append("could not read docs/metadata/languages.yml")
        return

    badge = re.search(r"badge/languages-(\d+)-", text)
    if not badge:
        problems.append("no languages badge found")
    elif int(badge.group(1)) != len(languages):
        problems.append(f"languages badge says {badge.group(1)}, languages.yml has {len(languages)}")

    line = re.search(r"\*\*(\d+) interface languages:\*\*\s*([^—\n]+)", text)
    if not line:
        problems.append("no 'N interface languages:' line found")
        return
    if int(line.group(1)) != len(languages):
        problems.append(f"the interface-languages line says {line.group(1)}, "
                        f"languages.yml has {len(languages)}")
    listed = {name.strip() for name in line.group(2).split(",") if name.strip()}
    expected = {native for _, native in languages}
    for missing in sorted(expected - listed):
        problems.append(f"language {missing!r} ships but is not listed in the README")
    for extra in sorted(listed - expected):
        problems.append(f"the README lists language {extra!r}, which does not ship")


def check_plugins(text, problems):
    """Every plugin the table names must exist. The table's display names have spaces the
    directories do not ('Disk Map' is Plugins/Treemap), so a name is accepted when it matches a
    directory with the spaces removed, or is listed here as a deliberate alias."""
    aliases = {"Disk Map": "Treemap", "AI Assistant": "AIAssistant", "Archive formats": "Archive",
               "iCloud": "ICloud", "Filesystem Images": "FSImage", "AI On-Device": "AILocal"}
    present = set(os.listdir(os.path.join(ROOT, "Plugins")))
    for row in re.findall(r"^\|\s*(\*\*.+?\*\*(?:\s*·\s*\*\*.+?\*\*)*)\s*\|", text, re.M):
        for name in re.findall(r"\*\*(.+?)\*\*", row):
            directory = aliases.get(name, name.replace(" ", ""))
            if directory not in present:
                problems.append(f"the plugin table names {name!r}, but Plugins/{directory} "
                                f"does not exist")


def check_platform(text, problems):
    badge = re.search(r"badge/platform-macOS%20(\d+)%2B-", text)
    target = re.search(r'deploymentTarget:\s*"(\d+)', read(PROJECT))
    if not badge:
        problems.append("no platform badge found")
    elif target and badge.group(1) != target.group(1):
        problems.append(f"the platform badge says macOS {badge.group(1)}+, "
                        f"project.yml builds for {target.group(1)}")


def main():
    text = read(README)
    problems = []
    check_links(text, problems)
    check_languages(text, problems)
    check_plugins(text, problems)
    check_platform(text, problems)

    for problem in problems:
        print(f"  ✗ README: {problem}")
    print(f"checked=README.md problems={len(problems)}")
    if problems:
        print("The README is the first thing anybody reads; these are its checkable claims.",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
