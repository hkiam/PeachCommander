---
title: Migrating from Total Commander
slug: migration-from-total-commander
group: Get started
section: user-guide
order: 20
related: [keyboard-shortcuts, ftp-and-sftp, settings]
---

If you are coming from Total Commander on Windows, Peach Commander will feel familiar from the first launch. It is a dual-panel file manager with the same two-window rhythm, the same function-key commands, and roughly 150 commands you can bind and call. This page helps you switch your muscle memory over, bring across the parts of your setup that transfer cleanly, and understand the handful of things that work differently because this is macOS.

Peach Commander is not affiliated with or endorsed by the makers of Total Commander. It reads Total Commander's configuration files only to help you move your own settings across.

## Step 1: Turn on the TC-classic key scheme

Peach Commander ships with two keyboard layouts. Pick the one that matches how you already work.

- **TC-classic** reproduces the Total Commander function keys you know: F5 to copy, F6 to move, F7 to make a folder, F8 to delete, and Tab to jump between panels.
- **macOS-native** follows Mac conventions instead (Command-based shortcuts, Delete to Trash, and so on).

To switch:

1. Open the **Configuration** menu.
2. Open **Settings** (Cmd+,) and pick the **Keys** page.
3. Select **TC Classic**.

That single choice restores the function-key commands you have been pressing for years. For the full list of keys in each scheme, see [Keyboard shortcuts](keyboard-shortcuts.md).

*(screenshots/settings-layout.png)*
*The Configuration options window, where you choose your keyboard scheme and other defaults.*

## Step 2: Import your wincmd.ini

Total Commander keeps most of your personalization in a file called `wincmd.ini`, and your saved FTP sites in a companion file called `wcx_ftp.ini` next to it. Peach Commander can read both.

1. Copy your `wincmd.ini` (and, if you use FTP, the `wcx_ftp.ini` sitting beside it) from your Windows machine onto your Mac. Keep the two files in the same folder.
2. In Peach Commander, open the **Configuration** menu and choose **Import wincmd.ini…**.
3. In the file chooser, select your `wincmd.ini`.
4. Confirm the import. A short summary tells you exactly what came across.

What the import brings over:

- **Directory hotlist** → your directory bookmarks become entries in Peach Commander's favorites list. Nested submenus are flattened down to their folder entries, and separators are dropped. Existing bookmarks are kept — nothing is overwritten, only added. (See [Favorites & hotlist](favorites.md).)
- **Button bar** → your toolbar buttons are imported, whether they were stored inside `wincmd.ini` or in a separate `.bar` file kept next to it. Your current toolbar is backed up first (as a `.bak` file) before it is replaced.
- **FTP sites** (from `wcx_ftp.ini`) → each saved connection is recreated with its host, port, username, remote start folder, passive-mode setting, and whether it uses TLS (FTPS). Sites whose names already exist are skipped so nothing is duplicated.

What the import deliberately does **not** bring over:

- **Passwords.** Total Commander stores FTP passwords in an obfuscated form; Peach Commander does not decode them. You re-enter each password the first time you connect, and it is then saved in the macOS **Keychain** rather than in a settings file. See [Connecting to FTP & SFTP](ftp-and-sftp.md).
- **Colours.** If your `wincmd.ini` contains a custom colour scheme, the importer notes that it was found but does not apply it. Set your colours in Peach Commander directly under Configuration; see [Settings](settings.md).

## What maps one-to-one

Most of Total Commander's core is present and behaves the same way.

