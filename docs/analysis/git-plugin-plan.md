# Git plugin — assessment and plan

> **Status: phases 0–3 built (F-415…F-418), phase 4 planned.** §1 describes the first pass, §2–§3 the
> assessment of it, and §5's phase 0 and phase 1 are done — the four defects and the panel with the compare-window
> handover, including the `compareFiles` host service §6.1 asked for. Phase 2 (history, file history, blame) is built too, with
> blame as a table rather than in the viewer's gutter — that needs a host service for line
> annotations, which stays in §6. Phase 3 (branches, stashes, sync with cancel, conflict
> compare) is built as well. What remains is phase 4 — status icons in the column, ignore
> management, revert/cherry-pick, submodule and worktree awareness — plus the host services in
> §6 that blame-in-the-gutter and localized column headers need. Everything marked *measured* was measured in this repository or on
> this machine on 2026-08-18; everything else is named as an estimate or an open question.

The Git plugin shipped as a first pass: two panel columns and five commands. This document asks two
questions — is what exists technically sound, and is it *functionally* worth having next to
TortoiseGit, GitFinder or Git Extensions — and then plans an extension in phases that each ship on
their own.

---

## 1. What exists

`Plugins/Git/git.swift`, 209 lines, a PDX content plugin with a contribution surface:

* **Two columns** — `Git Status` (per file: Modified / Added / Untracked / Conflict / …) and `Branch`.
* **Five commands** — Status…, Add (stage), Commit…, Push, Pull — in `Commands ▸ Git` and in the
  panel's context menu, all acting on the repository the cursor item belongs to.
* **How** — it runs `/usr/bin/git` as a subprocess, computes `status --porcelain` plus the branch once
  per directory and caches that, keyed by the file's parent directory.
* Output is shown with `presentInfo`, i.e. an `NSAlert` holding git's raw text.

That is a reasonable first pass and it does something no other panel column does. What follows is
what is wrong with it and what is missing from it.

---

## 2. Technical assessment

### 2.1 Every command runs on the main thread — *measured*

`ContributionRegistry` is `@MainActor` (`Sources/PCApp/ContributionRegistry.swift:16`) and calls
`plugin.runCommand` synchronously, so `PcRunCommand` executes on the main thread. `git push` and
`git pull` are network operations that can take minutes, can stall on a credential prompt, and cannot
be cancelled: for their whole duration the application is frozen — no scrolling, no other panel, no
Escape. This is the same defect class as F-414 (a quadratic redraw in the viewer), and it is worse
here because the wait is unbounded rather than merely long.

It is not the plugin's fault alone: the SDK offers no way to say "this command is long". Either the
plugin spawns its own thread and reports back (possible today, but every plugin then reinvents
progress and cancellation), or the host gains a declared *asynchronous* command with progress and
cancel. §6 treats that as host work, because the second Git command that needs it already exists
(fetch) and the FTP side of the app has the same shape solved (`TransferManager`).

### 2.2 The status column is empty for every file with a non-ASCII name — *measured*

`git status --porcelain` quotes paths outside ASCII, by default (`core.quotePath` is true). Measured
in a scratch repository:

```
A  "Gr\303\266\303\237e mit Leerzeichen.txt"
A  normal.txt
```

The plugin takes the text after the status letters as a relative path verbatim, so for that file it
builds `<root>/"Gr\303\266\303\237e mit Leerzeichen.txt"` and the lookup by real path never matches:
the column stays blank. A German, French or Czech working copy hits this on the first file with an
umlaut. `--porcelain=v2 -z` reports raw bytes with no quoting and also carries the staged/unstaged
distinction the plugin needs anyway (§3.1), so the fix and the next feature are the same change.

### 2.3 `git` is a hardcoded path

`/usr/bin/git` is not git on macOS; it is a shim from the Command Line Tools. On a machine where the
tools are not installed, invoking it opens the installer dialog — from a *column value*, i.e. while
the user is merely scrolling a folder. And a user with a newer git in `/opt/homebrew/bin` gets the
older one silently. The plugin should resolve git once (setting → `PATH` → `/usr/bin/git`), report its
absence once, and disable itself rather than ask macOS to install anything.

