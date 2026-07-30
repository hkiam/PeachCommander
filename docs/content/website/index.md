---
title: Peach Commander
description: A fast, keyboard-driven, dual-panel file manager for macOS in the Total Commander tradition — with built-in FTP/SFTP/WebDAV, archives as folders, deep search, and plugins.
---

# Peach Commander

**The fast, keyboard-driven, dual-panel file manager for macOS — one app that replaces a drawer full of file utilities.**

Peach Commander puts two folders side by side and every operation under your fingertips. Copy with F5, move with F6, switch panels with Tab, and reach roughly 150 named commands without ever lifting your hands from the keyboard. It is built in the Total Commander tradition and made for people who move a lot of files — and it wires that workflow straight into the Mac you already use. Hit a remote server, crack open an archive, and rename a thousand files at once, all inside one native window.

![Peach Commander main window with two file panels](screenshots/main-window.png)
*Two folders side by side — the whole workflow lives in one window, and the keyboard drives all of it.*

---

## Two panels, driven by the keyboard

Source and target are always in view, and there is a command for everything. You never hunt through nested windows or drag across desktops — you press a key and it happens.

Line up your Downloads folder on the left and a project folder on the right, select a batch of files with the arrow keys, hit F5 to copy or F6 to move, and press Tab to flip focus and keep going. Prefer muscle memory from another tool? Switch to the TC-classic key scheme or stay on the macOS-native one, and rebind anything you like.

![The command browser listing named commands](screenshots/command-browser.png)
*Around 150 named commands — every action is searchable, runnable, and bindable to a key.*

---

## The network is just another folder

FTP, FTPS (explicit and implicit), SFTP/SCP over libssh2, WebDAV, and SOCKS5 proxying are all built in — remote servers browse, copy, and edit exactly like local directories. A wget-style HTTP(S) downloader with resume rounds it out.

Point the left panel at a production SFTP host and the right at a local project, then copy a release straight across with F5 as if both were folders on your Mac — no separate client, no context switch. Need a single file off the web instead? The downloader fetches it and resumes if the connection drops.

![The FTP and SFTP connection manager](screenshots/ftp-connection-manager.png)
*Saved connections for FTP, FTPS, SFTP/SCP, WebDAV, and SOCKS5 — pick one and it opens as an ordinary panel.*

---

## Archives you can walk into

Zip, 7z, tar (.gz/.bz2/.xz), and rar open like directories: step inside, copy files out, pack new ones, or edit a zip in place — with AES-256 encryption and split volumes.

Press Enter on a `.zip` to browse it, drag a corrected file in, and the archive updates in place — no unpack-edit-repack detour. Packing a release is just as direct: select files, open the pack dialog, and choose AES-256 encryption or split volumes when you need them.

![Browsing inside an archive as a folder](screenshots/archive-browse.png)
*Step into a zip, 7z, tar, or rar and navigate it exactly like a normal directory.*

---

## Search that actually finds it

Content and full-text search uses memory-mapped scanning — uncapped for local substring search — with regex, whole-word, hex, and encoding-aware modes. Filter by size, date, and attributes; search inside archives; tap into Spotlight; and save your searches as templates.

Search a source tree for a regex pattern, restrict it to files modified this week over a certain size, and have it look inside zipped backups too — then store that query as a template you rerun each release.

![The advanced find-files dialog with filters](screenshots/find-files-advanced.png)
*Regex, hex, whole-word, encoding awareness, and size/date/attribute filters — including inside archives.*

---

## Real power tools, built in

Multi-rename with regex, counters, and a live preview. Directory synchronize and compare (text and hex). A duplicate finder, checksums (CRC32/MD5/SHA), split/combine, base64/uu/hex conversion, and a background transfer manager with pause, resume, and bandwidth limiting.

Rename a few hundred photos with a regex and a counter and watch the preview update as you type; then queue a large copy in the transfer manager and pause, resume, or cap its bandwidth while you keep working elsewhere.

![The multi-rename tool with a live preview](screenshots/multi-rename.png)
*Build a rename rule from regex and counters and see the exact result before anything is written.*

![The background transfer manager](screenshots/transfer-manager.png)
*Queue long transfers and pause, resume, or bandwidth-limit them while you keep working.*

---

## Built for macOS, not ported to it

Peach Commander is a native AppKit app that respects the platform end to end. Panels render pixel-perfect on Retina displays, follow your system light/dark appearance automatically, and hand off to the tools you already rely on — Quick Look, "Open With," Reveal in Finder, Finder tags, native Services, and the macOS Share sheet — instead of reinventing them. There is even a built-in editor with syntax highlighting and "Open Terminal here" when you want it.

![The dual-panel main window in dark mode](screenshots/main-window-dark.png)
*Full Retina, native light/dark appearance, and the same tags and Quick Look you know from Finder.*

