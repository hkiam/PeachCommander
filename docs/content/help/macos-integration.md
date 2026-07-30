---
title: macOS integration
slug: macos-integration
section: macOS & privacy
order: 130
related: [opening-files, privacy-and-security]
---

Peach Commander works the way the rest of your Mac does. The apps you use, the Finder tags you rely on, the Share sheet, Quick Look, and even trackpad swipes all behave here just as they do in the Finder — so you rarely have to leave the app to get something done.

## Open files with any app

Right-click a file (or a selection) to reach the system actions for it:

1. Choose **Open** to open the item the same way Return would.
2. Choose **Open in Default App** to hand it to the app macOS normally uses for that type.
3. Point at **Open With** to pick from every app that can open the file. Each app is listed with its name and icon.
4. At the bottom of **Open With**, choose **Other…** to browse to any application yourself.

## Reveal, share, and preview

- **Reveal in Finder** opens a Finder window with the item selected — handy when you need Finder's own commands.
- **Share…** opens the standard macOS Share sheet for the selected files (Mail, Messages, AirDrop, and anything else you've enabled in System Settings).
- **Quick Look** shows a full-size preview without opening an app. Press Cmd+Y, or choose it from the View menu or the right-click menu.

## Finder tags

Right-click a file and point at **Tags** to toggle the seven standard Finder color tags (Red, Orange, Yellow, Green, Blue, Purple, Gray). A checkmark shows which tags are already applied. Tags set here are the same Finder tags you see everywhere else on your Mac.

## Open a terminal here

Choose **File ▸ Open Terminal Here** (or **Commands ▸ Open Terminal Here**), or press Cmd+Option+T, to open Terminal already pointed at the active panel's folder.

## Services and trackpad

- The standard macOS **Services** menu works on the current selection, so any Service that accepts files is available.
- On a trackpad, a two-finger horizontal swipe moves through the panel's history like a web browser: swipe right to go **Back**, swipe left to go **Forward**.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Quick Look | Cmd+Y |
| Open Terminal Here | Cmd+Option+T |

## Notes

- The trackpad swipe gesture only fires when the system **Swipe between pages** trackpad gesture is turned on in System Settings.
- Open Terminal Here launches Terminal; it isn't available while you're browsing inside an archive.
- Tags, Reveal in Finder, Share, and Open With apply to real files on disk, so they aren't offered for items inside archives or on the parent-folder (..) row.
- Some macOS features need permission before Peach Commander can read every folder. If files look missing, see **Privacy and security** for the Full Disk Access guide (Commands ▸ Full Disk Access…).