### 2.4 The cache is keyed and invalidated wrongly

Keyed by the file's *parent directory*, so a repository with a thousand directories holds a thousand
entries each containing the whole repository's status; bounded by `if count > 256 { removeAll() }`,
which throws away everything at 257. It is invalidated only when one of the plugin's own commands
runs — so a commit made in a terminal, or by the app's own Terminal plugin two panes away, leaves the
column showing the state from before, indefinitely.

Keyed by repository root, invalidated on the mtime of `.git/index` plus the directory being listed,
it costs one `stat` per listing and is right in both directions.

### 2.5 "Add (stage)" and "Commit" contradict each other

`plugin.git.commit` runs `git commit -a -m …`, which commits every tracked change and ignores the
index. So the *only* staging command in the plugin has no effect on the *only* commit command next to
it: you stage one file, commit, and get all of them. Either the commit respects the index (correct,
and what every reference product does) or the staging command should not be there.

### 2.6 The reporting surface is git's stdout in a modal

`Git Status…` renders up to 40 changed files into an alert and appends "… and 5 more". An alert is
not a place to work: you cannot select a file in it, open it, stage it, or diff it. This is the single
biggest gap between the plugin and its references, and it is a UI question rather than a git one (§5).

### 2.7 No tests, no gate

Of the shipped plugins with behaviour, this is the only one with no test target and no VM scenario.
The status parser, the label mapping and the repo-root resolution are pure functions over text and
belong in a test the way `PluginCSV` now is (F-411) — a fixture repository per case, created in a temp
directory, no network.

### 2.8 Column headers are not localized

Deliberate and documented in the source: the host derives the content-field id from the field *name*,
so translating it would rename the column and invalidate saved column sets. Needs a host-side
id/title split; it is a small host change and it is not urgent, but it should be named here because
every other visible string in the plugin *is* translated.

---

## 3. Functional assessment — against TortoiseGit, GitFinder, Git Extensions

What the three references have in common, roughly in the order their users reach for it:

| Capability | TortoiseGit | GitFinder | Git Extensions | Here |
|---|---|---|---|---|
| Per-file status in the file list | overlay icons | overlay badges | — | ✅ column |
| Branch, ahead/behind at a glance | ✅ | ✅ | ✅ | branch only |
| Staged vs unstaged, per file/hunk | ✅ | ✅ (file) | ✅ (hunk) | ❌ |
| Commit dialog with file list + diff | ✅ | ✅ | ✅ | message-only alert |
| Diff of a working file | ✅ | ✅ | ✅ | ❌ |
| Log / history with graph | ✅ | ✅ | ✅ | ❌ |
| File history / blame | ✅ | ✅ | ✅ | ❌ |
| Branch & tag management | ✅ | ✅ | ✅ | ❌ |
| Merge / rebase / cherry-pick | ✅ | partly | ✅ | ❌ |
| Conflict resolution | ✅ own tool | opens editor | ✅ | ❌ |
| Stash | ✅ | ✅ | ✅ | ❌ |
| Fetch / pull / push with progress | ✅ | ✅ | ✅ | blocking, no progress |
| Ignore management | ✅ | ✅ | ✅ | ❌ |
| Submodules | ✅ | — | ✅ | ❌ |

The honest summary: what exists is the *awareness* layer (which file is dirty, which branch am I on)
and a shortcut for the three commands a user types most. Everything that makes those products worth
opening — seeing *what* changed, choosing what goes into a commit, and reading history — is missing.

### 3.1 What this app can do that the references cannot

Worth planning around, because it decides what to build rather than copy:

* **Two panels and a compare window.** The app already diffs two files with syntax highlighting
  (`DiffWindowController`, F-190). A Git diff is that window with one side filled from a blob — no new
  diff UI, no new highlighter.
