# Peach Commander — Documentation System

This repository uses a **single-source-of-truth (SSOT)** documentation system:
one set of Markdown sources plus structured metadata generates every output —
the in-app macOS Help Book, the documentation website, the product homepage, the
GitHub README, feature overviews, the developer & architecture guide, and the
SDK / plugin / API reference.

> **Status:** this document defines the system, and it is meant to describe what
> exists. It drifted once: most of §4 sat marked _(planned)_ long after the scripts
> were written and wired into CI, and it named two generators — `gen-readme.py` and
> `gen-features.py` — that were never written at all. Corrected 2026-08-22. What is
> still genuinely ahead says so, and §4 names the two ideas that were abandoned
> rather than leaving them looking pending. The coverage report in
> `docs/generated/coverage-report.md` tracks feature documentation, not this file.

---

## 1. Principles

1. **Write once, publish many.** A user-facing topic is authored a single time
   in `docs/content/` and rendered into both the Apple Help Book and the website
   from the same file. No copy-and-paste between outputs.
2. **Metadata drives generation.** `docs/metadata/features.yml` is the canonical
   feature registry; navigation, coverage matrices, feature overviews and the
   README feature list are generated from it — never hand-maintained twice.
3. **Screenshots are reproducible.** Every screenshot is produced by the VM
   harness (`Tools/vm/`) from a scripted app state, indexed in
   `docs/metadata/screenshot-index.yml`, so it can be regenerated on demand at a
   consistent size, theme and sample content. See §5.
4. **Audience separation, shared content.** User, developer and SDK/plugin
   audiences are served from the same source tree via front-matter `audiences:`
   tags and reusable includes in `docs/content/shared/`.
5. **Truth from the code.** The API reference and much of the developer guide are
   derived from the real source and its doc-comments, not written from memory.
   Claims that cannot be traced to the code are marked as open questions.

---

## 2. Source layout

```
docs/
├── content/                 # SSOT Markdown (front-matter + Mermaid + include markers)
│   ├── shared/              #   reusable fragments included elsewhere (no standalone page)
│   ├── help/                #   in-app Help Book topics (user-facing subset)
│   ├── website/             #   homepage / marketing pages
│   ├── user-guide/          #   online user documentation
│   ├── developer-guide/     #   contributor & build docs
│   ├── architecture/        #   architecture narrative + diagrams
│   ├── sdk/                 #   SDK overview & guides
│   ├── plugins/             #   plugin developer handbook
│   ├── reference/           #   generated API reference + shortcut/command tables
│   ├── tutorials/           #   end-to-end walkthroughs
│   └── troubleshooting/     #   problem/solution + FAQ + known limitations
├── assets/
│   ├── screenshots/         #   full-window captures (light/dark)
│   ├── screenshots-annotated/
│   ├── crops/               #   focused detail crops
│   ├── diagrams/            #   rendered diagram images (Mermaid source lives inline)
│   ├── icons/
│   └── animations/
├── metadata/
│   ├── features.yml         #   canonical feature registry (see §6)
│   ├── terminology.yml      #   glossary (canonical term → definition + forbidden synonyms)
│   ├── nav-groups.yml       #   per-language label for the one umbrella nav group
│   ├── languages.yml        #   the 19 supported languages, read by every doc script
│   └── screenshot-index.yml #   screenshot registry (see §5)
├── templates/               #   Help Book HTML shell, website overrides, page templates
├── scripts/                 #   generators & checks (see §4)
└── generated/               #   build outputs & reports (git-ignored except reports)
```

The **existing** `docs/architecture/`, `docs/specs/`, `docs/product/`,
`docs/iterations/`, `docs/distribution/`, `docs/testing/` trees are the
authoritative *source material* mined into `docs/content/`. As topics migrate
into `content/`, the originals stay as an internal engineering record (specs,
iteration logs) rather than being duplicated.

---

## 3. Outputs and how each is produced

| Output | From | Tool | Command |
|--------|------|------|---------|
| **In-app macOS Help Book** (`PeachCommander.help`) | `content/help/` + `content/shared/` | custom generator + `hiutil` index | `docs/scripts/build-helpbook.py` |
| **Documentation website** (user + dev + SDK + plugins + reference) | `content/**` | MkDocs Material | `docs/scripts/build-site.py` |
| **Translated Help subsites** (18 languages at `/<code>/`) | `docs/help-<code>/` | MkDocs Material | `docs/scripts/build-site.py` |
| **Product homepage** | `content/website/index.md` | MkDocs + `docs/assets/website/peach.css` | `docs/scripts/build-site.py` |
| **GitHub README** | hand-written; its checkable claims are gated | — | `Tools/check-readme.py` |
| **FEATURES.md** (feature overview) + glossary | `features.yml`, `terminology.yml` | generator | `docs/scripts/gen-overviews.py` |
| **API reference** | Swift/C sources + doc-comments | generator | `docs/scripts/gen-api-reference.py` |
| **Offline HTML** | `content/**` | MkDocs (`mkdocs build` output is self-contained) | `mkdocs build` |
| **PDF** _(planned)_ | `content/**` | MkDocs + `mkdocs-with-pdf` | `ENABLE_PDF=1 mkdocs build` |

