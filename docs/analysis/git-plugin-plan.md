# Git plugin — assessment and plan

> **Status: phases 0–4 built (F-415…F-419).** §1 describes the first pass, §2–§3 the assessment of it,
> and §5's phases 0–4 are done: the four defects and the panel with the compare-window handover
> (including the `compareFiles` host service §6.1 asked for), the history with a lane graph, file history
> and blame, branches/stashes/sync with a cancel and conflict compare, and phase 4's ignore management,
> revert/cherry-pick, worktree- and submodule-correct status and a scannable column. Two of phase 4's
> five bullets were *decided against as written* and are argued where they stand: the status column got a
> **glyph** rather than an icon, because an icon needs the host field in §6.2 and a glyph buys most of the
> benefit for none of the ABI; and **per-repository settings** were dropped, because git already has that
> configuration and a second place to set it can only disagree with the first. What remains is the host
> work in §6 — an icon column field and localized column headers (declared asynchronous commands are
> **built**, F-422, and blame in the gutter is **built**, F-426) — and §5's **phase 5**, which re-examines the four things the first version
> of this plan put out of scope — all four settled: the conflict resolver on the markers (5a, F-420),
> credential *diagnosis* without storage and "open on the web" without an API (5b/5c, F-421), and the
> rebase bounded to the commits ahead of the upstream (5d, F-423) are **built**, with a merge editor,
> credential *storage* and the GitHub/GitLab API argued down rather than deferred. What is left is host
> work: blame in the viewer's gutter, an icon column field, localized column headers.
> Everything marked *measured* was measured in this repository or on this
> machine on 2026-08-18; everything else is named as an estimate or an open question.

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

### Phase 4 — Parity and finish · **built (F-419)**

* Status *icons* in the panel column rather than words (needs a host-side icon field, §6.2).
  → **Built as a glyph, not an icon.** `● Modified`, `⚠ Conflict`, `✚ Added`, `? Untracked`: the column
  becomes scannable — "which of these forty files is in conflict" is a glance rather than a read — without
  the ABI change §6.2 describes. The icon field stays worth having and stays host work; this is what a
  plugin can ship today, and it costs the host nothing.
* `.gitignore` management from the context menu (ignore by name, extension, directory). → **Built.** The
  pattern is decided in the SDK and unit-tested, because a leading `/` is the difference between ignoring
  *this* `build` directory and every directory called `build`, and an extension glob must *not* be
  anchored. An exact duplicate line is refused with a message; whether an existing pattern *implies* the
  new one is git's judgement, not the plugin's.
* Revert/discard a file, revert a commit, cherry-pick a commit. → **Built.** Discarding a file was
  already in the panel (phase 1); the two commit-level actions are buttons in the history window, where
  the commit is. Both refuse before they start when the working tree is not clean: git's sequencer
  requires that and phrases its refusal in terms of overwritten local changes, which reads as if the
  chosen commit were at fault. A conflicting *result* is not treated as an error — git stops and leaves
  the markers, and saying so points at the conflict command instead of at a red "failed".
* Submodule and worktree *awareness* (listed, status correct inside them) — not management. → **Built,
  and it was a defect, not a gap.** `rev-parse` is now asked for `--absolute-git-dir` as well, because in
  a linked worktree — and in a submodule — `.git` is a *file*, so `<root>/.git/index` does not exist and
  the cache's index-mtime check had nothing to compare: the column followed an outside commit only when
  the three-second TTL expired. Measured in the running app: in a linked worktree an external
  `git add` is reflected on the next listing, and inside a submodule the file shows the *submodule's*
  status and branch, which is what §7 asked phase 4 to decide.
* ~~Per-repository settings (default remote, pull strategy) in the plugin's own config pane.~~
  → **Dropped, deliberately.** git already stores exactly these (`remote.pushDefault`, `pull.ff`,
  `pull.rebase`) per repository, and everything else in the repository — hooks, CI, the command line —
  reads them from there. A second place to set the same thing cannot make the first one wrong, so it can
  only disagree with it: the plugin would either silently override the repository's own configuration or
  quietly ignore its own pane. If a UI for git's configuration is wanted, it belongs in an editor for
  `git config` values, not in a plugin's private settings, and it needs the config service §6 lists.

**Size: M.** Individually small, each one independently useful.

### Phase 5 — The four that were out of scope, reconsidered

Asked directly about interactive rebase, an own merge editor, credential storage and
GitHub/GitLab integration (2026-08-18). Re-examined rather than re-quoted, because two of the four
have a *bounded* version that is worth building and one of them closes a gap phase 3 left open. The
order below is by value per unit of work, not by the order they were asked in.

**5a. A conflict resolver on the markers — built (F-420). Size M.** Phase 3's `Resolve Conflict…` shows
*ours* against *theirs* and then leaves the reader alone with `<<<<<<<` in the file, which means a
conflict still ends in a terminal. Instead: parse the file's conflict hunks, list them, and offer
*ours / theirs / both / open in the editor* per hunk, then write the file and stage it. The parsing
is pure, testable logic (including diff3-style `|||||||` sections, CRLF, and a truncated marker set,
which must fail safely rather than eat the file); the window is the size of the blame window; no host
work is needed. This is explicitly **not** a merge editor: no base pane, no result pane, no
hunk-level text editing — the app already has an editor and a compare window, and a second one of
each is a second set of defects.

