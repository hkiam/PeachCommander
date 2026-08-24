<!-- SPDX-License-Identifier: Apache-2.0 -->
# KaTeX, vendored

`katex.min.js`, `katex.min.css`, `auto-render.min.js` and `fonts/*.woff2` — KaTeX **0.16.47**, MIT,
verbatim from the npm package (`katex/dist/` and `katex/dist/contrib/`). `LICENSE` is that package's
own licence file, unchanged.

`auto-render.min.js` (3.5 KB) is KaTeX's own extension for finding `$…$` and `$$…$$` in a rendered
page. It is used instead of hunting delimiters in the Markdown source, and not only to save code:
its default `ignoredTags` already include `pre` and `code`, so a `$` inside a code block is left
alone — which is the part a hand-written scanner gets wrong.

    sha256 katex.min.js   a29d2961d3146de5949d78ac7c1a9d93ae54955bad22a6db4fbe836e88e8bf48
    sha256 katex.min.css  0289a02cf451a44dd73add683a09644252363871ac11713a647b732cee8b1ee3
    sizes  272 KB js · 24 KB css · 296 KB fonts (20 files)

## Licence, checked rather than repeated

The plan for this work said "MIT, fonts SIL OFL 1.1 — to be checked at the package". Checked: the
package declares `"license": "MIT"` and ships **one** licence file, MIT, covering everything in it —
`dist/fonts/` included. There is no separate font licence in the artefact, so MIT is what is
attributed. Should upstream split them later, this note is where to start looking.

## Only the woff2 fonts

The package also ships `.ttf` and `.woff` of each face, for browsers that need them. Every WebKit
this app can run on takes woff2, so the other two formats are 800 KB of nothing. `katex.min.css`
still names all three in each `@font-face`; the plugin rewrites only the woff2 `url()` and leaves
the rest to fail silently, which is exactly what a font stack is for.

## Why the fonts are inlined

The plugin injects the CSS with each `url(fonts/…woff2)` replaced by a `data:` URI. Not for
convenience: the page is loaded with `loadHTMLString`, whose base URL is the *document's* folder, so
it has no read access to this bundle — and the document's Content-Security-Policy is
`font-src file: data:`, which admits a `data:` URI and nothing that would need a network. Inlining is
what makes the fonts reachable without relaxing either.

Cost: ~395 KB of base64 in the injected stylesheet, and only for a document that actually contains
maths. A document without a formula gets no KaTeX at all.

## Updating it

    cp …/katex/dist/katex.min.js  Vendor/katex/katex.min.js
    cp …/katex/dist/katex.min.css Vendor/katex/katex.min.css
    cp …/katex/dist/fonts/*.woff2 Vendor/katex/fonts/
    cp …/katex/LICENSE            Vendor/katex/LICENSE

Then refresh the digests above, re-check the licence claim against the new package, run
`Tools/generate-third-party-notices.py`, and **look at a formula** — `Tools/build.sh` followed by F3
on a `.md` with `$$…$$` in it is the cheapest proof.
