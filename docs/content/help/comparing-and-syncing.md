---
title: Comparing & synchronizing
slug: comparing-and-syncing
group: Using Peach Commander
section: Power tools
order: 90
related: [multi-rename]
---

When you keep two copies of the same folder — a working folder and a backup, a laptop and a network share, a project and its archive — Peach Commander helps you see exactly what changed and bring the two sides back in step. You can synchronize two directories, compare individual files line by line, and inspect files byte by byte when you need certainty down to the last character.

## Synchronize two directories

1. Open the folder you want to sync in the left panel and the folder to compare it against in the right panel.
2. Choose **Commands ▸ Synchronize Dirs…**. The two folder paths are filled in from your panels.
3. Set how thorough the comparison should be: include subfolders, compare **by content** (not just by date and size), or ignore the modification date.
4. Add a filter mask (for example `*.jpg;*.png`) if you only want to sync certain files.
5. Review the result grid. Each row shows a file on the left, a direction arrow in the middle, and the matching file on the right. The arrows tell you what will happen: **→** copies left to right, **←** copies right to left, and **=** means the two are identical.
6. Adjust individual rows if you disagree with a suggested direction, then click the synchronize button to carry out the changes.

![The synchronize directories window with two folder paths and a result grid of files with left, equal, and right arrows](screenshots/sync-dialog.png)
*(Figure: The Synchronize Dirs window compares both sides and proposes a copy direction for each file.)*

## Compare two files by content

1. Select one file in each panel (or two files in the same panel).
2. Choose **File ▸ Compare by Content…**.
3. The two files open side by side with their differences highlighted. Use the next/previous controls to jump between changed blocks.
4. If you turn on edit mode, you can adjust either file directly and save your changes.

![The compare window showing two text files side by side with differing lines highlighted](screenshots/diff-window.png)
*(Figure: Comparing two text files; changed lines are highlighted on both sides.)*

## Compare files byte by byte

When two files look the same but you need to prove they are truly identical (or find the one byte that differs), use the binary comparison. It shows both files in a hex view with mismatching bytes marked, which is ideal for verifying downloads, checking encoded data, or confirming an exact copy.

## Compare directory listings

To spot differences between two open folders at a glance, choose **Mark ▸ Compare Directories** (Shift+F2). Peach Commander marks the files that differ or are missing on the other side, so you can act on them with the usual copy, move, and delete commands.

## Filter what a synchronisation includes

The mask field holds one include list over file names. For what it cannot express, **Filter…** beside it opens a sheet with three tabs. Whatever you set there applies to the *next* comparison, and the button then says how many criteria are active — a filter you cannot see is how a backup ends up incomplete while the window reports that it is done.

- **Exclude** takes patterns separated by `;` or `|`. A name without a slash matches at any depth (`*.tmp`), a trailing slash means a folder and everything in it (`node_modules/`), and a pattern containing a slash matches the relative path (`src/*/generated`). Case is ignored.
- **Size** and **date** judge a pair as a whole: if either side falls outside the range, the whole pair is left out. That is deliberate. Applied to one side only, an exclusion would make the pair look one-sided and turn into a copy in the wrong direction.
- **Within the last N days** is measured from each comparison, not from when a preset was saved, so a saved job keeps meaning "the last month".
- The **Plugins** tab asks a content plugin about the side a file would be copied from. It needs a real file, so it is offered only when both sides are folders on this Mac.

An excluded folder is not deleted in mirror mode either — a mirror removes only what it actually compared. The status line says how many entries the filter held back, next to what the run will do. A filter is saved and loaded with the sync preset it belongs to.

## Keep two folders the same, both ways

The two original modes cannot tell one thing apart: a file that is on one side only is either **new
here** or **deleted there**, and they look identical. So the symmetric mode copies it — delete
something on your laptop, synchronise, and it comes back from the backup — and the mirror mode
deletes, but only in one direction, so anything you did on the target side is lost.

**Two-way (remember)** answers that by keeping a record of what both folders looked like the last
time they agreed. With that record a deletion on one side can be carried to the other.

- The **first** run of a pair has no record, so it behaves exactly as before and deletes nothing. It
  writes the record. The mode does its work from the second run on.
- A deletion carried over is shown in its own colour with a `⇒🗑` arrow and is **not ticked**. It is
  the one row that comes from the app's memory rather than from anything you can see in the two
  folders, so you arm it yourself. Clicking the arrow offers the other answers: copy the file back
  instead, or leave both sides alone.
- Changed on one side and deleted on the other is a **conflict**, never a deletion. So is a file
  that changed on both sides.
- Nothing is deleted on the strength of an absence the comparison could not confirm — an unreadable
  folder, or one the filter held back, proves nothing about what is inside it.
- Two folders on this Mac only. Not a server and not an archive: a deletion in an archive rewrites
  it, a deletion on a server is permanent, and this mode is not the one to try that with.

**There is no undo for a deletion.** On this Mac a deleted file goes to the Trash and can be put back
from the Finder; that is the whole of the safety net. The record lives with the app's settings, so
moving one of the folders means the pair has no history any more — and a run without a history
deletes nothing, which is the way that failure should point.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Compare directory listings (mark differing files) | Shift+F2 |
| Compare by content | File ▸ Compare by Content… |
| Synchronize directories | Commands ▸ Synchronize Dirs… |

## Notes

- **By content vs. by date/size.** A quick comparison matches files by size and modification date, which is fast but can be fooled when timestamps differ for identical files. Turn on **by content** for a reliable result at the cost of reading every file.
- **Subfolders and filters.** The synchronize window can descend into subfolders and can be limited with a filter mask, so you can sync just the file types you care about.
- **You stay in control.** Synchronizing never runs on its own — you review the proposed directions in the result grid and can change any of them before anything is copied.
- **Presets.** Frequently used synchronize setups can be saved and reused so you don't re-enter the same options each time.
