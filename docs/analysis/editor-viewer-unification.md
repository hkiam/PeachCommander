# Editor / Viewer Unification

Status: analysis + phased plan (Phase 1 in progress).

## Decision summary

- **Keep two render substrates.** The Editor uses `NSTextView` (editing, undo,
  find-bar, IME, accessibility for free); the Viewer (`TextListerView` /
  `CodeListerView` / `HexListerView`) is custom-drawn on an mmap `FileSlice`
  (opens arbitrarily large files instantly via virtual scrolling). Merging them
  onto one substrate would sacrifice one of those. **Do not merge the engines.**
- **Unify the shell.** Window chrome (toolbar, status bar), the marks panel, the
  menu taxonomy, key equivalents, and the context menu should be identical
  across Editor and Viewer. This is the bulk of the user-visible "same look &
  feel / logically split menus" goal.
- **Plugin externalization of the core editor/viewer: no.** They are deeply wired
  (F3/F4 commands, command registry, marks, menu-bar swapping). The extension
  path already exists for *new* viewers via the **PLX lister plugin ABI** (the
  Viewer already hosts plugin listers) and via the contribution system.

## Current inconsistencies being fixed (Phase 1)

| Action | Editor (old) | Viewer (old) | Unified |
|---|---|---|---|
| Find | ⌘F (find bar) | Ctrl+F (dialog) | ⌘F |
| Find Next | ⌘G | F3 | ⌘G |
| Find Previous | — | — | ⇧⌘G |
| Mark All | ⇧⌘M | `m` | ⇧⌘M (viewer keeps `m` as extra accel) |
| Count | ⇧⌘L (selection) | menu (prompt) | ⇧⌘K |
| Go to line/offset | — | Ctrl+G | ⌘L |
| Save | ⌘S | — | ⌘S |
| Next / Prev File | — | n / p | ⌘] / ⌘[ (viewer keeps n/p) |

## Unified menu taxonomy (document windows)

`App | File | Edit | View | Search | Window | Help`

- **File** — Save*, Reload, —, Next/Previous File†, —, Close (⌘W)
- **Edit** — native (Undo/Cut/Copy/Paste/Select All) for the editor; Copy/Select
  All for the read-only viewer
- **View** — representations (Text/Code/Hex/Image/Rendered/Auto)†, —, Cycle
  Encoding, Format JSON/XML/Code, XML Tree†
- **Search** — Find/Find Next/Find Previous, Replace*, —, Go to…, XPath†, —,
  Mark All, Count, Next/Previous Mark, Marks Panel, Clear All Marks

`*` editable windows only · `†` capability-gated per window/mode. Granular mark
removal (single occurrence / by search) lives in the docked **marks panel**
(tabs with ✕), so the menu only offers "Clear All Marks".

Built by the shared `DocumentMenus` builder from a per-window
`DocumentMenuCaps`, targeting uniform `doc*` selectors both controllers
implement. `WindowContextMenuProviding.toolMenus()` returns the ordered list;
`AppMenu.buildTool(menus:…)` installs it.

## Phases

1. **Menus + keys + look&feel** — DONE: shared `DocumentMenus` taxonomy + unified
   keys, Viewer gained a toolbar, shared context menu builder.
2. **Consolidate duplicated shell code** — DONE (via composition, not a base
   class): `SyntaxTheme.color(kind:)`, `DocumentMarksPanel` (marks panel + split
   + delegate), `DocumentFile` (`.bak` save + dirty-close), plus dead-code
   removal. Chose composition over an inheritance base class to avoid reworking
   three controllers' differing init/layout.
   - Not consolidated (deliberately deferred): find/go-to — the editor uses the
     native NSTextView find bar while the viewer/hex/compare roll their own over
     `InputDialog` + `ByteSearch`/`ChunkSearcher`. Unifying these means picking
     one search UI across two substrates; left for a focused pass if wanted.
3. *(optional)* Viewer text/code as a read-only `NSTextView` under a size
   threshold (falls back to the custom virtual view for huge files) — one
   substrate for the common case, collapses most remaining duplication.
