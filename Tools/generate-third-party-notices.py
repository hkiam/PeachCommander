#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""generate-third-party-notices.py — assemble the app's open-source attributions.

Produces (all committed to the repo, like the localization catalog):
  • Resources/Licenses/<key>.txt        — the full license text of each component
  • Resources/ThirdPartyNotices.json    — bundled into the app; drives the
                                          Help ▸ Open Source & Third-Party dialog
  • THIRD_PARTY_NOTICES.md               — human-readable notices for the repo

Versions of SwiftPM dependencies are read automatically from Package.resolved so
they never drift; license texts are copied verbatim from the real sources: the
SwiftPM checkouts, the Homebrew kegs for the bundled dylibs, and the upstream
LICENSE files committed under Sources/CTreeSitter*/LICENSE for the vendored
grammars. Descriptions/websites are curated below. The script WARNS if
Package.resolved pins a dependency that is not described here.

Run it whenever dependencies change:  python3 Tools/generate-third-party-notices.py
"""

import datetime
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIC_DIR = os.path.join(REPO, "Resources", "Licenses")
JSON_OUT = os.path.join(REPO, "Resources", "ThirdPartyNotices.json")
MD_OUT = os.path.join(REPO, "THIRD_PARTY_NOTICES.md")
RESOLVED = os.path.join(REPO, "PeachCommander.xcodeproj", "project.xcworkspace",
                        "xcshareddata", "swiftpm", "Package.resolved")

# The standard MIT license body (SPDX: MIT); {copyright} is filled per component.
MIT_TEXT = """MIT License

{copyright}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""


def find_checkouts():
    for pat in [
        os.path.expanduser("~/Library/Developer/Xcode/DerivedData/PeachCommander-*/SourcePackages/checkouts"),
        os.path.join(REPO, "build", "*", "SourcePackages", "checkouts"),
    ]:
        for d in sorted(glob.glob(pat)):
            if os.path.isdir(d):
                return d
    return None


def resolved_pins():
    """identity -> {version, url} from Package.resolved (v2/v3)."""
    pins = {}
    try:
        data = json.load(open(RESOLVED, encoding="utf-8"))
    except OSError:
        return pins
    for pin in data.get("pins", []):
        ident = pin.get("identity", "")
        st = pin.get("state", {})
        if st.get("version"):
            ver = st["version"]
        elif st.get("branch"):
            ver = "%s (%s)" % (st["branch"], (st.get("revision") or "")[:7])
        else:
            ver = (st.get("revision") or "")[:7]
        pins[ident] = {"version": ver, "url": pin.get("location", "")}
    return pins


def first_glob(*patterns):
    for p in patterns:
        for m in sorted(glob.glob(p)):
            return m
    return None


CHECKOUTS = find_checkouts()
PINS = resolved_pins()


def checkout_license(name):
    if not CHECKOUTS:
        return None
    for fn in ("LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING"):
        p = os.path.join(CHECKOUTS, name, fn)
        if os.path.isfile(p):
            return open(p, encoding="utf-8", errors="replace").read()
    return None


def repo_license(rel_dir):
    """Read the original upstream LICENSE checked into a vendored source dir."""
    p = os.path.join(REPO, "Sources", rel_dir, "LICENSE")
    return open(p, encoding="utf-8", errors="replace").read() if os.path.isfile(p) else None


def path_license(rel_path):
    """Read an upstream LICENSE checked in beside vendored source, anywhere in the repo.

    `repo_license` only looks under Sources/. Vendored code also lives beside the plugin that needs
    it — the zstd decoder sits in Plugins/FSImage/Vendor — and its licence has to travel with it.
    """
    p = os.path.join(REPO, rel_path)
    return open(p, encoding="utf-8", errors="replace").read() if os.path.isfile(p) else None


def homebrew_version(formula):
    d = first_glob("/opt/homebrew/Cellar/%s/*" % formula, "/usr/local/Cellar/%s/*" % formula)
    return os.path.basename(d).split("_")[0] if d else None


