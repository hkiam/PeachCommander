# SPEC-008 — Find Files (Alt+F7) & Duplicate Finder

Covers: F-150..F-158. Perf: performance.md §Search rules.

## §1 Dialog layout (TC parity)

Tabs: **General** | **Advanced** | **Plugins** (I16) | **Load/Save**.
Bottom: results list (streams in), buttons: Start/Cancel, View (F3), Edit (F4),
Go To File, Feed To Listbox, New Search.

- General: "Search for" masks (space-separated, `|` excludes, dir masks with
  trailing `/`), "Search in" (start dirs, multiple via `;`, dropdown history +
  "current dir" default + browse), depth limit combo ("all" / 1..N levels),
  checkboxes: search archives (F-153; label names no formats — the set follows what
  the panel can open), only selected files/dirs.
- "Find text" checkbox + field: encodings (auto/UTF-8/UTF-16/Latin-1/hex),
  case-sensitive, whole words, NOT containing, regex (F-154).
- Advanced: date between/older-than (units), size (=,>,< with units),
  attributes tri-state (hidden/system→flags, dir, executable), duplicates
  section (§4).
- Load/Save: named templates (searches.ini) — also consumed by select-group
  dialog, color rules, sync filters (F-156).

## §2 Engine

- Enumeration: VFS walk (works on local, archive, FTP…), respects depth,
  follows symlinks OFF by default (cycle guard when on), skips /System volume
  firmlink duplicates & /Volumes recursion into startup disk clone.
- Pipeline per performance.md: enumerator → bounded channel → matcher workers.
  Name match first (cheap), then attribute filters, then content (expensive).
- Content: mmap when local & regular; VFS streams otherwise (16 MB cap). An archive
  member above that cap is extracted and searched as a local file, so the same bytes
  answer the same whether they sit on disk or inside an archive (F-463).
- Archives: opened through the shared `ArchiveOpening` registry (SPEC-007 §2), not by
  the engine's own format list — so plugin formats and user-configured extensions are
  searched wherever they are browsable. A walk prefers a backend with random access
  over one that spawns a process per member, and honours `Search.ArchiveMaxBytes`.
- Skips are reported, never silent: unreadable, encrypted, over-size and too-deeply-
  nested archives are collected as `SearchNotice`s and named in the status line (F-463).
- Regex: Swift Regex; TC-dialect notes: TC uses its own flavor — document the
  few differences in help (no need to emulate exactly; parity of capability).
- Results stream to UI (batch 100/100 ms); count + current-dir status line.

## §3 Results actions

- **Feed to listbox** (F-155): creates `ResultsFS` (virtual VFS listing the hits
  flat, each entry remembering real location) and navigates active panel to it.
  Operations on entries act on real files (delete/copy work!); `..` leaves.
  Panel title `[Search results]`. This reuses branch-view infrastructure (I17
  shares ResultsFS).
- Go To File: navigate panel to containing dir, cursor on file.

## §4 Duplicate finder (F-158)

- On Advanced tab (TC): "Find duplicates" checkbox: by name (opt), by size
  (opt), by content (pairwise size prefilter → chunked hash (BLAKE3/SHA-256)
  first 128 KB → full hash on match). Results grouped with separators; "same
  content" groups selectable by mask "all but first per group" helper button.

## §5 Tests

- Fixture tree with known matches (names, contents in 4 encodings, dates,
  sizes, dupes). Assert exact hit sets. Cancel mid-search leaves no tasks.
- Perf: 100k-tree name search < 2 s cold; content 1 GB budget per perf doc.
