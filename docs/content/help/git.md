---
title: Git
slug: git
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

The Git plugin surfaces the state of a Git repository right inside the file panel — no separate app, no terminal. It adds two columns that show each file's working-tree status and the current branch, a **Git** submenu for the everyday commands (status, stage, commit, pull, push), and it runs the `git` already installed on your Mac. It's a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**.

## What it adds

- **Two file-list columns** — *Git Status* and *Branch*. In a repository, each file shows a short status word (Modified, Added, Deleted, Untracked, Renamed, Copied, Conflict, Ignored, or Changed) and the panel shows the current branch. Turn the columns on in **Configuration ▸ Columns…** (see [View modes & sorting](view-modes-and-sorting.md)).
- **A Git menu** — under **Commands ▸ Git**, and in the right-click menu of a file, with: **Git Status…**, **Git Add (stage)**, **Git Commit…**, **Git Pull**, and **Git Push**.

![The Git Status dialog showing the current branch and the changed files in the repository](screenshots/git-status.png)
*(Figure: Git Status reports the branch and every change in the working tree.)*

## Check the status

1. Put the cursor on a file or folder inside a Git repository.
2. Choose **Commands ▸ Git ▸ Git Status…** (or right-click ▸ **Git ▸ Git Status…**).
3. A summary appears: the current branch (or *(detached)*), then either *Working tree clean.* or a list of changes, each line showing the status and the file path.

If the cursor isn't inside a repository, the plugin simply says *Not a Git repository.*

## Stage, commit, pull, push

- **Git Add (stage)** stages the file under the cursor (`git add`).
- **Git Commit…** asks for a commit message, then commits all changes (`git commit -a`). The combined output is shown so you can see exactly what happened.
- **Git Pull** does a fast-forward-only pull (`git pull --ff-only`).
- **Git Push** pushes the current branch (`git push`).

After a command that changes the repository, the active panel refreshes so the status columns stay current.

## Notes

- The plugin uses the system Git at `/usr/bin/git`. If Git isn't installed, the commands report that Git is not available. (Installing the Xcode Command Line Tools provides it.)
- Repository status is read once per folder and cached, so scrolling a large repo stays fast; the cache refreshes after any command that changes the tree.
- Commit uses `git commit -a`, which commits tracked changes; brand-new files still need **Git Add (stage)** first.
- The *Git Status* and *Branch* column headers currently show in English even in other interface languages; the values and dialogs are localized.
