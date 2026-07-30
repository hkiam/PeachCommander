# Peach Commander — Documentation System

This repository uses a **single-source-of-truth (SSOT)** documentation system:
one set of Markdown sources plus structured metadata generates every output —
the in-app macOS Help Book, the documentation website, the product homepage, the
GitHub README, feature overviews, the developer & architecture guide, and the
SDK / plugin / API reference.

> **Status:** this document defines the system. Sections marked _(planned)_ are
> part of the design but not yet wired; everything else is in place. The build
> report in `docs/generated/coverage-report.md` tracks what is implemented.

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
│   ├── navigation.yml       #   site/help navigation tree
│   ├── terminology.yml      #   glossary (canonical term → definition + forbidden synonyms)
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
| **Documentation website** (user + dev + SDK + plugins + reference) | `content/**` | MkDocs Material | `mkdocs build` |
| **Product homepage** | `content/website/` | MkDocs (landing template) | `mkdocs build` |
| **GitHub README** | `content/shared/` + `features.yml` | generator | `docs/scripts/gen-readme.py` |
| **FEATURES.md** (feature overview) | `features.yml` | generator | `docs/scripts/gen-features.py` |
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
| `build-helpbook.py` | Render `content/help/` → `PeachCommander.help` bundle, run `hiutil` | _(planned — Priority 1)_ |
| `gen-api-reference.py` | Extract public Swift/C API + doc-comments → `content/reference/` | _(planned — Priority 5)_ |
| `gen-readme.py` / `gen-features.py` | Generate README / FEATURES from `features.yml` | _(planned)_ |
| `gen-nav.py` | Build `navigation.yml` / `mkdocs.yml` nav from front-matter | _(planned)_ |
| `check-docs.py` | Link check, missing/unreferenced images, term consistency, Mermaid validation, undocumented-feature check | _(planned — §7)_ |
| `capture-screenshots.py` | Drive `Tools/vm/` to (re)generate indexed screenshots | _(planned — §5)_ |

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
   website automatically). Add developer notes under `content/developer-guide/`
   or `content/architecture/` if it has architectural impact; SDK/plugin notes
   under `content/sdk/` or `content/plugins/` if it adds an extension point.
3. Add a screenshot capture spec and run `capture-screenshots.py`; register the
   image in `screenshot-index.yml`.
4. Run `docs/scripts/check-docs.py` and fix any reported gaps.
5. Rebuild: `docs/scripts/build-helpbook.py` and `mkdocs build`.

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
