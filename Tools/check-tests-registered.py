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
import sys

try:
    import yaml
except ImportError:                                  # noqa: BLE001 — a clear message beats a traceback
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = pathlib.Path(__file__).resolve().parents[1]
PROJECT = REPO / "project.yml"
TESTS = REPO / "Tests"


def main() -> int:
    spec = yaml.safe_load(PROJECT.read_text(encoding="utf-8"))
    targets = spec.get("targets", {})

    # Bundles the project defines, and the directories each of them compiles.
    unit_bundles: dict[str, list[str]] = {}
    for name, target in targets.items():
        if not str(target.get("type", "")).startswith("bundle."):
            continue
        sources = []
        for entry in target.get("sources", []):
            sources.append(entry["path"] if isinstance(entry, dict) else entry)
        unit_bundles[name] = sources

    problems = 0

    # 1) Every test file lives under a directory some bundle compiles.
    compiled_dirs = {pathlib.Path(s) for paths in unit_bundles.values() for s in paths}
    for path in sorted(TESTS.rglob("*.swift")):
        rel = path.relative_to(REPO)
        if not any(rel == d or d in rel.parents for d in compiled_dirs):
            print(f"  ⚠️  {rel}: in no test bundle — it will never be compiled or run")
            problems += 1

    # 2) Every unit-test bundle is in the AllTests scheme.
    scheme = spec.get("schemes", {}).get("AllTests", {})
    listed = set(scheme.get("test", {}).get("targets", []))
    for name, target in targets.items():
        if targets[name].get("type") != "bundle.unit-test":
            continue
        if name not in listed:
            print(f"  ⚠️  {name}: a unit-test bundle that the AllTests scheme does not run")
            problems += 1

    print(f"bundles={len(unit_bundles)} test_files={len(list(TESTS.rglob('*.swift')))} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
