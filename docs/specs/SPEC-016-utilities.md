# SPEC-016 — Utilities: Attributes, Split/Combine, Encode, Checksums, Tree, Branch View, Comments, Print

Covers: F-015, F-023, F-034, F-037, F-093..F-098. Iteration I17 mostly.

## §1 Calculate occupied space (Ctrl+L) (F-037)

Dialog: total size (bytes + human), file/dir counts, size on disk (blocks),
per-selection; live-updates while walking; also "space on volume" summary.

## §2 Change attributes dialog (F-094)

- Fields: POSIX perms grid (rwx × ugo + octal field, tri-state for mixed),
  BSD flags (hidden, locked/uchg), dates (modified/created; "use current",
  copy-from-file picker), recursive checkbox (files/dirs/both), plugin
  ContentSetValue fields section (I16+).
- Runs as queue op (progress on recursive), admin fallback per SPEC-004 §9.

## §3 Split/Combine (F-095)

- Split: part size presets (floppy…custom bytes/MB), output dir, generates
  `.001…` parts + `.crc` file (TC format: filename, size, crc32) for combine
  verification. Combine: select `.001` → auto-collect siblings, verify crc if
  present; also `cat`-compatible.

## §4 Tree & branch view (F-015, F-034)

- Tree (Ctrl+F8): left-of-panel tree pane (lazy children, follows panel);
  Alt+F10 = tree dialog with quick search jump. Both share TreeModel.
- Branch view (Ctrl+B): ResultsFS-based flattened listing of subtree (reuses
  SPEC-008 §3 infra); Shift+Ctrl+B selected-dirs-only. Operations & sorting
  work; size column shows full path column addition (auto column set).

## §5 Encode/Decode (F-096)

Files > Encode: Base64/UUE/XXE/MIME(quoted-printable) to `.b64/.uue/...`
with line length option; Decode auto-detects by content/ext. Streamed (no
size limit), queue ops.

## §6 Checksums (F-097)

- Create: dialog (algorithms multi-select: CRC32, MD5, SHA-1/256/512, BLAKE3;
  one file per checksum vs combined .sfv/.md5/.sha256; per-dir or single).
- Verify: Enter on checksum file → verification listing (ok/failed/missing)
  with re-check button; runs streamed with progress.

## §7 Comments (F-023)

- Ctrl+Z editor dialog (plain text, multi-line). Storage: `descript.ion`
  (TC-compatible, CP variable → write UTF-8 w/ BOM option) AND/OR Finder
  comments (config: which backend, default descript.ion + read both).
- Comments column + comments view mode; shown in status tips.

## §8 Volume label, system info (menu Commands)

Volume rename (where FS supports via `diskutil rename` w/ auth), System info
dialog: hw model, OS, RAM, disks with SMART-ish basics via IOKit (keep small).

## §9 Print (F-098)

Print file list (visible columns / selected / with subdirs option) via
NSPrintOperation of generated attributed text; Lister has its own print.
Export list to file (txt/csv) shares the generator (cm_CopyFileDetailsToClip
reuses it too).

## §10 Directory hotlist editor

(Referenced by SPEC-003 §7) list editor with drag reorder, submenu nodes,
import from Finder sidebar favorites (P3 nicety).

## §11 Tests

Split/combine round trip (incl. >4 GB sparse), checksum vectors (known test
vectors per algorithm), encode/decode round trips vs `base64`/`uuencode`
reference output, descript.ion round trip with unicode, tree lazy-load model.
