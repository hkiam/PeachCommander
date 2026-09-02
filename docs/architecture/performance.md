# Performance — Budgets & Rules (MANDATORY)

Speed and low resource usage are product requirements (vision.md #2). This file
defines hard budgets, enforced by PCPerfTests (docs/testing/test-strategy.md §5),
and the engineering rules that achieve them. **Read before writing or modifying
listing, operations, viewer, or search code.**

## Hard budgets (Apple Silicon M1 baseline, Release build)

| Scenario | Budget |
|---|---|
| Open directory, 10k entries | first paint < 100 ms, complete < 250 ms |
| Open directory, 100k entries | first paint < 200 ms, complete < 1.0 s |
| Open directory, 1M entries | first paint < 500 ms, complete < 5 s, RAM < 600 MB |
| Re-sort 100k loaded entries | < 150 ms |
| Quick filter keystroke on 100k entries | < 50 ms per keystroke |
| Open Lister on 50 GB file | window visible + first page < 150 ms, RAM < 100 MB |
| Scroll Lister anywhere in 50 GB file | seek < 50 ms |
| Copy throughput local SSD | ≥ 90% of `cp` for big files; small-file overhead ≤ 2× `cp -R` |
| Same-volume APFS copy w/ clone enabled | O(files), not O(bytes) |
| App cold start to interactive | < 800 ms |
| Idle: CPU ~0%, no timers > 1 Hz, RAM after browsing spree | < 300 MB (caches evict) |
| Text search 1 GB file | > 500 MB/s (memchr-based scan) |
| UI main thread | no task > 16 ms; enforced by debug assertion helper |

Budgets live machine-readable in `Tests/PCPerfTests/budgets.json`; CI compares.

## Listing rules (PCVFS local FS)

1. Use `getattrlistbulk(2)` with one attribute set fetching everything the panel
   needs (name, objtype, size, mtime/crtime, POSIX mode, flags, link count). One
   syscall per ~few-hundred entries instead of 3+ per entry. No FileManager in
   hot paths. (ADR-009)
2. Stream batches (~4096) into the model; UI paints after the first batch.
3. Entry struct is a compact value type; **no NSObject per row**, no URL objects
   stored (path built lazily), strings interned where repeated (extensions).
4. Sort off-main with precomputed sort keys (e.g. `localizedStandardCompare`
   replaced by cached collation keys / numeric-aware key). Never sort in
   `tableView(_:sortDescriptorsDidChange:)` directly.
5. Icons, dir sizes, thumbnails, content-plugin columns: **lazy, async, cached,
   cancel-on-scroll**. Never block a row draw on I/O. Placeholder first.
6. FSEvents coalesced ≥100 ms; incremental apply (insert/remove/refresh row)
   instead of full re-list where the event stream allows.
7. Formatting caches: one `DateFormatter`(-like) cached formatter; sizes formatted
   via table lookup, not NumberFormatter per row.

## File-operation rules (PCOperations)

1. local→local same volume: try `clonefile(2)` (if enabled F-088), else
   `copyfile(3)` with `COPYFILE_ALL | COPYFILE_NOFOLLOW` + progress callback.
2. Streamed VFS copies: 4–8 MB reusable buffers, at most 2 in flight per file;
   read/write overlapped. Small files: batch open/close, consider `openat`.
3. Enumeration for totals is itself streamed & cancellable; UI shows "counting…"
   but copying may begin immediately (TC behavior) with indeterminate total.
4. Progress events coalesced to ≤ 30 Hz; byte counters are atomics, no locks in
   the data path.
5. Deletes to Trash are batched per parent dir via NSWorkspace (one undo unit).
6. Never `stat` twice: plan-phase metadata flows to execute phase.

## Viewer rules (SPEC-005)

- mmap the file (`F_NOCACHE` consideration for giant sequential reads), render
  only visible lines; line-index built lazily per chunk (binary files: fixed
  16-byte rows need no index). Encoding detection on first 64 KB only.
- Never copy the whole file into a String. Ever.

## Search rules (SPEC-008)

- Producer/consumer: enumeration task feeds a bounded channel of candidates;
  N worker tasks (N = activeProcessorCount) do content matching.
- Content scan: memory-mapped, memchr for first byte, then verify; encodings by
  transcoding the needle not the haystack (search UTF-8/UTF-16LE/Latin-1 needles).
- Results stream into the UI list incrementally; cap memory via batched rows.

## Caches (central `CacheRegistry`)

| Cache | Key | Budget |
|---|---|---|
| Icon cache | ext or UTType or path (apps) | 4k entries LRU |
| Thumbnail cache | path+mtime+size (or mount+member+size) | 128 MB LRU |
| Dir-size cache | path+mtime | 64k entries |
| Collation-key cache | string | 2M keys, evict with model |
| Archive directory cache | archive path+mtime | 32 archives |
| Member stage (F-479) | mount identity + member path + size | 64 files / 256 MB LRU, *preview copies only* |

All caches respond to memory-pressure notifications (`DISPATCH_SOURCE_TYPE_MEMORYPRESSURE`). The
member stage gives up only what a *preview* staged: a copy another application has open, or one the
editor is writing, is not the app's to reclaim — so its budget bounds the evictable half and nothing
else, and `report()` states both halves rather than one number that would hide it. Copies that
outlive their mount are created one explicit gesture at a time and go at the next quit.

## Work nobody asked for (F-479)

Three surfaces read a file because the cursor moved onto it — the side panel's info page, the
embedded Quick View, and the gallery's thumbnails. They are held to `ImplicitWorkBudget`, which is
a pure function over the source's *locality* rather than over the path:

| Source | Ceiling until measured | Then |
|---|---|---|
| Local disk (`.fast`) | none (`Preview.AutoPreviewLocalMB`, 0) | unchanged |
| Share / FTP / SFTP / S3 / plugin mount (`.remote`) | 4 MB (`Preview.AutoPreviewRemoteMB`) | whatever fits in `Preview.AutoPreviewSeconds` (1.5 s) at the measured rate |
| Dataless cloud file (`.dormant`) | never (`Preview.AutoPreviewDormant`, off) | — |
| Archive member | 32 MB (`Preview.AutoPreviewArchiveMB`), on top of the locality's own | — |
| `MemberAccessCost.processPerMember` archive | never automatically | — |

Throughput comes from `TransferRateEstimator`, an EWMA per mount. Samples under 64 KB are discarded
(that is latency, not throughput) and a duration is clamped to a 1 ms floor rather than discarded —
a read too fast to time is a *fast* link, and throwing those away kept the conservative fallback in
place on exactly the links that deserved none. A *throttled* transfer and a `clonefile` copy measure
something other than the link and must never be recorded, which is why the copy engine does not feed
this.

Two sources feed it, and between them they cover every remote case:

- `MemberStage`, for anything it stages — archive members, FTP, SFTP, S3, plugin mounts. The key it
  records under has to be the key `ImplicitWorkBudget` looks up, or the samples are filed where
  nobody reads them.
- `TransferRateEstimator.probe`, one bounded read (≤ 1 MB) per directory on a **mounted share**. A
  share is `LocalFS`, so nothing stages from it and nothing else ever times it. Never for a dormant
  file: reading one is what downloads it.

An explicit gesture — Cmd+Y, Enter, F3 — is not budgeted and does not consult the function at all.

## Gallery thumbnails

Two rules, both added after the table above had described the first one for a long time without it
existing:

- **Only what is on screen.** `requestThumbnails` ran over the whole filtered listing, and it is
  called from `updateRows` — which fires for every partial batch of a listing, up to ten times a
  second. A 2,000-file folder therefore asked the system for 2,000 thumbnails, repeatedly.
  `GridLayout.indexes(intersecting:width:count:)` answers which items a viewport covers, by
  arithmetic rather than by testing every cell, and the grid re-asks on scroll (coalesced to one
  pass per run-loop turn).
- **A cache that exists.** `ThumbnailCache` over `PCFoundation.ByteBudgetCache`, keyed by identity
  and not by location — a file replaced in place keeps its path, and a path-only key would serve the
  previous file's picture for the rest of the session. Budgeted in *decoded pixels*, because a
  128×128 thumbnail at 2× is 256 KB and budgeting in points would hold four times what the number
  says.

Measured on a folder of 300 images: first visit **12** thumbnails requested (the cells actually
visible) and 0 from cache; scrolling through it requests 13 more per screen; a second visit requests
**0** and answers all 12 from cache. Locally this was churn that QuickLook's own daemon hid; the
moment a thumbnail costs a read — a share, an archive member — there is no daemon to hide it.

## Reading a member out of an archive

Bounded end to end since F-479. `ArchiveSource.reader(atIndex:password:)` hands back an
`ArchiveMemberReader` that produces the member a chunk at a time, and `ArchiveFS.openRead` prefers it
— so the viewer, the search, `MemberStage` and Alt+F9 all read a member without it existing whole:

| Backend | how |
|---|---|
| zip, stored | slices of the mapped archive — no copy at all |
| zip, deflated | `compression_stream_*`, the incremental half of the same framework `inflate` uses |
| tar | slices of the tar (mapped, for a plain `.tar`) |
| zip, **encrypted** | one-shot, deliberately: the decryption code is where a mistake hands back plausible wrong bytes, and the case it would buy does not pay for the risk |
| a format read per subprocess | one-shot, via the protocol's default |

`ArchiveExtractor` writes as the bytes arrive, into a scratch file it moves into place. Measured on a
400 MB member inside a zip, opened with Cmd+Y: **588 MB RSS before, 151 MB after**, same bytes on
disk.

Two shapes stay whole in memory regardless, because the *format* requires it: a `.tar.gz` is inflated
entirely before any member can be located (`TarReader.retainedBytes` reports it, and the archive cache
budgets against it), and an encrypted zip member as above.

## Measurement discipline

- Every perf-relevant task in iterations has a "Perf check" line: run the named
  PCPerfTests before/after; a >10% regression fails the task.
- `Tools/make-fixtures.sh` builds: `tree-10k`, `tree-100k`, `tree-1m` (generated,
  sparse), `big-50g.sparse` (sparse file), `mixed-media` fixtures.
- Use Instruments (Time Profiler, Allocations) when a budget fails; record findings
  in STATE.md.
