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
# Usage:
#   Tools/make-fsimage-fixtures.sh            # rebuild every fixture
#   Tools/make-fsimage-fixtures.sh cramfs     # rebuild the ones whose name contains "cramfs"
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
OUT="$ROOT/Tests/PCPluginHostTests/Fixtures/fsimage"
FILTER="${1:-}"
IMAGE="ubuntu:24.04"
CONTAINER="pc-fsimage-fixtures"

command -v docker >/dev/null || { echo "error: docker is required (colima start, or Docker Desktop)" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "error: the docker daemon is not running" >&2; exit 1; }

mkdir -p "$OUT"
BUILD_SCRIPT="$(mktemp)"
trap 'rm -f "$BUILD_SCRIPT"; docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT

# The script is copied into the container rather than piped to `bash -s`: with the script on stdin,
# any child process that reads stdin swallows the rest of it, and the run ends early and silently.
# That happened while writing this.
cat > "$BUILD_SCRIPT" <<'CONTAINER_SCRIPT'
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1 </dev/null
apt-get install -y -qq util-linux mtd-utils btrfs-progs python3 >/dev/null 2>&1 </dev/null

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
V="$(mkfs.jffs2 --version 2>&1 | head -1)"
mkfs.jffs2 -r "$R" -o "$O/jffs2-le.img" -e 128KiB -l -p >/dev/null 2>&1
record jffs2-le.img "mkfs.jffs2 -r \$TREE -o jffs2-le.img -e 128KiB -l -p" "$V"
mkfs.jffs2 -r "$R" -o "$O/jffs2-be.img" -e 128KiB -b -p >/dev/null 2>&1
record jffs2-be.img "mkfs.jffs2 -r \$TREE -o jffs2-be.img -e 128KiB -b -p" "$V"
# rtime is JFFS2's own codec and mkfs picks it only when it beats zlib on a given node — which on
# this tree is never. Disabling zlib and lzo forces it, so the decoder has an image to be tested
# against instead of being reasoned about and shipped untried.
mkfs.jffs2 -r "$R" -o "$O/jffs2-rtime.img" -e 128KiB -l -p -x zlib -x lzo >/dev/null 2>&1
record jffs2-rtime.img "mkfs.jffs2 -r \$TREE -o jffs2-rtime.img -e 128KiB -l -p -x zlib -x lzo" "$V"

# --- Btrfs ----------------------------------------------------------------------------------------
# -M (mixed block groups) with 4 KB nodes is what keeps this to 16 MB. Without it mkfs.btrfs grows the
# file to its ~109 MB minimum, and the committed fixture would be 120 KB compressed instead of 21 KB.
V="$(mkfs.btrfs --version 2>&1 | head -1)"
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
else
  echo "  note: skipping btrfs-rich.img — needs a privileged container (docker run --privileged)" >&2
  rm -f "$O/btrfs-rich.img"
fi

cd "$O"
for f in *.img; do sha256sum "$f"; done > sha256.txt
gzip -9 *.img
CONTAINER_SCRIPT

echo "==> Building fixtures in $IMAGE"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
# --privileged is needed for exactly one fixture: btrfs-rich.img has to be *mounted* to
# get compressed extents, subvolumes and snapshots into it, and mount needs it. Every
# other image is built by an mkfs that writes a file, so the run degrades to skipping
# that one fixture rather than failing when privileges are unavailable.
docker create --privileged --name "$CONTAINER" "$IMAGE" bash /build.sh >/dev/null
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
