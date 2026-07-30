---
title: Editing files
slug: editing-files
section: Viewing & editing
order: 72
related: [viewing-files]
---

When you need to change a file rather than just look at it, Peach Commander opens it in a built-in editor. Text and code files open in a full editor with syntax highlighting, find and replace, an outline of the symbols in your code, and a minimap for quick navigation. Binary files can be opened in a separate hex editor, where you can inspect and change individual bytes. You never have to leave the app to make a quick edit.

## Edit a text or code file

1. In either panel, move the cursor to the file you want to change.
2. Press F4, or choose File ▸ Edit. The file opens in the editor window.
3. Make your changes. If the file is a recognized programming or data format, keywords, strings, and comments are colored automatically.
4. Press Cmd+S (or click Save) to write your changes. The first save keeps a backup of the original alongside the file, so you can always fall back to it.

To start a brand-new text file at the current location, press Shift+F4.

![The built-in text editor showing syntax highlighting, the symbol outline, and the minimap](screenshots/editor.png)
*(Figure: The editor with syntax highlighting, the symbol outline on the left, and the minimap on the right.)*

## Find, replace, and navigate

- Press Cmd+F to open the find bar. To replace text, open the find bar and switch it to the replace view, or click Find/Replace in the toolbar.
- Click Format JSON/XML to re-indent a JSON or XML document into clean, readable layout.
- Click Symbols (or press Cmd+Shift+O) to show a sidebar that lists the classes, functions, and methods in your code. Click an entry to jump straight to it.
- Press Cmd+L to jump to a specific line.
- Press Cmd+\ to jump between a bracket and its matching partner.
- Click the map button to show or hide the minimap, a scaled overview of the whole file you can click to scroll.
- Use the Encoding menu in the toolbar if the file was saved in something other than the default text encoding.

## Edit a file byte by byte

1. Select the file in a panel.
2. Choose File ▸ Edit as Hex (or right-click the file and choose Edit as Hex).
3. Type hex digits to overwrite bytes, or use the arrow keys to move through the file. Backspace and Delete remove bytes.
4. Press Cmd+S to save. As with the text editor, a one-time backup of the original is kept.

## Shortcuts

| Action | Key |
|---|---|
| Edit file | F4 |
| Create and edit a new text file | Shift+F4 |
| Save | Cmd+S |
| Find | Cmd+F |
| Show/hide symbol outline | Cmd+Shift+O |
| Go to line | Cmd+L |
| Jump to matching bracket | Cmd+\ |
| Undo / redo (hex editor) | Cmd+Z / Cmd+Shift+Z |

## Notes

- Syntax highlighting covers JSON, C, C#, Java, JavaScript, TypeScript, Python, and Rust. Other file types still open and edit normally with basic coloring, but detailed highlighting and the symbol outline are only available for the supported languages.
- The symbol outline and Go to Line features apply to the text editor. The hex editor is meant for binary inspection and byte-level edits, not for text.
- Both editors keep a backup of the original file the first time you save, so an accidental change is easy to undo by restoring that backup.
