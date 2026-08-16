---
title: Plugins
slug: plugins
section: Plugins
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Plugins extend Peach Commander with extra tools, file formats, and places to browse. A dozen plugins come built in, so you can start using them right away, and you can turn individual plugins on or off — or install new ones — from a single window. Use plugins when you want capabilities beyond everyday copying and browsing: visualizing what fills a disk, connecting to a WebDAV server, checking the state of a Git repository, watching system activity, and more.

Plugins come in a few flavors: some add a **panel or sidebar** (a view), some add **columns** to the file list, some add a **place you navigate into** like a drive, and some teach the app a new **archive format**. Each is enabled independently.

## What the built-in plugins add

Several plugins have their own detailed help topic — follow the link for the full story:

- **[Disk Map](disk-map.md)** — visualizes what fills a folder or volume as a treemap or sunburst, reconciled against free, purgeable, and hidden space, with a cleanup collector.
- **[AI Assistant](ai-assistant.md)** — an optional, removable assistant that summarizes, renames, translates, tabulates, and tidies files in plain language, on-device or via a cloud model.
- **[Git](git.md)** — shows each file's working-tree status and the current branch as panel columns, and adds a **Git** menu for status, stage, commit, pull, and push.
- **[System Monitor](system-monitor.md)** — a live readout of CPU, memory, disk, network (and, where available, GPU, battery, sensors) in the window title bar, with click-through detail graphs.
- **[Task Manager](task-manager.md)** — mounts your running processes as a browsable **TaskManager** drive; sort them, inspect them like files, or end them with Delete.
- **[Filesystem Images](filesystem-images.md)** — opens a filesystem image (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) the way an archive opens, including disk images with several partitions. Read-only, and off until you switch it on.
- **[Uninstaller](uninstaller.md)** — removes an application **and** the support files, caches, and preferences it leaves behind, after showing you exactly what will go.

The remaining built-in plugins are smaller and don't need a page of their own:

- **WebDAV** — connect to a WebDAV server (**Net ▸ WebDAV Connect…**) and browse, upload, download, rename, and delete on it as if it were a folder. Passwords are kept in the macOS Keychain.
- **iCloud Drive** — adds an *iCloud Drive* entry to the drive bar that jumps straight to your local iCloud Drive folder. It appears only when iCloud Drive is set up on your Mac.
- **Notes** — keep a note beside any file or folder. A small **●** badge marks items that have one; edit notes in a docked **Notes** sidebar or a full rich-text editor (**Commands ▸ Edit Note…**), and browse them all with **Notes Overview…**.
- **Log Viewer** — open a file as a color-coded, level-classified, live-tailing log (**File ▸ View as Log…**), with per-level filters, search, and support for common log formats plus your own regex formats. Handles multi-gigabyte logs instantly.
- **CSV Lister** — press F3 on a `.csv` or `.tsv` file and it opens as a real table with sortable columns instead of raw text. The delimiter is detected automatically, so semicolon-separated exports line up too, and the viewer's search finds values cell by cell.
- **AI Column** — adds an *AI Language* column that detects each text file's dominant language on-device (using Apple's NaturalLanguage framework — not a cloud model).
- **Archive formats** — teaches the app to browse and extract more archive types (7z, tar family, gzip/bzip2/xz/zstd, and RAR where a helper tool is installed), which then open like folders.

## Turn plugins on or off

1. Choose Configuration ▸ Plugins… to open the plugin window.
2. Each installed plugin appears in the list with its name, type, and an Enabled checkbox.
3. Select or clear the checkbox to enable or disable a plugin. Changes take effect immediately — enabled plugins add their menus, columns, and features; disabled ones stay out of the way.

![The plugin window listing installed plugins with enable checkboxes and Install and Remove buttons](screenshots/plugins-window.png)
*(Figure: The plugin window, where you enable, disable, install, or remove plugins.)*

## Install a new plugin

1. Choose Configuration ▸ Plugins….
2. Click **Install from Folder…**.
3. Choose a plugin bundle or a `.zip` containing one, then confirm. The plugin is added to the list and enabled.

## Remove a plugin

1. In the plugin window, select the plugin in the list.
2. Click **Remove**. Built-in features are unaffected; only the selected plugin is removed.

## Notes

- The plugin list shows each plugin's type and interface version alongside its name and location, so you can confirm what is installed.
- If no plugins are installed, the window shows a short prompt pointing you to **Install from Folder…**.
- Some plugins add their own columns, menu items, or panel places only while they are enabled. If a feature you expected is missing, check that its plugin is turned on here.
