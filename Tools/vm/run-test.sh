#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# run-test.sh - Drive one Peach Commander test run inside a fresh macOS VM.
#
# Each run starts from a pristine clone of the golden VM (copy-on-write, seconds),
# so state never leaks between runs — this is our "reset to snapshot".
#
#   1. clone golden -> ephemeral run VM
#   2. boot it with the built-in VNC server (framebuffer capture from the host)
#   3. rsync the Debug .app into the guest over SSH (key-based, set up by prepare-golden.sh)
#   4. launch the app and drive it via the -AutomationScript hook
#   5. screenshot the VM framebuffer via VNC (no guest Screen-Recording/TCC grant needed)
#   6. tear the clone down
#
# Usage: run-test.sh [--keep] [--script AUTOMATION] <path-to-.app> [out.png]
set -euo pipefail

KEEP=0
[ "${1:-}" = "--keep" ] && { KEEP=1; shift; }
AUTO=""
[ "${1:-}" = "--script" ] && { AUTO="$2"; shift 2; }

APP="${1:?path to built .app required}"
OUT="${2:-/tmp/pc-vm-shot.png}"
GOLDEN="golden"
RUN="pc-run-$$"
KEY="$HOME/.ssh/id_ed25519"
GUEST_USER="admin"
SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $KEY"

say() { printf '\033[1;36m[vm-test]\033[0m %s\n' "$*"; }
cleanup() {
  if [ "$KEEP" = 1 ]; then
    say "keeping $RUN running (VNC: ${VNC:-?}, ip: $(tart ip "$RUN" 2>/dev/null || echo ?)). Stop with: tart stop $RUN && tart delete $RUN"
    return
  fi
  [ -n "${RUN_PID:-}" ] && kill "$RUN_PID" 2>/dev/null || true
  tart delete "$RUN" 2>/dev/null || true; say "clone $RUN removed"
}
trap cleanup EXIT

[ -d "$APP" ] || { echo "no such .app: $APP"; exit 1; }

say "cloning $GOLDEN -> $RUN (copy-on-write)…"
tart clone "$GOLDEN" "$RUN"

say "booting $RUN with VNC…"
# --no-graphics as well: the VNC flag alone makes tart open the vnc:// URL, and that Screen Sharing
# window is never closed — one per run, piling up in a single process. The VNC server itself remains.
tart run "$RUN" --vnc-experimental --no-graphics >/tmp/tart-$RUN.log 2>&1 &
RUN_PID=$!

say "waiting for VNC endpoint…"
VNC=""
for _ in $(seq 1 60); do VNC=$(grep -o 'vnc://[^ ]*' /tmp/tart-$RUN.log | head -1 || true); [ -n "$VNC" ] && break; sleep 1; done
[ -n "$VNC" ] || { echo "no VNC url in /tmp/tart-$RUN.log"; cat /tmp/tart-$RUN.log; exit 1; }
# tart prints:  Opening vnc://:<password>@<host>:<port>...
VNC_CRED="${VNC#vnc://}"; VNC_PASS="${VNC_CRED#*:}"; VNC_PASS="${VNC_PASS%%@*}"
VNC_HOSTPORT="${VNC_CRED#*@}"; VNC_HOST="${VNC_HOSTPORT%%:*}"
VNC_PORT="${VNC_HOSTPORT##*:}"; VNC_PORT="${VNC_PORT%%[!0-9]*}"   # strip trailing "..."
say "VNC at $VNC_HOST:$VNC_PORT"

say "waiting for guest IP + sshd…"
IP=""
for _ in $(seq 1 60); do IP=$(tart ip "$RUN" 2>/dev/null || true); [ -n "$IP" ] && break; sleep 2; done
[ -n "$IP" ] || { echo "no guest IP"; exit 1; }
for _ in $(seq 1 60); do ssh $SSHOPTS "$GUEST_USER@$IP" true 2>/dev/null && break; sleep 2; done
say "guest $IP reachable"

say "deploying app…"
APPNAME="$(basename "$APP")"
rsync -a --delete -e "ssh $SSHOPTS" "$APP/" "$GUEST_USER@$IP:pc-test/$APPNAME/"

say "launching app (via open → GUI session)…"
ARGS=""
[ -n "$AUTO" ] && { scp $SSHOPTS "$AUTO" "$GUEST_USER@$IP:pc-test/auto.txt" && ARGS="--args -AutomationScript /Users/$GUEST_USER/pc-test/auto.txt"; }
# open routes through LaunchServices so the app lands in the auto-logged-in Aqua
# session (an SSH-launched binary would have no WindowServer connection).
ssh $SSHOPTS "$GUEST_USER@$IP" "xattr -dr com.apple.quarantine ~/pc-test 2>/dev/null; open ~/pc-test/$APPNAME $ARGS"
sleep 10   # let the window come up in the GUI session

# The base image auto-opens a Terminal that covers the app; close it and re-raise
# the app so the framebuffer shows Peach Commander unobstructed.
ssh $SSHOPTS "$GUEST_USER@$IP" "killall Terminal 2>/dev/null; open ~/pc-test/$APPNAME" 2>/dev/null || true
sleep 2

say "capturing framebuffer via VNC -> $OUT"
VNCDO="$(command -v vncdo || echo "$HOME/Library/Python/3.9/bin/vncdo")"
if [ -x "$VNCDO" ]; then
  "$VNCDO" -s "$VNC_HOST::$VNC_PORT" -p "$VNC_PASS" capture "$OUT"
  say "screenshot saved: $OUT"
else
  echo "vncdotool not installed (pip install --user vncdotool) — skipping capture"
fi

say "app.log tail:"; ssh $SSHOPTS "$GUEST_USER@$IP" "tail -5 ~/pc-test/app.log" 2>/dev/null || true
say "done"
