# SPEC-007 — Archives as Directories

Covers: F-130..F-139. Engine: libarchive (ADR-005) + own zip random-access.

## §1 Format matrix (v1.0 targets)

| Format | Browse/Unpack | Pack | Modify in place | Engine |
|---|---|---|---|---|
| zip (incl. zip64, AES) | yes | yes | yes (rewrite) | own reader + libarchive fallback; write: own writer |
| tar (+gz/bz2/xz/zst) | yes | yes | rewrite | libarchive |
| gz/bz2/xz single file | yes | yes | n/a | libarchive |
| 7z | yes | no (plugin later) | no | libarchive read |
| rar | yes | no (licensing) | no | libarchive read (v4/v5 w/o encryption headers), else plugin |
| iso/cab/cpio/lzh/ar/xar | yes | no | no | libarchive |
| dmg | mount-based browse (P3, I18) | no | no | hdiutil attach |

PCX plugins (I14) extend/override by extension (plugins.ini associations F-137).

## §2 ArchiveFS (VirtualFileSystem)

- Who opens what: one `ArchiveOpening` registry (protocol in PCVFS, knowledge in
  `NativeArchiveBackend`/`PCXArchiveBackend`, assembled in PCApp). Enter, Ctrl+PgDn,
  unpack, test-archive, archive reload and the search all consult it, so a plugin
  format or a user-configured extension reaches every one of them at once (F-463).
  Background opens (a search walk) carry a size ceiling and never prompt.
- Open: read central directory / scan headers ONCE → in-memory tree (cache by
  archive path+mtime, performance.md cache table). zip: own central-directory
  parser (seek to EOCD) → O(entries) open without decompressing.
- list/stat from tree; openRead: zip stored/deflate → stream-decompress with
  seek-from-start emulation; non-seekable formats (tar.gz, 7z solid) →
  extract-to-temp on first read (progress dialog if > 20 MB), then serve local.
- Write ops (zip only in core): F5 into zip, F8, F6 rename → staged edit list,
  committed by rewriting the zip (streaming old entries raw — no recompress —
  plus new/changed). Multi-op batches commit once. Other formats: read-only
  error `unsupported` → UI offers "unpack, modify, repack" assist (P3).

## §3 Unpack (Alt+F9) (F-131)

Dialog: target path (other panel prefill), file masks, "unpack with full paths"
(default on), "overwrite existing" (else overwrite dialog per file), "unpack
each archive to its own subdir <name>" when multiple archives selected.
Runs as queue operation with progress + cancellation.

## §4 Pack (Alt+F5) (F-132)

Dialog: target line `zip:/path/name.zip`, packer radio (zip, tar, tgz, tbz,
txz + PCX plugins), options per packer: compression 0-9, "also pack paths"
(recursive with relative paths), "move to archive" (delete originals after
verify), encrypt checkbox (zip-AES256; prompt password twice, Keychain opt-in),
multivolume: n/a v1 (P3), self-extracting: n/a-macos.
Shift+Alt+F5 = move-to-archive preset (F-132). Per-file progress, background.

## §5 In-archive UX details

- Status bar shows packed+unpacked sizes; Attr column shows ratio (TC shows
  packed size column in archives — custom column set auto-switch).
- **Everything that needs a real file goes through one stage (`MemberStage`, F-479)**: F3, the hex
  editor, Quick Look (Cmd+Y), the info page, Quick View, Enter/double-click and Open With. One
  extraction is shared between them, keyed by the archive's `FileStamp` + member path + size, LRU
  with a byte budget (performance.md). Two lifetimes: a *preview* copy dies when the panel leaves
  the mount, a *handoff* copy (given to another application) outlives it, is written 0444 and is
  swept at the next launch by its own process id. Nothing is written back into the archive — the
  user is told so once, with a "don't show again" box.
- **The cursor-following previews are budgeted, the gestures are not** — see performance.md, "Work
  nobody asked for". A member over the ceiling shows its icon and a sentence naming Cmd+Y.
- F3 view (temp extract, F-120); Enter on nested archive → nested FS (F-134);
  Alt+Enter → archive properties (format, entries, sizes, comment).
- Archive comment shown after open if present (config toggle, TC behavior).
- Test archive (F-135): CRC/whole-read verify all entries, result dialog.
- Encrypted entries: password prompt once per archive session; wrong password →
  re-prompt; opt-in Keychain store keyed by archive path (F-136).

## §6 Tests

- Fixture archives generated in `Tools/make-fixtures.sh` (zip: stored/deflate/
  zip64/AES/comment/CP437-names; tar.gz incl. symlinks; 7z; rar sample binary
  committed tiny). VFS conformance battery (SPEC-006 §6) runs against ArchiveFS.
- Round-trip: pack tree → unpack → byte-compare + metadata compare.
- Fuzz-ish: truncated/corrupt archives must error cleanly, never crash
  (libarchive guards + own zip parser bounds tests).
