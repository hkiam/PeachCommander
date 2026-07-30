# Tech Stack

Deployment target: **macOS 13.0+**, Apple Silicon + Intel (universal binary).
Toolchain: Xcode 16+, Swift 5.10+.

## Core choices (see DECISIONS.md for rationale)

| Area | Choice | ADR |
|---|---|---|
| UI | AppKit, view-based NSTableView, custom drawing where needed | ADR-001 |
| Project | XcodeGen (`project.yml`), SPM local packages for engine modules | ADR-002 |
| Concurrency | Swift Concurrency (actors, AsyncStream); no new GCD | ADR-008 |
| Listing | getattrlistbulk(2) custom enumerator; FSEvents for watching | ADR-009 |
| Copy engine | copyfile(3) with callbacks; clonefile(2) fast-path; manual read/write streaming fallback for VFS | ADR-008 |
| Archives | libarchive (system `/usr/lib/libarchive.dylib` via module map) + own random-access zip reader/writer | ADR-005 |
| Plugins | C-ABI dylibs in bundles, dlopen/dlsym | ADR-004 |
| Config | Own INI parser (PCFoundation) | ADR-007 |
| Network | Network.framework (FTP/FTPS custom impl), libssh2 (SPM: e.g. swift-libssh2 or vendored) for SFTP | ADR-011 |
| Updates | Sparkle 2 (SPM) | ADR-006 |
| Diff | Own Myers-diff implementation in PCFoundation (small, no dep) | — |
| Regex | NSRegularExpression/Swift Regex (ICU) | — |
| Hashing | CryptoKit (MD5 via Insecure, SHA family); CRC32 own/zlib; BLAKE3 optional vendored | — |
| Logging | os.Logger + optional file log ring buffer | — |
| Help | Bundled markdown -> HTML help viewer (WKWebView, local only) | — |

## Allowed third-party dependencies (pin exact versions in project.yml/Package.swift)

1. **Sparkle** (updates) — added in I20 only.
2. **libssh2 wrapper** (SFTP) — added in I15 only. Prefer a thin vendored build
   over a heavy Swift wrapper; decision recorded when I15 starts (mini-ADR).
3. Nothing else without a new ADR. (libarchive & zlib & SQLite come from the OS.)

Optional (P3, needs ADR when introduced): SQLite (search index/thumbnails cache),
BLAKE3 reference C implementation.

## System APIs cheat-sheet (implementers: read before the relevant iteration)

- Enumeration: `getattrlistbulk(2)`, `ATTR_CMN_*`, fallback `fts(3)`.
- Watching: `FSEventStreamCreate` (per panel path, latency 0.1 s, coalesce).
- Volumes: `FileManager.mountedVolumeURLs`, `NSWorkspace.shared.notificationCenter`
  mount/unmount notifications, `unmountAndEjectDevice`.
- Trash: `NSWorkspace.recycle` / `FileManager.trashItem`.
- Icons: `NSWorkspace.icon(forFile:)` cached by (type, ext); thumbnails:
  `QLThumbnailGenerator` (I17).
- Quick Look panel: `QLPreviewPanel` (I18).
- Metadata: `NSMetadataQuery`/`MDItemCreate` for Spotlight fields (I18).
- Permissions: `FileManager` POSIX perms, `acl(3)` for ACLs, `getxattr(2)` family.
- Privileged ops: `SMAppService` + XPC helper, or `AuthorizationExecuteWithPrivileges`
  replacement pattern (osascript admin fallback documented in SPEC-004 §9).
- Full Disk Access detection: attempt read of `~/Library/Mail` etc., guide user (I18).
- Clipboard file ops: `NSPasteboard` `.fileURL` types; cut = Finder-compatible
  `NSPasteboard` promise behavior (best effort).
- Session restore: own state file (not NSDocument restoration).

## Build & scripts (Tools/)

| Script | Purpose | Introduced |
|---|---|---|
| `Tools/bootstrap.sh` | install xcodegen (brew) + generate project | I01 |
| `Tools/build.sh` | xcodegen + xcodebuild build (Debug) | I01 |
| `Tools/test.sh` | run all test targets, pretty output | I01 |
| `Tools/make-fixtures.sh` | generate test file trees (incl. 100k-entry dir, sparse big files) | I02 |
| `Tools/bench.sh` | run PCPerfTests, compare against budgets JSON | I19 (skeleton I04) |
| `Tools/make-dmg.sh` | build Release, sign, notarize, staple, DMG | I20 |
| `Tools/make-appcast.sh` | Sparkle appcast generation | I20 |
