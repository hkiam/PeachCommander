#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-fsimage-fixtures.py — is every filesystem-image driver actually built and actually tested?

The FSImage plugin grows one format at a time, over months. Three lists have to agree for a driver
to be real, and none of them fails loudly on its own:

  * `DriverRegistry.all` in Plugins/FSImage/Support/DriverRegistry.swift — what the plugin probes.
  * `SOURCES` in Tools/build-fsimage-plugin.sh — what the shipped binary contains.
  * `pluginSources` in Tests/PCPluginHostTests/FSImagePluginTests.swift — what the tests compile.

A driver missing from the build script is registered but absent from the shipped plugin, and the
symptom is "that format just doesn't open" with nothing in any log. A driver missing from the test
list makes the tests compile a *different* plugin than the one that ships, so a green run says
nothing about the binary the user gets. Both are the same failure `check-tests-registered.py` was
written for after four test files sat unexecuted behind a green suite.

The fourth check is coverage: a registered driver must be named by at least one test, so a format
cannot be added with no case exercising it and still pass.

Usage: Tools/check-fsimage-fixtures.py
"""
from __future__ import annotations

import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
REGISTRY = REPO / "Plugins/FSImage/Support/DriverRegistry.swift"
BUILD_SCRIPT = REPO / "Tools/build-fsimage-plugin.sh"
TESTS = REPO / "Tests/PCPluginHostTests/FSImagePluginTests.swift"
DRIVERS_DIR = REPO / "Plugins/FSImage/Drivers"


def registered_drivers() -> list[str]:
    """Type names listed in `DriverRegistry.all` — commented-out lines do not count."""
    text = REGISTRY.read_text(encoding="utf-8")
    match = re.search(r"static let all:.*?=\s*\[(.*?)\]", text, re.S)
    if not match:
        sys.exit(f"error: could not find `DriverRegistry.all` in {REGISTRY.relative_to(REPO)}")
    names = []
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        found = re.match(r"([A-Za-z0-9_]+)\.self", line)
        if found:
            names.append(found.group(1))
    return names


def listed_sources(path: pathlib.Path, pattern: str) -> set[str]:
    """Driver file basenames referenced by a source list, ignoring commented lines."""
    out = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("#") or stripped.startswith("//"):
            continue
        for hit in re.findall(pattern, line):
            out.add(pathlib.Path(hit).stem)
    return out


def main() -> int:
    failures: list[str] = []

    drivers = registered_drivers()
    if not drivers:
        print("==> No drivers registered yet — nothing to check.")
        return 0

    built = listed_sources(BUILD_SCRIPT, r"Plugins/FSImage/Drivers/([A-Za-z0-9_]+\.swift)")
    tested = listed_sources(TESTS, r"Plugins/FSImage/Drivers/([A-Za-z0-9_]+\.swift)")
    test_text = TESTS.read_text(encoding="utf-8")

    if not check_vendored_sources():
        failures.append("vendored C sources differ between the build script and the tests")

    print("==> Checking every registered FSImage driver is built and tested")
    for driver in drivers:
        problems = []
        if not (DRIVERS_DIR / f"{driver}.swift").exists():
            problems.append(f"no such file Plugins/FSImage/Drivers/{driver}.swift")
        if driver not in built:
            problems.append("not in SOURCES in Tools/build-fsimage-plugin.sh — it would not ship")
        if driver not in tested:
            problems.append("not in pluginSources in FSImagePluginTests.swift — the tests build a "
                            "different plugin than the one that ships")
        # Coverage: the driver's own name, or the format id it declares, has to appear in a test.
        format_id = driver_format_id(driver)
        if driver not in test_text and (format_id is None or format_id not in test_text):
            problems.append("no test mentions it — a registered format with no case exercising it")

        if problems:
            for problem in problems:
                failures.append(f"{driver}: {problem}")
            print(f"  ✗ {driver}")
        else:
            print(f"  ✓ {driver}")

    # The reverse direction: a driver file that exists but is not registered is dead code, not a
    # failure — it may be a stage in progress. Say so rather than passing it over silently.
    #
    # "Driver" means a file declaring `static let id`, not every file in Drivers/. Support files
    # live there too (a format's metadata layer belongs beside the format, not in Support/), and
    # listing them here would train the reader to ignore this line — at which point a genuinely
    # unregistered driver goes unnoticed in the same noise.
    unregistered = sorted(
        p.stem for p in DRIVERS_DIR.glob("*.swift")
        if p.stem not in drivers and driver_format_id(p.stem) is not None
    ) if DRIVERS_DIR.exists() else []
    if unregistered:
        print(f"==> Note: driver files present but not registered: {', '.join(unregistered)}")

    if failures:
        print()
        for failure in failures:
            print(f"  ✗ {failure}", file=sys.stderr)
        return 1
    print("==> OK")
    return 0


def check_vendored_sources() -> bool:
    """Do the build script and the tests compile the same vendored C?

    The plugin links one vendored translation unit (zstd's single-file decoder). The tests build the
    plugin themselves, so they have to compile and link it too — when they did not, every test in the
    file failed at once on undefined ZSTD symbols. Loud, but only because the symbol happened to be
    load-bearing everywhere; a vendored source used by one format would have taken a single format's
    coverage away instead, quietly.
    """
    pattern = r"Plugins/FSImage/Vendor/([A-Za-z0-9_]+\.c)"
    in_build = listed_sources(BUILD_SCRIPT, pattern)
    in_tests = listed_sources(TESTS, pattern)
    if in_build == in_tests:
        return True
    print(f"  ✗ vendored C in the build script: {sorted(in_build) or '(none)'}", file=sys.stderr)
    print(f"  ✗ vendored C in the tests:        {sorted(in_tests) or '(none)'}", file=sys.stderr)
    return False


def driver_format_id(driver: str) -> str | None:
    """The `static let id` a driver declares, e.g. "cpio" — used for the coverage check."""
    path = DRIVERS_DIR / f"{driver}.swift"
    if not path.exists():
        return None
    match = re.search(r'static let id\s*=\s*"([^"]+)"', path.read_text(encoding="utf-8"))
    return match.group(1) if match else None


if __name__ == "__main__":
    sys.exit(main())
