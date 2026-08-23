#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""affected-tests.py — which test bundles can a set of changes possibly break?

The full suite is the thing you run before you commit, not the thing you run after every edit.
Between those two points most changes can only affect a handful of bundles, and this works out
which — from `project.yml`'s own dependency graph, not from a hand-kept table that would rot.

Four rules, in order of how much they narrow things down:

  * a change under `Tests/<Bundle>/` affects that bundle;
  * a change under a target's `sources:` affects every test bundle whose dependency closure
    contains that target — so touching PCFoundation still means almost everything, honestly;
  * a change under `Plugins/<Name>/` affects the bundles that name that directory, because the
    plugin tests compile the real plugin sources and plugins are not Xcode targets (there is no
    dependency edge to follow, so the reference in the test source is the edge);
  * anything else — project.yml, Tools/, Resources/, CI, the SDK package — affects everything,
    because a build-setting or fixture-generator change can reach any bundle at all.

The last rule is what keeps this safe to use: it does not try to be clever about files it does not
recognise, it gives up and says everything. A narrower answer that is wrong costs a green run on
broken code, which is the one outcome worth spending whole minutes to avoid.

A bundle is only ever named if the scheme that will run it contains it: the benchmarks live in
`PerfTests` and naming them to an `AllTests` run is not a narrower answer, it is xcodebuild refusing
to start ("isn't a member of the specified test plan or scheme").

Usage:
  Tools/affected-tests.py                 # uncommitted work: working tree + index vs HEAD
  Tools/affected-tests.py --since main    # everything accumulated since a branch point
  Tools/affected-tests.py --files a b c   # an explicit list, for testing this script
  Tools/affected-tests.py --scheme AllTests   # only bundles that scheme runs
  Tools/affected-tests.py --explain       # also say, per bundle, what pulled it in

Prints one bundle name per line, or the single word ALL.
"""
from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "lib"))
import projectyml  # noqa: E402  (path set above)

REPO = projectyml.REPO

# Directories whose contents map to a bundle by one of the narrow rules. Everything outside them
# means ALL — see the module docstring.
NARROW_ROOTS = ("Tests/", "Sources/", "Plugins/")


def changed_files(since: str | None) -> list[str]:
    """Repo-relative paths that differ, including staged, unstaged and untracked."""
    if since:
        out = git("diff", "--name-only", f"{since}...HEAD") + git("diff", "--name-only", "HEAD")
    else:
        out = git("diff", "--name-only", "HEAD")
    out += git("ls-files", "--others", "--exclude-standard")
    return sorted({line for line in out if line})


def git(*args: str) -> list[str]:
    result = subprocess.run(["git", "-C", str(REPO), *args],
                            capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.splitlines()


def plugin_directories_named_by(bundle_sources: list[str]) -> set[str]:
    """The `Plugins/<Name>/` directories a bundle's own sources mention.

    Read out of the test sources rather than configured, because that reference *is* the
    dependency: a plugin is a swiftc invocation in a shell script, so nothing in project.yml
    records that PCPluginHostTests compiles Plugins/S3.
    """
    named: set[str] = set()
    for entry in bundle_sources:
        root = REPO / entry
        files = root.rglob("*.swift") if root.is_dir() else [root]
        for file in files:
            if not file.is_file():
                continue
            text = file.read_text(encoding="utf-8", errors="ignore")
            for part in text.split('"Plugins/')[1:]:
                name = part.split("/")[0].split('"')[0]
                if name:
                    named.add(f"Plugins/{name}")
    return named


def under(path: str, directory: str) -> bool:
    return path == directory or path.startswith(directory.rstrip("/") + "/")


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--since", metavar="REF",
                        help="changes since REF, not just uncommitted ones")
    parser.add_argument("--files", nargs="*", metavar="PATH",
                        help="use these paths instead of asking git")
    parser.add_argument("--scheme", metavar="NAME",
                        help="restrict the answer to bundles this scheme's test action runs")
    parser.add_argument("--explain", action="store_true",
                        help="print why each bundle was selected, to stderr")
    args = parser.parse_args()

    project = projectyml.load()
    bundles = project.test_bundles()
    if args.scheme:
        if args.scheme not in project.scheme_tests:
            raise SystemExit(f"no scheme called {args.scheme} in project.yml")
        runnable = set(project.scheme_tests[args.scheme])
        bundles = {n: b for n, b in bundles.items() if n in runnable}
    files = args.files if args.files is not None else changed_files(args.since)

    if not files:
        return 0  # nothing changed: nothing to run

    unrecognised = [f for f in files if not any(under(f, r) for r in NARROW_ROOTS)]
    if unrecognised:
        if args.explain:
            print(f"ALL: {unrecognised[0]} is outside Tests/, Sources/ and Plugins/", file=sys.stderr)
        print("ALL")
        return 0

    # Which project targets each changed file belongs to, by the sources each target compiles.
    touched_targets: set[str] = set()
    for path in files:
        for name, target in project.targets.items():
            if any(under(path, source) for source in target["sources"]):
                touched_targets.add(name)

    selected: dict[str, str] = {}
    for name, bundle in bundles.items():
        closure = project.dependency_closure(name)
        hit = sorted(closure & touched_targets)
        if hit:
            selected[name] = f"depends on {', '.join(hit)}"
            continue
        plugin_dirs = plugin_directories_named_by(bundle["sources"])
        for path in files:
            if any(under(path, d) for d in plugin_dirs):
                selected[name] = f"compiles {path}"
                break

    # A changed file that belongs to no target at all is a file nothing compiles — but it may be a
    # fixture, a plugin source no bundle names, or a source someone forgot to register. Any of those
    # can change behaviour, so widen rather than guess.
    orphans = [f for f in files
               if not any(under(f, s) for t in project.targets.values() for s in t["sources"])
               and not any(under(f, d) for n in bundles
                           for d in plugin_directories_named_by(bundles[n]["sources"]))]
    if orphans:
        if args.explain:
            print(f"ALL: {orphans[0]} belongs to no target and no plugin any bundle compiles",
                  file=sys.stderr)
        print("ALL")
        return 0

    for name in sorted(selected):
        if args.explain:
            print(f"{name}: {selected[name]}", file=sys.stderr)
        print(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
