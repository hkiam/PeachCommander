# SPEC-004 — File Operations Engine & Dialogs

Covers: F-080..F-101, F-067, F-122. Perf: performance.md §File-operation rules.

## §1 Engine (PCOperations)

- `FileOperation` protocol: plan → execute → (verify). Ops: Copy, Move, Delete,
  MkDir, Rename, ChangeAttributes, Checksum, Pack/Unpack (I09 adds), Split/Combine
  (I17). All VFS→VFS (SPEC-006); local fast paths per performance.md.
- `TransferQueue` actor: default queue = sequential (TC main queue via F2/
  "queue" checkbox); ad-hoc ops each get their own queue → parallel. Transfer
  Manager window lists queues/ops with pause/resume/cancel/reorder (F-085).
- Cancellation: cooperative, checked per file and per buffer. Pause = suspend
  loop (keep handles). Speed limit (KB/s) via token bucket per queue (F-084).
- Events: `AsyncStream<OpEvent>` — progressTotal, progressFile, question(...),
  error(...), log(...), done. Coalesced ≤30 Hz for UI.
- Questions: overwrite (§5), error-retry (§6). Answers may carry "apply to all
  matching" scope. Engine blocks that op only; other queues continue.

## §2 Move semantics

- Same volume local: `rename(2)`; cross-device: copy+delete with per-file
  transactionality (delete source only after target verified written & closed).
- Move of dir merges on conflict? TC asks per-file with overwrite dialog and
  merges dirs — implement merge-with-questions.

## §3 Copy/Move dialog (F-080)

- Fields: prompt "Copy <N files / 'name'> to:", editable target line prefilled
  with other panel path + mask `*.*`; wildcard rename support (`*.bak`,
  `name.*`); "as administrator" checkbox appears on EPERM retry (§9).
- Options popover: keep dates/perms/xattrs (defaults on), verify (F-090),
  only-newer, skip-all-errors, follow-symlinks (default: copy links as links).
- Buttons: OK, Queue (=F2, enqueue to main queue), Options, Cancel, "In
  background" checkbox (own queue, TC parity).
- F5 F5 (dialog open, F5 again) = TC shortcut to queue — nice-to-have P2.

## §4 Progress dialog (F-084)

Two progress bars (current file, total), byte + file counts, speed (1 s EMA),
ETA, pause/resume, cancel, "Background" button detaches dialog into Transfer
Manager (dialog closes, op continues; F-085).

## §5 Overwrite dialog (F-086)

Trigger: target exists (copy/move/unpack). Shows both files: name, size, date,
thumbnail/preview + custom fields line (configurable content fields, I16).
Buttons: Overwrite | Overwrite All | Skip | Skip All | Overwrite All Older |
Overwrite All Smaller/Larger | Rename (inline new-name field) | Auto-Rename
(target gets " (2)" suffix pattern) | Append (resume/concat, only when target
smaller — used by FTP resume) | Compare (opens SPEC-010 diff) | Cancel.
"Remember choice for this queue" per TC "All" semantics.

## §6 Errors (F-089)

Per-file failures raise question: Retry | Skip | Skip All | As Admin (§9) |
Abort. Non-interactive mode (config/checkbox): auto-skip + error list shown at
end (log window, exportable text). Disk-full: special message + pause (user can
free space and retry).

## §7 Delete (F-083)

- Default Trash (NSWorkspace, batched); Shift+F8 permanent (rm) with distinct
  confirmation listing count + total size. Dirs: recursive with progress +
  cancellation; permanent delete streams (no full pre-enumeration needed, but
  do it when < 10k for accurate progress).
- Locked/uchg files: question offering "unlock & delete". EPERM → §9 admin path.

## §8 MkDir (F-082)

- `a/b/c` nested; multiple dirs `dir1|dir2` (TC syntax); prefill: name under
  cursor (config). Invalid char mapping macOS: only `/` and NUL invalid; `:`
  shown as `:` but Finder-compat warning (config toggle).

## §9 Privileged operations (F-099, I18)

- On EPERM/EACCES the question dialog offers "Retry as administrator": a
  privileged helper (SMAppService daemon, XPC, audited command set: copy, move,
  delete, chmod, chown, mkdir) executes that one op. Helper installed on first
  use with macOS authorization prompt. Fallback if user declines helper install:
  osascript `with administrator privileges` one-shot (documented limitation).

## §10 Clipboard & drag-drop (F-091, F-067)

- Cmd/Ctrl+C: write file URLs to NSPasteboard (Finder-compatible). Cut: same +
  internal cut-marker (dim rows); Paste in panel = copy (or move if cut). Paste
  from Finder-copy works. Names-to-clipboard variants in I13 (F-092).
- Drag: rows drag as fileURLs (works to Finder/other apps). Drop on panel/tab/
  path bar/buttonbar: default copy, Cmd=move (macOS convention; show badge),
  Alt on drop = menu (copy/move/link/cancel — TC-style question option
  `Always ask` in config). Drop onto dir row targets that dir (spring-load open
  after 800 ms hover, P2).

## §11 Unicode & names (F-100)

- Preserve NFD from APFS, display NFC; compare NFC-insensitively +
  case-insensitivity by volume property (query `volumeSupportsCasePreservedNames`
  etc.). Tests: umlauts, emoji, mixed normalization collisions, 255-byte-name
  edge, deep paths > 1024 (use openat-relative traversal for deletes).

## §12 F4 edit / Shift+F4 (F-122)

- Editor per internal association (SPEC-013 §4); default: open with system
  default app for text, fallback TextEdit; config lets user set e.g. VS Code
  (`open -a`). Shift+F4: prompt filename, create empty (template option), open
  editor. Non-local VFS: download to temp, watch for changes, offer re-upload
  (TC does the same on FTP).

## §13 Tests

- Integration tests on temp trees: every § above incl. cancellation mid-file,
  pause/resume byte-accuracy, cross-device move fallback, trash + restore,
  merge-move conflicts, symlink preservation, xattr/resource-fork preservation
  (create fixture with xattrs), clone-copy identity (same volume), unicode names.
- Perf: throughput budgets (performance.md).
