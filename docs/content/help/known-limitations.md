---
title: Known limitations
slug: known-limitations
section: Help & troubleshooting
order: 144
related: [troubleshooting]
---

Peach Commander does a lot, but a few features have honest limits in the current version. Knowing these ahead of time saves confusion when something behaves unexpectedly. This page lists the current constraints and, where possible, a simple workaround.

## Archives

- **Very large ZIP files (ZIP64) can't be opened by the built-in reader.** Standard ZIP, TAR, and gzip-compressed TAR archives open directly as folders. ZIP64 archives — used when an archive holds more than about 65,000 items or exceeds 4 GB — are outside what the native reader handles, so they may fail to open or list incompletely.
- **Encrypted ZIP archives** (both older ZipCrypto and WinZip AES) are supported for browsing, but you'll be asked for the password.
- Other formats such as CPIO, ISO, CAB, LZH, XAR, and PAX open through a helper tool rather than the native reader.

## Network (SFTP / SCP)

- **Changing file attributes over SFTP has no effect in this version.** You can browse, download, and upload over SFTP/SCP, but requests to change permissions, ownership, or timestamps on a remote server are silently ignored. Make those changes on the server itself, or over a different protocol.
- On first connection to an SFTP server you'll be asked to trust its host key. Peach Commander remembers it after that (trust on first use).

## Downloading from a URL

- The **Download from URL** command (Net menu) currently uses the shortcut Cmd+Shift+D, which is the same shortcut as Go > Desktop. When both are available the menus can conflict — start the download from the Net menu directly to be sure.

## Directory refresh

- **Only folders on this Mac are watched for outside changes.** A folder on this Mac updates by itself as soon as another program adds, changes, or removes a file in it. A remote location (FTP or SFTP) and the inside of an archive are not watched, because those protocols offer no way to be told — press F2 or Ctrl+R to re-read them.

## Other current limits

- **Some very long absolute paths** (deeply nested folders whose full path is unusually long) may not be handled reliably. Working closer to the top of the folder tree avoids this.
- **This preview build is unsigned.** macOS Gatekeeper may warn that the app is from an unidentified developer the first time you open it. Right-click the app and choose Open, then confirm, to run it. Automatic updates are not yet available in this build.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Refresh active panel | F2 or Ctrl+R |
| Download from URL | Cmd+Shift+D |

## Notes

These are limitations of the current version and are expected to improve in later releases. If you hit behavior not described here, see the troubleshooting topic.
