---
title: Network shares
slug: network-shares
group: Using Peach Commander
section: Network & remote
order: 104
related: [ftp-and-sftp]
---

Peach Commander can connect to file servers on your local network or company network — SMB (Windows/Samba) and AFP shares — and show their contents in a panel just like a folder on your own Mac. Once a share is connected, you can browse, copy, move, rename, and open files across it exactly as you would locally, including copying between the share and your other panel.

## Connect to a server

1. Click the panel you want to connect (the connected share opens in the active panel).
2. Press Cmd+K, or choose **Net > Network Neighborhood > Mount Network Share…**.
3. In the **Connect to Server** dialog, type the server address. You can enter:
   - an SMB address, for example `smb://fileserver/projects`
   - an AFP address, for example `afp://fileserver/projects`
   - a Windows-style path, for example `\\fileserver\projects\reports`
   - a plain `server/share` name
4. Click Connect (or press Return). If the server needs a name and password, macOS shows its standard sign-in prompt — enter your credentials there.
5. When the share is ready, the active panel opens it automatically. Browse and work with it like any other folder.

## Disconnect

A connected share appears as a mounted volume on your Mac. To disconnect it, eject it the usual macOS way — for example from the Finder sidebar, or from the drive list in Peach Commander.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Mount network share… | Cmd+K |

## Notes

- Authentication (user name, password, and any "remember this in my keychain" choice) is handled by the standard macOS sign-in sheet, so saved server passwords work the same as they do in the Finder.
- If you enter an address that can't be understood, Peach Commander asks you to provide an SMB/AFP address, a Windows-style path, or a `server/share` name, and nothing is mounted.
- After you confirm, connecting can take a moment while macOS mounts the share; the panel switches to it as soon as it becomes available.
- This connects to shared drives on a network. To reach an FTP, FTPS, or SFTP server instead, see the related topic below.
- A Windows-style path works in **Go to Folder** and in the path bar above a panel too, not only in Connect to Server. Type `\\fileserver\projects\reports` there and you land in that folder.
- If the share is already connected you go straight to the folder — no sign-in sheet and no second trip to the server. Only the share itself is ever mounted; the folders below it are reached by ordinary navigation, so the whole tree above them stays available.
