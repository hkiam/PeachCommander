---
title: The button bar
slug: toolbar
group: Customise
section: Customizing
order: 110
related: [keyboard-shortcuts, settings]
---

The button bar is the strip of icon buttons across the top of the window. Each button is a one-click shortcut you define yourself: run a built-in command, launch an external program or app, jump to a folder, or open a whole sub-bar of more buttons. It's the fastest way to put the actions you use most within reach, and you can tailor it to exactly the way you work.

## Customize the button bar

1. Choose **Configuration > Customize Toolbar…**, or right-click the bar and choose **Edit Button Bar…**.
2. The list on the left shows the current buttons. Use **+** to add a button, **—** to add a separator, **−** to remove the selected button, and **↑ / ↓** to reorder.
3. Select a button and fill in the form on the right:
   - **Command** — type a built-in command, or click **Choose…** to pick one from a list. You can also enter the path to a program or app, a folder to open, or another button bar to use as a sub-bar.
   - **Caption** — the label and tooltip shown for the button.
   - **Parameters** and **Start path** — passed to external programs. Placeholders such as `%P` (source folder), `%N` (current file), and `%S` (selected files) are filled in when the button runs.
   - **Icon** — choose an SF Symbol or use a file's or app's own icon; turn on **icon-only** to hide the caption.
4. Click **Save**. The strip reloads immediately.

![The button bar across the top of the window with icon buttons](screenshots/button-bar-crop.png)
*(Figure: The button bar sits above the file panels; each button runs a command, program, folder, or sub-bar.)*

## Sub-bars and overflow

A button can open a *sub-bar* — a second set of buttons layered over the first. Click it to descend; a **◀** button at the left returns you to the previous bar. When there are more buttons than fit the window width, the extras collapse behind a **»** chevron at the right end; click it to reach them.

## Add a program by dropping it on the bar

You do not have to open the editor to put a tool on the bar. Drag a program, an app or a script from a panel — or from Finder — onto **free space** in the bar. A caret shows where it will land, and dropping creates the button there.

- **Programs, apps and scripts** become a button that runs them on your current selection: the new button's parameters default to `%S`, the selected file names. Clear that field in the editor for a tool that should take no arguments.
- **Folders** become a button that jumps to that folder — and that copies files into it when you drop them on it later.
- Anything that cannot be run is refused: a plain document has no execute permission, so dropping it would only create a button that fails when clicked.

Dropping onto an *existing* button keeps its own meaning — it runs that button with the dropped files. Only free space adds a new one.

## Drop files onto a button

You can drag files or folders straight onto a button:

- **Folder button** — the dropped items are copied into that folder in the background.
- **Program button** — the program runs with the dropped items as its selection.
- **Command button** — the command runs as usual.

## Hide the button bar

Choose **View > Button Bar** to hide the strip, and again to bring it back. The same switch is on the **Layout** page in Settings, and the choice is remembered.

## Vertical button bar

To move the strip from the top of the window to a column down the left side, choose **View > Vertical Button Bar**. Choose it again to switch back to the horizontal strip.

## Notes

- The bar is stored in a standard button-bar file that's compatible with Total Commander, so bars you already have can be reused.
- No keyboard shortcuts are assigned to these actions by default, but you can add your own — see [Keyboard shortcuts](keyboard-shortcuts).
- A button with no icon and no command shows as a plain separator, handy for grouping related buttons.
