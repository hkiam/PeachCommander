# DECISIONS — Architecture Decision Records

Rules: decisions here are binding. To change one, append a new ADR that supersedes
it (never rewrite history). Keep each ADR short: Context / Decision / Consequences.

---

## ADR-001: AppKit, not SwiftUI, for all performance-relevant UI
- **Context:** Panels must render 100k+ rows fluidly; TC-like dense pixel-exact
  look; SwiftUI Lists degrade at that scale and fight custom metrics.
- **Decision:** AppKit with view-based `NSTableView` (virtualized) for panels,
  custom `NSView` drawing where profiling demands it. SwiftUI allowed only for
  trivial auxiliary sheets.
- **Consequences:** More boilerplate; full control over drawing, focus, key events.

## ADR-002: XcodeGen (`project.yml`) as project source of truth
- **Context:** LLMs corrupt `.xcodeproj` plists; merges are painful.
- **Decision:** `project.yml` + `xcodegen generate` in build flow. `.xcodeproj`
  is gitignored.
- **Consequences:** Anyone (human/LLM) edits YAML only; deterministic project.

## ADR-003: Documentation and code in English
- **Context:** Small LLMs perform measurably better with English instructions/code.
- **Decision:** All docs, code, comments in English. UI localized (EN base, DE in I19).

## ADR-004: Plugin ABI = C ABI, in-process dylibs inside .bundle packages
- **Context:** TC plugins are flat C-ABI DLLs; we want function-for-function
  porting and maximum speed (content plugins are called per row!).
- **Decision:** Plugins are macOS bundles (`.pcxplugin`, `.pfxplugin`, `.plxplugin`,
  `.pdxplugin`) containing a dylib exporting the C functions defined in
  `Plugins/SDK/*.h` (UTF-8 strings, 64-bit sizes, TC names preserved:
  `OpenArchive`, `FsFindFirst`, `ListLoad`, `ContentGetValue`, …).
  Out-of-process/XPC hosting is a LATER opt-in hardening (post-1.0), not now.
- **Consequences:** A crashing plugin can crash the app (same as TC). Porting a TC
  plugin = recompile against our headers + replace Win32 calls per porting guide.

## ADR-005: libarchive as the archive engine core
- **Context:** Ships with macOS (`/usr/lib/libarchive`); reads zip, tar, gz, bz2,
  xz, 7z, iso9660, cab, rar (read), cpio, and writes zip/tar family. One battle-
  tested C library instead of many.
- **Decision:** `PCArchive` wraps libarchive for read; write via libarchive (tar/zip).
  Formats it can't handle (rar write, ace) come via PCX plugins — exactly TC's model.
- **Consequences:** ZIP64, encodings, sparse handling largely solved; we still write
  our own random-access ZIP directory reader for fast in-archive browsing (I09).

## ADR-006: Sparkle 2 for updates; Developer ID + notarized DMG for distribution
- **Context:** File manager needs full-disk powers -> Mac App Store sandbox is a
  non-starter. Sparkle is the de-facto standard outside MAS.
- **Decision:** No sandbox. Hardened runtime on. Sparkle 2 with EdDSA-signed
  appcast. DMG built by script (`Tools/make-dmg.sh`).
- **Consequences:** Requires Apple Developer ID (user-provided) for release builds.

## ADR-007: Config = INI file, TC-compatible key names where possible
- **Context:** TC stores config in `wincmd.ini`; users script/sync it; LLMs and
  humans can read/diff INI trivially. Resumability benefits from plain text.
- **Decision:** Config lives in `~/Library/Application Support/PeachCommander/`
  as INI files (`peachcmd.ini`, `buttonbar.bar`, `hotlist.ini`, `usercmd.ini`).
  Key names follow wincmd.ini conventions where a 1:1 concept exists. Passwords
  NEVER in INI — macOS Keychain only.
- **Consequences:** Own small INI parser in PCFoundation (no dependency needed);
  potential future TC-config importer becomes trivial.

## ADR-008: Swift Concurrency for the operation engine; no GCD in new code
- **Decision:** Actors + structured concurrency; cancellation via Task; progress
  via AsyncStream, coalesced to ≤ 30 UI updates/s.

## ADR-009: getattrlistbulk-based enumerator for directory listing
- **Context:** `FileManager.contentsOfDirectory` + per-file stat is O(n) syscalls
  and too slow for 100k+ entries.
- **Decision:** Custom enumerator using `getattrlistbulk(2)` fetching name, type,
  size, dates, flags, permissions in batched syscalls; icons/thumbnails resolved
  lazily and asynchronously. See docs/architecture/performance.md.

## ADR-010: Product name "Peach Commander", bundle id `com.peachcommander.app`
- Placeholder-quality decision; trivially changeable until I20 (release).

## ADR-011: FTP/SFTP implemented as file-system plugins, not core code
- **Context:** TC ships FTP built-in, but our PFX API must be proven.
- **Decision:** PCNet implements FTP (custom, on Network.framework) and SFTP
  (libssh2 via SPM) as bundled PFX plugins using the public plugin API.
- **Consequences:** API gets a real consumer early; network code stays isolated.
