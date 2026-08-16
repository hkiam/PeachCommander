#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# make-fsimage-fixtures.sh — build the golden filesystem images the FSImage plugin is tested against.
#
# Three of the formats this plugin reads have no image builder on macOS: cramfs, JFFS2 and Btrfs have
# no Homebrew formula, and mounting them to populate one needs a Linux kernel. So the images are built
# once, inside a container, and committed — SquashFS and ext are not here because mksquashfs and
# mke2fs run natively and the tests build those fixtures themselves on every run.
#
# This does NOT run in CI. It is the documented provenance of files that are already in the tree: run
# it when a fixture needs to change, commit the result together with the manifest it writes, and the
# tests keep using the committed copies.
#
# Why committed rather than generated per run: a test that needs Docker is a test that does not run.
# Why a manifest: in a year, "what was this image supposed to prove, and what built it" is not
# recoverable from the bytes. Each entry records the exact command, the tool version and the sha256
# of the uncompressed image.
#
# The images are stored gzip-compressed. They are mostly empty filesystem structure, so the committed
# files stay a few KB — under the 100 KB rule in CONVENTIONS.md for fixtures in the tree. The tests
# decompress with /usr/bin/gunzip, which is always present.
#
# The two NTFS images are the documented exception at 138 KB and 150 KB. An NTFS volume's own metadata
# is the floor: `$UpCase` alone is a 128 KB table of UTF-16 mappings that barely compresses, and even
# the smallest volume mkntfs will make lands there. Shrinking the sample tree does not help; the data
# is not what makes them big.
#
# Usage:
#   Tools/make-fsimage-fixtures.sh            # rebuild every fixture
#   Tools/make-fsimage-fixtures.sh cramfs     # rebuild the ones whose name contains "cramfs"
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/Tests/PCPluginHostTests/Fixtures/fsimage"
FILTER="${1:-}"
IMAGE="ubuntu:24.04"

