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
# The panel view mode lives in peachcmd.ini, not session.ini, so deleting the line above never reset it
# — the comment claimed a guarantee the code did not give. `brief-view` is the third scenario in the
# suite and Brief is drawn by IconGridView, so from that point on every scenario asserting
# `responder=PanelListView` was asking about a panel that had been a grid since scenario three. Six of
# them failed for months, passed when run with --only, and were written off as flaky. Stripped rather
# than the whole file removed: peachcmd.ini also carries settings the golden image was prepared with.
if [ -f "$HOME/pc-cfg/peachcmd.ini" ]; then
  sed -i '' -e '/^LeftViewMode=/d' -e '/^RightViewMode=/d' \
            -e '/^LeftTree=/d' -e '/^RightTree=/d' -e '/^SharedTree=/d' \
            "$HOME/pc-cfg/peachcmd.ini"
fi

# Probe settings for the app, when the scenario asked for any (~/pc-env.txt, KEY=VALUE per line).
#
# Passed as *arguments*, not as environment. `open` hands the app arguments and never the caller's
# environment, and `launchctl setenv` from here does not help either: an ssh session has its own
# launchd domain, so the variable was set in a session the app is not in — `launchctl getenv` came
# back empty in the guest while the same value worked when the binary was run directly. Measured,
# after a full run reported four empty reports and the app had plainly done everything else.
#
# `-KEY value` lands in the argument domain, which `AutomationProbe` reads after the environment. The
# same channel `-ConfigRoot` already uses.
# `${PCARGS[@]+…}` below, not a bare `"${PCARGS[@]}"`: this is bash 3.2 with `set -u`, where an empty
# array expands to an unbound variable and would take down every scenario that asks for nothing.
PCARGS=()
if [ -s "$HOME/pc-env.txt" ]; then
  while IFS='=' read -r key value; do
    [ -z "$key" ] && continue
    PCARGS+=("-$key" "$value")
  done < "$HOME/pc-env.txt"
fi

START=$(date "+%Y-%m-%d %H:%M:%S")
# open, not the binary: LaunchServices puts the app in the auto-logged-in Aqua session. The log comes
# from the unified log afterwards, so nothing needs redirecting.
open "$APP" --args -ConfigRoot "$HOME/pc-cfg" -AppleLanguages '(en)' \
     -AutomationScript "$HOME/auto.txt" ${PCARGS[@]+"${PCARGS[@]}"}
# Wait for the report this scenario writes, rather than for a fixed time.
#
# The settle used to be slept in full *first* and the report looked for afterwards, so every scenario
# paid its whole settle even when it had finished in two seconds. That was invisible while the app
# took 36 s to launch — a blocking DNS lookup in the terminal plugin, fixed 2026-09-06 — because the
# report never arrived before the settle expired anyway. With the launch back to a second, the
# sleeping was 34 of the suite's 43 minutes.
#
# So the settle is the *cap* now, not an addition. The report's arrival is the completion signal,
# which the comment above has always said is the better one: it is the LAST file a scenario writes
# (`Tools/check-scenario-reports.py` insists on that), so its presence means finished rather than
# "probably long enough". A scenario without a report has nothing to wait for and still sleeps.
#
# The floor and the grace are what keep the screenshots and the layout log worth having: without a
# floor a trivial scenario would be photographed a second after launch, and without the grace the
# last repaint — and any Auto Layout complaint it logs — would fall outside the window. Neither can
# be checked by comparing conflict counts against the baseline, because every count is currently
# zero and zero cannot get smaller; the log line counts are what to watch instead.
# GRACE is 1 s and not more because it was measured: at 3 s it ate the whole saving — ten typical
# scenarios came to 101 s against 105 s before, a 4 % gain for a real change. The screenshot is taken
# by the host only after `killall`, `log show` and the accessibility dump, which is one to two
# seconds of natural grace on top of this one.
FLOOR=4
GRACE=1
if [ -n "$EXPECT" ]; then
  DEADLINE=$(( SETTLE + 40 ))
  WAITED=0
  while [ "$WAITED" -lt "$DEADLINE" ]; do
    if [ -s "$EXPECT" ] && [ "$WAITED" -ge "$FLOOR" ]; then break; fi
    sleep 1
    WAITED=$(( WAITED + 1 ))
  done
  if [ -s "$EXPECT" ]; then
    sleep "$GRACE"
  else
    echo "===REPORT-MISSING=== $EXPECT"
  fi
  echo "===WAITED=== ${WAITED}s+${GRACE}s of ${SETTLE}s"
else
  sleep "$SETTLE"
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
