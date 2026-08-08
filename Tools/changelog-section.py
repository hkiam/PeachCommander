#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""changelog-section.py — the CHANGELOG entry for one version, for use as release notes.

The release workflow used `generate_release_notes`, which produces a list of commit subjects. That is a
record of what was done, not a description of what changed for the person downloading it — and this
project keeps the second one in CHANGELOG.md already.

Usage:
    Tools/changelog-section.py v0.4.0            # or 0.4.0
    Tools/changelog-section.py v0.4.0 --out notes.md

Exits non-zero if the version has no section, so a release cannot quietly ship with empty notes.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
CHANGELOG = REPO / "CHANGELOG.md"


def section(version: str) -> str | None:
    """The body under `## [<version>] — …`, up to the next `## ` heading."""
    lines = CHANGELOG.read_text(encoding="utf-8").split("\n")
    start = None
    for index, line in enumerate(lines):
        if re.match(rf"^##\s+\[{re.escape(version)}\]", line):
            start = index + 1
            break
    if start is None:
        return None
    end = len(lines)
    for index in range(start, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    return "\n".join(lines[start:end]).strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("version", help="v0.4.0 or 0.4.0")
    parser.add_argument("--out", help="write here instead of stdout")
    args = parser.parse_args()

    version = args.version.lstrip("v")
    body = section(version)
    if not body:
        print(f"no CHANGELOG section for {version} — add one before tagging", file=sys.stderr)
        return 1
    if args.out:
        pathlib.Path(args.out).write_text(body + "\n", encoding="utf-8")
    else:
        print(body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
