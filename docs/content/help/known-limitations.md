---
title: Known limitations
slug: known-limitations
section: Help & troubleshooting
order: 144
related: [troubleshooting]
---

Peach Commander does a lot, but a few features have honest limits in the current version. Knowing these ahead of time saves confusion when something behaves unexpectedly. This page lists the current constraints and, where possible, a simple workaround.

## Archives

- **Split (multi-part) ZIP archives open, but every part has to be there.** Standard ZIP — including ZIP64, so more than 65,535 items or more than 4 GB is fine — TAR, and gzip-compressed TAR open directly as folders. An archive split across several files opens too: press Enter on the `.zip` of a `.z01`, `.z02`, … set, or on the `.001` of a `name.zip.001` set. All the parts must sit in the same folder, and a set with one missing is refused rather than opened half-read. Split TAR archives are not covered.
- **Encrypted ZIP archives** (both older ZipCrypto and WinZip AES) are supported for browsing, but you'll be asked for the password.
- Other formats such as CPIO, ISO, CAB, LZH, XAR, and PAX open through a helper tool rather than the native reader.

## Network (SFTP / SCP)

- **Over SFTP, permissions and timestamps can be changed; an owner cannot.** The protocol carries owner and group as numbers only, and there is no way to look up a user name over it, so a change of owner is refused rather than guessed at — as are macOS file flags, which do not exist on the far side. Over plain FTP only permissions can be set, through the optional `SITE CHMOD` command, and a server that does not offer it says so instead of appearing to succeed.
- On first connection to an SFTP server you'll be asked to trust its host key. Peach Commander remembers it after that (trust on first use).

## Directory refresh

- **Only folders on this Mac are watched for outside changes.** A folder on this Mac updates by itself as soon as another program adds, changes, or removes a file in it. A remote location (FTP or SFTP) and the inside of an archive are not watched, because those protocols offer no way to be told — press F2 or Ctrl+R to re-read them.

## Other current limits

- **Some very long absolute paths** (deeply nested folders whose full path is unusually long) may not be handled reliably. Working closer to the top of the folder tree avoids this.
- **This preview build is unsigned.** Gatekeeper blocks the first launch, and how you allow it depends on your macOS version. On **macOS 15 Sequoia and later**: double-click once, dismiss the warning, then go to System Settings ▸ Privacy & Security and click **Open Anyway** — Apple removed the right-click shortcut for unsigned software in macOS 15, so right-clicking no longer helps. On **macOS 13–14**: right-click the app and choose Open, then confirm. Automatic updates are not yet available in this build.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Refresh active panel | F2 or Ctrl+R |
| Download from URL | Cmd+Shift+U |

## Notes

These are limitations of the current version and are expected to improve in later releases. If you hit behavior not described here, see the troubleshooting topic.
