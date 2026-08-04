#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-inventory.py — does the parity catalogue still tell the truth?

`docs/product/feature-inventory.md` is the list the next piece of work is chosen from, and it had gone
stale in the most expensive direction: of eighteen rows marked `todo`, sixteen were implemented — one of
them (multimedia playback) complete with an `AVPlayerView`. A catalogue that says "not built" about built
things sends somebody to build it twice.

Statuses alone cannot be checked mechanically. A *pointer* can, so a row may carry evidence in its Notes
cell and this verifies that each pointer resolves:

    ev: cm_SrcTree              a command in the registry (PCCommands.swift) — i.e. reachable by the user
    ev: test:SyncModelTests     a test class that exists
    ev: symbol:AVPlayerView     a symbol that appears in Sources/
    ev: plugin:WebDAV           a plugin directory under Plugins/
    ev: scenario:tree-view      a scenario in Tools/vm/regress.py

An unresolvable pointer fails the run: that is a claim about the code that the code contradicts. Rows with
no evidence are counted and listed, not failed — most of the catalogue predates this and retrofitting all
of it in one go would be worse than doing it as rows are touched.

Usage:
    Tools/check-inventory.py [--list-unverified]
"""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
INVENTORY = REPO / "docs/product/feature-inventory.md"
REGISTRY = REPO / "Sources/PCCommands/PCCommands.swift"
STUBS = REPO / "Sources/PCCommands/CommandStubs.swift"
SCENARIOS = REPO / "Tools/vm/regress.py"

ROW_START = re.compile(r"^\|\s*(F-\d+)\s*\|")
EVIDENCE = re.compile(r"ev:\s*([A-Za-z0-9_:.\-]+)")


def parse_row(line: str):
    """(id, notes, status) for a catalogue row, or None if the line is not one.

    Split rather than matched: a cell may contain a `|` inside backticks, and the n/a-macos sections use
    a shorter table. The first version required exactly seven columns and *silently skipped* seven rows —
    the same kind of quiet omission this script exists to catch, so anything unparsable is now reported.
    """
    if not ROW_START.match(line):
        return None
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    if len(cells) < 3:
        return None
    # Status is always the last cell; the notes are everything between the feature and the trailing
    # spec/iter/prio triple when that is present, else the single cell after the feature.
    fid, status = cells[0], cells[-1]
    notes = " ".join(cells[2:-4]) if len(cells) >= 7 else " ".join(cells[1:-1])
    return fid, notes, status


def known_commands() -> set:
    names = set()
    for path in (REGISTRY, STUBS):
        if path.exists():
            names |= set(re.findall(r'name:\s*"(cm_[A-Za-z0-9]+)"', path.read_text(encoding="utf-8")))
            names |= set(re.findall(r'"(cm_[A-Za-z0-9]+)"', path.read_text(encoding="utf-8")))
    return names


def test_classes() -> set:
    names = set()
    for path in (REPO / "Tests").rglob("*.swift"):
        names |= set(re.findall(r"final class (\w+): XCTestCase", path.read_text(encoding="utf-8")))
    return names


def scenario_names() -> set:
    if not SCENARIOS.exists():
        return set()
    return set(re.findall(r'^\s*\("([a-z0-9-]+)",\s*\[', SCENARIOS.read_text(encoding="utf-8"), re.M))


def source_text() -> str:
    return "\n".join(p.read_text(encoding="utf-8", errors="ignore")
                     for p in (REPO / "Sources").rglob("*.swift"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-unverified", action="store_true",
                    help="print every done row that carries no evidence")
    args = ap.parse_args()

    commands, tests, scenarios = known_commands(), test_classes(), scenario_names()
    sources = source_text()
    plugins = {p.name for p in (REPO / "Plugins").iterdir() if p.is_dir()}

    problems, unverified, verified = [], [], 0
    rows = 0
    for line in INVENTORY.read_text(encoding="utf-8").splitlines():
        if not ROW_START.match(line):
            continue
        parsed = parse_row(line)
        if parsed is None:
            problems.append(f"unparsable catalogue row: {line.strip()[:70]}")
            continue
        rows += 1
        fid, notes, status = parsed
        tokens = EVIDENCE.findall(notes)
        if not tokens:
            if status == "done":
                unverified.append(fid)
            continue
        for token in tokens:
            kind, _, value = token.partition(":")
            if not value:                      # a bare cm_ name
                kind, value = "command", token
            checks = {"command": lambda v: v in commands,
                      "test": lambda v: v in tests,
                      "symbol": lambda v: v in sources,
                      "plugin": lambda v: v in plugins,
                      "scenario": lambda v: v in scenarios}
            if kind not in checks:
                problems.append(f"{fid}: unknown evidence kind {kind!r} in {token!r}")
                continue
            ok = checks[kind](value)
            if ok:
                verified += 1
            else:
                problems.append(f"{fid}: evidence {token!r} does not resolve "
                                f"({'no such ' + kind})")

    for line in problems:
        print(f"  ⚠️  {line}")
    if args.list_unverified and unverified:
        print("  done rows without evidence: " + ", ".join(unverified))
    print(f"rows={rows} evidence_ok={verified} problems={len(problems)} "
          f"done_without_evidence={len(unverified)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
