# SPEC-014 — Command Registry, Button Bar, User Menu, Key Remapping

Covers: F-250..F-257, F-092. Reference: docs/product/menus-and-commands.md.

## §1 Command registry

Per menus-and-commands.md §2. Implementation notes:
- Registered at startup from static tables per module (each feature iteration
  appends its commands); id/name collisions are startup assertions.
- `CommandContext`: source/target panel refs, selection snapshot, window; every
  execution goes through `CommandDispatcher.execute(name|id, context)` — also
  the single choke point for logging/automation later.
- Command browser dialog: searchable table (id, name, category, description),
  used by toolbar editor, keymap editor, Start-menu editor (F-255).

## §2 Button bar (F-253, .bar format)

TC .bar INI format (keep compatible so users can port bars):
```
[Buttonbar]
Buttoncount=N
button1=<icon spec: path|builtin id>
cmd1=cm_Copy | em_MyCmd | /path/to/program | *.bar (subbar) | path (cd)
param1=%P %N …
path1=<start dir>
menu1=<tooltip>
iconic1=0|1
```
- Renderer: horizontal strip, 24/32 px icons, overflow chevron; right-click →
  Edit/Delete/Insert…, "Customize Toolbar…" dialog: list editor with command
  browser, icon picker (SF Symbols + .icns/.png path + app icons).
- Drag & drop: file onto program-button = launch with file as param; dir onto
  cd-button = navigate; drag item off bar (Cmd) removes; drag file WITH Shift
  onto bar creates button (F-067/TC parity).
- Subbars: cmd=*.bar switches bar (with back-arrow first button).

## §3 F-key bar & menu wiring

All menu items/toolbar/fkey buttons resolve через registry — single source.
Menu built from a menu-definition table (not IB), enabling F-257 later
(user-editable .mnu file parser P3 in I19).

### §3.1 User menu file (.mnu, F-257 — implemented)

`default.mnu` plus every `menus/*.mnu` (sorted) replace the command menus; App/Edit/
Window/Help stay standard AppKit menus. Grammar: `POPUP "&Caption"` … `END_POPUP`
(nested), `MENUITEM "&Caption", <command>`, `MENUITEM SEPARATOR`, `;`/`#`/`//`
comments; `&` mnemonic markers and `&&` are handled for display; a `"` inside a
caption is written and read doubled (`""`). `<command>` is a `cm_` name, an `em_`
name (dispatched to the user-command runner — the only route by which a `%P`-style
parameter reaches a menu entry) or a numeric TC command id.

Rules that are decisions, not gaps:
- **Encoding**: read through `WindowsTextFile` (BOM → UTF-8 → Windows-1252/Latin-1),
  because these files come from Windows; written back as UTF-8.
- **CRLF**: split on `isNewline`, never on the character `"\n"` (`"\r\n"` is one
  Character in Swift).
- **Accelerator hints** (`"&View\tF3"`) are parsed and *not* honoured: the keymap is
  the single source for shortcuts, so the menu shows what is bound.
- **Numeric ids** match TC's only where a 1:1 command exists; a token that resolves
  to nothing becomes a disabled item and is logged, never a live item that does
  nothing. Same for an `em_` name absent from usercmd.ini.
- **Lenient but not silent**: `MenuFile.parse` returns a diagnostic (file, line,
  kind) for every line it skips or repairs.
- No Load/Save/Restore dialog: `menus/*.mnu` is the drop-in path, deleting
  `default.mnu` restores the built-in menu.

## §4 User menu / Start menu & user commands (F-252)

- usercmd.ini analog: `[em_name] cmd=… param=… path=… menu=Title key=…`.
- Start menu shows em_ items; editor dialog (add/edit/delete/reorder,
  submenu support). Parameters expanded per menus-and-commands.md §2
  (%P %N %T %M %S %L… incl. list-file generation in temp).
- em_ commands usable everywhere cm_ are (buttons, keys, cmdline).

## §5 Key remapping (F-254)

- Keymap = ordered lookup: user overrides → scheme file → builtin defaults.
  File format: `[Shortcuts] key=command` e.g. `C+S+F5=cm_CopySamepanel`,
  modifiers C/A/S/W(⌘). Conflicts UI: grid editor on Options>Keys page with
  live conflict detection; "restore defaults".
- Two shipped scheme files (keyboard-shortcuts.md). Runtime: PanelListView and
  window-level `performKeyEquivalent` consult the keymap BEFORE menu key
  equivalents (menus display current mapping dynamically).

## §6 Copy-names commands (F-092)

cm_CopyNamesToClip, cm_CopyFullNamesToClip, cm_CopyNetNamesToClip (VFS URL),
cm_CopySrcPathToClip, cm_CopyFileDetailsToClip (visible columns, TSV) — all on
selection-or-cursor rule.

## §7 Tests

Registry uniqueness, param expansion matrix (%-tokens × quoting), .bar parser
round-trip with TC sample bars (fixtures), keymap precedence & conflict
detection, menu-shortcut dynamic display.