def homebrew_license(formula, *filenames):
    base = first_glob("/opt/homebrew/Cellar/%s/*" % formula, "/usr/local/Cellar/%s/*" % formula)
    if not base:
        return None
    for fn in filenames:
        p = os.path.join(base, fn)
        if os.path.isfile(p):
            return open(p, encoding="utf-8", errors="replace").read()
    return None


# --- Curated component set -------------------------------------------------
# Each entry: key, name, spdx, description, website, repository, and a `text`
# resolver returning the full license text (None -> keep any existing file).
# `pin` links to a Package.resolved identity for the auto version; `version`
# overrides it (vendored / bundled components). `note` is shown in the UI.

def mit(copyright_line):
    return lambda: MIT_TEXT.format(copyright=copyright_line)


COMPONENTS = [
    # -- SwiftPM dependencies (linked into the app) --
    dict(key="Sparkle", name="Sparkle", spdx="MIT", pin="sparkle",
         website="https://sparkle-project.org",
         repository="https://github.com/sparkle-project/Sparkle",
         copyright="Copyright (c) 2006 Andy Matuschak and Sparkle contributors.",
         description="Software update framework that powers the app's in-app updates.",
         text=lambda: checkout_license("Sparkle")),
    # Compiled into the Terminal plugin rather than linked into the app, which is why removing that
    # plugin removes the emulator with it. Referenced through SwiftPM at a pinned revision — this
    # repository carries none of its source.
    dict(key="SwiftTerm", name="SwiftTerm", spdx="MIT", pin="swiftterm",
         website="https://github.com/migueldeicaza/SwiftTerm",
         repository="https://github.com/migueldeicaza/SwiftTerm",
         copyright="Copyright (c) 2019-2026 Miguel de Icaza; portions (c) 2017-2019 The xterm.js authors; "
                   "(c) 2014-2016 SourceLair Private Company.",
         description="Terminal emulator (xterm-compatible) behind the embedded terminal plugin.",
         text=lambda: checkout_license("SwiftTerm")),
    # Pinned but not shipped: it is a dependency of SwiftTerm's own `Termcast` executable target, which
    # this project does not build. Described because Package.resolved lists it and an undescribed pin
    # is a warning — saying "not linked" is more honest than silencing the check.
    dict(key="swift-argument-parser", name="Swift Argument Parser", spdx="Apache-2.0",
         pin="swift-argument-parser",
         website="https://github.com/apple/swift-argument-parser",
         repository="https://github.com/apple/swift-argument-parser",
         copyright="Copyright (c) 2020 Apple Inc. and the Swift project authors.",
         description="Resolved as a dependency of SwiftTerm's command-line sample target; not compiled "
                     "into, or shipped with, this application.",
         text=lambda: checkout_license("swift-argument-parser")),
    dict(key="SwiftTreeSitter", name="SwiftTreeSitter", spdx="BSD-3-Clause", pin="swifttreesitter",
         website="https://github.com/ChimeHQ/SwiftTreeSitter",
         repository="https://github.com/ChimeHQ/SwiftTreeSitter",
         copyright="Copyright (c) 2021, Chime",
         description="Swift bindings for the tree-sitter parsing library, used for syntax highlighting and the symbol outline.",
         text=lambda: checkout_license("SwiftTreeSitter")),
    dict(key="Neon", name="Neon", spdx="BSD-3-Clause", pin="neon",
         website="https://github.com/ChimeHQ/Neon",
         repository="https://github.com/ChimeHQ/Neon",
         copyright="Copyright (c) 2022, Chime",
         description="Incremental syntax-highlighting engine for the built-in text editor.",
         text=lambda: checkout_license("Neon")),
    dict(key="Rearrange", name="Rearrange", spdx="BSD-3-Clause", pin="rearrange",
         website="https://github.com/ChimeHQ/Rearrange",
         repository="https://github.com/ChimeHQ/Rearrange",
         copyright="Copyright (c) 2019, Chime Systems Inc.",
         description="Text-range utilities used by Neon (transitive dependency).",
         text=lambda: checkout_license("Rearrange")),
    dict(key="tree-sitter", name="tree-sitter", spdx="MIT", pin="tree-sitter",
         website="https://tree-sitter.github.io",
         repository="https://github.com/tree-sitter/tree-sitter",
         copyright="Copyright (c) 2018-2024 Max Brunsfeld",
         description="Incremental parsing library; the runtime behind syntax highlighting and the symbol outline.",
         text=lambda: checkout_license("tree-sitter")),
    dict(key="tree-sitter-json", name="tree-sitter-json", spdx="MIT", pin="tree-sitter-json",
         website="https://github.com/tree-sitter/tree-sitter-json",
         repository="https://github.com/tree-sitter/tree-sitter-json",
         copyright="Copyright (c) 2014 Max Brunsfeld",
         description="JSON grammar for tree-sitter.",
         text=lambda: checkout_license("tree-sitter-json")),
    dict(key="tree-sitter-c", name="tree-sitter-c", spdx="MIT", pin="tree-sitter-c",
         website="https://github.com/tree-sitter/tree-sitter-c",
         repository="https://github.com/tree-sitter/tree-sitter-c",
         copyright="Copyright (c) 2014 Max Brunsfeld",
         description="C grammar for tree-sitter.",
         text=lambda: checkout_license("tree-sitter-c")),
    dict(key="tree-sitter-java", name="tree-sitter-java", spdx="MIT", pin="tree-sitter-java",
         website="https://github.com/tree-sitter/tree-sitter-java",
         repository="https://github.com/tree-sitter/tree-sitter-java",
         copyright="Copyright (c) 2017 Ayman Nadeem",
         description="Java grammar for tree-sitter.",
         text=lambda: checkout_license("tree-sitter-java")),

    # -- Vendored tree-sitter grammars (source checked into Sources/CTreeSitter*) --
    dict(key="tree-sitter-javascript", name="tree-sitter-javascript", spdx="MIT", version="v0.25.8",
         website="https://github.com/tree-sitter/tree-sitter-javascript",
         repository="https://github.com/tree-sitter/tree-sitter-javascript",
         copyright="Copyright (c) 2014 Max Brunsfeld",
         description="JavaScript grammar for tree-sitter (vendored).",
         vendor_dir="CTreeSitterJS",
         text=lambda vd="CTreeSitterJS": repo_license(vd)),
    dict(key="tree-sitter-python", name="tree-sitter-python", spdx="MIT", version="v0.25.9",
         website="https://github.com/tree-sitter/tree-sitter-python",
         repository="https://github.com/tree-sitter/tree-sitter-python",
         copyright="Copyright (c) 2016 Max Brunsfeld",
         description="Python grammar for tree-sitter (vendored).",
         vendor_dir="CTreeSitterPython",
         text=lambda vd="CTreeSitterPython": repo_license(vd)),
    # Vendored as zstd's own single-file *decoder* amalgamation: one translation unit, no build
    # system, decompression only. macOS ships no zstd at all — not in the SDK, not as a system
    # dylib — and current mksquashfs and btrfs both reach for it by default, so the alternative
    # was refusing a growing share of real images.
    dict(key="zstd", name="Zstandard", spdx="BSD-3-Clause", version="1.5.6 (single-file decoder)",
         website="https://facebook.github.io/zstd/",
         repository="https://github.com/facebook/zstd",
         copyright="Copyright (c) Meta Platforms, Inc. and affiliates.",
         description="Zstandard decompression, used by the Linux filesystem-image plugin to read "
                     "zstd-compressed SquashFS and Btrfs images. Dual-licensed BSD-3-Clause OR "
                     "GPL-2.0; this product takes the BSD option. Decompression only.",
         vendor_dir="Plugins/FSImage/Vendor",
         text=lambda: path_license("Plugins/FSImage/Vendor/LICENSE")),
    dict(key="tree-sitter-rust", name="tree-sitter-rust", spdx="MIT", version="vendored",
         website="https://github.com/tree-sitter/tree-sitter-rust",
         repository="https://github.com/tree-sitter/tree-sitter-rust",
         copyright="Copyright (c) 2017 Maxim Sokolov",
         description="Rust grammar for tree-sitter (vendored).",
         vendor_dir="CTreeSitterRust",
         text=lambda vd="CTreeSitterRust": repo_license(vd)),
    dict(key="tree-sitter-c-sharp", name="tree-sitter-c-sharp", spdx="MIT", version="vendored",
         website="https://github.com/tree-sitter/tree-sitter-c-sharp",
         repository="https://github.com/tree-sitter/tree-sitter-c-sharp",
         copyright="Copyright (c) 2014-2023 Max Brunsfeld, Damien Guard, Amaan Qureshi, and contributors.",
         description="C# grammar for tree-sitter (vendored).",
         vendor_dir="CTreeSitterCSharp",
         text=lambda vd="CTreeSitterCSharp": repo_license(vd)),
    dict(key="tree-sitter-typescript", name="tree-sitter-typescript", spdx="MIT", version="vendored",
         website="https://github.com/tree-sitter/tree-sitter-typescript",
         repository="https://github.com/tree-sitter/tree-sitter-typescript",
         copyright="Copyright (c) 2017 Max Brunsfeld",
         description="TypeScript grammar for tree-sitter (vendored).",
         vendor_dir="CTreeSitterTypeScript",
         text=lambda vd="CTreeSitterTypeScript": repo_license(vd)),

    # -- Documentation-website assets (not part of the app) --
    # Vendored because MkDocs Material renders the ```mermaid fences but, absent a `mermaid`
    # global, fetches the engine from unpkg.com — so the 34 diagrams rendered only for an online
    # reader, and only by telling a CDN which page they were on. Attributed here even though it
    # ships with no build of the app: leaving a vendored 3.2 MB MIT file unnamed would be the
    # omission, and the note says where it does and does not go.
    dict(key="mermaid", name="Mermaid", spdx="MIT", version="11.15.0",
         website="https://mermaid.js.org",
         repository="https://github.com/mermaid-js/mermaid",
         copyright="Copyright (c) 2014 - 2022 Knut Sveidqvist",
         description="Renders the architecture diagrams on the documentation website. Vendored at "
                     "docs/assets/vendor/mermaid/ and served from that site so it needs no CDN; "
                     "not linked into, bundled with, or invoked by the application.",
         note="Documentation website only — not part of any build of the app.",
         vendor_dir="docs/assets/vendor/mermaid",
         text=lambda: path_license("docs/assets/vendor/mermaid/LICENSE")),

    # -- Native libraries bundled into the installer (.app) builds --
    dict(key="libssh2", name="libssh2", spdx="BSD-3-Clause",
         version=homebrew_version("libssh2") or "bundled",
         website="https://libssh2.org",
         repository="https://github.com/libssh2/libssh2",
         copyright="Copyright (c) 2004-2023 Daniel Stenberg and the libssh2 contributors.",
         description="SSH2 client library powering the SFTP/SCP support. Bundled into installer (DMG) builds.",
         note="Bundled into installer (DMG) builds.",
         text=lambda: homebrew_license("libssh2", "COPYING")),
    dict(key="OpenSSL", name="OpenSSL", spdx="Apache-2.0",
         version=homebrew_version("openssl@3") or "3",
         website="https://www.openssl.org",
         repository="https://github.com/openssl/openssl",
         copyright="Copyright (c) 1998-2024 The OpenSSL Project Authors. All Rights Reserved.",
         description="Cryptography and TLS library used by libssh2. Bundled into installer (DMG) builds.",
         note="Bundled into installer (DMG) builds.",
         text=lambda: homebrew_license("openssl@3", "LICENSE.txt", "LICENSE")),
]

