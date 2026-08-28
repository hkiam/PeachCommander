#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-scenario-reports.py — a VM scenario's primary report must be the last file it writes.

`regress-guest.sh` sleeps for the scenario's settle time and then waits — up to forty seconds more —
for *one* file: `REPORTS[<scenario name>][0]`. As soon as that file appears it screenshots and kills
the app. So if the primary report is written in the middle of the script, everything after it is a
race the app usually loses, and the later reports come back empty.

That is not a hypothesis. Five scenarios were built that way, four of them in one afternoon, and they
passed when run alone and failed in a full suite where launches are slower — which is the worst shape
a test can have, because the failure looks like the feature and not like the harness.

The rule is mechanical, so it is checked mechanically: the file named by the bare scenario key must be
the last `/Users/admin/*.txt` the script mentions.
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
SRC = (REPO / "Tools/vm/regress.py").read_text()

scenarios = SRC[SRC.index("SCENARIOS = ["):SRC.index("\nREPORTS = {")]
reports = SRC[SRC.index("\nREPORTS = {"):]

# The keyboard/accessibility scenarios collect their files through KEYBOARD_REPORTS instead, which the
# host reads after the run rather than the guest waiting on. Different mechanism, not a mistake — and
# `accessibility` writes its dump for the A11Y section of the report rather than for an expectation.
keyboard_only = (set(re.findall(r'^    "([a-z0-9-]+)":', SRC[SRC.index("KEYBOARD_REPORTS = {"):]
                                .split("}")[0], re.M)) | {"accessibility"})
# …except the ones that have since been given a report of their own, which is the better arrangement
# and should be held to the rule like everything else.
keyboard_only -= set(re.findall(r'^    "([a-z0-9-]+)": \("/Users/admin/', reports, re.M))

# Scenarios whose report is written by a probe the environment switches on, keyed by scenario name.
env_block = SRC[SRC.index("SCENARIO_ENV = {"):] if "SCENARIO_ENV = {" in SRC else ""
env_reports = set(re.findall(r'^    "([a-z0-9-]+)": \{', env_block.split("\n}")[0], re.M))

problems = 0
checked = 0
for m in re.finditer(r'\("([a-z0-9-]+)",\s*\[(.*?)\],\s*(\d+)\)', scenarios, re.S):
    name, body = m.group(1), m.group(2)
    written = re.findall(r'/Users/admin/([a-z0-9.\-]+\.txt)', body)
    if not written:
        continue
    if name in keyboard_only:
        continue
    primary = re.search(r'"%s": \("/Users/admin/([a-z0-9.\-]+)"' % re.escape(name), reports)
    if not primary:
        # A scenario that writes reports but has none under its own name gets no wait-for-report at
        # all — the guest sleeps its settle time and kills. That is the same race by another route,
        # and it is how renaming a key "tidily" cost three checks in one run.
        print(f"  ⚠️  {name}: writes {written[-1]} but has no report under its own name, so the guest "
              f"never waits for anything")
        problems += 1
        continue
    checked += 1
    # A report the *environment* produces is not written by the script at all — the probe inside a
    # modal dialog writes it when the dialog would have appeared (SCENARIO_ENV, F-478). The rule below
    # is about a script that goes on writing after the guest has stopped waiting, and a scenario whose
    # report never appears in its script has no such tail to lose.
    if name in env_reports:
        continue
    if primary.group(1) != written[-1]:
        print(f"  ⚠️  {name}: the guest waits for {primary.group(1)}, but the script goes on to write "
              f"{written[-1]} — everything after the wait is a race the app loses on a slow launch")
        problems += 1

# A second rule from the same machinery: the host collects a scenario's reports as its own key *plus*
# every key starting with "<name>-", so a scenario whose name begins with another scenario's name and a
# dash has its reports adopted by that other one — which then fails on files it never writes, while the
# real scenario still passes later in the run. `settings-search` was adopted by `settings` exactly this
# way, and only a *full* run could show it: the scenario doing the claiming has to be in the same run.
names = set(re.findall(r'\("([a-z0-9-]+)",\s*\[', scenarios))
for name in sorted(names):
    owners = [other for other in names if other != name and name.startswith(other + "-")]
    if owners:
        print(f"  ⚠️  {name}: its reports are claimed by the scenario “{owners[0]}”, which will fail on "
              f"files it never writes — rename it so it does not start with another scenario's name")
        problems += 1

print(f"scenarios_with_reports={checked} problems={problems}")
sys.exit(1 if problems else 0)
