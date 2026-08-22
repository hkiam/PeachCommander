---
title: Troubleshooting
slug: troubleshooting
group: Reference & help
section: Help & troubleshooting
order: 140
related: [privacy-and-security, known-limitations]
---

This topic covers the problems people hit most often: macOS blocking access to certain folders, a folder that seems stuck on old contents, a secure FTP server that refuses to connect, and packing to RAR. Each section tells you what is happening and how to fix it.

## macOS asks for permission, or folders look empty

Some locations — such as your `~/Library` folder, other users' folders, and system areas — are protected by macOS and stay hidden until you grant access. Peach Commander detects when this happens and offers to guide you to the right setting.

1. When prompted, choose to open System Settings, or open it yourself.
2. Go to Privacy & Security, then Full Disk Access.
3. Turn on the switch next to Peach Commander. If it is not listed, use the Add button to add it.
4. Quit and reopen Peach Commander so the new permission takes effect.

Peach Commander does not run inside a restricted sandbox, so once Full Disk Access is granted it can browse and manage files just like Finder.

## A folder does not show recent changes

Panels normally update on their own when files change on disk. If a folder was changed by another program, is on a network volume, or simply looks out of date, refresh it manually.

1. Click the panel you want to update.
2. Press F2 (or Ctrl+R) to re-read that folder.

Network and mounted volumes do not always report changes to macOS, so a manual refresh is the reliable fix there.

## An FTPS server will not connect

If a secure FTP connection fails, check these settings in the connection details:

- Match the server's security mode: explicit FTPS (AUTH TLS) versus implicit FTPS (port 990) are not interchangeable.
- If the connection stalls after logging in, switch between passive and active transfer mode — most servers behind a firewall need passive.
- If the server uses a self-signed certificate, you must explicitly allow it; the connection is refused otherwise.
- Confirm the host, port, user name, and password, and whether a SOCKS5 proxy is required on your network.

## Packing to RAR does nothing

Peach Commander can create ZIP, 7z, TAR, TAR.GZ, BZ2, and XZ archives on its own. RAR is different: because RAR is a proprietary format, creating RAR archives requires a separate RAR command-line tool installed on your Mac. Without it, RAR is unavailable when you pack files (Option+F5). To read existing RAR archives you can still open them like a folder. If you do not need RAR specifically, choose ZIP or 7z instead — both support strong AES-256 encryption and split volumes.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Refresh the active folder | F2 or Ctrl+R |
| Connect to an FTP/FTPS server | Ctrl+F |
| Mount a network share | Cmd+K |
| Pack the selected files | Option+F5 |

## Notes

- Passwords and other credentials are stored only in the macOS Keychain, never in plain configuration files.
- Mounting a network share (Cmd+K, or Net menu ▸ Mount Network Share…) uses the same connection macOS itself uses, so it will also appear in Finder.
- If a problem persists after a refresh and a restart, it may be a known limitation rather than a fault — see Known limitations.
