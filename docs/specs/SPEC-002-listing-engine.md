# SPEC-002 — File Listing Engine & Views

Covers: F-020..F-038. Perf rules: docs/architecture/performance.md (mandatory).

## §1 Data model

```swift
struct VFSEntry {                 // compact value type, see performance.md §Listing
  var name: String                // NFC-normalized for display; raw bytes kept if needed
  var ext: String                 // display extension ("" for dirs; dotfile rule below)
  var kind: Kind                  // dir, file, symlinkDir, symlinkFile, appBundle, package
  var size: Int64                 // -1 unknown (dirs until calculated)
  var modified: Date; var created: Date?
  var posixMode: UInt16; var bsdFlags: UInt32; var isHidden: Bool
  var linkTarget: String?         // lazy
  var extra: ContentFieldsRef?    // plugin columns, lazy
}
```
- Extension rule (TC): last dot; leading-dot files → ext "" and name shown fully.
- App bundles: kind .appBundle — Enter launches, Ctrl+PgDn enters (F-051);
  other packages (.rtfd, .photoslibrary) treated as dirs with package icon +
  config `TreatPackagesAsDirs` (default: enter like TC would a dir? no — default
  Enter opens, Ctrl+PgDn enters; same rule as apps).

## §2 DirectoryModel (actor)

- Holds full entry array + derived visible snapshot (filter applied) + sort spec.
- API: `load(path)`, `applyBatch`, `sort(by:)`, `setFilter(wildcard)`,
  `applyChange(VFSChangeEvent)`, `snapshot() -> DirectorySnapshot` (immutable,
  handed to main actor).
- `..` entry synthesized (not from FS), pinned first, never selected/counted.

## §3 Views

- **Full** (default): columns Name | Ext | Size | Date | Attr. Column widths
  persisted; drag-reorder; right-click header = column menu incl. custom columns.
- **Brief**: NSCollectionView-like multi-column vertical flow, names only,
  horizontal scroll. Implemented as NSTableView with computed columns OR custom
  view — decide in I05 by prototyping both against 100k budget (record mini-ADR).
- **Thumbnails** (I17): grid, async QLThumbnailGenerator, budgeted cache.
- **Tree** (I17, SPEC-016 §4), **Comments** (I17).
- **Custom columns sets** (I16): named sets = ordered list of (source, field,
  width, alignment); sources: builtin.* or plugin fields `plugin.field.unit`.
  Auto-switch rules per path pattern (TC "file system dependent columns").

## §4 Sorting

- Keys: name (natural/logical option F-026), ext, size, date, attr, custom column.
  Dirs always first (option F-027); `..` pinned. Reverse per column. Stable.
- Collation: cached keys; TC modes: "alphabetical considering accents" vs
  "like Explorer" → map to `localizedStandardCompare` vs binary; expose both.

## §5 Size display & dir sizes

- Formats: bytes with thousands sep / KB / MB / dynamic (config `SizeStyle`).
- Space on dir: compute size (async walk, cancellable, cache by path+mtime),
  show in size column (F-030). Alt+Shift+Enter: all dirs in view (bounded
  concurrency 4). Ctrl+L dialog in I17.

## §6 Refresh & watching

- FSEvents on visible dirs of all tabs (active tab prioritized); coalesce 100 ms;
  re-stat changed entries only; full re-list on overflow/unknown events.
- Manual F2/Ctrl+R always full re-list. Network/VFS without watch: reread on
  activation if older than N s (config, default 3 s like TC's ~2 s check).

## §7 Icons (F-029)

- Modes: none / standard (by type) / all incl. exe-specific (default). By-type
  icons cached by UTType; .app icons by path (small LRU). Load async on first
  display; generic placeholder until resolved; no I/O in draw.

## §8 Hidden files (F-028)

- Hidden = dotfile OR UF_HIDDEN flag. Toggle cm_SwitchHidSys (Ctrl+H). `.` never
  shown; `..` always (except volume root option).

## §9 Attributes column (F-038)

- Compact string like `rwxr-xr-x`, plus badges: `@` (xattrs), `+` (ACL), lock
  (uchg). Tooltip expands. TC's "HRSA" concept documented as mapping table here.

## §10 Tests

- Unit: extension parsing, sort orders incl. numerals & umlauts, filter, batch
  apply, change-event application. Perf: budgets table scenarios. Fixture trees
  from Tools/make-fixtures.sh.