### Why this toolchain

- **MkDocs Material** is the de-facto professional standard for developer/product
  documentation sites: built-in client-side search, dark/light theming, native
  Mermaid rendering, macros/includes for de-duplication, fully offline output,
  and an optional PDF exporter — matching every website/online-docs requirement
  without bespoke web code. The Markdown source stays tool-agnostic, so MkDocs is
  a renderer, not a lock-in.

  **"Fully offline output" was a claim before it was a fact, and it is now stated
  precisely.** Out of the box Material has the site fetch Roboto from
  `fonts.googleapis.com` and the repository's star and fork counts from
  `api.github.com` on *every* page view — so opening any page told two third
  parties that somebody had, and none of it worked without a network. Both are
  gone: `theme.font: false` and an override of `partials/source.html` that keeps
  the repository link and drops the one attribute the counts hang on
  (`docs/assets/mkdocs-overrides/`). Mermaid is served from the site's own
  `assets/vendor/` rather than unpkg.com for the same reason (F-460). Measured, not
  assumed: on a documentation page,
  `performance.getEntriesByType('resource')` names one host, and it is the server
  the page came from.

  **One deliberate exception, and only on the homepage.** The download button asks
  GitHub for the newest published release, because that cannot be known offline.
  It is progressive enhancement — the markup already links to the releases page, so
  the buttons work with JavaScript off, offline, and against a rate-limited API —
  and the request happens only where such a button exists. No documentation page
  makes it.
