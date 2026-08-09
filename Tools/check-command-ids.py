#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-command-ids.py — are the command names and ids unique, and do they stay put? (F-250)

Every action in this app has a name (`cm_*`) and a numeric id, and both are part of its interface:
a toolbar button, a keyboard mapping and a `.bar` file all refer to a command by one or the other,
and Total Commander's own numbering is what makes an imported button bar do the right thing.

"Stable" was the claim and nothing checked it. Two ways it can break:

  * **A collision.** The registry stores commands in a dictionary keyed by id, so registering two with
    the same id keeps one and drops the other. `register` calls `assertionFailure`, which is compiled
    out of a release build — and the unit test that looked like it covered this could not fail, because
    it counted the ids *after* the dictionary had already collapsed them.
  * **A renumbering.** Changing an existing command's id is invisible in every test and silently makes
    somebody's toolbar button invoke a different action.

So this reads the source rather than the registry, and compares the result against
`docs/metadata/command-ids.json`: an existing name must keep its id, and a name must not vanish.
Adding commands is free. Run with `--update` after a deliberate change.

Usage: Tools/check-command-ids.py [--update]
"""
from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
SOURCE = REPO / "Sources/PCCommands/PCCommands.swift"
STUBS = REPO / "Sources/PCCommands/CommandStubs.swift"
STUB_BASE = 50000   # CommandStubs numbers its placeholders from here, by position
PINNED = REPO / "docs/metadata/command-ids.json"

# `static let cm_X = PCCommand(` on one line or spread over several; the id and the name follow within
# the same call. Both spellings are in the file and neither is wrong, so both are read.
DEFINITION = re.compile(r"static\s+let\s+(cm_\w+)\s*=\s*PCCommand\(", re.M)
ID = re.compile(r"\bid:\s*(\d+)")
NAME = re.compile(r'\bname:\s*"([^"]+)"')


def commands() -> dict[str, int]:
    """{name: id} as the source defines them."""
    text = SOURCE.read_text(encoding="utf-8")
    found: dict[str, int] = {}
    problems = 0
    for match in DEFINITION.finditer(text):
        # The call's arguments, up to the closing of the initializer. 600 characters is well past the
        # longest definition in the file and stops the search running into the next one.
        window = text[match.end():match.end() + 600]
        id_match, name_match = ID.search(window), NAME.search(window)
        if not id_match or not name_match:
            print(f"  ⚠️  {match.group(1)}: could not read its id or name")
            problems += 1
            continue
        found[name_match.group(1)] = int(id_match.group(1))
    if problems:
        sys.exit(problems)
    return found


def stub_commands() -> list[str]:
    """The placeholder command names, in the order CommandStubs registers them.

    Their ids are *positional* — `50000 + index` — so inserting a name in the middle renumbers every
    one after it. That is tolerable only because nothing refers to a command by number: the keyboard
    schemes, the menus and the AI's `run_command` all use the name. What is not tolerable is the block
    running into the real ids, which is checked below; a placeholder landing on a real command's number
    would replace it in the registry, and the assertion that would have caught it is compiled out of a
    release build.
    """
    text = STUBS.read_text(encoding="utf-8")
    start = text.index("stubCommandList")
    return re.findall(r'\(\s*"(cm_\w+)"\s*,', text[start:])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--update", action="store_true",
                        help="write the current ids to docs/metadata/command-ids.json")
    args = parser.parse_args()

    found = commands()
    problems = 0

    # The source defines each name once (Swift would not compile otherwise), so a duplicate *name*
    # cannot happen here — but a duplicate id can, and that is the one the registry hides.
    by_id = collections.Counter(found.values())
    for cid, count in sorted(by_id.items()):
        if count > 1:
            clash = sorted(n for n, i in found.items() if i == cid)
            print(f"  ⚠️  id {cid} is used by {count} commands: {', '.join(clash)}")
            print("        the registry keys on the id, so all but one would be dropped")
            problems += 1

    for name in sorted(found):
        if not name.startswith("cm_"):
            print(f"  ⚠️  {name}: a command name must start with cm_")
            problems += 1

    # The placeholders: their names share one namespace with the real commands, and their ids share one
    # dictionary. Either kind of collision silently loses a command.
    stubs = stub_commands()
    stub_ids = {name: STUB_BASE + index for index, name in enumerate(stubs)}
    for name, count in collections.Counter(stubs).items():
        if count > 1:
            print(f"  ⚠️  {name}: listed {count} times among the placeholders")
            problems += 1
    for name in sorted(set(stubs) & set(found)):
        print(f"  ⚠️  {name}: exists as a real command *and* as a placeholder — one replaces the other")
        problems += 1
    overlap = sorted(set(stub_ids.values()) & set(found.values()))
    if overlap:
        print(f"  ⚠️  placeholder ids collide with real command ids: {overlap}")
        problems += 1

    if args.update:
        PINNED.write_text(json.dumps(found, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"pinned {len(found)} command ids to {PINNED.relative_to(REPO)}")
        return 0

    if not PINNED.exists():
        print(f"  ⚠️  {PINNED.relative_to(REPO)} is missing — run with --update to create it")
        return 1

    pinned = json.loads(PINNED.read_text(encoding="utf-8"))
    for name, cid in sorted(pinned.items()):
        if name not in found:
            print(f"  ⚠️  {name} (id {cid}) is gone — a name in a .bar file or a keymap now resolves to nothing")
            problems += 1
        elif found[name] != cid:
            print(f"  ⚠️  {name}: id changed {cid} → {found[name]} — anything referring to it by number "
                  f"now invokes something else")
            problems += 1

    added = sorted(set(found) - set(pinned))
    print(f"commands={len(found)} placeholders={len(stubs)} pinned={len(pinned)} "
          f"new={len(added)} problems={problems}")
    if added:
        print("  new since the pin (fine; run --update to record them): " + ", ".join(added))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
