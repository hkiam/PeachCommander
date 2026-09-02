---
title: Previews of files that are not on this Mac
slug: remote-previews
group: Using Peach Commander
section: Viewing & editing
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander previews the file under the cursor in the info sidebar, in Quick View and as thumbnails in gallery view. When that file is not on a disk attached to this Mac, showing it costs something real — a download, an unpacking, or both — and none of it was asked for: the cursor merely moved onto the file. So Peach Commander decides how much a preview may cost before it starts, and this page explains what it decides and how to change it.

## Files inside an archive

A file inside an archive can be previewed exactly as one outside it. Peach Commander unpacks it to a temporary copy in the background and shows that. The same goes for Quick Look, for opening a file in another application with Enter or a double-click, and for the Open With submenu.

What another application receives is a copy, and it is read-only: what you change there is not written back into the archive. Peach Commander says so the first time, with a box to stop saying it. To edit a file that lives in an archive, unpack it first with F5 and work on the unpacked file.

## What a preview may cost

A preview follows the cursor, so it happens without being asked for. It is therefore held to a budget that depends on where the file's contents actually are:

- On a disk attached to this Mac there is no limit, and previews behave exactly as they always have.
- On a network location — a mounted share, FTP, SFTP, Amazon S3 or a plugin drive — files are previewed up to 4 MB, until Peach Commander has measured how fast that connection really is. After that it allows whatever it can read in about a second and a half, so a fast share shows large files and a slow one declines small ones.
- Inside an archive, a file is unpacked for a preview up to 32 MB.
- A file a cloud service has not yet downloaded to this Mac is never fetched just because the cursor moved onto it.
- In archive formats that have to be unpacked one file at a time — CPIO, ISO, CAB, LZH and similar — nothing is previewed automatically, because every single file costs a full pass over the archive.

A declined preview is not an empty panel: the sidebar shows the file's icon, its name, size and date, and one line saying why. Quick Look shows it anyway and is never held to any of these limits.

## Change the limits

1. Open Settings ▸ Edit/View.
2. Switch off "Preview files on network locations automatically" to stop network previews entirely, or set "Network files up to (MB)" to the size you want.
3. Switch on "Download files from the cloud to preview them" if you would rather have the preview than the saved traffic.
4. Set "Unpack from archives up to (MB)" for how large a file inside an archive may be.

Two more settings have no control of their own and live in `peachcmd.ini` under `[Preview]`: `AutoPreviewSeconds` is the time budget that applies once a connection has been measured (1.5 by default, 0 switches it off), and `AutoPreviewLocalMB` is a ceiling for local disks (0, meaning no limit).

## Where the unpacked copies go

Copies are written to the system's temporary folder, and the previews share them rather than each making its own. A copy made for a preview is removed when you leave the archive; a copy handed to another application stays until you quit Peach Commander, because that application still has it open. Whatever an unexpected quit leaves behind is recognized at the next launch and cleared then.

Thumbnails in gallery view follow the same budget, and only the cells actually on screen are made — so a folder of two thousand files costs a screenful, not two thousand. Files inside an archive get real thumbnails too; each one is unpacked for it, which is why the budget matters there most.