# External command-line tools the app invokes but does NOT redistribute — a
# courtesy acknowledgement, not a redistribution obligation.
EXTERNAL_TOOLS = [
    dict(name="7-Zip / p7zip", license="LGPL-2.1+ / GNU", url="https://www.7-zip.org",
         note="Invoked as an external command for some archive formats when installed."),
    dict(name="libarchive (bsdtar)", license="BSD-2-Clause", url="https://www.libarchive.org",
         note="Invoked via /usr/bin/tar for tar/gzip/xz archives."),
    dict(name="The Unarchiver (unar/lsar)", license="LGPL-2.1", url="https://theunarchiver.com",
         note="Optionally invoked to read RAR archives when installed."),
]

ACKNOWLEDGEMENT = ("Peach Commander gratefully builds on the work of the open-source "
                   "community. Thank you to all the authors and contributors of the "
                   "projects listed here.")


def main():
    os.makedirs(LIC_DIR, exist_ok=True)
    warnings = []
    components_json = []

    for c in COMPONENTS:
        # Resolve version (auto from Package.resolved when linked to a pin).
        version = c.get("version")
        if c.get("pin"):
            if c["pin"] in PINS:
                version = PINS[c["pin"]]["version"]
            else:
                warnings.append("pin '%s' for %s not found in Package.resolved" % (c["pin"], c["name"]))
        version = version or "unknown"

        # Resolve + write the license text (keep existing file if source missing).
        out_path = os.path.join(LIC_DIR, c["key"] + ".txt")
        text = None
        try:
            text = c["text"]()
        except Exception as e:  # noqa: BLE001
            warnings.append("license resolver for %s failed: %s" % (c["name"], e))
        if text:
            open(out_path, "w", encoding="utf-8").write(text.rstrip() + "\n")
        elif not os.path.isfile(out_path):
            warnings.append("NO license text for %s and no existing %s" % (c["name"], out_path))

        components_json.append({
            "name": c["name"],
            "version": version,
            "license": c["spdx"],
            "copyright": c["copyright"],
            "description": c["description"],
            "website": c["website"],
            "repository": c["repository"],
            "licenseFile": c["key"] + ".txt",
            "note": c.get("note", ""),
        })

    # Warn about SwiftPM pins we don't attribute (new/undocumented dependency).
    described_pins = {c["pin"] for c in COMPONENTS if c.get("pin")}
    for ident in PINS:
        if ident not in described_pins:
            warnings.append("Package.resolved pins '%s' but it is not described in this generator." % ident)

    payload = {
        "generator": "Tools/generate-third-party-notices.py",
        "components": components_json,
        "externalTools": EXTERNAL_TOOLS,
        "acknowledgement": ACKNOWLEDGEMENT,
    }
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    json.dump(payload, open(JSON_OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

    # Markdown notices for the repository.
    md = ["# Third-Party Notices", "",
          ACKNOWLEDGEMENT, "",
          "This product includes the following open-source software — plus, where a "
          "row says so, software that is described here without shipping in the app. "
          "The full license text of each is in `Resources/Licenses/`.", ""]
    for c in components_json:
        md.append("## %s %s" % (c["name"], c["version"]))
        md.append("")
        md.append("- **License:** %s" % c["license"])
        md.append("- **%s**" % c["copyright"])
        if c["note"]:
            md.append("- _%s_" % c["note"])
        md.append("- %s" % c["description"])
        md.append("- Repository: %s" % c["repository"])
        md.append("- License text: `Resources/Licenses/%s`" % c["licenseFile"])
        md.append("")
    md.append("## External tools (invoked, not redistributed)")
    md.append("")
    for t in EXTERNAL_TOOLS:
        md.append("- **%s** — %s — %s (%s)" % (t["name"], t["license"], t["url"], t["note"]))
    md.append("")
    open(MD_OUT, "w", encoding="utf-8").write("\n".join(md))

    print("Wrote %d components → %s" % (len(components_json), os.path.relpath(JSON_OUT, REPO)))
    print("Wrote %s and %d license files in %s"
          % (os.path.relpath(MD_OUT, REPO), len(components_json), os.path.relpath(LIC_DIR, REPO)))
    if CHECKOUTS:
        print("SwiftPM checkouts: %s" % CHECKOUTS)
    else:
        print("WARNING: no SwiftPM checkouts dir found — kept any existing license texts.")
    for w in warnings:
        print("  ! " + w)
    return 0


if __name__ == "__main__":
    sys.exit(main())
