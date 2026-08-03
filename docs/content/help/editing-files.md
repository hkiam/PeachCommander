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

If the file belongs to `root` — an entry in `/etc`, a launchd plist, a web server's config — saving offers to do it **as administrator**: macOS asks for authorization the usual way, the content is handed over through a private temporary file rather than a command line, and the file keeps its own owner and permissions instead of quietly becoming yours.

## Find, replace, and navigate

- Press Cmd+F to open the find bar. To replace text, open the find bar and switch it to the replace view, or click Find/Replace in the toolbar.
- Click Format to re-indent the file into a clean, readable layout. See [Formatting a file](#formatting-a-file) below for which file types this covers. The button is greyed out when nothing can format the file you have open.
- Click Symbols (or press Cmd+Shift+O) to show a sidebar that lists the classes, functions, and methods in your code. Click an entry to jump straight to it.
- Press Cmd+L to jump to a specific line.
- Press Cmd+\ to jump between a bracket and its matching partner.
- Click the map button to show or hide the minimap, a scaled overview of the whole file you can click to scroll.
- Use the Encoding menu in the toolbar if the file was saved in something other than the default text encoding.

## Formatting a file

Click **Format** in the editor (or use the same command in the viewer) to re-indent the file. Peach Commander picks a formatter based on the file's extension and shows which one it used in the status line, for example *formatted (jq)* — so you can always tell what shaped the result.

**Works out of the box** for JSON, XML, SVG, plists, HTML, INI-style configuration, and YAML. YAML is a special case: it is tidied rather than re-indented, because in YAML the indentation *is* the structure, and rewriting it without a real YAML parser could change what the file means. Trailing spaces go, stray tabs in the indentation become spaces, runs of blank lines collapse — and anything inside a block scalar (`|` or `>`) is left exactly as it is, because whitespace is content there.

**Better formatters take over automatically.** If you have one of these installed, Peach Commander uses it instead, because a dedicated tool usually matches what the wider ecosystem expects — and for configuration formats it keeps your comments:

| Install | and you get |
| --- | --- |
| `yq` or `prettier` | full YAML formatting, comments preserved |
| `taplo` | TOML |
| `sqlformat` or `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, in the conventional style |
| `xmllint` | XML and SVG |

If a file type has no formatter, the Format button is greyed out and the menu entry disabled. Trying anyway tells you why — *"taplo is not installed"* reads differently from *"Not valid JSON"*.

### Use your own formatter

To format a file type Peach Commander does not know, or to use a different tool, create `formatters.ini` in the configuration folder — one section per extension:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` is an executable name (looked up like your shell would) or an absolute path; `args` are passed as-is. The file's text goes in on standard input and the formatted text is read back from standard output, so any well-behaved command-line formatter works. Your entries win over everything else. A commented template is created for you on first launch, so you can simply open the file and fill it in.

Plugins can contribute formatters too — see [Plugins](plugins.md).

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
