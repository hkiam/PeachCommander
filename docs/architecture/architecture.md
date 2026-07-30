# Architecture Overview

## Module map (build targets; dependency arrows point down)

```
                       +-----------------+
                       |      PCApp      |  AppKit UI: windows, panels, dialogs,
                       | (the only AppKit|  Lister UI, menus, toolbar, theme
                       |     target)     |
                       +--------+--------+
        +----------+---------+--+------+----------+-----------+
        v          v         v         v          v           v
   PCCommands  PCOperations PCVFS   PCArchive  PCPluginHost  PCNet
   (registry,  (copy/move/  (VFS    (libarchive (dlopen,     (FTP/FTPS/
    keymaps,    delete queue, protocol,  backend,  C bridging, SFTP as
    user cmds)  progress)    local FS) zip writer) registry)   PFX plugins)
        +----------+---------+---------+----------+-----------+
                                  v
                            PCFoundation
                     (INI, logging, ByteSize, natural sort,
                      wildcard/regex helpers, Myers diff, paths)
```

Rules: engine modules never import AppKit; PCApp contains no business logic that
tests need (thin controllers). PCArchive/PCNet/plugin-provided file systems all
implement the same `VirtualFileSystem` protocol from PCVFS.

## The VFS — the load-bearing abstraction (SPEC-006)

Every panel shows a `VFSPath` = (filesystem id, path within it). Local disks,
archive contents, FTP servers, plugin file systems, and virtual panels (search
results, branch view) are all `VirtualFileSystem` implementations:

```swift
protocol VirtualFileSystem: AnyObject, Sendable {
  var scheme: String { get }                       // "file", "zip", "ftp", "pfx:<name>", "results"
  var capabilities: VFSCapabilities { get }        // read, write, rename, watch, execute, seekableStreams…
  func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error>
  func stat(_ path: VFSPath) async throws -> VFSEntry
  func openRead(_ path: VFSPath) async throws -> VFSReadStream    // seekable if capability
  func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream
  func mkdir(_:) / delete(_:) / rename(_:to:) / setAttributes(_:) ...
  func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>?      // nil if unsupported
  func localFileIfAvailable(_ path: VFSPath) async throws -> URL? // for execute/edit (temp extraction)
}
```

Key consequences:
- **File operations are VFS→VFS** (SPEC-004): copy from zip to sftp works by
  composing streams; the op engine special-cases local→local (copyfile/clonefile)
  and same-FS server-side ops (FTP rename, zip in-place) via capabilities.
- Listing is **streamed in batches** (`VFSEntryBatch` ≈ 4096 entries) so huge
  directories render progressively.
- `..` and path semantics handled by a `VFSNavigator` (stack of nested file
  systems: leaving a zip pops back to the local FS at the archive's location).

## Panel data flow (SPEC-002)

```
VirtualFileSystem.list  --batches-->  DirectoryModel (actor)
   sort (bg thread, cached keys)  --> visible snapshot (immutable array)
   --> @MainActor PanelViewModel --> NSTableView reload/diff
FSEvents/watch --> coalesced (100 ms) --> incremental model update
icon/thumbnail/dirsize resolvers --> async fill, row-level invalidation
```

Immutable snapshots kill data races; the table never touches the live model.

## Operation engine (SPEC-004)

`OperationQueue` (actor) holds `FileOperation`s (copy/move/delete/pack/unpack/
checksum…). Each op: plan phase (enumerate sources, compute totals — streamed,
cancellable) → execute phase (worker tasks, per-file progress) → verify phase
(optional). UI subscribes to `AsyncStream<OpEvent>` coalesced to ≤30 Hz. Conflicts
(overwrite/error) suspend the op and post a question event; answers can apply
"for all". Multiple queues; default queue runs ops sequentially (TC F2 behavior),
ad-hoc ops run in their own queue (TC "background" checkbox).

## Plugin host (SPEC-012)

`PCPluginHost` dlopens plugin dylibs, resolves the C entry points into Swift
function pointers, and wraps each plugin type in an adapter:
- PCX → `ArchiveFormatProvider` used by PCArchive's format registry
- PFX → `VirtualFileSystem` (mounted under the "Network" virtual root)
- PLX → `ListerViewProvider` (returns NSView) used by Lister
- PDX → `ContentFieldProvider` used by columns/search/rename/tooltip engines
Callbacks (progress, crypt, request-password) are C function pointers into the host.

## Windows & controllers (PCApp)

- `MainWindowController` — one per window; owns two `PanelController`s + shared
  chrome (toolbar, cmdline, fkey bar). Multiple main windows allowed (post-1.0).
- `PanelController` — tabs; each tab = `PanelViewModel` + `NSTableView` subclass
  `PanelListView` (key handling per SPEC-003).
- `ListerWindowController`, `SearchController`, `SyncController`, `MultiRename-
  Controller`, `OptionsController`, `TransferManagerController` — one per dialog,
  all driven by PCCommands.

## State & persistence

- Config: INI files per ADR-007 (`docs/architecture/configuration.md`).
- Session (open tabs/paths/sort/window frames): `session.ini`, saved on change
  (debounced) and on quit; loaded at startup (F-013).
- Caches (icons, dir sizes, thumbnails): memory LRU with byte budgets
  (performance.md); optional SQLite thumbnail cache is post-1.0.
