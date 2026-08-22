# Vision

Peach Commander is a native macOS dual-pane file manager in the Total Commander
tradition. It is **not a clone that copies pixels** — it takes the concept that has
worked for decades and interprets it properly for the Mac. What is held to parity is
*capability*, not appearance: someone arriving from TC on Windows should find their
keys, their workflow and their plugin idea intact within minutes, on a Mac app that
looks and behaves like one.

(The public wording in `README.md` and on the website is the canonical framing. This
file said "clone … functional parity as the explicit goal" until 2026-08-22, which
contradicted both — and this is the file somebody copies marketing copy out of.)

## Non-negotiables

1. **Orthodox dual-pane model.** Two equal panels, one active, command line below,
   function-key bar at the bottom. Keyboard-first; the mouse is optional.
2. **Speed as a feature.** Directory with 100,000 entries opens in under a second;
   file operations never block the UI; memory stays flat when browsing huge trees.
   Budgets are codified in `docs/architecture/performance.md` and enforced by tests.
3. **Everything is a file system.** Local disks, archives, FTP servers and plugin
   file systems are browsed, copied to/from, searched and viewed identically (VFS).
4. **Extensible like TC, and then some.** **Five** plugin kinds: four mirroring
   WCX/WFX/WLX/WDX, so the existing TC plugin ecosystem ports with minimal effort,
   plus a contributions ABI for declared commands and docked views that TC has no
   equivalent for. (This said "four" until 2026-08-22, while README, the website and
   the API reference all said five.)
5. **A good Mac citizen where it doesn't hurt parity.** Quick Look, Tags, Services,
   Share, Spotlight, Trash, APFS clone-copies — additive, never replacing TC behavior.

## Explicit non-goals (v1)

- Mac App Store distribution (sandbox incompatible with a real file manager).
- Windows-only tech parity: registry browsing, 8.3 names, NTFS ADS UI, parallel-port
  link. Each is marked `n/a-macos` in the feature inventory with a rationale.
- Cloud-vendor integrations beyond what FS plugins provide.
- Binary compatibility with compiled Windows TC plugins (source-porting instead).

## Target user

Four audiences, in the order the website addresses them:

- **Developers and power users** who live on the keyboard and move code, builds and
  assets all day.
- **Sysadmins and IT** who need FTP/SFTP/WebDAV, checksums, sync and batch operations
  in one place.
- **People migrating from Total Commander** who want the same two-panel muscle memory,
  `wincmd.ini` import and a TC-classic key scheme included.
- **Anyone who moves a lot of files** and has outgrown drag-and-drop in Finder.

The migrating group is the strictest, and measures us on keyboard fidelity,
large-directory speed, archive handling, multi-rename, sync, FTP/SFTP and whether
muscle memory just works. The others measure us on whether the first five minutes make
sense without knowing what an "orthodox file manager" is.
