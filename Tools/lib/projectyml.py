#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""projectyml.py — read project.yml without a YAML library.

Deliberately dependency-free. The first version of `check-tests-registered.py` imported pyyaml,
which the CI image does not have and — being an externally managed Python — will not install; a
gate that fails because of its own dependency is worse than no gate, because the first fix anyone
reaches for is deleting it.

This lives here rather than inside one script because two scripts now need the same reading, and
two hand-rolled parsers of one file is precisely the drift the gates in this directory exist to
catch. It reads `project.yml`, not the generated `.xcodeproj`: the yml is the source, and a stale
project file is itself a failure being guarded against.

Understands only as much of the format as this project uses:

  targets:
    <Name>:
      type: …
      sources:                      # `- path/to/dir` or `- path: path/to/file`
      dependencies:                 # `- target: <Name>` (packages and frameworks are ignored)
  schemes:
    <Name>:
      test:
        targets:                    # `- <Name>` or `- name: <Name>` plus its settings
"""
from __future__ import annotations

import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[2]
PROJECT = REPO / "project.yml"


class Project:
    def __init__(self, targets: dict[str, dict], scheme_tests: dict[str, list[str]]):
        self.targets = targets
        self.scheme_tests = scheme_tests

    def test_bundles(self) -> dict[str, dict]:
        """Every unit-test bundle, by name."""
        return {n: t for n, t in self.targets.items() if t["type"] == "bundle.unit-test"}

    def dependency_closure(self, name: str) -> set[str]:
        """`name` and everything it depends on, transitively."""
        seen: set[str] = set()
        stack = [name]
        while stack:
            current = stack.pop()
            if current in seen or current not in self.targets:
                continue
            seen.add(current)
            stack.extend(self.targets[current]["dependencies"])
        return seen


def load(path: pathlib.Path | None = None) -> Project:
    targets: dict[str, dict] = {}
    scheme_tests: dict[str, list[str]] = {}

    section = None          # "targets" | "schemes" | None
    target = None           # current target name
    listkey = None          # which list under the current target we are inside
    scheme = None
    in_scheme_test_targets = False

    for raw in (path or PROJECT).read_text(encoding="utf-8").splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()

        if indent == 0:
            section = line[:-1] if line.endswith(":") else None
            target = scheme = listkey = None
            in_scheme_test_targets = False
            continue

        if section == "targets":
            if indent == 2 and line.endswith(":"):
                target = line[:-1]
                targets[target] = {"type": "", "sources": [], "dependencies": []}
                listkey = None
            elif target:
                if indent == 4 and line.startswith("type:"):
                    targets[target]["type"] = line.split(":", 1)[1].strip()
                    listkey = None
                elif indent == 4 and line in ("sources:", "dependencies:"):
                    listkey = line[:-1]
                elif indent == 4:
                    # Any other key at target level ends the list — `settings:` in particular, whose
                    # own entries are indented exactly like a list item's continuation.
                    listkey = None
                elif listkey == "sources" and line.startswith("- "):
                    value = line[2:].strip()
                    m = re.match(r"path:\s*(.+)$", value)
                    targets[target]["sources"].append((m.group(1) if m else value).strip())
                elif listkey == "dependencies" and line.startswith("- "):
                    # `- target: X`. Packages and frameworks are not project targets, so they carry
                    # no test bundle and are skipped.
                    m = re.match(r"target:\s*(.+)$", line[2:].strip())
                    if m:
                        targets[target]["dependencies"].append(m.group(1).strip())
        elif section == "schemes":
            if indent == 2 and line.endswith(":"):
                scheme = line[:-1]
                scheme_tests.setdefault(scheme, [])
                in_scheme_test_targets = False
            elif scheme:
                if line == "targets:":
                    in_scheme_test_targets = True
                elif line.endswith(":") and not line.startswith("- "):
                    # `build:`/`test:` and their keys; only the list under `test:` matters, and it is
                    # the one that follows `targets:` at the deepest level.
                    in_scheme_test_targets = False
                elif in_scheme_test_targets and line.startswith("- "):
                    # Either `- PCFooTests` or the settings form, `- name: PCFooTests` followed by
                    # `parallelizable:`. Same shape as `path:` under a target's sources.
                    value = line[2:].strip()
                    m = re.match(r"name:\s*(.+)$", value)
                    scheme_tests[scheme].append((m.group(1) if m else value).strip())

    return Project(targets, scheme_tests)
