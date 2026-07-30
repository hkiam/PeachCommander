# SPEC-003 — Navigation, Cursor & Selection Model

Covers: F-050..F-065, F-035, F-060..F-064. Keys: docs/product/keyboard-shortcuts.md.

## §1 The NC model (critical to get right)

- **Cursor** (focused row) and **selection** (marked set) are independent.
- Commands operate on: selection if non-empty, else the file under cursor
  (TC rule; config "only selected" variants exist — default per TC).
- `..` can carry the cursor but never be selected or operated on.
- Cursor is per tab, persisted; entering a dir places cursor on first entry;
  going up places cursor on the dir we came from (position-memory stack,
  also used by history navigation) (F-052).

## §2 Key handling (PanelListView)

Implement in `keyDown` with the command registry — NO NSTableView default
behaviors for Space/Insert/type-select (disable `allowsTypeSelect`).

| Key | Behavior |
|---|---|
| Up/Down/PgUp/PgDn/Home/End | move cursor (no selection change) |
| Shift+same | move cursor + toggle-range like TC (marks items cursor passes) |
| Insert | toggle mark on cursor row, cursor down |
| Space | toggle mark; if dir & config on: calculate its size (async) |
| Enter | §3 |
| Backspace | parent |
| letters/digits | route per quick-search/cmdline mode (F-060, SPEC-001 §5) |

## §3 Enter semantics (F-051)

Ordered rules on cursor item:
1. `..` → parent (cursor memory).
2. dir / package-as-dir → enter.
3. archive by extension w/ association → enter as VFS (I09+); Ctrl+PgDn forces
   even without association or on self-extracting-like files.
4. app bundle → launch via NSWorkspace.
5. executable file (x-bit, Mach-O/script) → run in terminal? No: TC runs it;
   we run via NSWorkspace/Process with output window option (config).
6. document → open with associated app (internal associations first, SPEC-013).
Shift+Enter: open with… / run alternate (config). Alt+Enter: properties dialog.

## §4 Selection commands (F-054..F-058)

- Num+/Num-: dialog with wildcard (default `*.*` / last used), options: files
  only / also dirs (config `SelectDirs`). Supports multiple masks `*.c *.h`,
  exclude `| *.bak`, and saved search templates (I10+).
- Num*: invert (files only per config). Ctrl+Num+/-: all/none. Alt+Num+: same ext.
- Selection history: Num/ restores pre-operation selection; operations that
  complete successfully unmark processed items (TC behavior on copy: selection
  cleared; on failed items: stay selected) — implement exactly.
- Laptop fallbacks (no numpad): menu items + remappable; defaults documented in
  keymap (e.g. ⌥+= etc.), Mark menu always works.

## §5 Mouse modes (F-059)

- NC mode (default): left click = cursor only; right click (or right-drag) marks.
  Long right-press opens context menu (400 ms) — TC nuance.
- Windows mode: left selects w/ Ctrl(⌘)/Shift multi-select semantics; right =
  context menu. Double-click always = Enter. Middle-click = open in new tab.

## §6 Quick search & quick filter (F-060, F-035)

- Modes (config): letters-with-Ctrl+Alt (TC default), letters-direct, dialog box
  ("search dialog" small overlay showing typed string), off.
- Match: prefix by default; TC also matches word starts — implement prefix +
  substring fallback. Up/Down jump between matches keeping the string.
- Quick filter (Ctrl+S): overlay field filters visible entries live (wildcard,
  substring if no wildcard chars). Esc clears. Persists per tab until cleared
  (indicator in path bar, like TC's red filter arrow).

## §7 Hotlist, history, jumps (F-061..F-065)

- Hotlist (Ctrl+D): popup menu; entries: title→path (+ optional target-panel
  path pair), submenus, separators; "Add current dir", "Configure…" editor
  (list editor dialog). File: hotlist.ini. Double-entries navigate both panels.
- History: per tab, ring of 50; Alt+Left/Right walk; Alt+Down dropdown.
- Ctrl+Left/Right (F-063): if cursor on dir/archive → open it in OTHER panel,
  else mirror current dir to other panel. Ctrl+U swap paths (F-064).

## §8 Tests

- Unit-test the selection/cursor state machine exhaustively (it is pure logic):
  every table row above as a test case. UI smoke: keyboard-only walkthrough.
