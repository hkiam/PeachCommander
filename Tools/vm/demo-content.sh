#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# demo-content.sh - Create a consistent, privacy-clean sample tree in the guest,
# used as the panel content for all documentation screenshots. Idempotent.
#
# Usage (from the host, against a running VM):  Tools/vm/demo-content.sh <guest-ip>
set -euo pipefail
IP="${1:?guest IP required}"
KEY="$HOME/.ssh/id_ed25519"
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $KEY"

ssh $SSHOPTS "admin@$IP" bash -s <<'REMOTE'
set -e
ROOT="$HOME/pc-demo"
rm -rf "$ROOT"; mkdir -p "$ROOT"/{Documents,Images,Projects/peach-app/src,Music,Downloads,Archives}

# Documents — a realistic, boring, non-personal mix
printf 'Quarterly report\n================\n\nRevenue up 12%%.\n' > "$ROOT/Documents/report.txt"
printf '# Meeting notes\n\n- Ship 1.0\n- Write docs\n' > "$ROOT/Documents/notes.md"
printf 'name,qty,price\nApples,12,0.40\nPears,8,0.55\n' > "$ROOT/Documents/inventory.csv"

# A real multi-page PDF, built from tools every macOS has. The Info sidebar's whole point is a
# large preview you can page through, and that cannot be shown on a one-line text file.
python3 - > /tmp/pc-doc.txt <<'PYDOC'
for page in range(1, 4):
    print(f"Peach Commander \u2014 sample document, page {page}\n")
    for i in range(1, 40):
        print(f"  line {i:02d} of page {page}: the quick brown fox jumps over the lazy dog.")
    print("\f", end="")
PYDOC
/usr/sbin/cupsfilter /tmp/pc-doc.txt > "$ROOT/Documents/handbook.pdf" 2>/dev/null || true
rm -f /tmp/pc-doc.txt
printf '{ "app": "Peach Commander", "version": "1.0" }\n' > "$ROOT/Documents/config.json"
printf 'Lorem ipsum dolor sit amet.\n' > "$ROOT/Documents/readme.txt"

# Projects — a small code tree for the code viewer/highlighter
cat > "$ROOT/Projects/peach-app/README.md" <<'EOF'
# Peach App
A tiny sample project used in documentation screenshots.
EOF
cat > "$ROOT/Projects/peach-app/src/main.swift" <<'EOF'
import Foundation

func greet(_ name: String) -> String {
    return "Hello, \(name)!"
}
print(greet("world"))
EOF
cat > "$ROOT/Projects/peach-app/src/utils.py" <<'EOF'
def add(a, b):
    """Return the sum of a and b."""
    return a + b
EOF

# A handful of images (solid-colour PNGs via sips from a generated file)
for c in 1 2 3; do
  printf 'placeholder image %s\n' "$c" > "$ROOT/Images/photo_$c.txt"
done

# Two *real* images for the zoom scenarios (F-389). Solid colours, so a dump can compare the pixel the
# app actually drew against the pixel in the file; known sizes, because the levels under test are about
# size — a photo-sized one that has to open fitted, and a 16x16 icon that must be left at 100% rather
# than blown up to fill the window. The comment above claimed PNGs for years while writing .txt files,
# which is why nothing in the suite had ever looked at an image.
mkppm() { # mkppm <path> <w> <h> <r> <g> <b>
  /usr/bin/python3 - "$@" <<'PY'
import sys
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
r, g, b = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6])
with open(path, "wb") as f:
    f.write(b"P6\n%d %d\n255\n" % (w, h))
    f.write(bytes((r, g, b)) * (w * h))
PY
}
mkppm "$ROOT/Images/big.ppm" 3000 2000 200 60 60
mkppm "$ROOT/Images/icon.ppm" 16 16 60 120 200
for n in big icon; do
  sips -s format png "$ROOT/Images/$n.ppm" --out "$ROOT/Images/$n.png" >/dev/null 2>&1
  rm -f "$ROOT/Images/$n.ppm"
done

