---
title: Version notes
slug: version-notes
section: user-guide
order: 90
related: [known-limitations]
---

# Version notes

Peach Commander is a **pre-1.0 preview**. The current build carries version
**0.1.0**. This page summarizes what works today, what is still on the way, and
the honest limits of this release, so you know what to expect before you install
it.

Peach Commander is a **universal app** — it runs natively on both Apple Silicon
and Intel Macs — and requires **macOS 13 (Ventura) or later**.

## What works today

The core of a dual-panel file manager is in place and usable for day-to-day
work:

- **Dual-panel browsing** with tabs, a path bar, a drive bar that lists every
  mounted volume live (including disk images), and a status bar that summarizes
  your selection. Press **Tab** to switch panels.
- **File operations** — copy (**F5**), move (**F6**), delete, and create — with
  an optional background transfer manager so long copies don't block you, plus
  drag-and-drop between panels and to and from Finder.
- **Two keyboard schemes** so you can work the way you already think: a classic
  dual-commander layout and a macOS-native layout. See
  [Keyboard shortcuts](keyboard-shortcuts.md).
- **Archives as folders** — open ZIP, 7z, TAR, and RAR archives and step into
  them like any other folder. See [Working with archives](archives.md).
- **Deep search** across names and contents, including regular expressions, hex,
  text-encoding matching, searching inside archives, and Spotlight. See
  [Finding files](searching.md).
- **File utilities** — multi-rename, folder synchronize, compare, duplicate
  finder, and checksums. See [Multi-rename](multi-rename.md) and
  [Comparing and syncing](comparing-and-syncing.md).
- **Built-in networking** — FTP, FTPS, SFTP, SCP, WebDAV, and SOCKS5, plus a
  resuming HTTP downloader, with a saved-sites connection manager. Passwords are
  stored **only in the macOS Keychain**, never in plain files. See
  [FTP and SFTP](ftp-and-sftp.md).
- **Viewers and editors** — a text and image lister with Quick Look, a text
  editor with find and replace, a hex editor, a binary compare tool, and a diff
  viewer.
- **Native macOS integration** — Quick Look (**Cmd+Y**), the Share sheet, Open
  With, Finder Tags, and richer Get Info details. See
  [macOS integration](macos-integration.md).
- **Plugins and an SDK** — five plugin types are supported, and settings can be
  imported from a Total Commander `wincmd.ini`. See [Plugins](plugins.md).

Peach Commander collects **no telemetry** and transmits nothing about your usage
automatically. See [Privacy and security](privacy-and-security.md).

## Still coming

A few things are planned but **not yet enabled** in this build:

- **Automatic updates.** The groundwork for background auto-update is present but
  not wired up, so this preview will not update itself. Watch the project's
  release page for new builds and install them manually for now.
- **Finalized signing and notarization.** Developer-ID code signing and Apple
  notarization are being finalized. Until that is complete, a preview build is
  **not signed**, so macOS Gatekeeper may warn that the app is from an
  unidentified developer the first time you open it. To run it, **right-click
  (or Control-click) the app and choose Open**, then confirm.
- **Instant folder refresh.** A panel currently checks the active folder for
  outside changes about every 2 seconds rather than the instant a file appears.
  You can always refresh manually — see the limitations below.

## Known limitations

This is a preview, so some features have honest limits worth knowing before you
rely on them. In brief:

- **Very large ZIP files (ZIP64)** may not open in the built-in reader.
- **Changing file attributes over SFTP/SCP** has no effect in this version.
- The **Download from URL** shortcut can conflict with a Go-menu shortcut; start
  the download from the **Net** menu to be sure.
- Panels notice **outside changes on a short delay** (about 2 seconds); refresh
  the active panel with **F2** or **Ctrl+R** if you don't want to wait.
- The **preview build is unsigned** (see above).

For the full list, workarounds, and details, read
[Known limitations](known-limitations.md).

## A note on version numbers

Version numbers on this page come straight from the app and its changelog. As a
pre-1.0 preview, features and shortcuts may still change between builds, and
nothing here should be read as a promise of a specific future version. If your
copy behaves differently from what this page describes, check the version shown
in the **Help** menu against the number at the top of this page.
