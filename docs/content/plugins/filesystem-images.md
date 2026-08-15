---
title: Linux filesystem images
slug: filesystem-images
section: SDK & plugins
order: 40
related: [plugin-architecture-guide, plugin-tutorials]
---

The **Linux Filesystem Images** plugin opens a filesystem image the way Peach
Commander opens an archive: put the cursor on `rootfs.squashfs` and press Enter, and
the panel is inside the filesystem. The lister, the search and every file operation
then work on it unchanged, because the image is mounted as an ordinary virtual
filesystem.

It is **read-only**. Nothing in it can write to an image.

## What it reads

| Format | Notes |
|---|---|
| SquashFS 4.0 | gzip, xz, lz4, zstd and LZO; fragments, sparse files, uncompressed blocks |
| ext2 / ext3 / ext4 | extent trees and the classic block map, sparse files, both symlink kinds |
| JFFS2 | little- and big-endian; `none`, `zero`, `rtime`, zlib and LZO nodes |
| cramfs | little- and big-endian |
| initramfs / initrd | cpio `newc`, plain or gzip/xz-wrapped, including concatenated archives |
| Btrfs | single-device, zlib, zstd and LZO, subvolumes and snapshots |
| UBIFS | bare `.ubifs` and `.ubi` containers; LZO, zlib, zstd |

## Turning it on

The plugin ships **disabled**. Enable it in Settings ▸ Plugins.

Once it is on, an image opens whatever it is called. Firmware is rarely named tidily —
the images worth opening are called `firmware.bin`, `rootfs.img` or simply `dump` at
least as often as `.squashfs` — so when a file's extension means nothing, Peach
Commander asks the plugin to look at the file's first bytes instead. A file that is not
an image is declined after that one read and opens the way it always would have.

That look is why the plugin is off by default: with none installed, nothing reads a
file you only pressed Enter on.

## What it refuses, and why

A refusal names its reason instead of reporting damage, because the two lead
somewhere different — one tells you which tool to reach for, the other sends you
looking for a bad download.

- **RAID0, RAID10, RAID5, RAID6 (Btrfs)** — these spread one logical range across
  several stripes. Reading only the first would return every other piece of a file as
  whatever happened to sit at that offset, so the image is declined rather than read
  wrongly.
- **Multi-device Btrfs** — most of the data is in a file that is not this one.
- **A NAND dump with its spare area** — a raw dump interleaves out-of-band ECC bytes
  with the data, so node payloads fail their own checksums. Re-dump it with
  `nanddump --omitoob`.
- **Encrypted, bigalloc or META_BG ext4; zoned or extent-tree-v2 Btrfs** — each
  changes how the image must be read in a way this plugin does not implement.
- **An ext4 file whose inline data spills into `system.data`** — files and directories
  small enough to live inside their inode are read; one that continues in an extended
  attribute is declined rather than returned 60 bytes short, because a file that is
  quietly truncated looks exactly like one that read correctly.

## Unclean ext filesystems

An ext image taken from a running system, or from a device that lost power, can carry
a dirty journal. The committed truth is then in the journal while the block groups
still hold the older version — and this plugin does not replay journals.

Such an image still opens, with an entry at the top of its root reading
`!! UNCLEAN FILESYSTEM - run e2fsck, contents may be stale`. Run `e2fsck` on a copy
if the contents matter. Showing the older data with no indication would be the worse
answer: it looks exactly like the current data.

## Symlinks

A symbolic link inside an image is listed with its name and extracts as a small text
file holding its target. Peach Commander has no symlink concept inside an archive,
and creating a real link on extraction would let an image plant a link pointing
anywhere in your filesystem.

## Limits

Images are parsed once and cached, so reopening one is cheap — this matters, because
copying a directory out asks the plugin for each file separately. A listing is capped
at two million entries; deeper recursion, oversized decompressed blocks and
directory cycles are each bounded and reported rather than followed.
