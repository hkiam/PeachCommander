#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-plugin-sources.py — is every plugin source file actually compiled into the plugin?

Plugins are not built by Xcode. Each one is a `swiftc -emit-library` invocation in a shell script
with the source files listed by hand, so adding a file to `Plugins/<Name>/` does nothing until the
script is edited too. Both directions of forgetting are silent in a way that costs an afternoon:

  * A file in the directory but not in the script is simply not in the plugin. If it defines something
    the rest needs, the build fails with "has no member" pointing at the caller — which reads as a
    typo in the caller, not as a missing file. If it defines something nothing needs *yet*, the build
    succeeds and the code ships absent.
  * A file in the script but not in the directory fails the build outright, so it needs no gate; it
    is reported here anyway because the message is clearer than swiftc's.

Sample plugins and the SDK are skipped: `Plugins/Sample*` are examples and `Plugins/SDK` holds the
shared helpers every script lists on purpose.

Usage: Tools/check-plugin-sources.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = os.path.join(ROOT, "Plugins")
TOOLS = os.path.join(ROOT, "Tools")

# "$ROOT/Plugins/<Name>/<file>.swift" as it appears in a build script, including a nested path —
# FSImage keeps its sources in Support/ and Drivers/, and a pattern that stopped at the first slash
# reported all twenty-nine of them as missing.
REF = re.compile(r'Plugins/([A-Za-z0-9_]+)/((?:[A-Za-z0-9_+.-]+/)*[A-Za-z0-9_+.-]+\.swift)')


def build_scripts():
    for name in sorted(os.listdir(TOOLS)):
        if name.startswith("build-") and name.endswith(".sh"):
            with open(os.path.join(TOOLS, name), encoding="utf-8") as handle:
                yield name, handle.read()


def main():
    # Every (plugin, file) pair any build script compiles.
    compiled = {}
    for script, text in build_scripts():
        for plugin, source in REF.findall(text):
            compiled.setdefault(plugin, {}).setdefault(source, []).append(script)

    problems = 0
    checked = 0
    for entry in sorted(os.listdir(PLUGINS)):
        directory = os.path.join(PLUGINS, entry)
        if not os.path.isdir(directory) or entry.startswith("Sample") or entry == "SDK":
            continue
        on_disk = sorted(
            os.path.relpath(os.path.join(base, name), directory).replace(os.sep, "/")
            for base, _, files in os.walk(directory)
            for name in files
            if name.endswith(".swift")
        )
        if not on_disk:
            continue   # a C plugin, or one with no Swift at all
        listed = compiled.get(entry, {})
        for source in on_disk:
            checked += 1
            if source not in listed:
                print("  ✗ %s: Plugins/%s/%s is not compiled by any build script"
                      % (entry, entry, source), file=sys.stderr)
                problems += 1
        for source in sorted(listed):
            if source not in on_disk:
                where = ", ".join(listed[source])
                print("  ✗ %s: %s compiles Plugins/%s/%s, which does not exist"
                      % (entry, where, entry, source), file=sys.stderr)
                problems += 1

    print("plugin_sources=%d problems=%d" % (checked, problems))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