* **A viewer and an editor with a gutter and an outline.** Blame belongs in the viewer's gutter, not
  in a separate window; "open this file as of that commit" is the viewer with a different byte source.
* **View containers.** The sidebar and the bottom dock already host plugin views (Notes, Terminal,
  System Monitor). A Git panel is a view, not a window, and it can follow the active panel through
  `PcNotifyView("dir", …)`.
* **Panel columns.** Status per file is *already* where a Finder extension has to draw badges.
* **An automation harness.** Every phase below can have a VM scenario, which is what keeps a plugin
  this stateful honest.

---

## 4. Third-party components — the licence question

The brief allows dependencies if the licence fits. The recommendation is **no new dependency**, for
reasons worth writing down:

* **libgit2** is GPL-2.0 *with a linking exception*. The exception does permit linking from an
  Apache-2.0 application, so this is not strictly out of reach — but this repository already decided
  the same question the other way for filesystem readers (F-403: "libext2fs is LGPL, libsquashfs
  LGPL-3 and btrfs-progs GPL-2, none of which this Apache-2.0 product can take"), and a GPL core
  behind an MIT wrapper (SwiftGit2) does not change what is being linked. Adding it would also mean
  vendoring and keeping current a C library with its own CVE stream.
* **The git binary is the compatible interface.** It is on every machine that has developer tools, it
  is the reference implementation, and its plumbing is designed for exactly this: `--porcelain=v2`,
  `-z`, `--no-optional-locks`, `cat-file --batch`, `for-each-ref --format`, `log --format` with a
  field separator. TortoiseGit and Git Extensions both drive the binary for most of what they do.
* **Nothing else is needed.** The commit graph is a lane assignment over `log --parents` and is a
  hundred lines; diff rendering, syntax highlighting, text search and the outline all exist in the
  app already.

One dependency *would* be worth revisiting later, with a measurement rather than a preference:
`git blame` on a large file is slow enough to notice, and libgit2's blame is faster. That is a Phase 3
question and only if measured.

---

## 5. Plan

Five phases. Each one ships on its own, each one has its own gate, and the order is chosen so that the
two defects that lose data or freeze the app are fixed first — not so that the most visible feature
comes first.

### Phase 0 — Foundations (fixes §2.1–2.4, §2.7)

* Resolve `git` once: setting `git.executable` → `PATH` → `/usr/bin/git`, and never trigger the CLT
  installer from a column value. Report absence once, then behave as "no repository".
* Move every command off the main thread. Short reads (status, branch) stay synchronous but bounded;
  push/pull/fetch run on a queue and report through a host progress surface (§6 names the host work).
* Parse `status --porcelain=v2 -z`: raw paths, plus the staged/unstaged split that Phase 1 needs.
* Cache by repository root, invalidated on `.git/index` mtime + the listed directory's mtime, bounded
  per repository rather than by a global 256.
* Tests: a fixture repository per case (non-ASCII names, spaces, renames, conflicts, submodule stub,
  detached HEAD, empty repo, worktree), asserting the parser and the label mapping.
* Gate: a VM scenario `git-columns` that creates a repo in the guest, dirties a file with an umlaut in
  its name, and asserts the column.

**Size: S–M.** No new UI. This is the phase that makes the rest safe to build.

### Phase 1 — The Git panel (fixes §2.5, §2.6; the functional core)

A view in the bottom dock (default) or the sidebar, following the active panel:

* Header: repository name, branch, ahead/behind, dirty count, and the current operation if one is
  running.
* Three sections — Staged, Changed, Untracked — with per-file stage/unstage/discard, keyboard-driven,
  multi-select.
* Commit box: message (with the last messages available), amend, sign-off; commits the **index**.
* Double-click or Enter on a file: diff in the app's compare window (working tree against index or
  HEAD, chosen by which section the file is in).
* The five existing commands stay, now acting through the same model.

**Size: L.** This is where the plugin stops being a status light. Needs one host addition (§6.1).

