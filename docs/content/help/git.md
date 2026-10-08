---
title: Git
slug: git
group: Plugins
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

The Git plugin surfaces the state of a Git repository right inside the file panel — no separate app, no
terminal. It adds two columns, a **Git** submenu, a docked panel for staging and committing, and windows for
history, blame, branches, conflicts and rebasing. It drives the `git` already installed on your Mac. It's a
plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**.

## What it adds

- **Two file-list columns** — *Git Status* and *Branch*. Each file shows an icon and a short status word
  (Modified, Added, Deleted, Untracked, Renamed, Copied, Conflict, Ignored, Type changed), with *(staged)*
  where the change is already in the index; the *Branch* column shows the branch that file's repository is
  on. Turn the columns on in **Configuration ▸ Columns…** (see
  [View modes & sorting](view-modes-and-sorting.md)).
- **A Git menu** — under **Commands ▸ Git**, and in the right-click menu of a file.

![The Git Status dialog showing the current branch and the changed files in the repository](screenshots/git-status.png)
*(Figure: Git Status reports the branch and every change in the working tree.)*

## The panel: stage, commit, sync

**Commands ▸ Git ▸ Panel** docks a view showing the working tree grouped into *staged*, *changed* and
*untracked*. Select files and use **Stage**, **Unstage** or **Discard…**, type a message and press
**Commit** — with **Amend** to fold the change into the previous commit instead. **Fetch**, **Pull** and **Push** are
there too, next to the commit that usually precedes them; all three show progress and can be cancelled.

Committing uses the *index*, not `git commit -a`: what you staged is what is committed.

## History in the panel

Below its buttons the panel shows the history of every branch, remote branch and tag as a drawn graph, with the working copy as its first row. The area underneath follows the selection:

![The Git panel with the branch graph, the merge commit selected and its changed file with an inline diff](screenshots/git-panel.png)

- **Local changes** shows the staged, changed and untracked files and the commit box described above.
- A commit shows either **Commit** — author, committer, date, hash, parents, refs, signature and the full message — or **Changes**.
- **Changes** lists the touched files as a tree and the selected file's diff with line numbers; a double-click opens the compare window.
- The context menu copies hash or subject, reverts, cherry-picks, opens the commit on the web, and limits the list to **Only the current branch**.
- From the same menu a commit can be checked out, get a new branch or tag, be merged into the current branch, have the current branch rebased onto it or reset to it, or start an interactive rebase.
- The search field above the list searches the whole history — message, author name and e-mail, or a hash and its first characters — and lists the matches without the graph.

## More in the panel and in the Git menu

The working copy, the history and the **Commands ▸ Git** menu offer more than committing:

- Selecting a staged or changed file shows its diff under the list; selected lines or a whole hunk can be staged, unstaged or discarded from its context menu.
- The commit box takes several lines — a subject, a blank line, a body — commits with **Cmd+Return** and counts the subject's characters; the menu button beside it holds your last commit messages.
- **Show in the left panel** and **Show in the right panel** take a file panel to a file of the list or of a commit's changes, while the Git panel stays as it is; files stored by Git LFS are marked **LFS**.
- Stashes appear in the history as small squares above the commit they were made on, with **Apply stash**, **Pop stash** and **Drop stash…** in their context menu.
- **Reflog…** lists every move of HEAD; a commit lost to a reset or a deleted branch comes back with **New branch here…**.
- **Repository Settings…** adds, renames, re-points and removes remotes, adds, updates and removes submodules, manages worktrees, and gives this repository alone a name and e-mail for commits.
- **Create Repository Here…** and **Clone Repository…** work in the active panel's folder, and the clock beside the panel's title goes back to a recent repository.

## When git stops, and the settings

- **Push** sets the upstream the first time a branch is pushed. If the remote has commits this branch lacks, it offers **Pull, then push** or **Force push**, always with a lease that refuses if someone pushed since your last fetch; **Force push (with lease)…** is also in the right-click menu of **Push**.
- If **Pull** finds that the branch and its upstream have diverged, it asks whether to merge or to rebase instead of stopping with git's message.
- A merge, cherry-pick, revert, rebase or patch series that stops in a conflict shows a banner above the history with **Continue** and **Abort…**; a merge commit is reverted or cherry-picked against its first parent.
- Select two commits to compare them, or several to cherry-pick them in one go. **Compare with the working tree** and **Save as patch…** are in the history's menu, **Apply Patches…** is in the Git menu.
- The search field also takes filters — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — alone or together with words.
- **Bisect: mark as bad** and **Bisect: mark as good** in the history's menu start a bisect; the banner then offers **Good**, **Bad**, **Skip** and **End bisect** until git names the first bad commit.
- Stashing selected files or all changes asks for a message and whether to include untracked files or keep the index. Files in Git LFS can be locked and unlocked, and their file type tracked.
- In the branch list a branch can be renamed (**Rename…**), given an upstream (**Set upstream…**) or deleted on its server (**Delete on the remote…**).
- **Settings ▸ Git** sets the git program, your global name and e-mail, how **Pull** works, background fetch, what the history shows and how its dates look, signing, sign-off and hooks for commits, and whitespace and context lines for diffs. Authors in the history carry coloured initials.

