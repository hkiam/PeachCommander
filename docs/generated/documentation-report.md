# Documentation project — final report

_Peach Commander documentation system. This report accompanies the machine
coverage matrix in `coverage-report.md`._

## 1. What was produced

A single-source documentation system (see `DOCUMENTATION.md`): Markdown + metadata
in `docs/`, rendered into the in-app Apple Help Book and the MkDocs Material
website from the same sources.

| # | Deliverable | Where | Status |
|---|-------------|-------|--------|
| 1 | Feature inventory | `docs/metadata/features.yml` (64 features, 13 categories) | ✅ |
| 2 | Coverage matrix | `docs/generated/coverage-report.md` | ✅ |
| 3 | Information architecture | `DOCUMENTATION.md` + generated nav | ✅ |
| 4 | Single-source strategy | `DOCUMENTATION.md` §1–3 | ✅ |
| 5 | Build/generation concept | `DOCUMENTATION.md` §3–4 + `docs/scripts/` | ✅ |
| 6 | Integrated macOS Help | `Resources/PeachCommander.help` (37 topics) — verified in Help Viewer | ✅ |
| 7 | Homepage with USPs | `docs/content/website/index.md` (8 USPs) | ✅ |
| 8 | Online user docs | `docs/content/{help,user-guide,tutorials,troubleshooting}` | ✅ |
| 9 | Developer handbook | `docs/content/developer-guide/` (overview, onboarding, 8 module pages) | ✅ |
| 10 | Architecture docs | `docs/content/architecture/` (overview, diagrams, concurrency, security) | ✅ |
| 11 | SDK docs | `docs/content/sdk/sdk-overview.md` | ✅ |
| 12 | Plugin developer handbook | `docs/content/plugins/` (architecture + tutorials) | ✅ |
| 13 | API reference | `docs/content/reference/api-*.md` (6, generated from headers) | ✅ |
| 14 | Screenshots & crops | `docs/assets/screenshots` (39) + crops (4) | ✅ (4 deferred) |
| 15 | Screenshot index | `docs/metadata/screenshot-index.yml` | ✅ |
| 16 | Architecture diagrams | 15 Mermaid diagrams across the arch pages | ✅ |
| 17 | Tutorials | 6 user + plugin tutorials | ✅ |
| 18 | Troubleshooting | `troubleshooting/faq` + help `troubleshooting`/`known-limitations` | ✅ |
| 19 | Glossary | `docs/metadata/terminology.yml` + generated `reference/glossary.md` | ✅ |
| 20 | Maintenance/contributing | `DOCUMENTATION.md` §7–8 | ✅ |
| 21 | Automated quality checks | `docs/scripts/check-docs.py` + `.github/workflows/docs.yml` | ✅ |
| 22 | Missing/unclear report | this document | ✅ |

**Totals:** 73 content pages · 37 in-app help topics · 39 screenshots (+4 crops) ·
64 catalogued features · 15 pages with Mermaid diagrams · gate passes 0/0 ·
MkDocs `--strict` passes.

## 2. Coverage by audience

| Area | Coverage | Notes |
|------|----------|-------|
| Integrated macOS Help | **High** | All user-facing features; built, wired (`CFBundleHelpBookName`), verified live in Help Viewer. |
| Homepage | **High** | Claim, hero, 8 evidence-backed USPs, audiences, scenarios, honest download. |
| Online user docs | **High** | Help topics + installation, migration, FAQ, version notes, 6 tutorials. |
| Developer docs | **High** | Overview + onboarding + per-module reference for all 8 Swift modules. |
| Architecture | **High** | Layered overview, 15 diagrams, concurrency/persistence, security model. |
| SDK | **High** | Overview, integration (Swift/C), package, versioning. |
| Plugins | **High** | Architecture, all extension points, contributions/when/detect, tutorials. |
| API reference | **High (ABI)** | All C ABI symbols, generated from headers. Swift host-adapter API is described narratively, not auto-extracted (see §5). |
| Screenshots | **Medium-High** | 39 captured light/dark; 4 secondary shots deferred (§4). |
| Diagrams | **High** | Mermaid across architecture + plugin lifecycle. |

## 3. Auto-generated vs hand-maintained

