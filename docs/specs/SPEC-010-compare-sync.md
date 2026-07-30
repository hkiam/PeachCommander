# SPEC-010 — Compare by Content & Synchronize Dirs

Covers: F-190..F-194.

## §1 Compare by content — selection rules

Invocation (Files menu / cm_CompareFilesByContent): exactly 2 selected in one
panel → compare those; 1 selected per panel → compare across; 0 selected →
file under cursor in each panel; else error. Same for cm_ command from sync grid.

## §2 Diff window (F-190)

- Side-by-side panes, synchronized scrolling, per-block coloring (changed/
  added/deleted), intra-line char highlighting. Binary mode: hex panes with
  byte-diff blocks (switch automatic if not text).
- Myers diff (PCFoundation) on lines; big-file guard: > 256 MB → binary compare
  mode only (streamed compare, report first diff offsets + block map).
- Edit mode (TC!): panes become editable, "copy block →/←" buttons per diff,
  save either side (with encoding preserved), redo-compare button, undo.
- Toolbar: next/prev difference, ignore-case, ignore-whitespace(all/leading),
  ignore-line-ends, font, encoding pickers per side.

## §3 Synchronize dirs (F-192)

Dialog (own window, TC layout):
- Two dir lines (left/right; prefill panel paths; either may be an archive or
  VFS path — capability-gated), file mask field + search-template dropdown.
- Checkboxes: with subdirs, by content (else size+date), ignore date (content
  only), asymmetric (right = backup target: allows delete-on-right),
  ignore-daylight-hour-diff (FAT/network), case-sensitive names.
- Compare → result grid rows: name (indented tree), left size/date, action
  icon (`->`, `<-`, `=`, `!=` conflict, delete markers in asymmetric), right
  size/date. Colors per state. Progress + cancel during compare (content
  compare streams, size-first shortcut).
- Filter buttons (toggle visibility): show `->`, show `<-`, show `=`, show
  `!=`, duplicates/singles toggles — counts on buttons.
- Row context menu: reverse direction, exclude ("don't copy"), view both,
  **compare by content** (opens §2), copy manually.
- Synchronize button: confirm dialog with counts per direction incl. deletes →
  runs as queue op with progress; errors per SPEC-004 §6.
- Empty-dir handling + removing dirs that became empty (asymmetric), option.
- Presets: save/load full parameter set (syncs.ini) (F-194).

## §4 Compare directories (panel marking) (F-191)

cm_CompareDirs: marks files existing only-here or newer than other panel (both
panels marked accordingly). cm_CompareDirsWithSubdirs variant. "Mark newer,
hide same" mode per menu. Pure model operation → easy unit tests.

## §5 Tests

- Diff engine golden tests (fixtures with known diffs, unicode, huge lines,
  CRLF); edit-and-save round trip; binary compare offsets.
- Sync scenario matrix: new/newer/older/same/conflict/only-left/only-right ×
  subdirs × asymmetric; archive-side sync (zip) round trip; cancellation.
