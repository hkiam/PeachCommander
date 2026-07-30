---
title: Comparing & synchronizing
slug: comparing-and-syncing
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
