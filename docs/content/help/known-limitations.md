---
title: Known limitations
slug: known-limitations
section: Help & troubleshooting
order: 144
related: [troubleshooting]
---

Peach Commander does a lot, but a few features have honest limits in the current version. Knowing these ahead of time saves confusion when something behaves unexpectedly. This page lists the current constraints and, where possible, a simple workaround.

## Archives

- **Split (multi-part) archives can't be opened.** Standard ZIP — including ZIP64, so more than 65,535 items or more than 4 GB is fine — TAR, and gzip-compressed TAR open directly as folders. An archive split across several files (`.z01`, `.zip.001`) is not handled: join the parts first, or unpack it with the tool that made it.
- **Encrypted ZIP archives** (both older ZipCrypto and WinZip AES) are supported for browsing, but you'll be asked for the password.
- Other formats such as CPIO, ISO, CAB, LZH, XAR, and PAX open through a helper tool rather than the native reader.

## Network (SFTP / SCP)

- **Changing file attributes over SFTP has no effect in this version.** You can browse, download, and upload over SFTP/SCP, but requests to change permissions, ownership, or timestamps on a remote server are silently ignored. Make those changes on the server itself, or over a different protocol.
- On first connection to an SFTP server you'll be asked to trust its host key. Peach Commander remembers it after that (trust on first use).

## Directory refresh

- **Only folders on this Mac are watched for outside changes.** A folder on this Mac updates by itself as soon as another program adds, changes, or removes a file in it. A remote location (FTP or SFTP) and the inside of an archive are not watched, because those protocols offer no way to be told — press F2 or Ctrl+R to re-read them.

## Other current limits

- **Some very long absolute paths** (deeply nested folders whose full path is unusually long) may not be handled reliably. Working closer to the top of the folder tree avoids this.
- **This preview build is unsigned.** macOS Gatekeeper may warn that the app is from an unidentified developer the first time you open it. Right-click the app and choose Open, then confirm, to run it. Automatic updates are not yet available in this build.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Refresh active panel | F2 or Ctrl+R |
| Download from URL | Cmd+Shift+U |

## Notes

These are limitations of the current version and are expected to improve in later releases. If you hit behavior not described here, see the troubleshooting topic.
