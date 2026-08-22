---
title: Linux filesystem images
slug: plugin-filesystem-images
group: Develop
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
| FAT12 / FAT16 / FAT32 | long file names, all three table widths |
| exFAT | UTF-16 names, contiguous and chained files |
| NTFS | resident and non-resident files, LZNT1 compression, sparse files |
| Btrfs | single-device, zlib, zstd and LZO, subvolumes and snapshots |
| UBIFS | bare `.ubifs` and `.ubi` containers; LZO, zlib, zstd |

## Disk images with partitions

An image straight off a device usually has a partition table rather than a bare
filesystem, and the filesystem you want is a slice inside it. Such an image lists one
directory per partition — `1-rootfs`, `2-esp` — each holding that partition's tree. MBR
and GPT are both read; GPT partition names are used when the table records them.

A partition this build cannot read is still listed, as an empty directory named after
its type. Somebody auditing a device needs to see that a third partition exists even
when its contents are out of reach.

Whatever falls outside every partition is listed too, as an extractable blob named by
its offset. That space is where embedded devices keep their bootloader — a Raspberry Pi
uses the four megabytes ahead of partition 1, U-Boot on most ARM boards a fixed sector
offset — so listing only the partitions reports an image as having no bootloader when it
plainly has one. Runs below 64 KB are skipped: the table's own sector and a partition's
alignment slack are structure, not content, and reporting them would bury the one gap
that means something.

## Images with no table at all

Router and camera firmware usually has no partition table and no filesystem at offset 0.
It is a vendor header, a bootloader, a kernel and a rootfs concatenated at offsets the
vendor chose and recorded nowhere. When nothing else claims such a file, `CarvedDriver`
searches it for the filesystems themselves and lists what it finds:

```
0x00000000-firmware.trx      64 B    TRX firmware container
0x00000040-unknown.bin     192 KB    unrecognised data
0x00030040-kernel.uimage   2.0 MB    U-Boot kernel, gzip — Linux-6.1.0
0x00230044-squashfs/       1.4 MB    SquashFS 4.0, xz
```

Filesystems are directories to walk into; everything else is a file to copy out. The
offset is in the name because it is the only identifying fact such a region has.

**Every candidate is confirmed by opening it.** A signature match is never the answer on
its own — FAT's is the two bytes `55 AA`, which occur by chance roughly a thousand times
in a 64 MB image — so each hit is opened with the driver that claimed it, using the same
superblock validation an ordinary open performs. A coincidence fails that in microseconds.
This is what makes scanning for a two-byte pattern reasonable rather than a source of
invented entries.

Two consequences worth knowing when adding a driver. A driver joins the scan by declaring
`carveSignatures`, and declares `byteLength` when its superblock records how far the
filesystem extends — with a length, the driver is opened through a window that ends where
it ends, so a carved SquashFS cannot read into the kernel behind it. JFFS2 and UBIFS
record no length, and a region from those is reported as running to whatever comes next
rather than being given an invented extent.

`CarvedDriver.probe` accepts any file at all, because whether an image holds a buried
filesystem cannot be known without looking. The decision therefore lives in its
initialiser, which throws `.notThisFormat` when the scan found no filesystem — that
refusal is what keeps the plugin from claiming every `.bin` on the system, and
`CanYouHandleThisFile` answers by opening for real (through the parse cache) rather than
by probing, for the same reason.

**No search covers more than 512 MB.** The ceiling lives in `ImageLayout.scannedSpan`,
not at one entry point, because three callers reach the searching code and only one of
them is carving: `PartitionedDriver` searches the runs between its partitions, and a
whole-drive dump is mostly one such run — half a terabyte of unallocated tail at the
measured 400 MB/s is twenty minutes of frozen panel. Whatever lies past the ceiling is
still listed and still extracts; it is simply not searched, and the layout report says so
rather than letting a short list read as a complete one. 512 MB is what the technique is
for: it finds filesystems in *flash* images, and flash is not larger than that.

## The layout report

The plugin contributes one command, **Commands ▸ Scan Image Layout**, which writes the
scan result as `<image>.layout.txt` beside the image and reveals it in the panel.

It writes a report rather than navigating because it cannot navigate: `PcHostServices`
offers `openPath`, which goes to a real path, and there is no service that mounts a
virtual filesystem. Only pressing Enter on a file does that. What a command *can* produce
is the artefact — offsets, sizes, detected types, and the partition table if there is one
— which is usually what firmware work actually keeps, and which is tedious to rebuild by
walking a panel and copying numbers.

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
- **NTFS files whose attributes spill into an `$ATTRIBUTE_LIST`** — heavily fragmented
  files whose data runs live in other records. Reading only the first would hand back a
  fragment as if it were the file. Encrypted files and alternate data streams are
  likewise left out.
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
