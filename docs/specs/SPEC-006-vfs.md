# SPEC-006 — Virtual File System (VFS) Layer

The keystone abstraction (architecture.md §VFS). Built in I08 by refactoring the
then-working local-FS panels; archives (I09), search results (I10), plugins/FTP
(I15) plug into it.

## §1 Interfaces (PCVFS)

See architecture.md for the `VirtualFileSystem` protocol. Additional pieces:

- `VFSPath`: value type `{ fsID: VFSIdentifier, components: [String] }`, plus
  display string. NEVER string-concatenate paths manually.
- `VFSCapabilities`: OptionSet — `.read .write .rename .delete .mkdir .watch
  .seekableRead .resumeWrite .serverSideCopy .execute .attributes .trash
  .caseSensitive .preservesHardlinks`
- `VFSEntryBatch`: `[VFSEntry]` + `isFinal` flag.
- `VFSReadStream`/`VFSWriteStream`: async chunked read/write, optional `seek`,
  `expectedLength`, cancellation. Local impl: FileHandle/mmap-backed.
- Errors: `VFSError` enum: notFound, permissionDenied(needsElevation:Bool),
  exists, noSpace, connectionLost(retryable:Bool), cancelled, unsupported,
  underlying(code, message).

## §2 Registry & navigator

- `VFSRegistry`: scheme → factory. Built-ins: `file` (LocalFS). Later: `archive`
  (I09, factory takes host-VFS + archive path), `results` (I10), `pfx:*` (I15).
- `VFSNavigator` per tab: stack of (fs, path). Entering an archive pushes an
  ArchiveFS whose backing store is the CURRENT fs (recursion → nested archives
  F-134 work for free, via temp extraction when the backing store can't mmap).
  Leaving via `..` at fs root pops, cursor lands on the archive file.
- Display path composition: `/Users/x/a.zip/dir/file.txt` and
  `ftp://site/dir` — parseable back (used by cmdline cd, hotlist, session).

## §3 LocalFS implementation notes

- list(): getattrlistbulk batches (ADR-009); stat(): getattrlist single.
- watch(): FSEvents stream mapped to VFSChangeEvent (created/removed/modified/
  renamed/mustRescan).
- openRead: mmap-capable; openWrite: temp-file + atomic-rename option (config;
  default OFF for big files — write in place like TC, but pre-allocate via
  `fcntl F_PREALLOCATE`).
- Trash capability → NSWorkspace. Execute → NSWorkspace/Process.

## §4 Operation-engine contract

- Copy planning uses capabilities: local→local same-vol → clone/copyfile path;
  same-FS with `.serverSideCopy` → fs.copy (FTP site-to-site later); else
  stream copy. Resume: `.resumeWrite` + Append answer (SPEC-004 §5).
- All engine code MUST work against VFS mocks (test doubles in PCVFSTests).

## §5 Refactor plan for I08 (order matters, keep app green)

1. Introduce types + LocalFS; adapt DirectoryModel to consume VFS streams.
2. Move panel path state to VFSNavigator (session format migrates: add scheme).
3. Port operation engine internals to VFS streams; keep local fast paths.
4. Port Lister input to VFSReadStream/localFileIfAvailable.
5. Delete all direct FileManager/POSIX calls outside PCVFS (grep-gate: CI check
   `Tools/check-vfs-purity.sh` — allowlist PCVFS + Tools).

## §6 Tests

- Protocol conformance suite (generic test battery run against ANY VFS impl:
  list/stat/read/write/rename/delete semantics, unicode, cancellation) — this
  battery is reused by archive/FTP/plugin FS tests later. Invest here.
