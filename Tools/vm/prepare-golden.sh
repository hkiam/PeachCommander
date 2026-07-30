#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# prepare-golden.sh - One-time setup of the "golden" macOS test VM.
#
# The cirruslabs macos-tahoe-base image already ships with SSH enabled
# (user admin / password admin), auto-login and no screensaver. This script
# adds what we need on top: passwordless SSH from THIS host, disabled display
# sleep, and a Gatekeeper exception so an unsigned Debug build runs headlessly.
#
# Run ONCE after the golden VM is first pulled. It boots golden, configures it,
# shuts it down, and leaves a clean image to clone per test run.
#
# Screenshots are taken from the HOST via VNC (see run-test.sh), so no Screen
# Recording (TCC) grant is needed inside the guest.
set -euo pipefail

VM="${1:-golden}"
GUEST_USER="admin"
GUEST_PASS="admin"
KEY="$HOME/.ssh/id_ed25519"

say() { printf '\033[1;35m[golden]\033[0m %s\n' "$*"; }

command -v tart >/dev/null || { echo "tart not installed"; exit 1; }
command -v sshpass >/dev/null || { echo "need sshpass: brew install sshpass"; exit 1; }
[ -f "$KEY.pub" ] || { say "no $KEY.pub — generating"; ssh-keygen -t ed25519 -N '' -f "$KEY"; }

say "booting $VM (headless)…"
tart run "$VM" --no-graphics >/tmp/tart-golden-run.log 2>&1 &
RUN_PID=$!
trap 'kill $RUN_PID 2>/dev/null || true' EXIT

say "waiting for guest IP…"
IP=""
for _ in $(seq 1 60); do IP=$(tart ip "$VM" 2>/dev/null || true); [ -n "$IP" ] && break; sleep 2; done
[ -n "$IP" ] || { echo "no IP"; exit 1; }
say "guest IP: $IP"

SSHOPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
say "waiting for sshd…"
for _ in $(seq 1 60); do
  sshpass -p "$GUEST_PASS" ssh $SSHOPTS "$GUEST_USER@$IP" true 2>/dev/null && break; sleep 2
done

say "installing host public key for passwordless SSH…"
PUB=$(cat "$KEY.pub")
sshpass -p "$GUEST_PASS" ssh $SSHOPTS "$GUEST_USER@$IP" \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF '$PUB' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUB' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

say "disabling display sleep + Gatekeeper (needs sudo; admin is passwordless-sudo on these images)…"
ssh -i "$KEY" $SSHOPTS "$GUEST_USER@$IP" bash -s <<'REMOTE'
set -e
sudo pmset -a displaysleep 0 sleep 0 || true
sudo spctl --master-disable 2>/dev/null || true   # allow unsigned Debug .app
defaults write com.apple.screensaver idleTime 0 || true
mkdir -p ~/pc-test
echo "guest ready: $(sw_vers -productVersion)"
REMOTE

say "shutting down…"
ssh -i "$KEY" $SSHOPTS "$GUEST_USER@$IP" "sudo shutdown -h now" 2>/dev/null || true
for _ in $(seq 1 30); do tart ip "$VM" >/dev/null 2>&1 || break; sleep 1; done
say "golden prepared. Clone it per run: tart clone $VM run-1"
