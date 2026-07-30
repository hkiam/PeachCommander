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
| Thumbnail cache | path+mtime+size | 128 MB LRU |
| Dir-size cache | path+mtime | 64k entries |
| Collation-key cache | string | 2M keys, evict with model |
| Archive directory cache | archive path+mtime | 32 archives |

All caches respond to memory-pressure notifications (`DISPATCH_SOURCE_TYPE_MEMORYPRESSURE`).

## Measurement discipline

- Every perf-relevant task in iterations has a "Perf check" line: run the named
  PCPerfTests before/after; a >10% regression fails the task.
- `Tools/make-fixtures.sh` builds: `tree-10k`, `tree-100k`, `tree-1m` (generated,
  sparse), `big-50g.sparse` (sparse file), `mixed-media` fixtures.
- Use Instruments (Time Profiler, Allocations) when a budget fails; record findings
  in STATE.md.