# A sample archive
( cd "$ROOT/Documents" && /usr/bin/zip -q -r "$ROOT/Archives/documents.zip" report.txt notes.md inventory.csv )

# The archive-search case, as it was reported (F-463): a config file inside a .tar.gz whose
# text is nowhere else in the tree, plus an archive nothing can read. The first proves the
# search goes in; the second proves it says so when it cannot.
mkdir -p "$ROOT/Archives/stage/etc"
printf 'listen = 0.0.0.0\nsecret_token = swordfish\n' > "$ROOT/Archives/stage/etc/app.conf"
( cd "$ROOT/Archives/stage" && /usr/bin/tar -czf "$ROOT/Archives/backup.tar.gz" etc )
rm -rf "$ROOT/Archives/stage"
printf 'this is not an archive at all' > "$ROOT/Archives/broken.tar.gz"

# A few larger placeholder files so the Size column is interesting
mkfile 2m "$ROOT/Downloads/installer.dmg" 2>/dev/null || dd if=/dev/zero of="$ROOT/Downloads/installer.dmg" bs=1m count=2 2>/dev/null
mkfile 512k "$ROOT/Music/track01.m4a" 2>/dev/null || dd if=/dev/zero of="$ROOT/Music/track01.m4a" bs=1k count=512 2>/dev/null

# A few realistic third-party apps in ~/Applications so the Uninstaller plugin's
# picker (plugin.uninstaller.browse) has something to list. Apple system apps are
# hidden by the plugin, and a pristine VM has no third-party apps otherwise.
mkapp() { # mkapp "<Display Name>" <bundle-id> <size-kb>
  local name="$1" bid="$2" kb="$3"
  local c="$HOME/Applications/$name.app/Contents"
  mkdir -p "$c/MacOS" "$c/Resources"
  cat > "$c/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>$bid</string>
  <key>CFBundleShortVersionString</key><string>1.2.0</string>
  <key>CFBundleExecutable</key><string>app</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
  dd if=/dev/zero of="$c/MacOS/app" bs=1024 count="$kb" 2>/dev/null
}
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/"*.app
mkapp "Peachy Player"   com.example.peachyplayer 8200
mkapp "Markdown Mixer"  com.example.mdmixer      3100
mkapp "Widget Studio"   io.widgetstudio.app     24500
mkapp "Cloud Sync"      net.example.cloudsync    12800
mkapp "Retro Terminal"  com.example.retroterm    5300

# Leftover support files for "Peachy Player" (com.example.peachyplayer) so the
# Uninstaller's review window (plugin.uninstaller.uninstall on the cursor .app)
# lists real residuals — Application Support, Caches, Logs, Preferences — each with
# a size, matching the documented "review before removing" flow.
mkdir -p "$HOME/Library/Application Support/com.example.peachyplayer" \
         "$HOME/Library/Application Support/Peachy Player" \
         "$HOME/Library/Caches/com.example.peachyplayer" \
         "$HOME/Library/Logs/com.example.peachyplayer"
printf '{ "recent": ["report.txt"] }\n' > "$HOME/Library/Application Support/com.example.peachyplayer/state.json"
printf 'library database\n' > "$HOME/Library/Application Support/Peachy Player/library.db"
dd if=/dev/zero of="$HOME/Library/Caches/com.example.peachyplayer/thumbnails.cache" bs=1024 count=1800 2>/dev/null
printf 'session log\n' > "$HOME/Library/Logs/com.example.peachyplayer/session.log"
printf '<?xml version="1.0"?><plist version="1.0"><dict/></plist>\n' > "$HOME/Library/Preferences/com.example.peachyplayer.plist"

# Make Projects/peach-app a real Git repo with a few uncommitted changes, so the
# Git plugin's "Git Status" command (plugin.git.status) has content to report.
if command -v git >/dev/null 2>&1; then
  ( cd "$ROOT/Projects/peach-app"
    git init -q
    git config user.email demo@example.com
    git config user.name "Demo User"
    git add -A && git commit -q -m "Initial commit"
    # dirty the tree: modify a tracked file + add an untracked one
    printf '\n// TODO: polish greeting\n' >> src/main.swift
    printf 'print("staged change")\n' > src/new_feature.swift
    git add src/new_feature.swift
  ) || echo "git repo setup skipped"
