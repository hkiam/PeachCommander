# Vision

Peach Commander is a Total Commander clone for macOS with **functional parity as the
explicit goal** — not a quick reinterpretation. Users coming from TC on Windows must
feel at home within minutes: same layout, same keys, same dialogs, same plugin idea.

## Non-negotiables

1. **Orthodox dual-pane model.** Two equal panels, one active, command line below,
   function-key bar at the bottom. Keyboard-first; the mouse is optional.
2. **Speed as a feature.** Directory with 100,000 entries opens in under a second;
   file operations never block the UI; memory stays flat when browsing huge trees.
   Budgets are codified in `docs/architecture/performance.md` and enforced by tests.
3. **Everything is a file system.** Local disks, archives, FTP servers and plugin
   file systems are browsed, copied to/from, searched and viewed identically (VFS).
4. **Extensible like TC.** Four plugin types mirroring WCX/WFX/WLX/WDX so the
   existing TC plugin ecosystem can be ported with minimal effort.
5. **A good Mac citizen where it doesn't hurt parity.** Quick Look, Tags, Services,
   Share, Spotlight, Trash, APFS clone-copies — additive, never replacing TC behavior.

## Explicit non-goals (v1)

- Mac App Store distribution (sandbox incompatible with a real file manager).
- Windows-only tech parity: registry browsing, 8.3 names, NTFS ADS UI, parallel-port
  link. Each is marked `n/a-macos` in the feature inventory with a rationale.
- Cloud-vendor integrations beyond what FS plugins provide.
- Binary compatibility with compiled Windows TC plugins (source-porting instead).

## Target user

Power users, developers, admins who live in Total Commander today and use a Mac.
They measure us on: keyboard fidelity, large-directory speed, archive handling,
multi-rename, sync, FTP/SFTP, and whether their muscle memory just works.