- **Generated** (never hand-edit): `reference/api-*.md` (`gen-api-reference.py`),
  `FEATURES.md` + `reference/glossary.md` (`gen-overviews.py`), `coverage-report.md`
  (`check-docs.py`), the Help Book (`build-helpbook.py`), the site
  (`build-site.py`), all screenshots (`Tools/vm/capture.py`).
- **Hand-maintained source**: the Markdown topics in `docs/content/**`, and the
  metadata (`features.yml`, `terminology.yml`, `screenshot-specs.yml`).

## 4. Missing screenshots (deferred)

Four secondary screenshots need multi-step UI interaction the current automation
verbs don't script; their image references were removed so no broken images ship:

- `acl-editor` (ACL sheet reached from the Attributes dialog)
- `diff-window` (needs two files selected, then compare-by-content)
- `progress-dialog` (transient; needs a long-running copy captured mid-flight)
- `lister-image` (needs a real image file in the demo tree)

Follow-up: add a real image to `Tools/vm/demo-content.sh` and small automation
verbs (or a scripted multi-step spec) for the ACL/diff/progress states, then
`Tools/vm/capture.py --only …`.

## 5. Open technical questions (from the code inventory)

Surfaced during analysis; documented honestly where relevant, flagged here for
engineering follow-up:

- **Directory auto-refresh** — `FSEventsWatcher` currently **polls (~2 s)**;
  `LocalFS.watch` returns nil. True FSEvents is a placeholder. (Documented in
  `known-limitations` and `arch-concurrency-data`.)
- **Network-share mount** — `cm_MountShare`/`cm_NetConnect` implementation was not
  located in the read set (likely `NSWorkspace`); documented behaviorally.
- **Keyboard-shortcut collision** — `Cmd+Shift+D` is bound to both **Go ▸ Desktop**
  and **Net ▸ Download from URL** in `AppMenu.swift`; unresolved in the code.
- **Long paths** — absolute paths > 1023 bytes hit the OS `PATH_MAX` limit
  (backlog F-100, not a docs issue).
- **Swift host-adapter API** — the plugin *host* adapters (`PCXArchive`,
  `PFXFileSystem`, …) are documented narratively; there is no DocC/auto-extraction
  step for them yet (the C ABI is the stable public contract and is auto-generated).

## 6. Contradictions found & corrected

The original task brief and some older in-repo docs disagreed with the code; the
documentation follows the **code** as ground truth:

- **AI now ships as an optional, removable plugin** — the original inventory
  predated it and this report earlier stated "no AI/ML features exist." Since then
  the `AIAssistant.ptxplugin` was added (shared automation core in PCAutomation;
  on-device Apple Intelligence + optional cloud model; plan-then-confirm), so AI
  content is documented as a plugin, not dropped.
- **Sparkle auto-update is declared but not integrated**; documented as planned.
- **The app is currently unsigned/not notarized** (signing documented, not
  automated); the homepage/installation/security pages say so honestly.
- **`docs/product/menus-and-commands.md` is stale** (wrong menu names: it says
  "Show"/"Files" and omits the Go menu). The real menus per `AppMenu.swift` are
  **File · Edit · Mark · Commands · Net · Go · View · Configuration · Start · Help**.
  Recommend regenerating or retiring the stale `docs/product/` files.
- **Five plugin types** (pcx/pfx/plx/pdx/**ptx**) + contrib, not four.

## 7. Recommended next steps

1. Capture the 4 deferred screenshots (§4) and add German (`de.lproj`) Help Book
   localization via the existing translation pipeline.
2. Wire context-sensitive help: set `helpAnchor` on dialogs and add matching
   `anchor:` front matter (the Help Book generator already supports anchors).
3. Retire/regenerate the stale `docs/product/*.md` into the new SSOT.
4. Add a DocC or comment-extraction pass for the Swift host-adapter API (§5).
5. Publish the MkDocs site (GitHub Pages) and the Help Book with each release.

## 8. Process note

Priorities 1–3 were authored with multi-agent workflows (fan-out authoring +
review/judge critics) and finished in the main loop. During Priority 4 the org's
**monthly spend limit** was reached, which killed the remaining subagents; those
pages had already been written to disk and were validated and finalized in the main
loop, and Priority 5 was authored entirely in the main loop. All content passes the
same quality gate and strict site build regardless of how it was produced.