## Files, merging, git-flow and pull requests

- **Files** beside Commit and Changes shows the whole tree at the selected commit; a file opens with line numbers, and its menu compares it with the working tree, saves it elsewhere or puts it back into the working tree (**Restore this version…**).
- **Merge editor…** — on a conflicted file in the panel, in the banner, in **Resolve Conflict…** and in the Git menu — shows the current conflict as ours, base and theirs side by side and the whole file below it, editable. **Take ours**, **Take theirs**, both in either order or **Take the base** decide a conflict, and **Save and stage** marks the file resolved once no markers are left.
- The branch symbol in the panel's header is the **Git flow** menu: **Start feature…**, **Start release…** and **Start hotfix…** create the branch from develop or main, and **Finish …** merges it back — a release or a hotfix into main with a tag, then into develop. Finishing again after a conflict carries on where it stopped.
- **Pull Requests…** in the Git menu lists the open pull requests (merge requests at GitLab) and issues of the project the remotes point at, with the checks of each; it checks a pull request out into a branch of its own and opens a new one for the current branch.
- It needs a personal access token, entered in that window and kept in the Keychain; the token is sent only to the service's API. With a token, a symbol beside the branch in the panel's header shows whether CI passed for the current commit.
- **Settings ▸ Git** names the git-flow branches and prefixes and, under **Hosting**, self-hosted GitLab or GitHub Enterprise servers.

## History, blame and the web

- **History…** lists the commits with a lane graph, the refs pointing at each one (`● main`,
  `↗ origin/main`, `⚑ v1.0`), and the files each commit touched. Enter or a double-click opens that file's
  version against its parent in the compare window. **Revert commit** and **Cherry-pick** are there, and
  both refuse up front if the working tree is not clean.
- **File History…** is the same window for one file.
- **Blame (list)…** shows every line with its commit, author and date. **Blame in the Editor** puts the same
  information in the editor's gutter, next to the line numbers: hover a line for the commit's message, click
  it to open that commit against its parent.
- **Open on the Web** opens the file, commit or branch on GitHub, GitLab, Bitbucket or Azure DevOps, built
  from the remote's URL — no account, no token. For a host whose link layout it does not know, it offers the
  repository page rather than guessing.

## Branches, stashes and tags

**Branches, Stashes & Tags…** lists all three. Switch, create, merge or delete a branch; push, pop or drop a
stash; create, delete or push a tag, or switch to one — a tag is not a branch, so it says up front that HEAD
will end up detached. Fetch, Pull and Push are in the same window and can be cancelled while they run.

Pushing a tag is a separate action on purpose: `git push` does not carry tags.

## Conflicts

**Resolve Conflict…** lists the conflicted regions of the file under the cursor and takes a decision for
each: *ours*, *theirs*, *both*, or leave it open. Then **Write file** or **Write and stage**. It refuses to
stage while a region is still open — Git will happily commit `<<<<<<<` markers — and it refuses to touch a
file whose markers it cannot read rather than guessing at them. For a region that needs both sides
interleaved by hand, **Open in editor** is one button away.

## Rebase

**Rebase…** lists the commits ahead of the upstream — the ones nobody else has yet — and lets you squash,
fix up, drop, reorder or reword them before rewriting the branch. If a rebase stops in a conflict, the same
window becomes **Continue** / **Skip commit** / **Abort rebase**, so a half-finished rebase does not have to
be finished in a terminal.

## Ignoring files, and credentials

- **Ignore This File…**, **Ignore This File Type…** and **Ignore This Folder…** add the right pattern to
  `.gitignore` — anchored where it should be, so ignoring *this* `build` folder does not ignore every folder
  called `build`.
- **Credentials…** reports how this repository authenticates: SSH or HTTPS, whether a credential helper is
  configured, whether an SSH agent is running and holds a key. Where it helps, it offers one action — let
  Git keep credentials in the macOS Keychain. The plugin never asks for, shows or stores a passphrase.

## Notes

- The plugin uses the system Git at `/usr/bin/git`, or the program chosen in **Settings ▸ Git**. If Git isn't installed, the commands report that Git is not available. (Installing the Xcode Command Line Tools provides it.)
- Repository status is read once per folder and cached, so scrolling a large repo stays fast; the cache
  refreshes after any command that changes the tree, and follows a commit made outside the app.
- Linked worktrees and submodules are supported: a file inside a submodule shows the *submodule's* status and
  branch, not the parent's.
- Every list has a context menu, **Return** runs its main action and **Cmd+R** reloads the window.
- Git LFS, `gpg` for signed commits and credential helpers are found in Homebrew's and MacPorts' folders even when the app was opened from the Finder.