| In Total Commander | In Peach Commander |
| --- | --- |
| Two side-by-side panels, source and target | Same dual-panel layout |
| **Tab** to switch the active panel | Same (TC-classic scheme) |
| **F5** copy, **F6** move, **F7** new folder, **F8** delete | Same (TC-classic scheme) |
| Directory hotlist | Favorites (imported from `wincmd.ini`) |
| Button bar | Toolbar (imported from `wincmd.ini`) |
| Command list with `cm_` command names | The same command names, browsable in the Command Browser |
| Built-in FTP/FTPS/SFTP client | Built-in FTP, FTPS, SFTP, SCP, WebDAV, plus SOCKS5 proxy and a resuming HTTP downloader |
| Browsing archives as folders (zip, 7z, tar, rar) | Same — open an archive and step inside it like any folder |
| Multi-rename tool, synchronize, compare, find duplicates, checksums | All present |
| Deep file search | Search by name, content, regex, hex, encoding, inside archives, and via Spotlight |

Because the command names carry over (Total Commander's `cm_` commands), tips and macros that reference commands by name will read the same way. Open the **Command Browser** from the Configuration menu to search all ~150 commands and see which key each one is bound to.

*(screenshots/main-window.png)*
*The familiar dual-panel window: source on the left, target on the right.*

## What is different on macOS

A few things change because you are now on a Mac, not Windows. None of them get in your way once you know them.

- **No drive letters.** macOS has one file tree, not `C:` / `D:`. Instead of drive buttons you navigate to your home folder, and external disks and network volumes appear under **/Volumes**. Use the Go menu, favorites, or type a path directly in the path bar to jump around.
- **Delete goes to the Trash.** F8 (or the delete command) moves items to the macOS Trash by default, from where you can restore them, rather than deleting permanently. See [Deleting files](deleting-files.md).
- **Permissions are Unix-style.** Instead of Windows attributes you will see owner/group/other read-write-execute permissions and macOS flags. See [Attributes & permissions](attributes-and-permissions.md).
- **Path separators are forward slashes.** Paths look like `/Users/you/Documents`, not `C:\Users\you\Documents`.
- **Deeper system integration.** Peach Commander plugs into macOS features Total Commander never had: Quick Look preview, Finder tags, the Share sheet, Reveal in Finder, Open With, and "Open Terminal here". See [macOS integration](macos-integration.md).

## Your plugins: the heritage carries over

Total Commander's plugin ecosystem inspired Peach Commander's own. Peach Commander supports five plugin types and ships an SDK, and the categories line up with the ones you know:

- **Packer** plugins (Total Commander's WCX) — add support for more archive formats.
- **File-system** plugins (WFX) — surface a remote or virtual location as a browsable folder.
- **Lister / viewer** plugins (WLX) — preview additional file types.
- **Content** plugins (WDX) — expose extra columns and searchable fields.

Because the type model matches, an existing Total Commander plugin can be **source-ported** rather than rebuilt from scratch: the concepts translate directly, and the SDK gives you the matching entry points on macOS. Compiled Windows `.wcx` / `.wfx` / `.wlx` / `.wdx` binaries do **not** run as-is — they are Windows code — so a port means rebuilding the plugin against the Peach Commander SDK, not copying a `.dll`. To manage what is installed, open **Configuration ▸ Plugins…**; see [Plugins](plugins.md).

## Frequently asked questions

**Will my F-keys work right away?**
Yes, once you select the TC Classic keyboard scheme (Step 1). The default on a fresh install may be macOS-native, so check that first if F5 does not copy.

**Can I bring my passwords across?**
No, and this is on purpose. You re-enter each FTP/SFTP password once, and macOS then stores it securely in the Keychain.

**Where did my saved FTP servers go after import?**
They land in the connection manager. Open the Net menu to see them and connect. See [Connecting to FTP & SFTP](ftp-and-sftp.md).

**My colour scheme did not come across.**
Colours are not imported. Set them under Configuration; see [Settings](settings.md).

**Does Peach Commander phone home or track me?**
No. There is no telemetry.

## A note on the pre-1.0 build

Peach Commander is still pre-1.0. It is a universal app (Apple Silicon and Intel) and requires macOS 13 or later. Developer-ID signing and notarization are being finalized, so a preview build may need you to **right-click the app and choose Open** the first time to get past Gatekeeper. Automatic updates (Sparkle) are planned but not yet switched on, so for now you update by downloading a new build.
