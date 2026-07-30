# Evaluating CodeEditSourceEditor for Peach Commander

Status: evaluation / recommendation (no dependency added yet — this is a
decision for the maintainer to make).

## What it is (verified facts)

[CodeEditSourceEditor](https://github.com/CodeEditApp/CodeEditSourceEditor) — the
editor component extracted from the CodeEdit IDE. "An Xcode-inspired code editor
view written in Swift powered by tree-sitter."

- **License:** MIT. **Min OS:** macOS 13 (matches Peach's deployment target).
- **APIs:** SwiftUI `SourceEditor(...)` (with `SourceEditorConfiguration`,
  `EditorTheme`, `SourceEditorState`, `TextViewCoordinator`) **and** an AppKit
  `TextViewController`.
- **Features:** tree-sitter syntax highlighting + themes, find & replace,
  code completion hooks, current-line highlight, **minimap**, bracket matching,
  inline messages (warnings/errors), text diff, validation.
- **Underlying view:** `CodeEditTextView.TextView` — a **custom `NSView` text
  system** (CoreText, its own `TextLayoutManager`), **not** `NSTextView` and
  **not** TextKit. Fast initial layout, "supports large documents", but no
  documented mmap/virtualization, and explicitly *not* feature-parity with the
  system text view (no RTL, etc.).
- **Dependencies:** CodeEditTextView, CodeEditLanguages (=0.1.20, pinned;
  tree-sitter grammars), CodeEditSymbols, TextFormation (ChimeHQ),
  swift-custom-dump, SwiftLintPlugin — plus transitively SwiftTreeSitter and many
  tree-sitter C grammar targets.
- **Maturity:** the maintainers state plainly: *"currently in development and it
  is not ready for production use."*

## Fit for Peach Commander

**Genuine wins:**
- Tree-sitter highlighting across dozens of languages — a large upgrade over
  Peach's lightweight `SyntaxHighlighter` (4 token kinds, a handful of lexers).
- Free, high-quality features: line numbers, minimap, bracket matching,
  current-line highlight, find/replace, inline diagnostics.
- MIT + macOS 13 fit; an AppKit entry point exists (no forced SwiftUI).

**Real costs / risks:**
1. **Not production-ready** (their words) — API churn and bugs, against Peach's
   goal of a polished TC-parity app.
2. **Its own text engine, not `NSTextView`.** Everything Phases 1–3 built on
   `NSTextView` — `TextMarkController` marks, the native find-bar unification, the
   `MarksPanelView` wiring — does **not** carry over. Marks would be
   re-implemented against their highlight/`TextViewCoordinator` API; their find
   replaces ours. Adopting it partly undoes recent work.
3. **Heavy dependency tree** (tree-sitter + grammars): build time, binary size,
   SwiftPM wiring in an XcodeGen project, a pinned grammar-pack version.
4. **Editor-shaped, not viewer-shaped.** It fits the **Editor** and the viewer's
   **code mode** for reasonable sizes. It does *not* replace the viewer's reason
   to exist: instant huge-file viewing (mmap virtual scroll), hex, image,
   rendered-Markdown/HTML, XML-tree, plugin listers. CodeEditTextView loads the
   whole document.

## Recommendation

**Do not rip out the current editor now.** Two reasons: the "not production
ready" caveat, and that it would reverse the NSTextView marks/find unification we
just landed.

Capture the biggest win at a fraction of the cost instead:

- **Near term (recommended): tree-sitter highlighting behind our own abstraction.**
  Adopt `SwiftTreeSitter` + tree-sitter grammars (or `CodeEditLanguages`) *behind
  the existing `SyntaxHighlighter` interface*, keeping our `NSTextView` shell,
  marks, find, and the whole Phase 1–3 taxonomy. Big highlighting upgrade,
  minimal disruption, no UI rework.

- **Medium term (optional): CodeEditSourceEditor as a "rich code" substrate.**
  When it declares production-readiness, adopt it *behind an adapter* so the swap
  is contained:
  - Add via XcodeGen `packages:` in `project.yml`; depend on
    `CodeEditSourceEditor` from `PCApp`.
  - Introduce a `CodeDocumentView` protocol the document window talks to
    (load text, set language/theme, get/set selection, reveal range, apply
    marks). Provide two implementations: today's `NSTextView` and a
    CodeEditSourceEditor-backed one. The Phase 1–2 shell (DocumentMenus,
    DocumentMarksPanel, DocumentFile) stays and drives either.
  - Use the **AppKit `TextViewController`** (not the SwiftUI `SourceEditor`) to
    avoid a SwiftUI bridge.
  - Keep the custom virtual viewer for huge files, hex, and non-text modes — the
    adapter only serves the editor + viewer code mode under a size threshold.
  - Re-implement marks via their highlight API / `TextViewCoordinator`; route
    their find/replace into our **Search** menu.
  - Surface the "extra" features the user wants in the menus: **View ▸ Minimap /
    Line Numbers / Wrap**, bracket-matching, **Search ▸** their find/replace,
    and inline diagnostics — genuine additions over today's editor.

- **Fallback:** revisit later; the near-term tree-sitter step is valuable
  regardless of whether full adoption ever happens.

## Alternative: STTextView + Neon + tree-sitter

A more à-la-carte stack (verify versions against a pinned release):

- **Neon** (ChimeHQ) — incremental/async tree-sitter highlighting engine.
  **BSD-3-Clause**, depends on `SwiftTreeSitter`, mature (widely used ChimeHQ
  code). Crucially **text-system agnostic**: its `TextViewHighlighter`
  integrates with a **plain `NSTextView`** (TextKit), as well as other views.
- **SwiftTreeSitter + grammars** — the parsing layer (permissive: MIT/Apache).
- **STTextView** (krzyzanowskim) — a TextKit-2 `NSView` text view (gutter/line
  numbers, find, multi-cursor, Neon plugin for highlighting). **But:**
  **GPL v3.0** (commercial license sold separately) and **macOS 14+** minimum.

**Assessment.** The decisive facts are STTextView's **GPLv3 license** and
**macOS 14** floor:
- GPLv3 imposes copyleft on Peach if distributed — a likely dealbreaker for a
  would-be polished/commercial TC clone, unless Peach itself goes GPL or a
  commercial STTextView license is bought.
- macOS 14 would drop Peach's macOS 13 support.

The **valuable, low-risk half of this stack is Neon + tree-sitter — without
STTextView.** Because Neon highlights a normal `NSTextView`, we can:
- Keep the `NSTextView` we already adopted in Phase 3 → **native find bar and our
  `TextMarkController` marks stay intact**, Phases 1–3 untouched.
- Replace Peach's hand-rolled `SyntaxHighlighter` with Neon-driven tree-sitter
  highlighting **behind the same interface** — dozens of languages, incremental,
  async, scales to large docs.
- Stay on **macOS 13** with **permissive licensing** (BSD-3 + MIT/Apache).

This is the same "near-term" recommendation as above, now with a concrete,
mature engine (Neon) instead of a bespoke highlighter — and it avoids both
CodeEditSourceEditor's "not production ready" caveat and STTextView's GPL/OS
constraints.

### Ranking for Peach's highlighting goal
1. **Neon + SwiftTreeSitter on our existing NSTextView** — best fit: mature,
   permissive, macOS 13, keeps native find + marks + shell. *Recommended.*
2. **CodeEditSourceEditor** (behind an adapter, later) — most batteries-included,
   MIT/macOS 13, but not production-ready and its own non-NSTextView engine.
3. **STTextView + Neon** — capable text engine, but GPLv3 + macOS 14 make it a
   poor fit unless those constraints are acceptable.

## Implemented (option 1 chosen)

Tree-sitter highlighting is now wired behind Peach's own text views:
- `TreeSitterLanguages` — extension → `LanguageConfiguration` registry (grammar +
  `highlights.scm`). JSON, C, Java (SPM grammars with bundled queries) and
  JavaScript, Python (vendored — see below). Theme-aware colors via
  `Theme.currentSyntax`.
- Viewer read-only NSTextView: one-shot `TreeSitterHighlighter`.
- Editor live NSTextView: **Neon** `TextViewHighlighter` (incremental, async),
  `NeonEditorHighlighter`. Non-tree-sitter languages fall back to the built-in
  lexer. Marks (backgroundColor) coexist with Neon (foregroundColor).
- SPM deps: `SwiftTreeSitter`, `Neon`, `TreeSitterJSON`, `TreeSitterC` (+ their
  transitive `TreeSitter`/`Rearrange`), all matched on ChimeHQ/SwiftTreeSitter to
  avoid a duplicate-target conflict.

**Grammar packaging caveat (resolved by vendoring):** grammars with an external
scanner (JavaScript, Python, …) fail to link as SPM packages because their
manifests add `scanner.c` only via a relative-path `fileExists` check that is
false during manifest evaluation. Scanner-less grammars (JSON, C, Java) are used
directly as SPM packages; scanner-based ones (JavaScript, Python) are **vendored**
as local `CTreeSitterJS` / `CTreeSitterPython` static-library targets that
compile `parser.c` + `scanner.c` unconditionally, with `highlights.scm` shipped
as a PCApp resource. Verified live (JS regex/template literals, Python
INDENT/DEDENT both parse correctly).

## Bottom line

Integrable and appealing for the editor/code-view, and macOS-13/MIT make it a
clean technical fit — but its "not production ready" status and its non-NSTextView
engine (which would undo recent marks/find work) argue against a full swap right
now. Best value: pull in **tree-sitter highlighting** behind our current
`SyntaxHighlighter`, and gate full CodeEditSourceEditor adoption behind an adapter
for when it stabilizes.
