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

# A sample archive
( cd "$ROOT/Documents" && /usr/bin/zip -q -r "$ROOT/Archives/documents.zip" report.txt notes.md inventory.csv )

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
