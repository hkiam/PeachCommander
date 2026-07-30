# UI Reference — Replicating the Total Commander Look

Authoritative description of the visual target. When in doubt, mimic Total Commander
11 on Windows 10/11 with default settings, translated to macOS metrics. Screenshots
for comparison: https://www.ghisler.com/screenshots/en/ (fetch when needed).

## Main window, top to bottom

```
+------------------------------------------------------------------+
| macOS menu bar (not in window): Files Mark Commands Net Show     |
|   Configuration Start  (+ standard App/Window/Help menus)        |
+------------------------------------------------------------------+
| [Main button bar]  32px icons, flat, tooltip, right-click=edit   |
+------------------------------------------------------------------+
| [Drive bar L]                     | [Drive bar R]                |  (optional row)
| volume buttons: ⏏ macOS volumes   | same for right panel         |
+------------------------------------------------------------------+
| [Drive combo][free/total space]   | [Drive combo][free/total]    |  (header row)
+-----------------------------------+------------------------------+
| [Tab row L: tabs, + ]             | [Tab row R]                  |
| [Path bar L: /Users/x/Downloads ] | [Path bar R]  (active=blue)  |
| [Column headers: Name Ext Size Date Attr]                        |
| [ FILE LIST LEFT ]                | [ FILE LIST RIGHT ]          |
|   dense rows                      |                              |
| [Status bar L: 0 k / 231 k in 0 / 42 file(s)] | [Status bar R]   |
+-----------------------------------+------------------------------+
| [current path>] [command line________________________] [v]       |
+------------------------------------------------------------------+
| F3 View | F4 Edit | F5 Copy | F6 Move | F7 NewFolder | F8 Delete |
+------------------------------------------------------------------+
```

Every element toggleable in Options > Layout (F-270), exactly like TC.

## Metrics & style (theme constants -> PCApp/Theme.swift)

- Row height: compact — 18–20 pt @ 13 pt system-ish font (TC uses ~16px @ 12px).
  Default font: system monospaced-digit variant for size/date columns, regular for
  names. Font & size user-configurable (F-272).
- Cursor (focused row): 1 px dotted/solid rectangle + subtle fill — NOT macOS
  selection style. Selection (marked files): **red-ish file name color**
  (TC default: red names) or full-row highlight — both as options, TC default on.
- Active panel: path bar with accent background (TC: dark blue bg, white text).
  Inactive: gray. Only one panel shows a cursor.
- Column separators: thin vertical lines; sortable headers with sort arrow;
  `Name` and `Ext` are separate columns (F-020).
- Directories: shown as `[name]` in brackets when icons are off (TC classic), with
  icons on: folder icon + name. `..` up-dir entry always first.
- Colors (light default): window bg #FFFFFF list, text #000000, selected #FF0000,
  cursor frame #000080-ish. Full table + dark-mode mapping in Theme.swift; user
  overrides via Colors options page (F-032). Dark mode: same structure, TC-like
  dark palette (F-295).
- Function key bar: 6–8 equal-width flat buttons with "F3 View" style labels;
  pressing Ctrl/Alt/Shift live-relabels them to the modified commands (nice TC
  detail, P2).

## Key dialogs (replicate layout & defaults)

Each dialog has a detailed section in its owning spec; this is the index:

| Dialog | Spec | TC reference behavior |
|---|---|---|
| Copy/Move (F5/F6) | SPEC-004 §3 | Single-line target w/ wildcards, options button, queue checkbox, F2=queue |
| Overwrite confirmation | SPEC-004 §5 | Buttons: Overwrite, All, Skip, Skip all, Rename, Append, Smaller, Older + previews |
| Progress | SPEC-004 §4 | Two bars (file/total), speed, pause, background button |
| MkDir (F7) | SPEC-004 §6 | Single field, creates nested paths |
| Delete confirm | SPEC-004 §7 | List of items, Trash vs permanent |
| Change attributes | SPEC-016 §2 | perms/flags/dates + recurse + plugin fields |
| Pack (Alt+F5) | SPEC-007 §4 | Packer choice radio, options, "move to archive", target line |
| Unpack (Alt+F9) | SPEC-007 §5 | Target + masks + "unpack paths" |
| Find files (Alt+F7) | SPEC-008 §2 | Tabs: General / Advanced / Plugins / Load-Save; results list + feed-to-listbox |
| Multi-rename (Ctrl+M) | SPEC-009 §2 | Mask fields, counter def, search/replace, preview grid, F2 load/save |
| Synchronize dirs | SPEC-010 §3 | Two path rows, filter, checkboxes (subdirs, by content, ignore date), result grid with <- = -> icons, sync button |
| Compare by content | SPEC-010 §2 | Side-by-side, diff blocks colored, edit mode, next/prev diff |
| FTP connect (Ctrl+F) | SPEC-011 §2 | Session list + New/Edit/Delete, folders |
| Options | SPEC-013 §2 | Left tree of pages, live Apply |
| Plugin manager | SPEC-012 §8 | 4 type tabs, install/remove/configure |
| About | SPEC-001 | version, credits, license note |

## Interaction fidelity rules

1. Keyboard focus NEVER gets trapped in a toolbar/pathbar; Tab always toggles panels
   (except inside dialogs/command line per TC rules, SPEC-003).
2. Typing plain characters with command line visible goes to command line; with
   quick-search mode "letters only" they go to quick search — configurable, TC
   default: letters go to command line, quick search = Ctrl+Alt+letters (F-060).
3. Enter on a file executes/opens; on `..` goes up; on dir enters; on archive enters
   archive (F-051). Modifier table in SPEC-003.
4. All list views virtualized; resizing window never re-enumerates the directory.
5. Every menu action shows its shortcut; every toolbar button has a tooltip with
   the cm_ name (helps users script buttons — TC does this too).

## macOS translation decisions

- Menu bar lives in the macOS system menu bar (not in-window). Order/content per
  TC with an added standard "Peach Commander" app menu (About/Settings/Quit).
- TC "Configuration > Options" == app Settings (Cmd+,) — same dialog.
- Windows drive letters -> volume list from `FileManager.mountedVolumeURLs` +
  `/Volumes`, with eject buttons; "\\" root == "/" of current volume (F-065).
- System file dialogs, alerts, and fonts follow macOS; the PANEL AREA follows TC.
