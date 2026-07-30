# SPEC-001 — App Shell, Dual Panels, Command Line, F-Key Bar

Covers: F-001..F-014, F-005, F-066. UI target: docs/product/ui-reference.md.

## §1 Window composition

- One `MainWindowController` per window. Layout (top→bottom): toolbar (I13),
  drive bars (optional row), panel headers (drive combo + free space), tab rows,
  path bars, two panels in an `NSSplitView` (vertical divider), status bars,
  command-line row, function-key bar. Every chrome element has a visibility flag
  in `[Layout]` config and updates live from Options (F-270).
- Splitter: draggable; double-click resets 50/50; right-click offers 25/50/75;
  position persisted per window in session.ini. Min panel width 200 pt.
- Horizontal arrangement flag swaps split axis (F-002).

## §2 Panel identity & activation

- Exactly one active panel; activation via click, Tab, Ctrl+I, or programmatic
  (command targets "source"/"target" panel). Active path bar uses accent style.
- Panels are position-agnostic ("left/right" only for commands that need it,
  e.g. cm_LeftOpenDrives). All commands operate on source/target abstraction.

## §3 Function-key bar

- 6 buttons default (F3..F8) + optional F1/F2 per config. Click = command.
- Live relabel when Ctrl/Alt/Shift held (P2 polish, I13): e.g. Shift → "F5 Copy"
  becomes "F5 Copy (same dir)". Labels from command registry help strings.

## §4 Drive/volume UI

- Drive combo lists mounted volumes: icon, name, free/total. Selecting navigates
  panel to volume root, remembering last path per volume (TC behavior).
- Drive bar buttons: one per volume; network volumes get distinct icon; eject
  button (⏏) on removable/network. React to mount/unmount notifications live.
- Special entries appended: Home (~), Network (PFX plugin root, I15), Trash (I18),
  Recents? no (not TC). Cloud folders appear naturally as dirs.

## §5 Command line (F-005, F-066)

- Single-line field + history dropdown (persisted, 50 entries). Focus rules:
  typing letters in panel focuses cmdline and inserts (default TC mode); Esc
  clears & returns focus to panel; Enter executes.
- Execution: `cd`/path → navigate. `cm_*`/`em_*` → command registry. Else run via
  `/bin/zsh -lc` in active dir; if config "open terminal for output" or command
  ends with output, show output window (simple NSTextView console). Env vars, `~`.
- Ctrl+Enter/Ctrl+Shift+Enter append name/path (quoted if spaces).
- Tab-completion of paths (files+dirs of typed prefix).

## §6 App lifecycle

- Startup: load config → restore session (windows, tabs, paths; invalid paths fall
  back to nearest existing ancestor, then home) → first paint target < 800 ms.
- Quit: save session; running operations prompt (cancel / continue in background
  is n/a — block quit like TC with confirmation).
- Single instance by default (config `AllowMultipleInstances=0`): second launch
  activates existing (NSApplication default behavior covers this).

## §7 Acceptance highlights

- Kill the app any time; relaunch restores exact tabs/paths/sort/active panel.
- Every layout element can be hidden and the window reflows without artifacts.
- No main-thread I/O during startup path restoration (async list with placeholder).
