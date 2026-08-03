#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# regress-guest.sh — run one scenario inside the VM and print the AppKit layout log.
#
# A file rather than an ssh one-liner because the log predicate contains quotes at three levels
# (python → ssh → shell), and passing it inline silently produced an empty result that read as
# "no conflicts". Everything the host needs comes back on stdout.
#
# Usage: regress-guest.sh <scenario-name> <settle-seconds>
set -uo pipefail
NAME="${1:?scenario name}"
SETTLE="${2:-10}"
APP="$HOME/pc-test/PeachCommander.app"

pkill -x PeachCommander 2>/dev/null
sudo -n pkill -x PeachCommander 2>/dev/null
sleep 1
# Per-scenario reset: persisted view mode or directory from the previous scenario would make this one
# show something else entirely.
rm -f "$HOME/pc-cfg/session.ini" "$HOME/pc-cfg/workspaces.ini"

START=$(date "+%Y-%m-%d %H:%M:%S")
# open, not the binary: LaunchServices puts the app in the auto-logged-in Aqua session. The log comes
# from the unified log afterwards, so nothing needs redirecting.
open "$APP" --args -ConfigRoot "$HOME/pc-cfg" -AppleLanguages '(en)' \
     -AutomationScript "$HOME/auto.txt"
sleep "$SETTLE"
killall Terminal 2>/dev/null
# The whole process log, not a subsystem filter: AppKit's layout complaints are found reliably by
# their text, and narrowing the predicate is what produced an empty capture the first time.
log show --info --style compact --start "$START" \
    --predicate 'process == "PeachCommander"' 2>/dev/null
