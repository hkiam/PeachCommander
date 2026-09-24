---
title: Markdown and HTML in the viewer
slug: markdown-viewer
group: Plugins
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Press F3 on a `.md` or `.html` file and it appears formatted rather than as source: headings, lists, tables, links, task lists, and code blocks coloured by language. Diagrams written as ` ```mermaid ` blocks are drawn, and mathematics written between dollar signs is typeset.

This is a plugin. Everything on this page comes from **Markdown and HTML**, which you can switch off in **Configuration ▸ Plugins…** — see below for what changes if you do.

## Where the rendered view appears

- **The viewer (F3).** The formatted page. The **View** popup still offers Text, Code and Hex, so the source is one click away, and the plugin's own name is in that list too.
- **Quick View (Ctrl+Q) and the info page** of the side panel show the same rendering, so a preview and a full view of one file never disagree.
- **The gallery** shows a small picture of a Markdown file's beginning instead of a generic document icon.
- **Quick Look (Cmd+Y)** is macOS's own preview and is *not* affected — that panel belongs to the system, and no plugin can draw in it.

## The symbol outline

Press **Symbols** in the viewer to get the document's headings, nested as they are written, and click one to jump to it in the page. It works on the formatted view and on the source, and both agree about where a heading is.

## Diagrams and mathematics

A fenced block whose language is `mermaid` becomes a diagram; `$…$` and `$$…$$` become set mathematics. Both are drawn **on your Mac**, by engines that ship inside the plugin — nothing is downloaded, and no part of your document is sent anywhere. A dollar sign inside a code block or inline code stays a dollar sign.

A document with no diagram and no formula loads neither engine, so an ordinary README costs nothing extra. A diagram that cannot be parsed shows the error where the block was, with the block's own text below it, rather than disappearing.

Both can be switched off separately in **Configuration ▸ Settings ▸ Markdown**, which is also where you can see which engine version is in use and where it came from.

## Your own engine version

If you need a newer or different build of Mermaid or KaTeX, put it in the folder the **Engine Folder…** button opens and it is used instead of the bundled one. The file names are `mermaid.min.js`, `katex.min.js`, `katex.min.css` and `auto-render.min.js`. Nothing is ever fetched from the internet for you.

## Making a PDF

With the cursor on a `.md` or `.html` file, **Commands ▸ Export to PDF…** — or the same entry in the panel's context menu — writes the document as a PDF beside it, under its own name. It is offered on ordinary folders only — inside an archive or on a mounted drive there is no file on the disk to read and nowhere beside it to write. Mark several documents and they are exported one after the other.

The PDF is the page you see with F3: the same stylesheet, the same coloured code, the same diagrams and mathematics. It is laid out on A4 by default (Letter is a setting), the page breaks fall between paragraphs, list items and table rows rather than through a line of text, and no page begins without the heading its section starts with. A document with something too wide for the text column — a table with many columns, a long unbroken line — is scaled down to fit rather than cut off at the edge, the way a browser's own print does it.

On the plugin's settings page, under **PDF**:

- **Offer "Export to PDF" on .md and .html files** — switched off, the command declines and says so. The menu entry itself stays visible: the application builds a plugin's menus from the plugin's description of itself without loading it, so there is nothing for a setting to be read from at that moment.
- **Paper** — A4 or US Letter.
- **Replace an existing PDF of the same name** — off by default, so a second export is written beside the first as `Name 2.pdf` rather than overwriting it.
- **Show the new PDF in the panel** — moves the panel to the file that was just written. With this off you get a short message instead, so an export is never silent.

A document too large for the formatted view (see **Limits**) cannot be exported either; the message names it.

## What the rendered page will not do

The formatted page is deliberately sealed off, because a Markdown file is content that came from somewhere else:

- **It loads nothing over the network.** An image whose address begins with `http` stays blank on purpose: fetching it would tell that server when you opened the file, and from which address. An image beside the document on disk loads normally.
- **A document's own scripts and HTML never run.** HTML written inside a Markdown file is shown as text, and an `.html` file is displayed with scripting switched off.

## Switching it off

Turn the plugin off in **Configuration ▸ Plugins…**, and `.md` and `.html` files open as text. The outline still works, syntax colouring still works, and nothing else changes — the formatted view is simply not offered. The same is true if you switch only the rendered view off on the plugin's settings page.

## Limits

- Files above a size limit (8 MB by default, on the settings page) open as text instead. Turning a very large generated document into a formatted page is slow, and the text viewer opens it at once.
- The formatted page cannot be edited. Use F4 for that, or the Text view for **Format**, **Encoding** and **Go To**, which apply to source and not to a rendered page.