**5b. Credential diagnosis and setup — built (F-421), storing nothing. Size S.** With
`GIT_TERMINAL_PROMPT=0` a `push` that needs a secret fails immediately, which is correct and
unhelpful: the message does not say what to configure. So report the situation — is a remote HTTPS or
SSH, is an agent running and does it hold a key (`ssh-add -l`), is a credential helper configured —
and offer one action: set `credential.helper` to `osxkeychain`, which ships with git and keeps the
secret in the macOS Keychain under git's management. The plugin never sees a passphrase. Note that
`PcHostServices.crypt` *would* give a plugin a Keychain-backed store, and it is still the wrong tool
here: git looks credentials up by URL and decides their lifetime, and a second store beside it can
only be a stale copy. Writing our own `git credential-…` helper would be possible and would add a
second secret path for no gain over the one git already ships.

**5c. "Open on the web" — built (F-421). Size S.** No API, no token, no account: build the URL from the
remote (GitHub, GitLab, Bitbucket, Azure DevOps, both SSH and HTTPS forms) for a file, a line, a
commit or a branch, and hand it to the browser. It is the thing one most often wants a *file
manager* to do with a hosted repository, and it is a handful of string rules with tests.

**5d. A bounded interactive rebase — built (F-423), after §6.3. Size M–L.** The blocker I assumed
turns out not to exist: git runs `$GIT_SEQUENCE_EDITOR <todo-file>`, so
`GIT_SEQUENCE_EDITOR="cp <our-todo>"` hands git a todo list we generated, with no editor process and
no terminal, and `GIT_EDITOR` covers a reworded message the same way. What is genuinely expensive is
the *state afterwards*: a rebase that hits a conflict leaves the repository mid-sequence, so this
needs "rebase in progress" in the panel header with *Continue / Skip / Abort* — without that we
create exactly the situation where the user must finish in a terminal while the plugin says nothing.
It also needs the asynchronous command path (§6.3) — built as F-422, which is why this came last. In the
end the run itself is started from the *window* rather than from a command, so the window owns its
threading (as the branches window already did) and §6.3's value here was the precondition plus what push
and pull gained from it. There is deliberately no cancel for the run: git's sequencer cannot be killed
safely mid-flight, and Abort is the operation that undoes what it leaves behind. Scope it to *the commits ahead of the upstream*, with squash / fixup / drop /
reorder / reword — "clean up what I have not pushed yet", not a general rebase editor.

### Deliberately out of scope

Still out, after the re-examination in phase 5: a **merge editor** with base and result panes (5a
builds the useful half of it), **credential storage** of any kind (5b configures the stores that
already exist instead), the **GitHub/GitLab API** — pull requests, reviews, issues — which needs
OAuth tokens, a client, rate limits and enterprise hosts, and would drag in the token store 5b
declines to be (5c gets the web links without any of it), a **general interactive-rebase editor**
across arbitrary history (5d does the commits ahead of the upstream), and a graphical
branch-diagram editor. Each of these is a product in itself, and none of them is what a file manager
is for.

---

## 6. Host work this requires

The plugin cannot do the following through today's SDK, and each is small on the host side:

0. **Annotate lines in the editor's gutter** — *built (F-426)*: `annotateLines(path, records, title,
   commandId)`, one record per line, the click routed back as a command id rather than as a callback
   pointer. This is what blame-in-the-gutter needed, and it serves anything else per line (coverage, a
   linter) for free.
1. **Compare two files on demand** — `compareFiles(a, b, titleA, titleB)` in `PcHostServices`, so a
   plugin can put a blob written to a temp file next to the working file in the app's own compare
   window. Without it the plugin would have to open its own diff view, which is a second diff
   implementation in the same application.
2. **A column field that carries an icon** (§2.8's sibling): the content ABI returns strings today.
   Phase 4 shipped a leading glyph instead (`● Modified`), which is most of the benefit; the field is
   still what a real icon needs.
3. **Declared asynchronous commands with progress and cancel** — *built (F-422)*, and as the second
   option rather than the first: a manifest flag (`"async": true`) makes the host run the existing
   `PcRunCommand` off the main thread, plus `beginProgress`/`updateProgress`/`endProgress` in
   `PcHostServices`. No new entry point, so a plugin that does not opt in is unaffected. Two things had to
   change underneath: the host bridge's services now hop to the main actor instead of *asserting* they are
   already on it (`assumeIsolated` traps off-main, so the first asynchronous plugin would have killed the
   application), and dispatch does not await the command — awaiting merely moved the block from the main
   thread to the caller. Push and pull use it, and are cancellable.
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
* **Worktrees and submodules.** *Settled in phase 4.* `rev-parse --show-toplevel` inside a submodule
  returns the *submodule's* root, and that is what the columns report — the file's status and the
  submodule's branch, never the parent's, verified in the running app. The part that was actually broken
  was refreshing: `.git` is a file in both a linked worktree and a submodule, so the index-mtime check
  was looking at a path that does not exist. `--absolute-git-dir` fixed it.
* **Terminal plugin overlap.** With the Terminal plugin open, a user will run git there and expect the
  column to follow. That is what Phase 0's index-mtime invalidation is for, and it is worth a scenario
  of its own: commit in the terminal pane, column updates.
