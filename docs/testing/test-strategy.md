# Test Strategy

Testing is part of every task, not a phase. Every iteration file lists required
tests; WORKFLOW.md forbids commits with red tests.

## 1. Test pyramid & targets

| Layer | Framework | Target | What |
|---|---|---|---|
| Unit | XCTest | `<Module>Tests` | pure logic: sorting, selection state machine, INI, placeholders, diff, detect strings, parsers |
| Integration | XCTest | PCVFSTests, PCOperationsTests, PCArchiveTests, PCNetTests | real temp-FS trees, archives, mock FTP server; the VFS conformance battery |
| UI smoke | XCUITest | PCAppUITests | keyboard walkthroughs per iteration demo script; low count, high value |
| Performance | XCTest `measure` + custom timers | PCPerfTests | budgets.json comparison (performance.md) |
| Manual | checklist | docs below | OS-panel features (Quick Look, Share, FDA onboarding) |

## 2. Fixtures (`Tools/make-fixtures.sh`)

Deterministic generator (seeded), creates under a temp/cached dir (never in repo):
- `tree-10k`, `tree-100k`, `tree-1m`: dirs with tuned fan-out, mixed names
  (unicode, spaces, long), sizes 0..1 MB (sparse where possible).
- `big-50g.sparse`: sparse file with markers at offsets (for Lister seek tests).
- `mixed-media`: png/jpg/gif/pdf/html/rtf/utf16 text/mp3-stub samples.
- `archives/`: zip variants (stored/deflate/zip64/AES/comment/cp437), tar.gz
  with symlinks, 7z, tiny rar (committed binary <100 KB allowed), corrupt files.
- `xattr-tree`: files with xattrs, resource forks, ACLs, tags, quarantine.
- `ftp-scripts/`: canned protocol dialogs for the mock server.

## 3. The VFS conformance battery

Generic test suite parameterized by a `VirtualFileSystem` factory; asserts the
full protocol contract (SPEC-006 §6). Every FS implementation (local, archive,
results, FTP mock, SFTP mock, sample PFX plugin) MUST pass it. This is the
single highest-leverage test asset in the project.

## 4. UI smoke tests

One XCUITest per iteration named `I<NN>_DemoFlow` executing that iteration's
demo script headlessly (keyboard events, assert list contents via accessibility).
Keep under 60 s each. Accessibility identifiers on all panels/dialogs from I01
(also enables VoiceOver work in I19).

## 5. Performance tests

- `budgets.json`: scenario → {metric, budget, tolerance}. Runner measures on
  fixtures, fails on breach, writes `bench-results.json` history (committed to
  a `bench/` branch or artifacts, not main).
- Run on: every task touching perf-relevant modules (WORKFLOW rule), full run
  at each iteration exit, CI nightly.

## 6. CI (GitHub Actions, added in I01 as build+test, extended over time)

- `ci.yml`: macos-15 runner: bootstrap, xcodegen, build Debug, run unit +
  integration (fixtures generated, 1m-tree scenarios skipped by env flag),
  UI smoke on main merges. Release pipeline lives in `release.yml` (I20).

## 7. Manual test checklists

`docs/testing/manual-checklists/` (created per iteration when needed): OS
integration items, multi-display, external volumes (USB, SMB), APFS vs HFS+
vs FAT/exFAT volume matrix, case-sensitive volume run of the full unit suite
(CI job with case-sensitive sparse bundle mount — cheap and catches classics).

## 8. Quality gates recap

- Task-level: tests named in task green + module tests green.
- Iteration-level: full suite + demo flow + perf run + inventory statuses updated.
- Release-level (I20): parity audit (every P1/P2 feature `done` or explicitly
  deferred by user decision), full manual checklist, notarized build smoke on
  clean macOS VM.