### Phase 2 — History and blame

* A log view (same container): commits with author/date/subject, a lane graph computed from
  `log --parents`, the changed files of the selected commit, and a diff per file into the compare
  window.
* File history from the panel's context menu; "open this file as of commit X" in the viewer.
* Blame in the viewer's gutter, with commit and author per line, and a jump to that commit in the log.

**Size: L.** Nothing here needs a dependency; the graph is ours (§4).

### Phase 3 — Branches, remotes, sync

* Branch and tag list: create, switch, merge, delete, with a plain refusal when the working tree is
  dirty rather than a half-finished switch.
* Stash: list, push, pop, drop, show.
* Fetch / pull / push with progress and cancel, credentials left to git's own credential helper and
  the SSH agent — the plugin must never prompt for or store a secret itself.
* Conflicts: a list, and each entry opens in the compare window; three-way where the app's compare can
  take a base, two-way otherwise.

**Size: M–L.** The sync part depends on Phase 0's asynchronous command path.

### Phase 4 — Parity and finish

* Status *icons* in the panel column rather than words (needs a host-side icon field, §6.2).
* `.gitignore` management from the context menu (ignore by name, extension, directory).
* Revert/discard a file, revert a commit, cherry-pick a commit.
* Submodule and worktree *awareness* (listed, status correct inside them) — not management.
* Per-repository settings (default remote, pull strategy) in the plugin's own config pane.

**Size: M.** Individually small, each one independently useful.

### Deliberately out of scope

Interactive rebase UI, a merge *editor* of our own (the compare window plus the editor is enough),
credential storage, GitHub/GitLab integration (pull requests are a different product), and a
graphical branch-diagram editor. Each is a product in itself, and none is what a file manager is for.

---

## 6. Host work this requires

The plugin cannot do the following through today's SDK, and each is small on the host side:

1. **Compare two files on demand** — `compareFiles(a, b, titleA, titleB)` in `PcHostServices`, so a
   plugin can put a blob written to a temp file next to the working file in the app's own compare
   window. Without it the plugin would have to open its own diff view, which is a second diff
   implementation in the same application.
2. **A column field that carries an icon** (§2.8's sibling): the content ABI returns strings today.
3. **Declared asynchronous commands with progress and cancel** — `PcRunCommandAsync` plus a progress
   handle, or the host running `PcRunCommand` off the main thread when the manifest says the command
   is long. Needed by push/pull/fetch and by anything in Phase 3.
4. **Localized column headers** — the id/title split described in §2.8.

Each addition bumps the plugin SDK version and belongs in `Plugins/SDK/contrib.h` with a note in
`PORTING.md`.

---

## 7. Risks and open questions

* **Repository size.** `status` on a 100k-file repository costs seconds. Phase 0's cache makes it once
  per index change rather than once per listing, but a budget and a measurement are needed —
  `PCPerfTests` has the shape for it.
* **git versions.** `--porcelain=v2` needs git ≥ 2.11 (2016), `for-each-ref --format` older still.
  The resolved binary's version should be read once and the two or three features that need a newer
  git guarded rather than assumed.
* **Credential prompts.** A `push` that wants a passphrase must not block the app invisibly. With
  `GIT_TERMINAL_PROMPT=0` git fails fast instead of waiting on a terminal that does not exist; the
  plugin then says so and points at the SSH agent. Open: whether to offer an in-app passphrase sheet
  at all (leaning no).
* **Worktrees and submodules.** `rev-parse --show-toplevel` inside a submodule returns the
  *submodule's* root, which is correct but means "the repository" is ambiguous in the UI. Phase 4
  decides how to show it; Phase 0 must at least not report the parent's status for a submodule's file.
* **Terminal plugin overlap.** With the Terminal plugin open, a user will run git there and expect the
  column to follow. That is what Phase 0's index-mtime invalidation is for, and it is worth a scenario
  of its own: commit in the terminal pane, column updates.