![The built-in editor with syntax highlighting](screenshots/editor.png)
*A built-in text/code editor with syntax highlighting — plus a hex viewer and the F3 lister.*

---

## Extensible, with five kinds of plugins

Packers, file systems, viewers, content columns, and tools all plug in, and a distributable Swift/C SDK lets you write your own — you can even source-port Total Commander WCX/WFX/WLX/WDX plugins.

Turn on the Git plugin to get status columns and commit commands right in the panel, or open Disk Map to see a treemap of what is eating your storage. Bundled plugins also include System Monitor, Task Manager, Uninstaller, WebDAV, iCloud, Notes, Log Viewer, and extra archive formats.

![The plugins management window](screenshots/plugins-window.png)
*Five plugin types plus an SDK — the bundled set spans Git, Disk Map, System Monitor, and more.*

---

## Make it yours

A button bar with sub-bars, two keyboard schemes (TC-classic and macOS-native) plus full rebinding, custom colors, fonts, and themes, named workspaces, and INI-based configuration — including importing your existing `wincmd.ini`.

![Color and theme settings](screenshots/settings-colors.png)
*Custom colors, fonts, and themes — tune both light and dark to taste.*

---

## Who it is for

- **Developers and power users** who live on the keyboard and move code, builds, and assets all day.
- **Sysadmins and IT** who need FTP/SFTP/WebDAV, checksums, sync, and batch operations in one place.
- **People migrating from Total Commander** who want the same two-panel muscle memory — including `wincmd.ini` import and a TC-classic key scheme — on the Mac.
- **Anyone who moves a lot of files** and has outgrown drag-and-drop in Finder.

## Top usage scenarios

- Copy and move large batches between two locations without leaving the keyboard.
- Push and pull files to remote servers over SFTP/FTP/WebDAV as if they were local.
- Browse, extract, and build archives — including encrypted and split ones — in place.
- Hunt down files or text across a whole tree, including inside archives.
- Rename hundreds of files at once, synchronize two directories, or find duplicates.
- Queue and manage long transfers in the background with pause, resume, and bandwidth limits.

## Main feature groups

- **Navigation:** dual panels, tabs, path bar, drive bar, named workspaces, trackpad-swipe history, and a searchable command browser.
- **File operations:** copy, move, delete, and a background transfer manager with pause/resume/bandwidth limiting.
- **Networking:** FTP, FTPS, SFTP/SCP, WebDAV, SOCKS5 proxy, and a resuming HTTP(S) downloader.
- **Archives:** zip, 7z, the tar family, and rar — browse, pack, extract, AES-256, split volumes, edit-in-place.
- **Search:** content/full-text, regex, hex, encoding-aware, attribute filters, in-archive, Spotlight, saved templates.
- **Power tools:** multi-rename, synchronize, compare (text + hex), duplicate finder, checksums (CRC32/MD5/SHA), split/combine, base64/uu/hex.
- **Viewers and editors:** a built-in text viewer/lister and an editor with syntax highlighting, plus Quick Look.
- **macOS integration:** native Services, Finder tags, Share sheet, "Open With," Reveal in Finder, Open Terminal here, full Retina, light and dark.
- **Customization:** button bar with sub-bars, two keyboard schemes plus rebinding, custom colors/fonts/themes, INI-based config with `wincmd.ini` import.

## How it is different from Finder

- **Two panels** — source and target visible at once, not one window at a time.
- **Keyboard-driven batch operations** — copy, move, rename, and select without touching the mouse.
- **Built-in FTP/SFTP/WebDAV** — remote servers as browsable panels, no extra client.
- **Archives as folders** — step inside a zip or 7z and edit it in place.
- **Deep search** — regex, hex, encoding-aware, in-archive content search with saved templates.
- **Plugins** — extend the app itself with five plugin types and an SDK.

## Privacy

Peach Commander is built to respect your data:

- **Passwords live in the macOS Keychain only** — never in plain-text config.
- **Crash reports stay local** — nothing is uploaded.
- **No telemetry** — the app does not phone home.

## Download

Peach Commander is currently a **preview / pre-1.0 release**. It is honest, working software — but expect the occasional rough edge while we head toward 1.0:

- Distributed **outside the App Store**. Developer-ID signing and notarization are being finalized, so a preview build may need a right-click → **Open** the first time.
- **Auto-update via Sparkle is planned but not yet enabled** — for now, you update by downloading a new build.
- **Universal binary:** native on both Apple Silicon and Intel.
- **Requires macOS 13 or later.**

**[Download the preview build](#)**

- Documentation: [the Peach Commander docs site](#)
- Source and issues: [the GitHub repository](#)

*Peach Commander is under active development. Expect rough edges, and please report what you find.*
