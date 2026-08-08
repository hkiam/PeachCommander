#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-tests-registered.py — is every test file actually going to run?

A test file that is not in the generated Xcode project compiles nowhere and runs never, and the suite
reports success the whole time. This happened four times in one working session: `ContentFieldValues`,
`ParamExpanderQuoting`, `FinderTagWrite` and `WildcardMask` each sat unexecuted behind a green run until
somebody counted the passing test names.

Two things are checked, both cheap:

  * every `Tests/<Bundle>/…Tests.swift` lies under a bundle the project knows about, and
  * every unit-test bundle is listed in the `AllTests` scheme.

The second is the one that bites hardest, because a bundle can exist as a target, build perfectly, and
still never be run — `PCTagTests` was added to an aggregate target instead of the scheme and behaved
exactly like a bundle that was not there at all.

This reads `project.yml`, not the generated `.xcodeproj`: the yml is the source, and a stale project file
is itself the failure being guarded against.

Usage: Tools/check-tests-registered.py
"""
from __future__ import annotations

import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
PROJECT = REPO / "project.yml"
TESTS = REPO / "Tests"


def read_project() -> tuple[dict[str, dict], list[str]]:
    """(targets, AllTests scheme test targets) from project.yml, without a YAML library.

    Deliberately dependency-free. The first version imported pyyaml, which the CI image does not have
    and — being an externally managed Python — will not install; a gate that fails because of its own
    dependency is worse than no gate, because the first fix anyone reaches for is deleting it.

    Only what is needed is parsed: a target's `type`, its `sources` paths, and the list under the
    AllTests scheme's `test: targets:`. Verified against the pyyaml reading of the same file.
    """
    targets: dict[str, dict] = {}
    scheme_tests: list[str] = []

    section = None          # "targets" | "schemes" | None
    target = None           # current target name
    in_sources = False
    in_alltests = False
    in_scheme_test_targets = False
    scheme = None

    for raw in PROJECT.read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()

        if indent == 0:
            section = line[:-1] if line.endswith(":") else None
            target = scheme = None
            in_sources = in_alltests = in_scheme_test_targets = False
            continue

        if section == "targets":
            if indent == 2 and line.endswith(":"):
                target = line[:-1]
                targets[target] = {"type": "", "sources": []}
                in_sources = False
            elif target:
                if indent == 4 and line.startswith("type:"):
                    targets[target]["type"] = line.split(":", 1)[1].strip()
                    in_sources = False
                elif indent == 4 and line == "sources:":
                    in_sources = True
                elif indent == 4:
                    in_sources = False
                elif in_sources and line.startswith("- "):
                    value = line[2:].strip()
                    m = re.match(r"path:\s*(.+)$", value)
                    targets[target]["sources"].append((m.group(1) if m else value).strip())
        elif section == "schemes":
            if indent == 2 and line.endswith(":"):
                scheme = line[:-1]
                in_alltests = scheme == "AllTests"
                in_scheme_test_targets = False
            elif in_alltests:
                if line == "targets:":
                    in_scheme_test_targets = True
                elif line.endswith(":") and not line.startswith("- "):
                    # `build:`/`test:` and their keys; only the list under `test:` matters, and it is
                    # the one that follows `targets:` at the deepest level.
                    in_scheme_test_targets = False
                elif in_scheme_test_targets and line.startswith("- "):
                    scheme_tests.append(line[2:].strip())
    return targets, scheme_tests


def main() -> int:
    targets, listed_names = read_project()

    # Bundles the project defines, and the directories each of them compiles.
    unit_bundles: dict[str, list[str]] = {
        name: target["sources"] for name, target in targets.items()
        if target["type"].startswith("bundle.")
    }

    problems = 0

    # 1) Every test file lives under a directory some bundle compiles.
    compiled_dirs = {pathlib.Path(s) for paths in unit_bundles.values() for s in paths}
    for path in sorted(TESTS.rglob("*.swift")):
        rel = path.relative_to(REPO)
        if not any(rel == d or d in rel.parents for d in compiled_dirs):
            print(f"  ⚠️  {rel}: in no test bundle — it will never be compiled or run")
            problems += 1

    # 2) Every unit-test bundle is in the AllTests scheme.
    listed = set(listed_names)
    for name in targets:
        if targets[name]["type"] != "bundle.unit-test":
            continue
        if name not in listed:
            print(f"  ⚠️  {name}: a unit-test bundle that the AllTests scheme does not run")
            problems += 1

    print(f"bundles={len(unit_bundles)} test_files={len(list(TESTS.rglob('*.swift')))} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