else
  echo "git not found; skipping repo setup"
fi

echo "demo content ready at $ROOT: $(find "$ROOT" -type f | wc -l | tr -d ' ') files"
REMOTE

# ---------------------------------------------------------------------------
# A router firmware image, built on the HOST and copied in.
#
# Everything above runs inside the guest, and this cannot: the rootfs has to be a
# real SquashFS written by mksquashfs, and macOS has no such tool. Building it here
# and copying the result keeps the guest free of build dependencies, which is the
# same reason the golden image carries no toolchain.
#
# What it is for: the Filesystem Images plugin finds filesystems inside a file that
# has no partition table, and a screenshot of that needs a file actually shaped like
# router firmware — a vendor header, a bootloader, a U-Boot kernel and a rootfs at an
# offset nothing records. Faking it with an empty file would produce a screenshot of
# a feature not working.
mksquashfs="$(command -v mksquashfs || true)"
if [ -z "$mksquashfs" ]; then
  echo "mksquashfs not found (brew install squashfs) — skipping the firmware sample;" \
       "the filesystem-images screenshot cannot be captured without it" >&2
  exit 0
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/rootfs"/{bin,etc/init.d,lib,www}
printf 'ImaginaryTech RT-9000\nfirmware 2.4.1\n' > "$STAGE/rootfs/etc/banner"
printf 'hostname=rt9000\nlan_ip=192.168.1.1\nwifi_ssid=ImaginaryNet\n' > "$STAGE/rootfs/etc/config"
printf '#!/bin/sh\n/bin/httpd -p 80 -h /www &\n' > "$STAGE/rootfs/etc/init.d/httpd"
printf '<html><body><h1>RT-9000</h1></body></html>\n' > "$STAGE/rootfs/www/index.html"
for f in busybox httpd nvram wpa_supplicant; do
  head -c 24000 /dev/zero | tr '\0' 'x' > "$STAGE/rootfs/bin/$f"
done
head -c 90000 /dev/zero | tr '\0' 'y' > "$STAGE/rootfs/lib/libc.so.0"
"$mksquashfs" "$STAGE/rootfs" "$STAGE/root.sqfs" -comp xz -noappend -no-progress -quiet

python3 - "$STAGE" <<'PYFW'
import struct, sys
stage = sys.argv[1]
blob = bytearray()
# A vendor container header that declares its own length, so it reads as one region.
blob += b"HDR0" + struct.pack("<I", 64) + bytes(56)
# The bootloader: filler that cannot carry any signature the scan looks for.
blob += bytes(i % 128 for i in range(192 * 1024))
# A U-Boot legacy image. All fields big-endian, by definition of the format.
kernel = bytes((i * 31 + 7) % 251 for i in range(1_100_000))
name = b"Linux-5.15.0-rt9000"
header = (b"\x27\x05\x19\x56" + bytes(8) + struct.pack(">I", len(kernel)) + bytes(12)
          + bytes([5, 2, 2, 1]) + name + bytes(32 - len(name)))
assert len(header) == 64
blob += header + kernel
# The rootfs follows the kernel directly. Its offset is still aligned to nothing —
# the kernel's length sees to that — which is the property worth showing. Padding a
# gap in on purpose only added a three-byte region to the picture, and a 0.0 KB row
# in a documentation screenshot reads as a defect rather than as precision.
blob += open(f"{stage}/root.sqfs", "rb").read()
open(f"{stage}/rt9000-firmware.bin", "wb").write(bytes(blob))
print(f"firmware image: {len(blob)} bytes")
PYFW

ssh $SSHOPTS "admin@$IP" "mkdir -p ~/pc-demo/Firmware"
scp $SSHOPTS -q "$STAGE/rt9000-firmware.bin" "admin@$IP:~/pc-demo/Firmware/"
echo "firmware sample copied to ~/pc-demo/Firmware/rt9000-firmware.bin"