- The **Apple Help Book** has bundle-specific requirements (an `AppleTitle` meta
  tag, an `hiutil`-built search index, anchor-based context-sensitive help) that
  no site generator emits, so a **small custom generator** renders the
  user-facing subset of the same Markdown into the `.help` bundle. `hiutil`
  (Apple's help indexer, `/usr/bin/hiutil`) builds the searchable index.
- **`features.yml`-driven generation** keeps the README feature list, FEATURES.md
  and coverage matrices in lockstep with a single registry.

---

## 4. Scripts (`docs/scripts/`)

| Script | Purpose | Status |
|--------|---------|--------|
| `build-helpbook.py` | Render `content/help/` → `PeachCommander.help` bundle, run `hiutil`; `--all` for every language | built · gated |
| `build-site.py` | Stage `content/**` and each `help-<code>/` into MkDocs workspaces, generate `mkdocs.yml` and the nav, render 19 sites | built · gated |
| `gen-api-reference.py` | Extract public C API + doc-comments from `Plugins/SDK/*.h` → `content/reference/` | built · gated |
| `gen-overviews.py` | Generate `FEATURES.md` from `features.yml` and the glossary from `terminology.yml` | built · gated |
| `check-docs.py` | Front-matter completeness, `slug` == filename, `related`/link resolution, missing and unreferenced screenshots, terminology | built · gated |
| `check-translations.py` | Every language has one `.md` per English help topic, and a translated value per UI string | built · gated |
| `check-translation-drift.py` | Translated pages keep the English skeleton — headings, paragraph/list counts, image targets, code | built · gated |
| `check-nav-order.py` | Every page has a `group:`, every group is known, first tab is the entry and last is the deep end | built · gated |
| `i18n_help_status.py` | Authoring helper: which slugs a language is missing, and its section map | built |
| `Tools/vm/capture.py` | Drive the VM harness to (re)generate the indexed screenshots | built |
| `gen-nav.py` | ~~Build `navigation.yml` from front-matter~~ | **abandoned** — the nav is derived at build time by `build-site.py` from `group:`/`section:`/`order:` plus its `GROUP_ORDER`. There is no navigation file. |
| `gen-readme.py` | ~~Generate the README from `features.yml`~~ | **abandoned** — the README is written by hand; `Tools/check-readme.py` checks the claims in it that have a machine-readable counterpart. |

---

## 5. Screenshots — reproducible via the VM harness

All documentation screenshots are captured inside a disposable macOS VM
(`Tools/vm/`, see `Tools/vm/README.md`) so they are deterministic, isolated from
the host, and unaffected by display sleep or Screen-Recording permissions:

1. A capture spec drives the app to a known state via the DEBUG
   `-AutomationScript` hook (consistent sample content, no private data).
2. The hypervisor framebuffer is grabbed over VNC (full window) and, where
   useful, cropped to a detail region.
3. Light and dark variants are captured where the feature's appearance differs.
4. Each image is registered in `docs/metadata/screenshot-index.yml` with its
   feature, pages, theme, app version, alt text and caption.

This makes every screenshot regenerable on a new release rather than a one-off
manual capture. **This is the standing method for every documentation screenshot.**

---

## 6. Feature metadata schema (`docs/metadata/features.yml`)

Each feature is one record; the registry powers coverage checks and generated
overviews:

```yaml
- id: dual-pane-navigation           # stable slug
  name: Zwei-Panel-Navigation         # user-facing name (de)
  name_en: Dual-pane navigation
  category: navigation                # navigation | file-ops | search | network | archive | viewer | customization | plugins | system
  audiences: [user, developer]        # user | expert | developer | sdk | plugin | internal
  status: stable                      # stable | beta | planned | experimental
  backlog: F-xxx                       # optional link to BACKLOG id
  ui:
    menus: [View]
    shortcuts: ["Tab"]
    dialogs: []
  source:
    modules: [PCApp]
    types: [MainWindowController]
  documentation:
    integrated_help: true
    website: true
    developer_docs: false
    sdk_docs: false
  screenshots: [main-dual-pane]
  limitations: []
```

The `documentation.*` booleans are cross-checked against the actual generated
pages by `check-docs.py`; the result is the coverage matrix in
`docs/generated/coverage-report.md`.

---

## 7. Quality gates (`docs/scripts/check-docs.py`, CI)

Run on every docs change (and in CI on pull requests):

- internal link check + anchor validity
- missing image references / unreferenced assets
- Markdown lint + terminology consistency against `terminology.yml`
- Mermaid diagram validation
- undocumented public API / missing Help topic detection (features.yml vs pages)
- stale-screenshot detection (app version vs screenshot-index)
- Help Book build + website build must succeed

---

## 8. Updating docs when you add a feature

1. Add or update the feature's record in `docs/metadata/features.yml`.
2. Write/adjust the user topic in `docs/content/help/` (and it flows to the
   website automatically) — with `group:` as well as `section:`/`order:`, or
   `check-nav-order.py` will tell you it would land outside the tabs. Add developer
   notes under `content/developer-guide/` or `content/architecture/` if it has
   architectural impact; SDK/plugin notes under `content/sdk/` or `content/plugins/`
   if it adds an extension point.
3. **A new or renamed help topic has to exist in all 19 languages in the same
   commit** — `docs/help-<code>/<slug>.md`, same slug, same skeleton.
   `docs/scripts/i18n_help_status.py <code>` lists what a language is missing.
4. Add a spec to `docs/metadata/screenshot-specs.yml` and run
   `python3 Tools/vm/capture.py --only <id>`; it registers the image in
   `screenshot-index.yml` itself.
5. Run `check-docs.py`, `check-translations.py`, `check-translation-drift.py` and
   `check-nav-order.py`, and fix what they report.
6. Rebuild and commit both outputs: `docs/scripts/build-helpbook.py --all` (CI
   byte-compares the shipped bundle) and `docs/scripts/build-site.py`.

See `CONTRIBUTING.md` for the full contributor workflow.

## Localization (UI + Help)

English is the **source of truth** for both the app UI and the Help. The supported
languages are listed once in `docs/metadata/languages.yml` (19 today). Everything else
derives from that list.

- **App UI** lives in `Sources/PCApp/Localizable.xcstrings` — one `stringUnit` per
  language per source string. Format specifiers (`%@`, `%lld`, `%n$@`, `%%`) must be
  preserved exactly in every translation.
- **Help** lives in `docs/content/help/` (English SSOT) and `docs/help-<code>/` for each
  other language — one `.md` per topic, same `slug`/`order`/`related`; only `title`,
  `section`, and prose are translated. Screenshots are shared (English) to keep it simple.
- **Website tabs** come from a `group:` key that exists in the English pages only. A
  translated topic is placed by looking up its English counterpart's group by slug — the slug
  sets are identical, and `check-translations.py` gates that — so the 918 translated files
  need no `group:` of their own. A tab whose group holds exactly one section is labelled from
  that section's *translated* name; the one umbrella group that spans several sections has its
  per-language label in `docs/metadata/nav-groups.yml`. `check-nav-order.py` fails if either
  route cannot produce a label, which is how it caught 16 languages showing a stray English
  "Plugins" section.

**Rule — keep every language in sync.** When you add or change an English UI string or
help topic, you MUST add/update the corresponding translation for **all** languages in
`languages.yml`. CI enforces this:

```
python3 docs/scripts/check-translations.py   # fails if any language is behind
```

Build outputs cover all languages automatically:

```
python3 docs/scripts/build-helpbook.py --all  # en.lproj + <code>.lproj per language
python3 docs/scripts/build-site.py            # English site + /<code>/ Help subsites + language switcher
```

To add a new language: add it to `languages.yml`, translate the UI strings into the
`.xcstrings`, create `docs/help-<code>/` from the English topics, then run the two builds
and the coverage gate.
