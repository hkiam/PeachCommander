<!-- SPDX-License-Identifier: Apache-2.0 -->
# Mermaid, vendored

`mermaid.min.js` — Mermaid **11.15.0**, MIT, verbatim from the npm package
(`mermaid/dist/mermaid.min.js`). `LICENSE` is that package's own licence file, unchanged.

    sha256  70137e77bb273bb2ef972b86e8b0400cca8be53cb25bfc45911a186dc98665de
    size    3312967 bytes (≈886 KiB over gzip)

## Why the file is here at all

MkDocs Material renders ` ```mermaid ` fences itself, and when the page has no `mermaid`
global it fetches one **from `https://unpkg.com/mermaid@11/dist/mermaid.min.js`** — read the
condition out of its own bundle:

    function as(){ return typeof mermaid=="undefined" || mermaid instanceof Element
      ? _t("https://unpkg.com/mermaid@11/dist/mermaid.min.js") : $(void 0) }

So the 34 diagrams on this site used to render only for a reader who was online, and only by
telling a third-party CDN which page they were reading. `DOCUMENTATION.md` promises "fully
offline output", which that is not.

The same condition is the supported way out: define `mermaid` first and Material uses it and
never touches the network. `build-site.py` therefore lists this file in `extra_javascript` for
the English site — the only one with diagrams, all 15 files of them under `docs/content/`; no
translated Help topic contains a fence, so the other eighteen subsites do not carry the copy.

`extra_javascript` emits a plain classic `<script>`, which runs before `DOMContentLoaded`, and
that is when Material mounts its diagram components — hence "first" without needing `defer`
or an ordering trick. This bundle is self-contained: it ends in
`globalThis["mermaid"] = …` and, unlike the ESM build with its 81 lazy chunks, has no
dynamic `import()` at all, so one file is the whole engine.

Material also calls `mermaid.initialize` itself, passing the `--md-mermaid-*` themed CSS it
already ships — which is why light and dark both work here without an init file of our own.

## Updating it

    npm pack mermaid@<version>          # or take dist/mermaid.min.js from any install
    cp …/mermaid/dist/mermaid.min.js Vendor/mermaid/mermaid.min.js
    cp …/mermaid/LICENSE              Vendor/mermaid/LICENSE

Then check the tail still assigns `globalThis["mermaid"]` (an ESM-only release would break the
whole arrangement), refresh the digest above, run `Tools/generate-third-party-notices.py`, and
**look at a built page** — `build/site/site/arch-diagrams.html` has seven diagrams and is the
cheapest proof.
