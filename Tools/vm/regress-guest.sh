#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# regress-guest.sh — run one scenario inside the VM and print the AppKit layout log.
#
# A file rather than an ssh one-liner because the log predicate contains quotes at three levels
# (python → ssh → shell), and passing it inline silently produced an empty result that read as
# "no conflicts". Everything the host needs comes back on stdout.
#
# Usage: regress-guest.sh <scenario-name> <settle-seconds> [report-file-to-wait-for]
#
# The third argument is what makes a long suite reliable. A fixed sleep was enough when the guest was
# fresh and not enough late in a run of thirty-plus scenarios: the app took longer to launch (its own log
# shows ten seconds of image loading), the settle expired before the automation wrote its report, and the
# host then read an *empty* report and reported every expectation as wrong. Waiting for the file the
# scenario is supposed to produce turns that into "it is finished" instead of "probably long enough".
set -uo pipefail
NAME="${1:?scenario name}"
SETTLE="${2:-10}"
EXPECT="${3:-}"
APP="$HOME/pc-test/PeachCommander.app"

pkill -x PeachCommander 2>/dev/null
sudo -n pkill -x PeachCommander 2>/dev/null
sleep 1
# Per-scenario reset: persisted view mode or directory from the previous scenario would make this one
# show something else entirely.
rm -f "$HOME/pc-cfg/session.ini" "$HOME/pc-cfg/workspaces.ini" "$HOME/pc-cfg/terminal/session.json"

START=$(date "+%Y-%m-%d %H:%M:%S")
# open, not the binary: LaunchServices puts the app in the auto-logged-in Aqua session. The log comes
# from the unified log afterwards, so nothing needs redirecting.
open "$APP" --args -ConfigRoot "$HOME/pc-cfg" -AppleLanguages '(en)' \
     -AutomationScript "$HOME/auto.txt"
sleep "$SETTLE"
# …and then wait for the report, if this scenario writes one. Up to 40 s more, checked twice a second:
# a scenario that is simply slow gets to finish, and one that is broken still fails within a minute.
if [ -n "$EXPECT" ]; then
  for _ in $(seq 1 80); do
    [ -s "$EXPECT" ] && break
    sleep 0.5
  done
  [ -s "$EXPECT" ] || echo "===REPORT-MISSING=== $EXPECT"
fi
killall Terminal 2>/dev/null
# The whole process log, not a subsystem filter: AppKit's layout complaints are found reliably by
# their text, and narrowing the predicate is what produced an empty capture the first time.
log show --info --style compact --start "$START" \
    --predicate 'process == "PeachCommander"' 2>/dev/null
# The accessibility dump, when the scenario asked for one, marked so the host can split it off.
if [ -f "$HOME/a11y.txt" ]; then
  echo "===A11Y==="
  cat "$HOME/a11y.txt"
  rm -f "$HOME/a11y.txt"
fi
