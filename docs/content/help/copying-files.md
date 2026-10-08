---
title: Copying files
slug: copying-files
group: Using Peach Commander
section: Files & folders
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander is built around two side-by-side panels: one holds the files you are working with, the other is the destination. Copying takes whatever is selected in the active panel and puts a duplicate in the folder shown in the other panel, leaving the originals in place. This is the fastest way to duplicate files and folders between two locations without dragging.

## Copy a selection to the other panel

1. In one panel, open the folder that contains the items you want to copy.
2. In the other panel, open the folder where the copies should go.
3. Select the files and folders to copy. If nothing is selected, the item under the cursor is used.
4. Press F5. The copy dialog opens, showing the destination path already filled in.

![The copy dialog with the destination path and options](screenshots/copy-dialog.png)
*(Figure: The copy dialog. The target path points at the other panel; use the options to fine-tune the copy.)*

5. Adjust the destination if needed, then confirm to start copying.

## Copy options

Before you confirm, you can change how the copy behaves:

- **Only newer files** — skips any item whose copy already exists and is the same age or newer, so only changed files are updated.
- **Run in background** — hands the copy to the background transfer manager instead of showing the progress window.
- **Queue for later** — adds the copy to the background queue without starting it yet.
- **Rename mask** — type a wildcard pattern in the target field (for example `*.bak`) to rename items as they are copied.

Two settings apply to every copy and live in **Configuration ▸ Settings… ▸ Copy/Delete**: preserving dates, permissions, and other attributes (on by default), and a speed limit that keeps a large copy from saturating your disk or network connection. For jobs in the queue, see Background transfers.

## Progress

A progress window shows the whole job with file and byte counts, the transfer speed, and the time left; when a file takes more than a moment, a second bar above it shows that file. You can pause and resume at any time. The speed menu next to the buttons limits this copy straight away (1, 5 or 20 MB/s, or full speed) without changing the limit in Configuration; **Default** goes back to that limit. **Background** hands the running copy to the background transfer manager: the window closes and the copy goes on there.

![The transfer progress dialog with a bar for the current file and one for the whole job, file and byte counts, a speed menu, and Background, Pause and Cancel buttons](screenshots/progress-dialog.png)
*(Figure: The progress dialog shown during a copy or move.)*

## Handling files that already exist

If a copy would replace an existing file, Peach Commander stops and asks what to do. A preview of both files helps you decide.

![The overwrite conflict dialog comparing two files](screenshots/overwrite-dialog.png)
*(Figure: The overwrite dialog compares the existing file with the one being copied.)*

Your choices include:

- **Overwrite** the existing file, or **Overwrite all** to apply that to every remaining conflict.
- **Skip** this file, or **Skip all** remaining conflicts.
- **Rename** the incoming copy automatically so both files are kept.
- **Append** the incoming data to the end of the existing file.
- Overwrite only when the source is **newer** or **larger** than the existing file.

## Shortcuts

| Action | Key |
|---|---|
| Copy selection to the other panel | F5 |
| Copy in the same folder (make a renamed duplicate) | Shift+F5 |
| Open the background transfer manager | Cmd+Shift+B |

## Notes

- Copying between two locations on the same disk uses a fast clone when the disk supports it, so large files copy almost instantly and use little extra space.
- Folders are copied with everything inside them.
- To move files instead of copying them, use F6. To watch or manage queued jobs, open the background transfer manager with Cmd+Shift+B.
