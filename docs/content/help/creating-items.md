---
title: New folders & files
slug: creating-items
group: Using Peach Commander
section: Files & folders
order: 30
related: [opening-files]
---

When you're organizing files, you often need somewhere new to put them or a fresh document to start from. Peach Commander lets you create a new folder or a new text file directly in the panel you're working in, without switching to Finder. New items are created in the folder currently shown in the active panel.

## Create a new folder

1. Click the panel where you want the new folder to appear so it becomes the active panel.
2. Press F7.
3. Type a name in the box that appears.
4. Press Return (or click OK). The new folder appears in the panel, ready to use.

You can do more than create a single folder in one step:

- **Nested folders in one go.** Type a path with slashes, such as `a/b/c`, to create a folder `a` containing `b` containing `c`. Any levels that don't exist yet are created for you.
- **Several folders at once.** Separate names with a vertical bar, such as `d1|d2`, to create both `d1` and `d2` side by side. You can combine both styles, for example `reports/2026|archive`.

## Create a new text file

1. Click the panel where you want the new file to appear.
2. Press Shift+F4.
3. Type a name for the file, including its extension (for example `notes.txt`).
4. Press Return. The empty file is created and opens in your editor so you can start typing right away.

The file opens in whichever editor Peach Commander is set to use for that kind of file. See **Opening & viewing files** for how editing works.

## Shortcuts

| Action | Key |
| --- | --- |
| New folder | F7 |
| New text file | Shift+F4 |

## Notes

- On macOS a folder or file name can contain almost any character. Only the slash `/` (which is used as the path separator for nested folders) and a few reserved characters are not allowed in a single name.
- Using a colon `:` in a name is possible but can look confusing in Finder, so it's best avoided.
- If a folder with the same name already exists, Peach Commander simply keeps the existing one — nothing is overwritten.
