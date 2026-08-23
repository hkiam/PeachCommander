#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""plugin-build-stamp.py — a content hash of everything one plugin build script reads.

`build-all-plugins.sh` rebuilt all seventeen plugins on every run, which is the slowest part of a
build and is wasted whenever the change was not to a plugin. Comparing this stamp against the one
stored beside the last output tells it which scripts have anything to do.

Content, not timestamps: a `git checkout` or a branch switch rewrites mtimes on files whose bytes
did not change, and mtimes would rebuild everything every time anyone moved between branches.

The inputs are the script itself plus every `Plugins/<Name>/` directory it names — the whole
directory, not just the .swift files it lists, because a plugin also ships Info.plist and its
Resources/*.lproj, and a translation change must reach the bundle. `Plugins/SDK` and
`Tools/lib/pc-universal.sh` are always included: every script compiles something out of the first
and links through the second.

The settings that change what comes out for unchanged sources go in as well. `PC_PLUGIN_ARCHS=arm64`
is the one people actually use — it is the fast slice for iterating — and without it in the stamp,
an arm64-only build followed by a release build into the same directory would skip every plugin and
ship a universal app with single-architecture plugins inside it. Silent, and only visible on someone
else's Mac.

Usage: Tools/plugin-build-stamp.py Tools/build-s3-plugin.sh
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Same shape as the reference Tools/check-plugin-sources.py looks for, widened to any file so that
# a script naming a .c or a .h pulls that plugin's directory in too.
REF = re.compile(r'Plugins/([A-Za-z0-9_]+)/')


def files_under(directory):
    for base, _, names in os.walk(directory):
        for name in sorted(names):
            if name == ".DS_Store":
                continue
            yield os.path.join(base, name)


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    script = os.path.abspath(argv[1])
    with open(script, "rb") as handle:
        text = handle.read()

    directories = {"SDK"} | set(REF.findall(text.decode("utf-8", "replace")))
    digest = hashlib.sha256()
    digest.update(text)
    # Normalised to what pc-universal.sh would actually use, so that leaving PC_PLUGIN_ARCHS unset
    # and setting it to its own default are the same stamp rather than two.
    archs = " ".join(sorted(os.environ.get("PC_PLUGIN_ARCHS", "").split() or ["arm64", "x86_64"]))
    deploy = os.environ.get("PC_PLUGIN_DEPLOY") or "13.0"
    digest.update(f"archs={archs} deploy={deploy}\n".encode("utf-8"))
    with open(os.path.join(ROOT, "Tools", "lib", "pc-universal.sh"), "rb") as handle:
        digest.update(handle.read())
    for plugin in sorted(directories):
        directory = os.path.join(ROOT, "Plugins", plugin)
        if not os.path.isdir(directory):
            continue
        for path in sorted(files_under(directory)):
            digest.update(os.path.relpath(path, ROOT).encode("utf-8"))
            with open(path, "rb") as handle:
                digest.update(handle.read())
    print(digest.hexdigest())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
