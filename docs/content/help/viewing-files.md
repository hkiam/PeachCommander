---
title: Viewing files
slug: viewing-files
section: Viewing & editing
order: 70
related: [editing-files, searching]
---

Peach Commander has a built-in viewer that lets you look inside a file without opening another app or changing the file. Press F3 on the item under the cursor and the viewer opens instantly, even for very large files. It automatically chooses the best way to show the content: readable text, syntax-colored code, a raw hex dump, or a full-size image. You can also preview a file right inside the window using Quick View, or hand it to macOS Quick Look.

## View a file

1. Move the cursor onto a file in the active panel.
2. Press F3 (or choose View in the File menu). The viewer opens in its own window.
3. Use the toolbar to switch how the content is shown: Text, Code, Hex, Image, or Rendered. Leave it on the automatic setting to let Peach Commander decide.
4. Scroll with the arrow keys, Page Up/Page Down, and the scroll bar. For long text, turn on the minimap button to see and jump around the whole file at a glance.
5. Press N to jump to the next selected file, or close the window with Esc.

![The built-in viewer showing a text file with the minimap on the right](screenshots/lister-text.png)
*(Figure: Viewing a text file, with the representation picker and minimap in the toolbar.)*

## Find text and change the encoding

- Press Ctrl+F to search within the file. Press F3 to jump to the next match and Shift+F3 for the previous one.
- If text looks garbled, click Encoding in the toolbar (or press E) to cycle through text encodings until it reads correctly; the automatic setting usually gets it right.
- Press W to toggle word wrap for long lines.

## Quick View and Quick Look

Quick View shows a live preview in the panel you are *not* using, so you can keep browsing on one side while previewing on the other.

1. Press Ctrl+Q. The inactive panel turns into a preview area.
2. Move the cursor over different files in the active panel to preview each one.
3. Press Ctrl+Q again, or Esc, to return the panel to a normal file list.

For a fast full-screen preview handled by macOS itself, press Cmd+Y (Quick Look). Press Cmd+Y or Space again to close it.

## The Info side panel

The side panel (**View > Preview Panel**, or Cmd+Shift+P) has an **Info** page that shows the item under the cursor the way Finder's info sidebar does.

- The preview fills the width of the panel, so widen the panel and the preview grows with it. Drag the panel's left edge to make it wider or narrower; the width is remembered.
- It is a real macOS preview, not a small thumbnail: every format Quick Look can show works here, and a multi-page document scrolls page by page inside the preview.
- Below it are the name, the kind and the size, then when the item was created and changed and which folder it is in.

Moving the cursor updates the name and details immediately; the preview itself follows a moment later, so holding an arrow key through a long folder does not start a preview for every row it passes.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| View file under cursor | F3 |
| View only the file under cursor (ignore marked files) | Shift+F3 |
| Open in an external viewer | Option+F3 |
| Find within the viewer | Ctrl+F |
| Next / previous match | F3 / Shift+F3 |
| Quick View in the other panel | Ctrl+Q |
| Quick Look (macOS preview) | Cmd+Y |
| Close the viewer or Quick View | Esc |

## Notes

- The viewer is read-only. To change a file, use the editor instead (see Editing files).
- Very large files open without delay: text opens a fast, scrollable view and the hex view streams straight from disk at any size.
- Press F3 on a folder to see a summary of its contents and total size instead of file bytes.
- The Rendered mode displays formatted content such as web pages and Markdown; hex mode shows the raw bytes side by side with their characters, which is handy for inspecting binary files.
- In Rendered mode you can select text and copy it, and Find searches the rendered page. Buttons that cannot apply to a rendered page — Format, Encoding, Mark All, Marks and Go To — are greyed out rather than doing nothing.
- The Format button re-indents structured files (JSON, XML, HTML, INI, YAML, and more when you have the matching command-line tool installed). It is described in full under [Editing files](editing-files.md#formatting-a-file), and works the same way here.
