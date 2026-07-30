#!/usr/bin/env python3
"""gen-api-reference.py — generate the plugin ABI reference from the real headers.

The public plugin ABI is defined by the C headers in Plugins/SDK/. This script
derives one reference page per header directly from the source so the reference
can never drift from the ABI: the header's own doc comment becomes the intro, a
symbol index (constants + callback/entry-point names) is extracted, and the full
annotated header is embedded verbatim. Run after any ABI change (and after
Tools/sync-plugin-sdk.sh).

Output: docs/content/reference/api-<stem>.md  (+ api-overview.md index)
Usage:  python3 docs/scripts/gen-api-reference.py
"""
from __future__ import annotations
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SDK = REPO / "Plugins/SDK"
OUT = REPO / "docs/content/reference"

HEADERS = [
    ("pc_common.h", "Common ABI (pc_common)", "Shared types, return codes, capability flags and callback typedefs used by all plugin ABIs.", 10),
    ("pcx.h", "Packer plugins (PCX)", "Browse, extract and create archives — the WCX-style packer ABI.", 20),
    ("pdx.h", "Content plugins (PDX)", "Compute typed content fields (custom columns, search criteria, rename placeholders) — the WDX-style ABI.", 30),
    ("pfx.h", "File-system plugins (PFX)", "Expose a remote or virtual file system mounted like a drive — the WFX-style ABI.", 40),
    ("plx.h", "Lister plugins (PLX)", "Render a file into a custom view for the viewer / Quick View — the WLX-style ABI.", 50),
    ("contrib.h", "Contributions ABI (contrib)", "Run declared commands and build declared views; unified host-services table. Orthogonal to the file-op ABIs.", 60),
]

TOP_COMMENT_RE = re.compile(r'^\s*/\*(.*?)\*/', re.DOTALL)
DEFINE_RE = re.compile(r'^#define\s+(PC_[A-Z0-9_]+)\s+(.+?)\s*(?:/\*(.*?)\*/|//(.*))?$')
CALLBACK_RE = re.compile(r'\(\s*\*\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)\s*\(')
PROTO_RE = re.compile(r'^\s*[A-Za-z_][\w\s\*]*?\b([A-Z][A-Za-z0-9_]+)\s*\([^;]*\)\s*;')


def strip_comment(block: str) -> str:
    lines = [re.sub(r'^\s*\*?', '', ln).rstrip() for ln in block.strip("\n").splitlines()]
    return "\n".join(lines).strip()


def gen(header, title, blurb, order) -> str:
    text = (SDK / header).read_text(encoding="utf-8")
    m = TOP_COMMENT_RE.match(text)
    intro = strip_comment(m.group(1)) if m else blurb

    defines, callbacks, protos = [], [], set()
    for ln in text.splitlines():
        dm = DEFINE_RE.match(ln.strip())
        if dm:
            name, val = dm.group(1), dm.group(2).strip()
            cmt = (dm.group(3) or dm.group(4) or "").strip()
            defines.append((name, val, cmt))
        for cb in CALLBACK_RE.findall(ln):
            callbacks.append(cb)
        pm = PROTO_RE.match(ln)
        if pm:
            protos.add(pm.group(1))

    out = [f"---\ntitle: \"API: {title}\"\nslug: api-{Path(header).stem}\n"
           f"section: API reference\norder: {order}\nrelated: [sdk-overview, plugin-architecture-guide]\n---\n",
           f"# {title}", "",
           f"> Source: `Plugins/SDK/{header}` — this page is generated from that header "
           f"by `docs/scripts/gen-api-reference.py`; edit the header, not this page.", "",
           intro, ""]

    seen = list(dict.fromkeys(callbacks))
    entry = sorted(p for p in protos if p not in {"PC_CONTRIB_H"})
    if entry:
        out += ["## Entry points & functions", "",
                "".join(f"- `{n}`\n" for n in entry)]
    if seen:
        out += ["", "## Callbacks & service members", "",
                "".join(f"- `{n}`\n" for n in seen)]
    if defines:
        out += ["", "## Constants", "", "| Name | Value | Meaning |", "|---|---|---|"]
        for n, v, c in defines:
            out.append(f"| `{n}` | `{v}` | {c} |")

    out += ["", "## Full header", "",
            "```c", (SDK / header).read_text(encoding="utf-8").strip(), "```", ""]
    return "\n".join(out)


def main():
    if not SDK.exists():
        sys.exit(f"no SDK headers at {SDK}")
    OUT.mkdir(parents=True, exist_ok=True)
    generated = []
    for header, title, blurb, order in HEADERS:
        if not (SDK / header).exists():
            print(f"! missing {header}", file=sys.stderr); continue
        (OUT / f"api-{Path(header).stem}.md").write_text(gen(header, title, blurb, order), encoding="utf-8")
        generated.append((header, title, order))
        print(f"✓ api-{Path(header).stem}.md")

    # index
    idx = ["---\ntitle: Plugin API reference\nslug: api-overview\nsection: API reference\norder: 5\n"
           "related: [sdk-overview]\n---\n", "# Plugin API reference", "",
           "The Peach Commander plugin ABI is C11, UTF-8, and versioned via `PcGetApiVersion`. "
           "Each page below is generated directly from the canonical header in `Plugins/SDK/`.", ""]
    for header, title, order in sorted(generated, key=lambda x: x[2]):
        idx.append(f"- [{title}](api-{Path(header).stem}.md)")
    (OUT / "api-overview.md").write_text("\n".join(idx) + "\n", encoding="utf-8")
    print(f"✓ api-overview.md ({len(generated)} headers)")


if __name__ == "__main__":
    main()
