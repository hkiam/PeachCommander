---
title: Workspaces
slug: workspaces
group: Customise
section: Customizing
order: 118
related: [settings, panels-and-tabs]
---

A workspace is a named context you work in: "Clean up backups", "Sort applicant documents". Each one remembers both panels, every open tab, which tab is active on each side, the view mode, the folder tree, the back/forward history and which files you had marked, the quick filter, and the window's arrangement — the side panel, the dock, the bars and where the divider sits. Switching between them takes one click, and nothing is ever lost on the way — a workspace is never saved, because it never ends.

Until you create a second one there is nothing to see. No bar, no menu, no shortcuts.

## How to

1. Set up both panels for the job at hand: open the folders, add the tabs, choose the view you want.
2. Open the **Go** menu and choose **Workspaces…**, then **New Workspace…**. Give it a name.
3. A strip of coloured chips appears across the top of the window, and a **Workspace** menu appears in the menu bar. The new workspace starts as a copy of the arrangement you were in.
4. Set the new workspace up for its own job. The one you came from keeps what it had.
5. Click a chip to switch, or press **Ctrl+1** to **Ctrl+9**. Everything switches with it.

## Coming back to a starting point

Each workspace also remembers the arrangement it was set up as. **Workspace ▸ Save Current State to Workspace** (Cmd+Ctrl+S) makes the current arrangement that starting point, and **Reset to Saved State** goes back to it after an afternoon of wandering.

This is separate from the continuous remembering: you never have to save in order not to lose your place.

## The stash

Every workspace has a basket, for the thing that actually happens while tidying up: three folders deep
in the backups you find something belonging to an entirely different job. **Drag files onto another
workspace's chip** and they land in *its* basket — you do not switch, and nothing is copied or moved;
the chip's counter goes up and you carry on. Hold **⌥** while dropping to copy into that workspace's
folder instead, or **⌘** to move. **Ctrl+Cmd+A** adds the selection to the current workspace's basket,
the **Stash** page in the side panel shows what is in it, and **Workspace ▸ Copy Stash to Other Panel**
does the whole basket in one operation.

Files deleted since, or on a volume that is not mounted, are shown as missing rather than removed, and
a bulk operation offers to skip them or take them out of the basket first. A move empties the basket of
what it moved; a copy leaves it as it was.

| Action | Shortcut |
| --- | --- |
| Switch to workspace 1 to 9 | Ctrl+1 … Ctrl+9 |
| Make the current arrangement the starting point | Cmd+Ctrl+S |

## Tips

- Right-click a chip to rename it, give it a colour, or delete it — or click the **✕** at a chip's right-hand end, which deletes that workspace after asking. The colour is how you tell workspaces apart at a glance when the window is narrow and the names no longer fit.
- Nine is the limit, so that every chip stays recognisable.
- **View ▸ Show Workspace Bar** hides the strip without switching the feature off, for anyone who moves between workspaces with the keyboard.
- Workspaces can be switched off entirely in **Settings ▸ Tabs**. Your workspaces are kept and come back unchanged when you switch it on again.

## Limiting a workspace to a folder

A workspace can be told which folder it is about, and then it checks before an operation reaches
outside it. Right-click its chip, **Limit to Folder ▸ Set to the Active Folder**, and choose whether
operations outside should be allowed, asked about, or refused.

It is checked before a delete takes files from outside, before a copy or a move lands outside, and
before a rename or a new folder writes outside. **Navigating is never restricted** — a file manager
that refuses to show you a folder is broken, and the value of this is entirely in the moment before
F8. Editor saves are not covered either; they happen in their own window.

## The journal

Each workspace keeps a record of what was done in it — folders visited, operations carried out, shell
lines run, and anything a folder limit refused. **Workspace ▸ Journal…** shows it, newest day first,
with a **Problems** filter for everything that failed or was stopped.

Return repeats the selected row, under the same rule as the history: only a copy or a move can be
repeated with one keystroke, and a shell line is filled into the command line rather than run. The
journal is separate from the global history on purpose — that one answers "where do I usually go" and
ranks by frequency; this one answers "what happened here" and keeps the order. It is deleted with its
workspace, kept indefinitely otherwise, and can be switched off in **Settings ▸ Tabs**.

## Passing a workspace on

**Workspace ▸ Export Workspace…** writes the current workspace to a `.pcworkspace` file you can mail
to somebody or keep in a project folder. **Import Workspace…** reads one back, and so does
double-clicking the file in the Finder.

What travels is the workspace's **saved starting point** — press ⌘⌃S first if you want the
arrangement you are looking at right now — along with its name, its colour, its folder limit and its
stash. Folders inside your home are written shortened, so the file opens in the *other* person's home
rather than in a folder named after you.

What deliberately does not travel:

- **Anything that could be a credential.** Tabs pointing at a connection or a mounted plugin drive are removed on export, and the report says how many. There is nothing to leak because nothing about a connection is written down.
- **The journal.** It is a record of what you did and names folders on your machine. It stays here.
- Cursor positions, the undo history, the window size, and open Lister, Editor, Find or Sync windows.
- Terminal tabs and assistant conversations. Those belong to this Mac; a workspace file carries where to work, not what is running.

An import always **adds** a workspace; it never replaces the one you are in and never switches by
itself — opening a file somebody sent should not move your window. Folders that are not on this Mac
open at the nearest one that is, stash entries keep their paths and show greyed out, and a folder
limit whose folder is missing is kept but set to ask rather than refuse. A report lists all of it.

## Notes

- Switching never asks whether to save, and never closes anything. Running file operations keep running, and so does anything in a terminal: the tabs of the workspace you leave are set aside with their shells alive, not shut. The assistant's conversations follow the workspace too; an answer still arriving when you switch away finishes and is waiting when you come back.
- Undo follows a workspace only while the app is running: an undo step carries the action that reverses it, and that cannot be written to disk.
- A workspace records folder locations, not the files inside them. If a saved folder has been moved or deleted, that tab opens at the nearest folder that still exists.
- Upgrading from an earlier version: any workspaces you had saved before become chips, and the session you were in becomes the first one. Nothing is lost, and the old `workspaces.ini` is kept as `workspaces.ini.migrated`.
