---
title: Moving around
slug: navigating
group: Get started
section: Getting started
order: 14
related: [interface-overview, favorites]
---

Peach Commander shows two folders side by side, so most of your time is spent moving one panel from folder to folder. You can open folders, step back up the hierarchy, retrace where you have been, type a path directly, and jump straight to everyday places like Home, Desktop, and Downloads. Every action works on the *active* panel — the one with the highlighted path bar.

## Open folders and step back up

1. Move the selection bar with the arrow keys until a folder is highlighted.
2. Press **Enter** (or double-click) to open it. This also enters archives and opens files with their default app.
3. To go up one level to the parent folder, press **Ctrl+PageUp** (or **Backspace**).
4. To jump to the top of the current drive, choose **Go ▸ Root**.

## Go back and forward

Peach Commander remembers the folders you have visited in each panel, just like a web browser.

- Press **Alt+Left** to go back to the previous folder, and **Alt+Right** to go forward again.
- Press **Alt+Down** to open a drop-down list of recent folders and jump to any of them.

## Type a path or use the path bar

The path bar across the top of each panel shows where you are and doubles as a way to get somewhere fast.

![Editable path bar showing the current folder as clickable segments](screenshots/path-bar-crop.png)
*(Figure: The path bar. Click any segment to jump to that folder, or the pencil to type a full path.)*

- Click any segment of the path (for example a parent folder name) to jump straight to it.
- Click the pencil at the right of the path bar to turn it into a text field, then type or paste any path and press Enter.
- Or choose **File ▸ Go to Folder…** (**Cmd+Shift+G**) to type a path from anywhere.

## Jump to common places

The **Go** menu takes the active panel to the folders you use most:

- **Home**, **Desktop**, **Downloads**, **Trash**, and **iCloud Drive**.
- **iCloud Drive** appears when it is set up on your Mac.

## Switch panels and drives

- Press **Tab** to move the focus between the left and right panels.
- The drive bar above each panel lists your mounted volumes with free space; click a volume to switch that panel to it.
- Press **Ctrl+U** to swap the two panels (their folders trade sides); **Ctrl+Shift+U** swaps them together with their tabs.
- Press **Ctrl+=** to point the other panel at the same folder as the active one (*target = source*) — handy just before a copy or move.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Open folder / file under the cursor | Enter |
| Go to parent folder | Ctrl+PageUp (or Backspace) |
| Back / Forward in history | Alt+Left / Alt+Right |
| History drop-down | Alt+Down |
| Global history (any panel) | Ctrl+Cmd+H |
| Go to Folder… (type a path) | Cmd+Shift+G |
| Home | Cmd+Shift+H |
| Desktop | Cmd+Shift+D |
| Downloads | Option+Cmd+L |
| Switch active panel | Tab |

## Tips

- A panel keeps itself up to date: a file another program creates, changes, or deletes in the folder you are looking at appears on its own, with your cursor and your marks left where they were. Turn it off in **Configuration ▸ Options ▸ Display** if a folder something writes to constantly keeps refreshing.
- Each panel keeps its own history, so Back and Forward affect only the active side.
- If a typed path is not a valid folder, the path bar quietly keeps your last location instead of navigating.
- Trash and iCloud Drive in the Go menu have no default shortcut, but you can assign one in **Configuration ▸ Options ▸ Keyboard**.