command -v docker >/dev/null || { echo "error: docker is required (colima start, or Docker Desktop)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "error: the docker daemon is not running" >&2; exit 1; }

mkdir -p "$OUT"
BUILD_SCRIPT="$(mktemp)"
CONTAINER=""
# The container is created without a fixed name and removed by id. A fixed name meant that
# one run which failed to clean up — a FUSE mount left standing inside it did exactly that —
# blocked every later run with a name conflict, and the stuck container could not be removed
# to clear it either.
cleanup() {
  rm -f "$BUILD_SCRIPT"
  [ -n "$CONTAINER" ] && docker rm -f "$CONTAINER" >/dev/null 2>&1
  return 0
}
trap cleanup EXIT

# The script is copied into the container rather than piped to `bash -s`: with the script on stdin,
# any child process that reads stdin swallows the rest of it, and the run ends early and silently.
# That happened while writing this.
cat > "$BUILD_SCRIPT" <<'CONTAINER_SCRIPT'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 </dev/null
apt-get install -y -qq util-linux mtd-utils btrfs-progs fdisk gdisk squashfs-tools e2fsprogs dosfstools mtools exfatprogs exfat-fuse fuse3 ntfs-3g attr python3 >/dev/null 2>&1 </dev/null

# The sample tree. Must match `ExpectedTree` in FSImagePluginTests.swift — that is what makes the
# conformance battery comparable across formats rather than three different trees checked three ways.
R=/tmp/tree
rm -rf "$R"; mkdir -p "$R/etc/conf.d" "$R/bin"
printf 'hello from initramfs\n' > "$R/etc/motd"
printf 'key = value\n'          > "$R/etc/conf.d/app.conf"
: > "$R/bin/empty"
ln -s ../etc/motd "$R/bin/motd-link"
# Spans many blocks so block lists are walked, but repeats so the committed image stays small.
# Deterministic, so a mismatch is the reader's fault and never the fixture's.
python3 -c "
import sys
sys.stdout.buffer.write(bytes((i * 7 + 3) % 251 for i in range(300000)))
" > "$R/bin/pattern.dat"

O=/out; rm -rf "$O"; mkdir -p "$O"
record() { echo "$1|$2|$3" >> "$O/commands.txt"; }

# --- cramfs: little- and big-endian ---------------------------------------------------------------
# Big-endian is not a curiosity: cramfs images out of MIPS and PowerPC devices are byte-swapped, and a
# reader that assumes little-endian reads them as garbage rather than refusing them.
V="$(mkfs.cramfs -h 2>&1 | grep -oiE 'from util-linux [0-9.]+' || echo 'util-linux')"
mkfs.cramfs "$R" "$O/cramfs-le.img" >/dev/null 2>&1
record cramfs-le.img "mkfs.cramfs \$TREE cramfs-le.img" "$V"
mkfs.cramfs -N big "$R" "$O/cramfs-be.img" >/dev/null 2>&1
record cramfs-be.img "mkfs.cramfs -N big \$TREE cramfs-be.img" "$V"

# --- JFFS2: little- and big-endian ----------------------------------------------------------------
# -e 128KiB is the erase-block size of the NOR flash these images target; -p pads to a whole block so
# the image looks like a flash dump rather than stopping mid-block.
V="$(mkfs.jffs2 --version 2>&1 | head -1 || true)"
mkfs.jffs2 -r "$R" -o "$O/jffs2-le.img" -e 128KiB -l -p >/dev/null 2>&1
record jffs2-le.img "mkfs.jffs2 -r \$TREE -o jffs2-le.img -e 128KiB -l -p" "$V"
mkfs.jffs2 -r "$R" -o "$O/jffs2-be.img" -e 128KiB -b -p >/dev/null 2>&1
record jffs2-be.img "mkfs.jffs2 -r \$TREE -o jffs2-be.img -e 128KiB -b -p" "$V"
# rtime is JFFS2's own codec and mkfs picks it only when it beats zlib on a given node — which on
# this tree is never. Disabling zlib and lzo forces it, so the decoder has an image to be tested
# against instead of being reasoned about and shipped untried.
mkfs.jffs2 -r "$R" -o "$O/jffs2-rtime.img" -e 128KiB -l -p -x zlib -x lzo >/dev/null 2>&1
record jffs2-rtime.img "mkfs.jffs2 -r \$TREE -o jffs2-rtime.img -e 128KiB -l -p -x zlib -x lzo" "$V"

# --- UBIFS, bare and inside a UBI container ---------------------------------------------------------
# The bare filesystem and the container firmware actually ships. UBI only reorders erase blocks, so
# both must read identically — which is the point of having each.
V="$(mkfs.ubifs -V 2>&1 | head -1 || true)"
mkfs.ubifs -q -r "$R" -m 2048 -e 126976 -c 200 -o "$O/rootfs.ubifs"
record rootfs.ubifs "mkfs.ubifs -r \$TREE -m 2048 -e 126976 -c 200 -o rootfs.ubifs" "$V"
cat > /tmp/ubinize.cfg <<CFG
[rootfs]
mode=ubi
image=$O/rootfs.ubifs
vol_id=0
vol_type=dynamic
vol_name=rootfs
vol_flags=autoresize
CFG
ubinize -o "$O/rootfs.ubi" -m 2048 -p 128KiB /tmp/ubinize.cfg >/dev/null 2>&1
record rootfs.ubi "ubinize -o rootfs.ubi -m 2048 -p 128KiB (wrapping rootfs.ubifs as volume 0)" "$V"

# --- Btrfs ----------------------------------------------------------------------------------------
# -M (mixed block groups) with 4 KB nodes is what keeps this to 16 MB. Without it mkfs.btrfs grows the
# file to its ~109 MB minimum, and the committed fixture would be 120 KB compressed instead of 21 KB.
V="$(mkfs.btrfs --version 2>&1 | head -1 || true)"
truncate -s 16m "$O/btrfs.img"
mkfs.btrfs -q -f -M -n 4096 -s 4096 -r "$R" "$O/btrfs.img" >/dev/null 2>&1
record btrfs.img "truncate -s 16m btrfs.img && mkfs.btrfs -f -M -n 4096 -s 4096 -r \$TREE btrfs.img" "$V"

# A second Btrfs image with the parts `mkfs.btrfs -r` cannot produce: compressed
# extents, a subvolume, a snapshot, and enough files to push the filesystem tree past
# a single level. Those are the paths most likely to be wrong — a driver that only
# ever sees one flat, uncompressed tree has tested almost none of what btrfs is. It
# needs a real mount, hence the privileged container.
if mount --help >/dev/null 2>&1 && truncate -s 32m "$O/btrfs-rich.img" \
   && mkfs.btrfs -q -f -M -n 4096 -s 4096 "$O/btrfs-rich.img" >/dev/null 2>&1 \
   && mkdir -p /mnt/btr && mount -o loop,compress-force=zlib "$O/btrfs-rich.img" /mnt/btr 2>/dev/null; then
  cp -a "$R/." /mnt/btr/
  btrfs subvolume create /mnt/btr/data >/dev/null 2>&1
  printf 'inside a subvolume\n' > /mnt/btr/data/note.txt
  btrfs subvolume snapshot /mnt/btr/data /mnt/btr/data-snap >/dev/null 2>&1
  mkdir -p /mnt/btr/many
  python3 -c "
for i in range(500):
    open('/mnt/btr/many/f%04d.txt' % i, 'w').write('file %d\n' % i)
"
  sync; btrfs filesystem sync /mnt/btr >/dev/null 2>&1; umount /mnt/btr
  record btrfs-rich.img "mkfs.btrfs -f -M -n 4096 -s 4096 btrfs-rich.img, then mounted with compress-force=zlib and populated (subvolume + snapshot + 500 files)" "$V"
  truncate -s 32m "$O/btrfs-lzo.img"
  mkfs.btrfs -q -f -M -n 4096 -s 4096 "$O/btrfs-lzo.img" >/dev/null 2>&1
  if mount -o loop,compress-force=lzo "$O/btrfs-lzo.img" /mnt/btr 2>/dev/null; then
    cp -a "$R/." /mnt/btr/ ; sync; umount /mnt/btr
    record btrfs-lzo.img "mkfs.btrfs -f -M -n 4096 -s 4096 btrfs-lzo.img, then mounted with compress-force=lzo and populated" "$V"
  else
    rm -f "$O/btrfs-lzo.img"
  fi
else
  echo "  note: skipping btrfs-rich.img — needs a privileged container (docker run --privileged)" >&2
  rm -f "$O/btrfs-rich.img"
fi

# --- FAT12 / FAT16 / FAT32 --------------------------------------------------------------------------
# mtools writes into the image without mounting it, so this needs no privileges at all. The three
# widths differ only in the allocation table, but the cluster count decides which one mkfs picks, so
# each gets a size that lands it there. A deliberately long filename exercises VFAT long names —
# without them the listing shows PATTER~1.DAT for a file called pattern.dat.
export MTOOLS_SKIP_CHECK=1
V="$(mkfs.vfat --help 2>&1 | head -1 || true)"
build_fat() {
  local img="$O/$1" bits="$2" mb="$3"
  rm -f "$img"; dd if=/dev/zero of="$img" bs=1M count="$mb" 2>/dev/null
  mkfs.vfat -F "$bits" -n SAMPLE "$img" >/dev/null 2>&1
  mmd -i "$img" ::/etc ::/etc/conf.d ::/bin
  mcopy -i "$img" "$R/etc/motd" ::/etc/motd
  mcopy -i "$img" "$R/etc/motd" "::/etc/a-rather-long-file-name.conf"
  mcopy -i "$img" "$R/etc/conf.d/app.conf" ::/etc/conf.d/app.conf
  mcopy -i "$img" "$R/bin/empty" ::/bin/empty
  mcopy -i "$img" "$R/bin/pattern.dat" ::/bin/pattern.dat
}
build_fat fat12.img 12 8
record fat12.img "mkfs.vfat -F 12 -n SAMPLE fat12.img (8 MB), populated with mtools" "$V"
build_fat fat16.img 16 32
record fat16.img "mkfs.vfat -F 16 -n SAMPLE fat16.img (32 MB), populated with mtools" "$V"
build_fat fat32.img 32 64
record fat32.img "mkfs.vfat -F 32 -n SAMPLE fat32.img (64 MB), populated with mtools" "$V"

# --- exFAT ------------------------------------------------------------------------------------------
# No mtools equivalent exists for exFAT, so this one has to be mounted. The kernel exfat driver is not
# in the container's kernel and exfat-fuse refuses a plain file, hence a loop device.
#
# The files are copied one by one rather than with `cp -R`: exFAT has no symbolic links, so copying the
# sample tree wholesale fails on `bin/motd-link` with "Function not implemented" — and a failure there
# left the FUSE mount standing, after which the container hung rather than ending. Everything is
# therefore `|| true`-guarded and unwound in a fixed order.
V="$(mkfs.exfat -V 2>&1 | head -1 || true)"
truncate -s 64m "$O/exfat.img"
mkfs.exfat -L SAMPLE "$O/exfat.img" >/dev/null 2>&1
EXLOOP="$(losetup -f --show "$O/exfat.img" 2>/dev/null || true)"
EXOK=0
if [ -n "$EXLOOP" ] && mkdir -p /mnt/x && mount.exfat-fuse "$EXLOOP" /mnt/x 2>/dev/null; then
  if mkdir -p /mnt/x/etc/conf.d /mnt/x/bin \
     && cp "$R/etc/motd" /mnt/x/etc/motd \
     && cp "$R/etc/motd" "/mnt/x/etc/a-rather-long-file-name.conf" \
     && cp "$R/etc/conf.d/app.conf" /mnt/x/etc/conf.d/app.conf \
     && cp "$R/bin/empty" /mnt/x/bin/empty \
     && cp "$R/bin/pattern.dat" /mnt/x/bin/pattern.dat; then
    EXOK=1
  fi
  sync || true
  umount /mnt/x || true
fi
[ -n "$EXLOOP" ] && { losetup -d "$EXLOOP" || true; }
if [ "$EXOK" = 1 ]; then
  record exfat.img "mkfs.exfat -L SAMPLE exfat.img (64 MB), populated over a loop device with exfat-fuse" "$V"
else
  echo "  note: skipping exfat.img — needs --privileged and /dev/fuse" >&2
  rm -f "$O/exfat.img"
fi

# --- NTFS -------------------------------------------------------------------------------------------
# Two images. `ntfscp` writes into one without mounting, which covers the flat case with no privileges
# at all. The rich one has to be mounted to get directories and — the part worth the trouble —
# compressed files: ntfs-3g compresses what is written into a directory carrying
# FILE_ATTRIBUTE_COMPRESSED. The `_be` spelling of the attribute is the one that takes; the plain one
# wants the other byte order and silently does nothing, which is how this looked like it was working
# while producing zero compressed files.
V="$(mkntfs -V 2>&1 | head -1 || true)"
truncate -s 8m "$O/ntfs.img"
mkntfs -Q -F -L SAMPLE "$O/ntfs.img" >/dev/null 2>&1
for f in motd app.conf empty pattern.dat; do ntfscp "$O/ntfs.img" "$R/$f" "/$f" >/dev/null 2>&1 || true; done
ntfscp "$O/ntfs.img" "$R/etc/motd" /motd >/dev/null 2>&1 || true
ntfscp "$O/ntfs.img" "$R/etc/conf.d/app.conf" /app.conf >/dev/null 2>&1 || true
ntfscp "$O/ntfs.img" "$R/bin/empty" /empty >/dev/null 2>&1 || true
ntfscp "$O/ntfs.img" "$R/bin/pattern.dat" /pattern.dat >/dev/null 2>&1 || true
ntfscp "$O/ntfs.img" "$R/etc/motd" "/a-rather-long-file-name.conf" >/dev/null 2>&1 || true
record ntfs.img "mkntfs -Q -F -L SAMPLE ntfs.img (8 MB), populated with ntfscp (no mount)" "$V"

truncate -s 16m "$O/ntfs-rich.img"
mkntfs -Q -F -L SAMPLE "$O/ntfs-rich.img" >/dev/null 2>&1
NTLOOP="$(losetup -f --show "$O/ntfs-rich.img" 2>/dev/null || true)"
NTOK=0
if [ -n "$NTLOOP" ] && mkdir -p /mnt/n && ntfs-3g -o compression "$NTLOOP" /mnt/n 2>/dev/null; then
  if cp -R "$R/." /mnt/n/ \
     && cp "$R/etc/motd" "/mnt/n/etc/a-rather-long-file-name.conf" \
     && mkdir -p /mnt/n/deep/a/b/c && printf 'nested\n' > /mnt/n/deep/a/b/c/leaf.txt \
     && mkdir -p /mnt/n/comp \
     && setfattr -h -v 0x00000800 -n system.ntfs_attrib_be /mnt/n/comp \
     && cp "$R/bin/pattern.dat" /mnt/n/comp/pattern.dat \
     && cp "$R/etc/motd" /mnt/n/comp/motd; then
    NTOK=1
  fi
  sync || true
  umount /mnt/n || true
fi
[ -n "$NTLOOP" ] && { losetup -d "$NTLOOP" || true; }
if [ "$NTOK" = 1 ]; then
  record ntfs-rich.img "mkntfs then mounted with ntfs-3g -o compression; directories, deep nesting and a FILE_ATTRIBUTE_COMPRESSED directory" "$V"
else
  echo "  note: skipping ntfs-rich.img — needs --privileged and /dev/fuse" >&2
  rm -f "$O/ntfs-rich.img"
fi

# --- Partitioned disk images, MBR and GPT -----------------------------------------------------------
# The case every driver here would otherwise miss: the filesystem is a slice, not the file. Each
# holds two partitions the plugin can already read, so what is being tested is the table and the
# windowing, not another format.
mksquashfs "$R" /tmp/p1.sqfs -comp gzip -noappend -no-progress -quiet >/dev/null 2>&1
mke2fs -q -t ext4 -d "$R" -b 1024 /tmp/p2.img 8M >/dev/null 2>&1
build_disk() {
  local img="$1" layout="$2"
  rm -f "$img"; truncate -s 48m "$img"
  printf '%b' "$layout" | sfdisk -q "$img" >/dev/null 2>&1
  dd if=/tmp/p1.sqfs of="$img" bs=512 seek=2048  conv=notrunc 2>/dev/null
  dd if=/tmp/p2.img  of="$img" bs=512 seek=18432 conv=notrunc 2>/dev/null
}
V="$(sfdisk --version 2>&1 | head -1 || true)"
build_disk "$O/disk-mbr.img" 'label: dos\n1: start=2048, size=16384, type=83\n2: start=18432, size=20480, type=83\n'
record disk-mbr.img "sfdisk 'label: dos' with two type-83 partitions, squashfs at LBA 2048 and ext4 at 18432" "$V"
# GPT names the partitions, which is what the listing shows instead of a type.
build_disk "$O/disk-gpt.img" 'label: gpt\n1: start=2048, size=16384, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="rootfs"\n2: start=18432, size=20480, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="esp"\n'
record disk-gpt.img "sfdisk 'label: gpt' with a Linux and an EFI partition, named rootfs and esp" "$V"

cd "$O"
# Every fixture, not just *.img: UBIFS images are named .ubifs and .ubi, and matching on
# one extension silently left them unchecksummed and uncompressed — after which the copy
# on the host failed and `set -e` ended the run with no output at all.
IMAGES=()
for f in *; do [ "$f" = commands.txt ] && continue; IMAGES+=("$f"); done
for f in "${IMAGES[@]}"; do sha256sum "$f"; done > sha256.txt
gzip -9 "${IMAGES[@]}"
CONTAINER_SCRIPT

echo "==> Building fixtures in $IMAGE"
# --privileged is needed for exactly one fixture: btrfs-rich.img has to be *mounted* to
# get compressed extents, subvolumes and snapshots into it, and mount needs it. Every
# other image is built by an mkfs that writes a file, so the run degrades to skipping
# that one fixture rather than failing when privileges are unavailable.
CONTAINER="$(docker create --privileged --device /dev/fuse "$IMAGE" bash /build.sh)"
docker cp "$BUILD_SCRIPT" "$CONTAINER:/build.sh" >/dev/null
docker start -a "$CONTAINER"

STAGING="$(mktemp -d)"
docker cp "$CONTAINER:/out/." "$STAGING/" >/dev/null

# The manifest is rewritten wholesale from what was just built, so it cannot describe a file that is
# no longer there.
MANIFEST="$OUT/manifest.txt"
{
  echo "# Golden filesystem images for the FSImage plugin tests."
  echo "# Generated by Tools/make-fsimage-fixtures.sh in $IMAGE — do not edit by hand."
  echo "#"
  echo "# Each row: <file>  <sha256 of the UNCOMPRESSED image>  <tool>  <command>"
  echo "# \$TREE is the sample tree in the generator script, which mirrors ExpectedTree in"
  echo "# FSImagePluginTests.swift."
  echo
} > "$MANIFEST"

COPIED=0
while IFS='|' read -r name command version; do
  [ -n "$name" ] || continue
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then continue; fi
  sum="$(grep "  $name\$" "$STAGING/sha256.txt" | cut -d' ' -f1)"
  cp "$STAGING/$name.gz" "$OUT/$name.gz"
  printf '%s  %s  %s  %s\n' "$name" "$sum" "$version" "$command" >> "$MANIFEST"
  COPIED=$((COPIED + 1))
done < "$STAGING/commands.txt"

rm -rf "$STAGING"
echo "==> Wrote $COPIED fixture(s) to ${OUT#$ROOT/}"
ls -l "$OUT" | tail -n +2 | awk '{printf "    %8d  %s\n", $5, $9}'
