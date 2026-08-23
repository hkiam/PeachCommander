#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check-tests-registered.py — is every test file actually going to run?

A test file that is not in the generated Xcode project compiles nowhere and runs never, and the suite
reports success the whole time. This happened four times in one working session: `ContentFieldValues`,
`ParamExpanderQuoting`, `FinderTagWrite` and `WildcardMask` each sat unexecuted behind a green run until
somebody counted the passing test names.

Two things are checked, both cheap:

  * every `Tests/<Bundle>/…Tests.swift` lies under a bundle the project knows about, and
  * every unit-test bundle is listed in a scheme that `Tools/test.sh` actually runs.

The second is the one that bites hardest, because a bundle can exist as a target, build perfectly, and
still never be run — `PCTagTests` was added to an aggregate target instead of the scheme and behaved
exactly like a bundle that was not there at all.

"A scheme Tools/test.sh runs" is `AllTests` plus `PerfTests`: the benchmarks live in their own scheme
because they are timing assertions and do not belong in the edit-test loop, but they are still run —
by `Tools/test.sh --perf` — so a bundle in that scheme is not orphaned. A bundle in neither is.

It reads `project.yml` through Tools/lib/projectyml.py — the yml is the source, and a stale project
file is itself the failure being guarded against.

Usage: Tools/check-tests-registered.py
"""
from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "lib"))
import projectyml  # noqa: E402  (path set above)

REPO = projectyml.REPO
TESTS = REPO / "Tests"


# The schemes Tools/test.sh runs. A unit-test bundle in neither is compiled and never executed.
RUN_SCHEMES = ("AllTests", "PerfTests")


def main() -> int:
    project = projectyml.load()
    targets, scheme_tests = project.targets, project.scheme_tests

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

    # 2) Every unit-test bundle is in a scheme Tools/test.sh runs.
    for missing in [s for s in RUN_SCHEMES if s not in scheme_tests]:
        print(f"  ⚠️  {missing}: the scheme Tools/test.sh runs is not in project.yml")
        problems += 1
    listed = {name for s in RUN_SCHEMES for name in scheme_tests.get(s, [])}
    for name in targets:
        if targets[name]["type"] != "bundle.unit-test":
            continue
        if name not in listed:
            print(f"  ⚠️  {name}: a unit-test bundle no scheme "
                  f"({', '.join(RUN_SCHEMES)}) runs")
            problems += 1

    print(f"bundles={len(unit_bundles)} test_files={len(list(TESTS.rglob('*.swift')))} problems={problems}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
