#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""regress.py — drive standard views in a VM and report Auto Layout conflicts + screenshots.

Why this exists
---------------
Four of the last six defects in this project were *claims about behaviour that nobody measured*: a
text view holding its content and rendering none of it, a split view giving one pane everything, a
search option that changed nothing, a settings page deleting another plugin's settings. Every one was
invisible to unit tests and visible in a picture. The Auto Layout conflicts are the same class: they
are printed and then ignored, so they accumulate.

So this boots a clean clone, walks a list of views, and for each one records what AppKit complained
about and what the window looked like. The complaints are counted against a baseline
(docs/metadata/layout-baseline.json), so the number can go down and not up — which is the only useful
property for a count nobody is going to fix all at once.

How the log is captured
-----------------------
Through the *unified log*, not stderr. AppKit reports layout conflicts via os_log under
`com.apple.AppKit:Layout`, and they do not appear on stderr at all — the first version of this script
captured stderr, reported "0 conflicts" for every view, and was believed until a deliberately
unsatisfiable constraint was added to prove the instrument could see one. It could not.

The unified log carries the whole constraint list, unredacted, including the view class names, which
is what makes the report say *which* view rather than only how many.

Usage
-----
    Tools/vm/regress.py [--app PATH] [--keep] [--update-baseline] [--out DIR]

Exits non-zero when a scenario reports more conflicts than its baseline, so CI can run it as a gate.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
APPNAME = "PeachCommander.app"
GUEST = "admin"
GOLDEN = "golden"
SSH = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
       "-o", "LogLevel=ERROR", "-i", str(Path.home() / ".ssh/id_ed25519")]
VNCDO = shutil.which("vncdo") or str(Path.home() / "Library/Python/3.9/bin/vncdo")
BASELINE = REPO / "docs/metadata/layout-baseline.json"

# The views worth watching. Each is an automation script plus how long to let it settle; the point is
# coverage of the *containers* that have historically produced conflicts, not of every feature.
SCENARIOS = [
    ("main-window", ["active left", "left /Users/admin", "wait 1500"], 8),
    ("details-view", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "cmd cm_SrcLong", "wait 800"], 8),
    ("brief-view", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "cmd cm_SrcShort", "wait 800"], 8),
    ("tree-view", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "cmd cm_SrcTree", "wait 1200"], 9),
    # Open, closed, open again: the *collapsed* panel is the state that produced seven Auto Layout
    # conflicts, because a scroll view pinned to both edges as a required rule cannot give its scroller
    # 17 pt inside a panel that is 0 wide. Toggling it back and forth here keeps that covered.
    ("preview-panel", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "previewpanel on", "wait 1200",
                       "previewpanel off", "wait 800",
                       "previewpanel on", "wait 1500"], 9),
    ("find-files", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "findtab 0", "wait 2000"], 10),
    ("settings", ["active left", "left /Users/admin", "wait 1000",
                  "settingspage Layout", "wait 2500"], 10),
    ("viewer-text", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "focus notes.txt", "wait 500", "cmd cm_List", "wait 2000"], 10),
    # Does the sidebar show the structure of a YAML or XML file (F-368)? It was empty for JSON, YAML and
    # XML — the three formats an administrator edits most. `editdump` reports the rows actually rendered
    # into the live outline, so an entry that exists only in the parser cannot pass here.
    ("editor-yaml-outline", ["editdump /Users/admin/pc-demo/stack.yml /Users/admin/yaml-outline.txt",
                             "wait 2000"], 10),
    ("editor-xml-outline", ["editdump /Users/admin/pc-demo/hosts.xml /Users/admin/xml-outline.txt",
                            "wait 2000"], 10),
    # Structural navigation, selection, the path and validation, driven through the real menu items
    # (F-369). `editstruct` sends each menu item and reports where the caret went — an item whose target
    # is wrong is disabled on screen and works perfectly when its method is called directly.
    ("editor-structure", ["editstruct /Users/admin/pc-demo/stack.yml|image: nginx|"
                          "/Users/admin/structure.txt", "wait 2000"], 10),
    # And the other half: a file with a trailing comma, which Apple's parser accepts and Python, Go and
    # jq refuse. The caret must land on the comma.
    ("editor-validate", ["editstruct /Users/admin/pc-demo/broken.json|\"debug\"|"
                         "/Users/admin/validate.txt", "wait 2000"], 10),
    # F3 on a *folder* — the viewer's folder summary. It crashed the app outright: a width constraint was
    # activated before the container became the scroll view's document view, so the two had no common
    # ancestor. No scenario had ever put the cursor on a folder and pressed F3.
    ("viewer-folder", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "focus sub", "wait 400", "cmd cm_List", "wait 2500",
                       "listerdump /Users/admin/folder-view.txt", "wait 500"], 10),
    # The editor's filter (F-356), in two pictures: the prompt, and the document after a command ran.
    # Reading the text back is not enough — a text view has held a whole document and rendered none
    # of it, and that is exactly this window.
    ("editor-filter", ["editfilter /Users/admin/pc-demo/hosts.txt|sort -u|/Users/admin/filter.txt",
                       "wait 2500"], 9),
    ("editor-filter-dialog", ["editfilterdlg /Users/admin/pc-demo/hosts.txt", "wait 2000"], 9),
    # The built-in line operations over a CRLF file with duplicates, blanks and trailing spaces
    # (F-359) — the terminator surviving is the part that fails silently.
    ("editor-lines", ["editlines /Users/admin/pc-demo/messy.txt|/Users/admin/lines.txt",
                      "wait 2000"], 9),
    # Dropping something onto the button bar (F-010). The drag itself cannot be scripted, but the entry
    # point the bar view calls can — and what matters is the other end: the button has to reach
    # default.bar, or it is gone at the next launch. That file is read by the shell afterwards.
    ("toolbar-drop", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "bardrop /System/Applications/Calculator.app", "wait 1500"], 9),
    # Double-clicking the divider gives two equal panels (F-001). The row promised it and nothing did
    # it — the window used an NSSplitView directly, with no click handling anywhere. Widen the left
    # panel first, so "equal" is a result rather than the state it started in.
    ("split-center", ["active left", "left /Users/admin/pc-demo", "wait 1000",
                      "widenleft", "wait 600", "splitdump /Users/admin/split-before.txt", "wait 300",
                      "splitcenter", "wait 600", "splitdump /Users/admin/split-after.txt", "wait 300"], 9),
    # The dock across the bottom of the window (F-381). Not "does it appear" — that passes while the
    # window is wrong. It was inserted by splitting the one constraint that tied the command line to the
    # panels into three, so what can break is the stack: a dock that opens without the panels giving up
    # the room overlaps them, and one that fails to push the command line down hides it. `dockdump`
    # measures the four edges against each other; the closed dump is the other half, because a dock that
    # never collapses back to zero leaves a dead strip across the window.
    # Opened, closed, then opened again — the last step only so the screenshot shows the feature
    # rather than the window without it. The closed dump has to come after an open one or "height=0"
    # would be true of a dock that never appeared.
    ("dock-seam", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   # The Terminal plugin ships a view here, and this scenario is about the *seam* — it
                   # was written before anything mounted in the dock and should keep working when the
                   # set of plugins changes again. So the view is moved out for the duration and put
                   # back at the end, because a placement override is persisted and would otherwise
                   # follow the app into every later scenario in the run.
                   "placeview plugin.terminal.view|sidebar", "wait 800",
                   "dock on", "wait 900", "dockdump /Users/admin/dock-open.txt", "wait 300",
                   "dock off", "wait 900", "dockdump /Users/admin/dock-shut.txt", "wait 300",
                   "placeview plugin.terminal.view|default", "wait 800",
                   "dock on", "wait 900"], 15),
    # A refresh must not destroy what it is not changing (F-381). ViewContainerRegistry.refresh began
    # with `live.forEach { $0.close() }`, so enabling or disabling *any* plugin tore down every mounted
    # plugin view and built it again. Harmless for a comment field; for a view with a process behind it
    # PcCloseView is how that process dies. The Notes view is opened first so there is something to
    # destroy, then the same entry point a plugin toggle reaches is called twice, and the counters sit
    # on the PcMakeView/PcCloseView call sites themselves rather than in the code that was changed.
    ("mount-refresh", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "previewpanel on", "wait 1500", "previewtab Notes", "wait 1200",
                       "mountdump /Users/admin/mounts-before.txt", "wait 300",
                       "refreshviews", "wait 800", "refreshviews", "wait 800",
                       "mountdump /Users/admin/mounts-after.txt", "wait 400"], 15),
    # Moving a plugin view between containers (F-381). The gesture cannot be scripted, so this drives
    # the entry point the drop and the menu item both call. Two claims: the view arrives in the dock,
    # and it *survives the trip* — made=1 closed=0, because moving used to route through a refresh that
    # closed everything, so a dragged terminal would have restarted its shell on arrival. Then back to
    # the default, which must forget the override rather than write the old container back.
    ("view-placement", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "previewpanel on", "wait 1500", "previewtab Notes", "wait 1200",
                        "placeview plugin.notes.sidebar|bottom", "wait 1200",
                        "dock on", "wait 800",
                        "mountdump /Users/admin/placed.txt", "wait 300",
                        "dockdump /Users/admin/placed-dock.txt", "wait 300",
                        "placeview plugin.notes.sidebar|default", "wait 1200",
                        "mountdump /Users/admin/placed-back.txt", "wait 400"], 17),
    # A key aimed at the command line must not reach the file panel (F-381). performKeyEquivalent is
    # broadcast to every view in the window — that is how F5 copies wherever the cursor is — so the
    # panel has to stand aside when something else is focused. It used to do that by asking
    # `firstResponder is NSText`, which fixed the command line and nothing else; the rule now asks the
    # focused view, which is the only form a terminal could ever answer.
    #
    # A file is selected first so there is something to copy: a passing "no files on the clipboard" is
    # worth nothing if nothing could have got there. The panel-focused half is the control — the same
    # key, the same window, and this time the panel *must* claim it.
    ("raw-keyboard", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "focus notes.txt", "wait 400",
                      "keyequiv C+b|/Users/admin/key-panel.txt", "wait 900",
                      "focuscmdline", "wait 600",
                      "keyequiv C+b|/Users/admin/key-cmdline.txt", "wait 900",
                      # …and with the command line *view* focused rather than its field editor, which
                      # is reachable and is not an NSText — the case the old rule missed.
                      "focuscmdline container", "wait 600",
                      "keyequiv C+b|/Users/admin/key-container.txt", "wait 900"], 14),
    # The Terminal plugin's skeleton (F-381) — everything except the terminal, which is the order the
    # plan asks for: prove removability before there is a pseudo-terminal to lose. It carries no
    # emulator and is still worth its weight, because it witnesses from the *other side of the C ABI*
    # three things the host has so far only claimed about itself: that a moved view is re-parented
    # rather than rebuilt (its instance number does not change), that a re-parented view is told where
    # it landed (PcNotifyView "container" was added with nothing to receive it), and that the dock
    # survives its only plugin leaving rather than showing a blank strip.
    ("terminal-session", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                          "panelsdump /Users/admin/panels-before.txt", "wait 300",
                          "dock on", "wait 2500",
                          "panelsdump /Users/admin/panels-after.txt", "wait 300",
                          # Long waits on purpose: a pseudo-terminal takes longer to come up, print a
                          # prompt and report its size than a view takes to appear.
                          "dockdump /Users/admin/term-idle.txt", "wait 300",
                          "termsend plugin.terminal.view|echo PEACH-$((6*7))\\n", "wait 1500",
                          # …and a full-screen program, which is the milestone: alternate screen
                          # buffer, cursor addressing, and a size the program believes.
                          "termsend plugin.terminal.view|top\\n", "wait 3500",
                          "dockdump /Users/admin/term-top.txt", "wait 500",
                          "panelsdump /Users/admin/panels-end.txt", "wait 300"], 19),
    # A tripwire for an open defect (see docs/analysis/terminal-plugin-plan.md §12). Measured: with a
    # shell running in the dock, the active panel's path is /Users/admin in some runs and the folder
    # the scenario opened in others — the same scenario, twice. Three runs of *this* one, which is
    # identical except that the terminal is moved out first so no shell ever starts, gave the opened
    # folder every time. So the shell is involved and the cause is not yet known; SwiftTerm's chdir is
    # in the child, not the parent, so the obvious explanation is ruled out. This scenario is the
    # control that keeps the finding honest: if it ever starts wandering too, the shell is exonerated.
    ("terminal-control", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                          "placeview plugin.terminal.view|sidebar", "wait 800",
                          "dock on", "wait 2500", "wait 1500", "wait 3500", "wait 500",
                          "dump /Users/admin/ctl-panel.txt", "wait 400"], 19),
    # Does quitting the app leave the shell's children running (plan §5)? An end-to-end guard, and it
    # has to quit the app itself: the harness's usual `pkill` never reaches applicationShouldTerminate.
    #
    # Stated plainly because it was nearly claimed as more than it is: **this passes with and without
    # the teardown added in that method** — verified twice, the second time after a stale build had
    # made an earlier mutation lie. Removing the closeAll() call leaves no stray sleep either, because
    # the app exiting closes the pseudo-terminal's master fd, the kernel HUPs the terminal's foreground
    # group, and the shell hups its own jobs. So this guards the outcome a user cares about — quit with
    # things running, nothing is left behind — and `terminal-teardown` is what guards the code. A
    # process deliberately detached with nohup or setsid survives, which is correct and what
    # Terminal.app does.
    #
    # Two jobs on purpose, because they sit in different process groups under job control: one in the
    # background (`&` gives it its own group, so a signal to the shell's group misses it) and one in
    # the foreground (its group is the terminal's, so closing the master fd should HUP it). Both are
    # named distinctly so `pgrep` cannot confuse them with anything else on the machine.
    ("terminal-orphan", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "dock on", "wait 2500",
                         "termsend plugin.terminal.view|sleep 391 &\\n", "wait 1200",
                         "termsend plugin.terminal.view|sleep 392\\n", "wait 1500",
                         "quit", "wait 4000"], 19),
    # Does PcCloseView actually reach the child processes (plan §5)? The quit scenario cannot answer
    # that — after the app exits everything dies from the master fd closing, so teardown and cleanup
    # look identical. This takes the same teardown path with the app still running, and then asks the
    # process table while it can still tell the difference.
    ("terminal-teardown", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           # Assert the precondition instead of inheriting it. Placement is persisted,
                           # so whether the terminal is in the dock at all depends on what earlier
                           # scenarios in the run did — which is exactly how this reported "no jobs
                           # running" when the truth was "no terminal here to run them".
                           "placeview plugin.terminal.view|default", "wait 800",
                           "dock on", "wait 3500",
                           "dockdump /Users/admin/td-dock.txt", "wait 300",
                           # Generous waits: the probe counts jobs, and a shell that has not finished
                           # starting yet counts as a failure rather than as a slow machine. One flaky
                           # run said 1 where it meant 2.
                           "termsend plugin.terminal.view|sleep 394 &\\n", "wait 2500",
                           "termsend plugin.terminal.view|sleep 395\\n", "wait 2500",
                           "probe /Users/admin/before.txt|pgrep -f 'sleep 39[45]' | wc -l | tr -d ' '",
                           "wait 500",
                           "closeviews", "wait 3000",
                           "probe /Users/admin/after.txt|pgrep -f 'sleep 39[45]' | wc -l | tr -d ' '",
                           "wait 500"], 23),
    # Tabs, and the promise underneath them (plan §4): a session outlives its view, so switching tabs
    # must not restart what is running. The witness is a job started in the first tab — if selecting
    # another tab and coming back rebuilt the session, its shell would have been torn down and the job
    # with it. The status line carries the session id, so a rebuilt one is visible as well as fatal.
    ("terminal-tabs", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "placeview plugin.terminal.view|default", "wait 800",
                       "dock on", "wait 3500",
                       "termsend plugin.terminal.view|sleep 397 &\\n", "wait 2500",
                       "dockdump /Users/admin/tabs-one.txt", "wait 300",
                       # Through the command a user reaches from the Terminal menu, so the whole
                       # chain is exercised: command → host → PcNotifyView → plugin.
                       "cmd cm_TerminalNewTab", "wait 2500",
                       "dockdump /Users/admin/tabs-two.txt", "wait 300",
                       "termnotify plugin.terminal.view|selectTab|1", "wait 1500",
                       "dockdump /Users/admin/tabs-back.txt", "wait 300",
                       "probe /Users/admin/tabs-alive.txt|pgrep -f 'sleep 397' | wc -l | tr -d ' '",
                       "wait 500",
                       "panelsdump /Users/admin/tabs-panels.txt", "wait 300"], 22),
    # Two terminals stacked, then the whole area for one again (plan §3). The claim that matters is
    # not that a divider appears: it is that *maximising is not closing*. A job is started in the
    # second pane, the view is collapsed back to one, and the job must still be running — a toggle
    # that quietly killed a build would be worse than no toggle.
    ("terminal-split", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "placeview plugin.terminal.view|default", "wait 800",
                        "dock on", "wait 3500",
                        "cmd cm_TerminalSplit", "wait 3000",
                        "dockdump /Users/admin/split-two.txt", "wait 300",
                        "termsend plugin.terminal.view|sleep 399 &\\n", "wait 2500",
                        # The same command again: it is a toggle, so the host asks and the plugin
                        # decides which way — the host has no business tracking a layout it cannot see.
                        "cmd cm_TerminalSplit", "wait 2000",
                        "dockdump /Users/admin/split-one.txt", "wait 300",
                        "probe /Users/admin/split-alive.txt|pgrep -f 'sleep 399' | wc -l | tr -d ' '",
                        "wait 500",
                        # Split again at the end, so the screenshot documents the feature rather than
                        # the window without it.
                        "cmd cm_TerminalSplit", "wait 2500"], 25),
    # The seams between the file manager and the terminal (plan §7). Three of them, each checked
    # through the shell itself rather than through what the app believes it did.
    #
    # The focus key is the most-used one and had the wrong shape at first: it toggled the dock's
    # *visibility*, so with the terminal open and the cursor in a panel it dismissed the terminal
    # instead of going to it. It now moves the keyboard and leaves the dock alone.
    ("terminal-integration",
     ["active left", "left /Users/admin/pc-demo", "wait 1200",
      "placeview plugin.terminal.view|default", "wait 800",
      "dock on", "wait 3500",
      # Opening the dock focuses it; the key must take us back to the panel…
      "keyequiv C+BACKQUOTE|/Users/admin/int-key1.txt", "wait 800",
      "panelsdump /Users/admin/int-panel.txt", "wait 300",
      # …and again to the terminal, with the dock still open throughout.
      "keyequiv C+BACKQUOTE|/Users/admin/int-key2.txt", "wait 800",
      "panelsdump /Users/admin/int-term.txt", "wait 300",
      "dockdump /Users/admin/int-dock.txt", "wait 300",
      # cd here: the shell is asked where it is afterwards, so this is the shell answering and not
      # the app repeating itself.
      "cmd cm_TerminalCdHere", "wait 1500",
      "termsend plugin.terminal.view|pwd > /Users/admin/int-cwd.txt\\n", "wait 1500",
      # Inserted names: `echo `, then the command, then a redirect. What lands in the file is what
      # the shell parsed — which is the only way to see that the quoting held.
      "focus notes.txt", "wait 500",
      "termsend plugin.terminal.view|echo\\s", "wait 800",
      "cmd cm_TerminalSendNames", "wait 1200",
      "termsend plugin.terminal.view|> /Users/admin/int-names.txt\\n", "wait 1500"], 23),
    # The command line, run in the embedded terminal instead of detached (plan §7). Worth more than a
    # preference: a detached command has no terminal, so anything that asks a question gets no answer —
    # `sudo` prompts into a pipe nobody reads and fails. The check is that the *shell* ran it, which
    # only holds if the line really went there.
    ("terminal-cmdline", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                          "placeview plugin.terminal.view|default", "wait 800",
                          "dock on", "wait 3500",
                          "cmd cm_TerminalRunCommandLine", "wait 500",
                          # `tty`, not `echo`: a detached command would create the file too, so the
                          # first version of this passed with the feature switched off. Only a command
                          # with a terminal attached can name one — which is the entire reason this
                          # option exists, so it is the right thing to ask.
                          "cmdline tty > /Users/admin/cmdline.txt", "wait 2500",
                          # …and the shell is still there afterwards with the panel's folder, since the
                          # line is preceded by a cd rather than run wherever the shell was left.
                          "termsend plugin.terminal.view|pwd > /Users/admin/cmdline-cwd.txt\\n",
                          "wait 1500"], 18),
    # Dropping files onto the terminal (plan §7). The drag itself cannot be scripted — the same
    # limitation as the button bar's `bardrop` — so this drives the entry point the drop calls, which
    # is where the quoting lives and where it matters. The fixture name has a space and an apostrophe
    # in it on purpose: a naive implementation splits it into three arguments.
    ("terminal-drop", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "placeview plugin.terminal.view|default", "wait 800",
                       "dock on", "wait 3500",
                       "termsend plugin.terminal.view|echo\\s", "wait 800",
                       "termnotify plugin.terminal.view|dropPaths|/Users/admin/pc-demo/it's a file.txt",
                       "wait 1200",
                       "termsend plugin.terminal.view|> /Users/admin/drop.txt\\n", "wait 1500"], 17),
    # The terminal's settings page (plan §6/§7). It exists to explain and to hold one switch that does
    # nothing on its own: the terminal can only follow the shell if the shell reports where it is, and
    # no shell on macOS does unless the user arranges it — Apple's own hook in /etc/zshrc is guarded to
    # Apple Terminal. So the page shows the exact lines and touches nothing.
    ("terminal-settings", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           "settingspage Terminal", "wait 2000",
                           "settingsdump /Users/admin/tset.txt", "wait 400"], 12),
    # …and with the switch on and the shell arranged, the panel follows a `cd`. The switch is set by
    # writing the plugin's own config file, which is exactly what ticking the box does — the box itself
    # is covered by terminal-settings, since a checkbox cannot be clicked from a script.
    ("terminal-follow", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "placeview plugin.terminal.view|default", "wait 800",
                         # \042 is a double quote: a literal one has to survive python → ssh → sh →
                         # the app's script parser, and this harness has lost bytes to that before.
                         "probe /Users/admin/set.txt|mkdir -p ~/pc-cfg/terminal && "
                         "printf '{\\042panelFollowsTerminal\\042:true}' > ~/pc-cfg/terminal/config.json && "
                         "cat ~/pc-cfg/terminal/config.json",
                         "wait 800",
                         "dock on", "wait 3500",
                         "panelsdump /Users/admin/follow-before.txt", "wait 300",
                         "termsend plugin.terminal.view|cd /usr/lib\\n", "wait 2500",
                         "panelsdump /Users/admin/follow-after.txt", "wait 400",
                         "dockdump /Users/admin/follow-dock.txt", "wait 300",
                         # Leave the world as it was found: the setting is persisted and the next
                         # scenario in the run would inherit it.
                         "probe /Users/admin/unset.txt|printf "
                         "'{\\042panelFollowsTerminal\\042:false}' > ~/pc-cfg/terminal/config.json && "
                         "echo unset", "wait 500"], 22),
    # ⌘F over the scrollback (plan §6). No search code of ours is involved: the Edit menu's Find item
    # goes to the first responder, and SwiftTerm's terminal view answers it with its own find bar. So
    # what is worth asserting is that the item is *enabled and answered* with the terminal focused —
    # a menu item nothing in the responder chain implements is disabled and claims nothing.
    ("terminal-find", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "placeview plugin.terminal.view|default", "wait 800",
                       # Generous before the keypress: one run in six sent ⌘F while the window was
                       # still settling, something else in the responder chain claimed it, and the bar
                       # never opened. The key has to arrive at a terminal that is already there.
                       "dock on", "wait 5000",
                       # Twice, and it is not superstition: one run in six had ⌘F claimed by
                       # something else in the responder chain while the window was still settling,
                       # and the bar never opened. Asking again is harmless — a find bar that is
                       # already open just takes the keyboard back.
                       "keyequivmenu W+f|/Users/admin/find-term.txt", "wait 1500",
                       "keyequivmenu W+f|/Users/admin/find-term2.txt", "wait 1000",
                       "dockdump /Users/admin/find-bar.txt", "wait 400",
                       # …and with a file panel focused instead, the same key finds nobody to answer.
                       "keyequiv C+BACKQUOTE|/Users/admin/find-toggle.txt", "wait 800",
                       "keyequivmenu W+f|/Users/admin/find-panel.txt", "wait 1000"], 19),
    # The function-key bar must not claim keys it does not have (plan §7). With a terminal focused,
    # F3 and F5 go to whatever is running in it — the raw-keyboard rule hands them over — so a bar
    # still reading "F3 View  F5 Copy" at full strength is saying something untrue.
    ("terminal-fkeys", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "placeview plugin.terminal.view|default", "wait 800",
                        "fkeydump /Users/admin/fk-panel.txt", "wait 400",
                        "dock on", "wait 3500",
                        "fkeydump /Users/admin/fk-term.txt", "wait 400",
                        # …and back: the bar has to come *back*, or it is a one-way dimming that
                        # leaves the file manager looking permanently disarmed.
                        "keyequiv C+BACKQUOTE|/Users/admin/fk-key.txt", "wait 1000",
                        "fkeydump /Users/admin/fk-back.txt", "wait 400"], 15),
    # ⌘-click a path in the scrollback and the panel shows it (plan §6) — the bridge back to the file
    # manager, and the reason to embed a terminal rather than launch Terminal.app. The click cannot be
    # scripted, so this drives the entry point it calls, which is where the resolution lives.
    #
    # Three words, and the two that must be refused matter as much as the one that works: a relative
    # name resolves against the shell's folder, and a word that names nothing navigates nowhere rather
    # than somewhere arbitrary because a sentence contained a slash.
    ("terminal-reveal", ["active left", "left /Users/admin", "wait 1200",
                         "placeview plugin.terminal.view|default", "wait 800",
                         "dock on", "wait 3500",
                         # Relative, which is how a path appears in real output: resolved against the
                         # shell's folder, not the panel's.
                         "termnotify plugin.terminal.view|revealPath|pc-demo",
                         "wait 1500",
                         "panelsdump /Users/admin/rev-abs.txt", "wait 300",
                         # A word that is not a path: the panel must not move.
                         "termnotify plugin.terminal.view|revealPath|Traceback", "wait 1200",
                         "panelsdump /Users/admin/rev-none.txt", "wait 400"], 16),
    # Closing a tab with something running asks first (plan §5). Losing an hour-long build to a stray
    # Cmd+W is the failure people remember, so the terminal checks the pseudo-terminal's foreground
    # process group against the shell's own — the same question Terminal.app asks — and puts up a
    # dialog naming what is running.
    #
    # `modaldump` is scheduled *before* the dialog opens, reads it, and aborts it; an aborted modal is
    # neither button, which the code treats as "do not close". So the tab must still be there after.
    ("terminal-close-ask", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                            "placeview plugin.terminal.view|default", "wait 800",
                            "dock on", "wait 3500",
                            # Foreground, not backgrounded: a job in its own group with `&` leaves the
                            # shell in the foreground and there would be nothing to warn about.
                            "termsend plugin.terminal.view|sleep 396\\n", "wait 2500",
                            "modaldump /Users/admin/close-alert.txt",
                            "termnotify plugin.terminal.view|closeTab|1", "wait 3000",
                            "dockdump /Users/admin/close-after.txt", "wait 500",
                            # …and then a tab that has nothing running closes without ceremony,
                            # through the command the ✕ on the tab and the menu both call. Two tabs
                            # first, so there is something to count.
                            "cmd cm_TerminalNewTab", "wait 2500",
                            # Between the two, or the "one tab afterwards" claim is true before the
                            # close as well and proves nothing.
                            "dockdump /Users/admin/close-two.txt", "wait 400",
                            "cmd cm_TerminalCloseTab", "wait 2000",
                            "dockdump /Users/admin/close-gone.txt", "wait 500"], 27),
    # ⌘C in the terminal copies text, not files. Both the panel and the terminal implement `copy:`,
    # and the Edit menu sends it to whatever is focused — so this is the one place where the file
    # manager and the terminal want the same key for different things, and getting it wrong means
    # someone copies a file when they meant a command.
    ("terminal-copy", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "placeview plugin.terminal.view|default", "wait 800",
                       "focus notes.txt", "wait 400",
                       "dock on", "wait 4000",
                       "termsend plugin.terminal.view|echo PEACH-COPY\\n", "wait 2000",
                       "keyequivmenu W+a|/Users/admin/copy-all.txt", "wait 800",
                       "keyequivmenu W+c|/Users/admin/copy-done.txt", "wait 1000"], 18),
    # Dropping a view onto a container moves it there (plan §2a). The drag cannot be scripted — the
    # same limitation the button bar's `bardrop` has — so this drives the drop, which is where the
    # decisions are: whether the drop would do anything, the placement write, opening the container if
    # it was shut, and bringing the view to the front.
    #
    # The refusal is checked as carefully as the move: dropping a view onto the container it is
    # already in must do nothing, because a container that lights up as a destination and then does
    # nothing is the drag equivalent of a button that does not work.
    ("view-drop", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "placeview plugin.terminal.view|default", "wait 800",
                   "dock on", "wait 3000",
                   # Onto the container it is already in: refused, and the world is unchanged.
                   "dropview bottom|plugin.terminal.view", "wait 1000",
                   "mountdump /Users/admin/drop-same.txt", "wait 300",
                   # …and onto the other one, which opens the side panel and shows it.
                   "dropview sidebar|plugin.terminal.view", "wait 1500",
                   "mountdump /Users/admin/drop-moved.txt", "wait 300",
                   "sidebardump /Users/admin/drop-side.txt", "wait 400",
                   "placeview plugin.terminal.view|default", "wait 1000"], 18),
    # The assistant's shell (plan §7). This drives the *execution* — the host method the tool calls —
    # and so goes past the permission gate on purpose: whether the tool exists for a session at all,
    # and whether it is refused without approval, are decided in DefaultAutomationCore and tested
    # there, where a fake bridge can prove nothing ran. What only a real machine can show is this:
    # a tab opens, a non-interactive shell runs the line, and the dotfiles do not rewrite it.
    #
    # It runs where the user can watch it: a hidden shell would be
    # the same capability with the evidence removed, and the point of a terminal tab is that what the
    # assistant did is on screen afterwards, in the user's own scrollback.
    #
    # The tab runs a *non-interactive* shell. A login shell reads the user's dotfiles, and an alias
    # there could make an approved command line mean something else — so the fixture defines one and
    # the scenario checks it does not take effect. That is the difference between "we show you the
    # command" and "the command we show you is the command that runs".
    ("terminal-runshell", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           "placeview plugin.terminal.view|default", "wait 800",
                           "dock on", "wait 3500",
                           "runshell /Users/admin/rs-out.txt|echo PEACH-SHELL-$((6*7))", "wait 3000",
                           "dockdump /Users/admin/rs-dock.txt", "wait 400",
                           # …and the alias the fixture defines must not apply.
                           "runshell /Users/admin/rs-alias.txt|pcalias", "wait 3000"], 22),
    # Terminal tabs come back after a restart, in the folders they were in. The sessions cannot —
    # those processes died with the app — so what is restored is where they were, which is what people
    # actually lose: three terminals in three checkouts, and after a restart three prompts at home.
    #
    # Two launches in one scenario is not something this harness does, so the state file is written by
    # the first half and read by a `quit` and the automatic relaunch the guest script performs.
    ("terminal-restore", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                          "placeview plugin.terminal.view|default", "wait 800",
                          "dock on", "wait 3500",
                          "cmd cm_TerminalNewTab", "wait 2500",
                          "termsend plugin.terminal.view|cd /usr/lib\\n", "wait 2000",
                          "dockdump /Users/admin/restore-before.txt", "wait 400",
                          # The state is written when tabs change and again on teardown, so quitting
                          # is what makes the answer worth reading — and the answer has to be asked
                          # for from outside, because after `quit` there is nobody left to ask.
                          "quit", "wait 3000"], 18),
    # …and the other half: with folders written down, opening the area brings them back. The view is
    # built when the area first shows it, so seeding the file before `dock on` is the same order a
    # launch has. \042 is a double quote — a literal one has to survive python → ssh → sh → the app's
    # script parser.
    ("terminal-restored", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           # Tear down first, *then* write the state, then build again — the order a
                           # real launch has. Seeding before the teardown does not work and the reason
                           # is the feature working: teardown writes the state, so it overwrote the
                           # seed with the single tab the app had started with.
                           "closeviews", "wait 800",
                           "probe /Users/admin/seed.txt|mkdir -p ~/pc-cfg/terminal && printf "
                           "'{\\042bottom\\042:[\\042/usr/lib\\042,\\042/usr/share\\042]}' "
                           "> ~/pc-cfg/terminal/session.json && cat ~/pc-cfg/terminal/session.json",
                           "wait 800",
                           "refreshviews", "wait 1500",
                           "dock on", "wait 4000",
                           "dockdump /Users/admin/restored.txt", "wait 500"], 18),
    # The shell survives being moved between containers. That is what the whole incremental-refresh
    # machinery exists for, and with a real process behind the view it is finally observable as
    # something a user would notice rather than as a counter.
    ("terminal-move", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "dock on", "wait 2500",
                       "termsend plugin.terminal.view|cd /usr/lib\\n", "wait 1200",
                       "placeview plugin.terminal.view|sidebar", "wait 1500",
                       "previewpanel on", "wait 1200", "previewtab Terminal", "wait 1200",
                       "termsend plugin.terminal.view|pwd\\n", "wait 1500",
                       "sidebardump /Users/admin/term-moved.txt", "wait 300",
                       "mountdump /Users/admin/term-mounts.txt", "wait 400",
                       # Put it back. A placement override is *persisted*, so a scenario that leaves
                       # one changes the world for every scenario after it in the run — which is how
                       # terminal-teardown came to find no terminal in the dock and report that no
                       # jobs were running, twice, only in full runs. dock-seam already learned this;
                       # the lesson is that any scenario touching placement owns putting it back.
                       "placeview plugin.terminal.view|default", "wait 1000"], 20),
    # Do the folder trees follow the colour scheme — in *every* palette (F-015)? Reported against
    # Midnight: a white column of pale text beside two dark panels. The cause was a repaint nobody
    # called, so no palette applied after the view was built ever reached it; "it looks right in Dark"
    # would have been an accident of which colours happen to be close.
    #
    # Both trees, because they are two instances of the same class reached by different routes — the
    # shared column and the one inside a panel — and only one of them was noticed.
    ("tree-colours", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "cmd cm_TreeShared", "wait 1000",
                      "cmd cm_SrcTree", "wait 1200",
                      "treecolors /Users/admin/treecolours.txt", "wait 600"], 14),
    # The rest of the surfaces (F-015). `tree-colours` knows what the tree should be and checks it;
    # this one knows nothing about any widget and reports surfaces that break the two properties the
    # tree defect broke — a bright box in a dark window, and text too close to what is behind it.
    #
    # As much as possible on screen first, because the audit can only see what is mounted: both trees,
    # the preview panel, the bottom area with its terminal, and the settings window, which is a second
    # window and so a second chance for a palette to have been forgotten.
    ("surface-colours", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "cmd cm_TreeShared", "wait 800",
                         "cmd cm_SrcTree", "wait 800",
                         "previewpanel on", "wait 1000",
                         "dock on", "wait 2500",
                         "settingspage Layout", "wait 2500",
                         "surfacecolors /Users/admin/surfaces.txt", "wait 1200",
                         # Leave a dark palette on screen. The dump restores the palette it started
                         # from, so without this the screenshot shows Light and cannot be used to
                         # judge a finding — and a finding about a bright surface is exactly the kind
                         # that has to be looked at before it is believed.
                         "theme midnight", "wait 1500"], 28),
    # Plain user behaviour, no sweep: open the Notes view, then change the colour scheme (F-015).
    # The surface audit crashed the app doing this incidentally; this asks whether the crash belongs
    # to the product rather than to the measurement, because "switch theme with a plugin view open"
    # is a thing people do and a crash there is not a diagnostics problem.
    ("plugin-theme-switch", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                             "previewpanel on", "wait 1000",
                             "previewtab Notes", "wait 1500",
                             "theme midnight", "wait 1500",
                             "theme norton", "wait 1500",
                             "panelsdump /Users/admin/still-alive.txt", "wait 600"], 16),
    # Which half is broken (F-015 follow-up)? Six keys-* scenarios write neither their key-loop dump
    # nor the accessibility dump that follows it. Two possibilities with different fixes: the script
    # stops at the window (a modal session never returns to it) or the script runs and `dumpKeyLoop`
    # writes nothing. A dump *after* the keyloop step answers it — if this file exists, the script
    # ran past the keyloop and the dump itself is the problem.
    ("keys-probe", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "settingspage Layout", "wait 2500",
                    "keyloop /Users/admin/probe-loop.txt",
                    "panelsdump /Users/admin/probe-after.txt", "wait 800"], 14),
    # The window title carries the active path (F-012).
    ("window-title", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                      "windowdump /Users/admin/title.txt", "wait 400"], 8),
    # Quick Look on the cursor file (F-123): the panel is not what has to appear, the preview is.
    ("quick-look", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "focus notes.txt", "wait 400", "cmd cm_QuickLook", "wait 2500",
                    "quicklookdump /Users/admin/quicklook.txt", "wait 400"], 10),
    # Thumbnail view (F-022): the rows have to survive the switch, not just the screenshot look busy.
    ("thumbnails", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "cmd cm_SrcThumbs", "wait 2500", "dump /Users/admin/thumbs.txt", "wait 400"], 10),
    # The panel paths reach session.ini, which is what a restart reads (F-013). Saving is debounced by
    # 0.3 s, so the wait matters; the file is read by the shell afterwards.
    ("session-save", ["active left", "left /Users/admin/pc-demo", "wait 800",
                      "right /Users/admin/sync-src", "wait 2000"], 9),
    # Ctrl+Right: the folder under the cursor opens in the *other* panel (F-063). The dump reports the
    # active panel, so the right one is activated afterwards — otherwise this would report where the
    # left panel is, which never moved, and pass either way.
    ("transfer-panel", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "focus sub", "wait 400", "cmd cm_TransferRight", "wait 1200",
                        "active right", "wait 400", "dump /Users/admin/transfer.txt", "wait 400"], 9),
    # Open a binary and switch to text. Reported as a hang: the switch handed ~900k characters drawn
    # from thousands of different Unicode scalars to an NSTextView, and the first thing that asked for
    # layout spent minutes in CoreText's font fallback. A hang writes no report at all, which the
    # harness reports as an empty report — so this needs no timing threshold to catch the regression;
    # `fast=` is there to catch a return to merely-slow.
    ("viewer-binary-text", ["view /Users/admin/pc-demo-bin.dat", "wait 2500",
                            "listermode text|/Users/admin/bintext.txt", "wait 2000",
                            "listercaret 2", "wait 1500"], 10),
    # Opening a large file must not pull it into memory (F-112). The outline asked the virtual view for
    # its text, which decodes the whole file — and then refused it for being too long, so every byte was
    # wasted. The witness is the process's own resident size, read by the shell while the file is open,
    # which is why this scenario deliberately does not quit.
    ("viewer-large-memory", ["view /Users/admin/pc-big.txt", "wait 6000",
                             "listermode text|/Users/admin/bigmem.txt", "wait 4000",
                             "memdump /Users/admin/bigmem-rss.txt", "wait 500"], 12),
    # Compare Directories including subfolders (F-190). The walk moved off the main thread — it costs a
    # stat per file over *two* trees — so this checks the result is still the same: what gets marked.
    ("compare-dirs", ["active left", "left /Users/admin/pc-cmp/a", "wait 1000",
                      "right /Users/admin/pc-cmp/b", "wait 1000",
                      "cmd cm_CompareDirsWithSubdirs", "wait 2500",
                      "seldump /Users/admin/compare.txt", "wait 500"], 9),
    # One tree for both panels (F-015). What matters is *which* panel it steers: choosing a folder must
    # move the active one and leave the other alone, so the scenario activates the right panel first and
    # then dumps both.
    ("shared-tree", ["active left", "left /Users/admin/pc-demo", "wait 1000",
                     "right /Users/admin", "wait 800",
                     "sharedtree on", "wait 1200",
                     "active right", "wait 500",
                     "sharedtree select /Users/admin/pc-demo/sub", "wait 1500",
                     "dump /Users/admin/tree-active.txt", "wait 400",
                     "active left", "wait 400", "dump /Users/admin/tree-other.txt", "wait 400"], 10),
    # Does previewing a document fetch what it points at (F-116)? An <img> pointing at a server needs no
    # JavaScript, so disabling that never stopped it: opening the file told the other end who opened it
    # and when. The witness is the server, not the app — see EXTERNAL_CHECKS below.
    ("viewer-beacon", ["active left", "left /Users/admin/pc-beacon", "wait 1200",
                       "focus beacon.md", "wait 400", "cmd cm_List", "wait 3000"], 10),
    # Does a crafted archive write outside the folder the user chose (F-131)? The archive extractor
    # refused this; the panel's own extract walk — this one — did not, and nothing in the unit tests
    # reaches it, because nothing there constructs a MainWindowController. The report says where files
    # actually are afterwards, in the destination and in its parent.
    ("zip-slip", ["active left", "left /Users/admin/pc-slip", "wait 1000",
                  "zipextract /Users/admin/pc-slip/evil.zip|/Users/admin/pc-slip/target/out"
                  "|/Users/admin/slip.txt", "wait 2500"], 10),
    # Does a synchronisation work with a *server* as one side (F-193)? The unit tests drive the remote
    # side through LocalFS — the same code, but nothing crosses a socket. This talks SFTP to the guest's
    # own sshd, and what arrived is asked of ssh afterwards, not of the app.
    ("sync-sftp", ["active left", "left /Users/admin", "wait 1000",
                   "syncsftp /Users/admin/sync-src|/Users/admin/sync-dst|/Users/admin/syncsftp.txt",
                   "wait 4000"], 12),
    # Do attribute changes over SFTP actually reach the server (F-364)? They used to be discarded by an
    # empty function while the dialog reported success. `sftpchmod` connects, changes the mode, and reports
    # what the server says the mode is afterwards — the only answer that counts.
    ("sftp-attributes", ["active left", "left /Users/admin", "wait 1000",
                         "sftpchmod /Users/admin/sftp-demo/perm.txt|600|/Users/admin/sftp.txt",
                         "wait 3000"], 12),
    # Does an SFTP download go to disk and resume, instead of through memory from the start (F-366)?
    ("sftp-download", ["active left", "left /Users/admin", "wait 1000",
                       "sftpget /Users/admin/sftp-demo/big.txt|/Users/admin/got.txt|"
                       "/Users/admin/sftpget.txt|10000", "wait 4000"], 12),
    # And the other direction: does an upload resume instead of sending everything again (F-212)?
    ("sftp-upload", ["active left", "left /Users/admin", "wait 1000",
                     "sftpput /Users/admin/sftp-demo/big.txt|/Users/admin/put.txt|"
                     "/Users/admin/sftpput.txt|15000", "wait 4000"], 12),
    # Does a file's comment follow the file through a rename, in the running app (F-372)? The Comment
    # column has to be switched on first — it is opt-in, and the column read is skipped when it is off.
    ("comment-carry", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "cmd cm_SrcLong", "wait 600", "column comment", "widenleft", "wait 600",
                       "commentcarry /Users/admin/pc-demo|notes.txt|renamed.txt|/Users/admin/comment.txt",
                       "wait 1500"], 10),
    # A `descript.ion` written by Total Commander: UTF-16 with a BOM, and a multi-line comment using TC's
    # 0x04 0xC2 extension (F-374). Read it, write one comment back, and check the file is still UTF-16 and
    # the comment nobody touched is still there.
    ("tc-descript", ["active left", "left /Users/admin/pc-tc", "wait 1200",
                     "cmd cm_SrcLong", "wait 600", "column comment", "widenleft", "wait 600",
                     "tccomment /Users/admin/pc-tc|/Users/admin/tc.txt", "wait 1200"], 10),
    # Can a comment be found again (F-373)? A file whose *content* holds nothing of the sort, found by
    # what somebody wrote about it. The comment is set through the host's own path first.
    ("find-comments", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "comment table.csv|superseded by the 2026 export", "wait 800",
                       "findcomments *.csv|superseded|/Users/admin/pc-demo|/Users/admin/found.txt",
                       "wait 1000"], 11),
    # One note, three faces (F-372): the Notes plugin's sidebar shows and edits the *host's* per-file
    # comment, so a comment typed with Ctrl+Z is not invisible to the plugin and vice versa. This is also
    # the first scenario that exercises a plugin at all — the harness used to ship an app with none.
    ("notes-sidebar", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "focus hosts.txt", "wait 400",
                       "comment hosts.txt|a comment from the host side", "wait 800",
                       "previewpanel on", "wait 2000",
                       # The Notes view is a *tab* in the preview panel, and setting a comment reloads the
                       # panel — which moves the cursor back to "..", i.e. to the global note. So: pick the
                       # tab, then put the cursor back on the file, then read.
                       "previewtab Notes", "wait 800",
                       "focus hosts.txt", "wait 1200",
                       "sidebardump /Users/admin/sidebar.txt", "wait 500",
                       # …and the other direction: type in the plugin's field, and the host's own comment
                       # for that file must change. `commentread` asks the host, not the plugin.
                       "sidebarsetfield edited in the plugin", "wait 1200",
                       "commentread hosts.txt|/Users/admin/sidebar-back.txt", "wait 400"], 11),
    # A note bound to a *place* in a file (F-379): the viewer asks the Notes plugin which lines of the
    # file carry a note — through the ordinary content-field mechanism, so nothing about the viewer knows
    # what a note is — and offers them in the marks panel. The store is seeded in setup; this scenario
    # only opens the file and asks the window what it found.
    ("viewer-note-lines", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           "focus annotated.txt", "wait 400", "cmd cm_List", "wait 2500",
                           # Open the panel before dumping: a group that exists in the model but is never
                           # drawn is not something the user has. The dump then carries both.
                           "listermarks", "wait 800",
                           "listerdump /Users/admin/note-lines.txt", "wait 500"], 11),
    # The other direction (F-379): put the caret on a line, ask for a note about it, and see which note
    # the plugin opened. The editor is the plugin's own window, so its title is the only thing the host
    # can honestly check — and it is enough: "annotated.txt line 2" can only be there if the caret's line
    # was worked out, published through the context, read by the plugin and parsed back into a place.
    ("viewer-note-write", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           "focus annotated.txt", "wait 400", "cmd cm_List", "wait 2500",
                           "listercaret 2", "wait 400", "listernote", "wait 2000",
                           "windowdump /Users/admin/note-write.txt", "wait 500"], 11),
    # The plugin-facing side of a Total-Commander comment (F-380). The Comment column reads
    # `descript.ion` through `DescriptionFile.decode`; the path plugins ask through read it as UTF-8,
    # which throws on the UTF-16 file TC writes — so the sidebar showed nothing where the column showed
    # "Grüße aus Zürich". Same fixture as tc-descript, asked through the plugin instead of the column.
    ("tc-comment-sidebar", ["active left", "left /Users/admin/pc-tc-ro", "wait 1200",
                          "focus tc-utf16.txt", "wait 400",
                          "previewpanel on", "wait 2000",
                          "previewtab Notes", "wait 800",
                          "focus tc-utf16.txt", "wait 1200",
                          "sidebardump /Users/admin/tc-sidebar.txt", "wait 500"], 11),
    # The plugin contribution surface, which nothing checked before: `menudump` reads the *main* menu,
    # so every AI ▸ / Notes / tag entry a plugin adds to the right-click menu was unverified. This dumps
    # the context menu of a real file, and asks for the new "Suggest a comment" action (F-380) — which
    # only exists if the plugin's manifest, the host's contribution registry and the skill catalogue all
    # agree on the same command id.
    ("plugin-context-menu", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                             "ctxdump table.csv|/Users/admin/ctxmenu.txt", "wait 800"], 11),
    # "Verify files after copy" applied to foreground copies only (F-090) — and the background queue is
    # exactly what one picks for the large copies where verifying is worth the time. The dump is
    # scheduled first: the report is a modal alert, and `runModal` never returns to the script.
    ("bg-copy-verify", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                        "modaldump /Users/admin/verify.txt",
                        "bgcopyverify /Users/admin/pc-demo/hosts.txt|/Users/admin", "wait 4000"], 11),
    # A Windows-style file in the *code* view (F-110). Its line ranges were built by comparing each
    # Character against "\n", and a CRLF is one Character equal to neither — so the whole file rendered
    # as a single line and every line-addressed feature (go to line, marks, per-line notes) pointed at
    # nothing. messy.txt is CRLF; `cmd cm_ListCode` forces the syntax-highlighted view rather than the
    # plain text one, which indexes bytes and was never affected.
    ("viewer-crlf-lines", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                           "focus crlf.json", "wait 400", "cmd cm_List", "wait 2500",
                           "listerdump /Users/admin/crlf-lines.txt", "wait 500"], 11),
    # Num/ brings back the selection from before the last selection operation (F-056). It was routed
    # through the helper that saves the current selection first, so it popped what it had just pushed
    # and did nothing. The dump reports the marked names, so "one marked" versus "everything marked" is
    # the whole check.
    ("selection-restore", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                           "focus hosts.txt", "wait 300", "markone hosts.txt", "wait 400",
                           "seldump /Users/admin/sel-before.txt",
                           "cmd cm_SelectAll", "wait 600",
                           "seldump /Users/admin/sel-all.txt",
                           "cmd cm_RestoreSelection", "wait 800",
                           "seldump /Users/admin/sel-after.txt", "wait 400"], 11),
    # Not a layout scenario either: does a panel notice a file another program created (F-361)? Two
    # dumps of the listing with an outside change in between, and no refresh command anywhere.
    ("panel-autorefresh", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                           "dump /Users/admin/watch-before.txt",
                           "mkfile /Users/admin/pc-demo/auto-appeared.txt", "wait 2500",
                           "dump /Users/admin/watch-after.txt"], 10),
    # Keyboard reachability and the menu's real shortcuts, per window (I19 T06). Each scenario opens
    # one window and asks it what Tab reaches and what a screen reader would find.
    # cm_SrcLong first: the view mode is persisted in peachcmd.ini and survives between scenarios, so
    # without it this one inherited whatever the last view scenario left behind — and in Icons mode the
    # panel's list is a different class, which made the label gate fail for the right reason in the wrong
    # place. Found by the full run, not by running this scenario alone.
    ("keys-main", ["active left", "left /Users/admin/pc-demo", "wait 1200", "cmd cm_SrcLong", "wait 800",
                   "menudump /Users/admin/menu.txt",
                   "keyloop /Users/admin/keyloop-main.txt",
                   "a11ydump /Users/admin/a11y-main.txt", "wait 500",
                   # A last file the guest can wait for. Without one this scenario had nothing but its
                   # settle time between launch and being killed, which is the flaw
                   # check-scenario-reports.py exempts the keyboard scenarios from — and it duly
                   # produced an empty menu dump the first time the menu bar grew.
                   "panelsdump /Users/admin/keys-main-done.txt", "wait 300"], 14),
    ("keys-find", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "findtab 0", "wait 1500", "keyloop /Users/admin/keyloop-find.txt",
                   "a11ydump /Users/admin/a11y-find.txt", "wait 500",
                   "panelsdump /Users/admin/keys-find-done.txt", "wait 300"], 14),
    ("keys-settings", ["active left", "left /Users/admin", "wait 1000",
                       "settingspage Layout", "wait 2500",
                       "keyloop /Users/admin/keyloop-settings.txt",
                       "a11ydump /Users/admin/a11y-settings.txt", "wait 500",
                   "panelsdump /Users/admin/keys-settings-done.txt", "wait 300"], 14),
    ("keys-editor", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "editfilterdlg /Users/admin/pc-demo/notes.txt", "wait 1500",
                     "keyloop /Users/admin/keyloop-editor.txt",
                     "a11ydump /Users/admin/a11y-editor.txt", "wait 500",
                   "panelsdump /Users/admin/keys-editor-done.txt", "wait 300"], 14),
    ("keys-viewer", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "focus notes.txt", "wait 400", "cmd cm_List", "wait 2000",
                     "keyloop /Users/admin/keyloop-viewer.txt",
                     "a11ydump /Users/admin/a11y-viewer.txt", "wait 500",
                   "panelsdump /Users/admin/keys-viewer-done.txt", "wait 300"], 14),
    # A structured file, not notes.txt: the editor builds its Structure menu only for JSON/YAML/XML, and
    # those seven shortcuts were unchecked by the hotkey gate until this dump existed.
    ("keys-editorwin", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "editdump /Users/admin/pc-demo/stack.yml /Users/admin/ed.txt", "wait 1800",
                        "keyloop /Users/admin/keyloop-editorwin.txt",
                        "a11ydump /Users/admin/a11y-editorwin.txt",
                        "menudump /Users/admin/menu-editor.txt", "wait 500",
                        "panelsdump /Users/admin/keys-editorwin-done.txt", "wait 300"], 14),
    ("keys-hotlist", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "hotlistmanage", "wait 1500",
                      "keyloop /Users/admin/keyloop-hotlist.txt",
                      "a11ydump /Users/admin/a11y-hotlist.txt", "wait 500",
                   "panelsdump /Users/admin/keys-hotlist-done.txt", "wait 300"], 14),
    # A modal dialog: the dump is scheduled first, because `runModal` never returns to the script.
    ("keys-overwrite", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "keyloopmodal /Users/admin/keyloop-overwrite.txt",
                        "overwritedlg", "wait 2500"], 11),
    # Not a layout scenario: this one asks the app what a screen reader would find. The hand-drawn
    # bars are the case where the failure mode is *no element at all* and nothing on screen differs,
    # so it can only be caught by asking (I19 T06).
    ("accessibility", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "cmd cm_OpenNewTab", "wait 600",
                       "a11ydump /Users/admin/a11y.txt", "wait 800"], 10),
]

# Labels that must appear in the accessibility dump. Each one is a control that draws itself and would
# otherwise be invisible; a missing entry means somebody removed the wiring, not that a label changed.
REQUIRED_A11Y = ["Drive bar", "Panel tabs", "Preview panel width", "All volumes"]

# What an *independent* tool must say after a scenario ran: the app changed something, and something other
# than the app is asked whether it really changed. `stat` over ssh is not the code under test.
EXTERNAL_CHECKS = {
    # Does the key-loop dump land on the guest at all? Asked of the machine rather than of the
    # harness's fetch, because "the file is empty here" has two causes — nothing was written, or
    # something was written and did not come back — and they need different fixes.
    "keys-probe": ("test -s ~/probe-loop.txt && echo written || echo nothing", "written"),
    # Asked of the machine after the app is gone, because that is when the question makes sense: two
    # tabs were open, and the file that survives the app has to name both of their folders.
    "terminal-restore": ("python3 -c \"import json;print(len(json.load(open('$HOME/pc-cfg/terminal/session.json'))['bottom']))\" 2>/dev/null || echo 0", "2"),
    # Is the OSC 7 hook the settings page describes actually in the guest's .zshrc? Asked over ssh
    # after the app is dead, because the probe that was supposed to answer this from inside the app
    # never produced a file at all — and a question about the fixture should not be routed through the
    # thing whose behaviour is in doubt.
    "terminal-settings": ("grep -c '^add-zsh-hook precmd _pc_osc7' ~/.zshrc 2>/dev/null || echo 0", "1"),
    # Asked of the machine after the app is gone, which is the only witness that counts: the app cannot
    # testify that it cleaned up after itself. Both jobs must be gone — the background one (own process
    # group, so it dies only because the shell hups its jobs) and the foreground one (the terminal's
    # group, HUPed by the kernel when the master fd closes). Either route failing is a leak.
    "terminal-orphan": ("pgrep -f 'sleep 39[12]' | wc -l | tr -d ' '", "0"),
    # The files, on the server, asked of the shell — including the one in a subfolder, because creating
    # the parent is the part a server does not do for you.
    "sync-sftp": ("cat ~/sync-dst/alpha.txt ~/sync-dst/sub/beta.txt 2>/dev/null | tr '\\n' ' '",
                  "one two"),
    # The button is in the file the app will read at the next launch, not merely in the view.
    # The `cmd` line specifically: a button writes the path twice, once as its icon and once as the
    # command, so counting mentions says 2 and says nothing about which is which.
    "toolbar-drop": ("grep -c '^cmd[0-9]*=.*Calculator.app$' ~/pc-cfg/default.bar 2>/dev/null || echo 0",
                     "1"),
    # Both panel paths in the file a restart reads.
    # Both paths present. Counting mentions was wrong — each path appears under more than one key —
    # so this asks the question directly and answers it in one word.
    "session-save": ("grep -q pc-demo ~/pc-cfg/session.ini && grep -q sync-src ~/pc-cfg/session.ini "
                     "&& echo both || echo missing", "both"),
    "sftp-attributes": ("stat -f %Lp ~/sftp-demo/perm.txt", "600"),
    # Three distinct answers, so the interesting failure cannot hide: "viewer-fetched" means the block is
    # not working, "server-not-running" means the witness died and the run proves nothing, and only
    # "only-selftest" means the document was rendered and reached nobody.
    "viewer-beacon": ("if grep -q viewer.png ~/beacon-hits.log 2>/dev/null; then echo viewer-fetched; "
                      "elif grep -q selftest ~/beacon-hits.log 2>/dev/null; then echo only-selftest; "
                      "else echo server-not-running; fi", "only-selftest"),
    # The downloaded file must be byte-identical to the original — asked of `cmp`, not of the downloader.
    "sftp-download": ("cmp -s ~/sftp-demo/big.txt ~/got.txt && echo identical || echo differs",
                      "identical"),
    "sftp-upload": ("cmp -s ~/sftp-demo/big.txt ~/put.txt && echo identical || echo differs",
                    "identical"),
}

# Scenarios that leave a report in the guest, and what has to be in it. The screenshot proves the
# window drew; this proves the *edit* happened — replaced, undoable, and with the expected text.
# Keyboard reachability is a gate, not a report to skim (I19 T06). For every window listed here the
# key-view loop must be closed, every focusable control must be in it, and every interactive control must
# have something to announce — because a control Tab cannot reach is never read out either, and none of
# that is visible in a screenshot.
#
# `labels` are the words that must appear somewhere in the window's accessibility tree: a renamed label is
# fine, a *missing* one means somebody removed the wiring.
KEYBOARD_GATES = {
    "keyloop-main.txt": ["File list, left panel", "File list, right panel"],
    "keyloop-find.txt": ["Search options", "Search results"],
    "keyloop-settings.txt": ["Settings pages"],
    "keyloop-editor.txt": ["Shell command"],
    # The remaining windows are held to reachability and labelling; no particular wording is pinned,
    # because these are ordinary AppKit controls whose titles already say what they are.
    "keyloop-viewer.txt": [],
    "keyloop-editorwin.txt": [],
    "keyloop-hotlist.txt": [],
    "keyloop-overwrite.txt": [],
}

KEYBOARD_REPORTS = {
    "keys-main": ["menu.txt", "keyloop-main.txt", "a11y-main.txt"],
    "keys-find": ["keyloop-find.txt", "a11y-find.txt"],
    "keys-settings": ["keyloop-settings.txt", "a11y-settings.txt"],
    "keys-editor": ["keyloop-editor.txt", "a11y-editor.txt"],
    "keys-viewer": ["keyloop-viewer.txt", "a11y-viewer.txt"],
    "keys-editorwin": ["keyloop-editorwin.txt", "a11y-editorwin.txt", "menu-editor.txt"],
    "keys-hotlist": ["keyloop-hotlist.txt", "a11y-hotlist.txt"],
    "keys-overwrite": ["keyloop-overwrite.txt"],
}

# Reports a scenario must have written, and what has to be in them ("!x" = must NOT be there).
#
# A scenario also claims every key that starts with "<its name>-" — that is how `notes-sidebar` owns
# `notes-sidebar-back`. So a *scenario* whose name extends another one's gets adopted by it, and its
# report is checked before it has run: name new scenarios so they are not a prefix-extension of an
# existing one. (Cost a run: "notes-sidebar-tc" passed alone and failed in company.)
REPORTS = {
    "editor-filter": ("/Users/admin/filter.txt",
                      ["outcome=replaced", "undo=true", "alpha.example\nbeta.example\n"]),
    # The file must be in the listing afterwards — and, so the check cannot pass for the wrong reason,
    # absent before it was created (an expectation starting with "!" must NOT appear).
    "panel-autorefresh": ("/Users/admin/watch-after.txt", ["auto-appeared.txt"]),
    # Three claims, because two of them can pass for the wrong reason. `listed=` must contain ".." —
    # otherwise the fixture never held a traversal member and the rest proves nothing. `inside=` must
    # hold the honest member, so a walk that refuses *everything* does not count as a fix. And the
    # parent must be empty: that is the only line that distinguishes the two behaviours, since the
    # extraction reports success either way.
    "zip-slip": ("/Users/admin/slip.txt",
                 ["listed=..,harmless.txt\n", "inside=harmless.txt\n", "parent=\n", "!escaped.txt"]),
    # What the sync decided, before what it did: an empty action list with no errors would otherwise
    # read as success.
    "sync-sftp": ("/Users/admin/syncsftp.txt",
                  ["compared=3", "alpha.txt:copyToRight", "sub/beta.txt:copyToRight", "errors=none"]),
    # Equal to within a point: the two panels are laid out in float widths and an odd window cannot
    # split evenly. `!diff=` catches nothing on its own, so the before-picture is checked too — without
    # it, a run where `widenleft` silently did nothing would pass.
    "split-center": ("/Users/admin/split-after.txt", ["equal=yes\n"]),
    "split-center-before": ("/Users/admin/split-before.txt", ["equal=no\n"]),
    # No plugin ships a "bottom" view yet, so the dock opens empty — and the empty state is itself worth
    # asserting: an unexplained empty frame and an explained one look identical in a screenshot, and only
    # one of them is a state the user can act on. `stacked=yes` is the real claim.
    "dock-seam-open": ("/Users/admin/dock-open.txt",
                  ["visible=true", "stacked=yes", "panels=\n",
                   "No plugin provides a view here.", "!height=0"]),
    "dock-seam": ("/Users/admin/dock-shut.txt",
                       ["visible=false", "height=0", "dividerGap=0", "stacked=yes"]),
    # One whole line, not three substrings: "closed=0" is also true of every mount that never built a
    # view, so scattered substrings would pass against a dump in which the Notes view had been
    # destroyed and rebuilt. The claim is that *this* view survived two refreshes — still standing,
    # built exactly once, never closed. The "before" dump is what makes it mean anything: a view that
    # was never made cannot be destroyed. (made/closed are per plugin, which is what the ABI boundary
    # can count; Notes contributes one view, so for this line they are the same thing.)
    "mount-refresh": ("/Users/admin/mounts-after.txt",
                      ["plugin.notes.sidebar container=sidebar built=true made=1 closed=0"]),
    "mount-refresh-before": ("/Users/admin/mounts-before.txt",
                             ["plugin.notes.sidebar container=sidebar built=true made=1 closed=0"]),
    # The whole line again: "container=bottom" alone would pass for a view that had been destroyed and
    # rebuilt there, which is exactly the failure this feature had to avoid.
    "view-placement-moved": ("/Users/admin/placed.txt",
                       ["plugin.notes.sidebar container=bottom built=true made=1 closed=0"]),
    # …and the dock really lists it, rather than the registry merely believing it does. Not "the only
    # panel there" and not "the selected one": the Terminal plugin also mounts here by default, so both
    # of those were claims about the *rest* of the plugin set rather than about the move.
    "view-placement-dock": ("/Users/admin/placed-dock.txt", ["plugin.notes.sidebar", "visible=true"]),
    "view-placement": ("/Users/admin/placed-back.txt",
                            ["plugin.notes.sidebar container=sidebar built=true made=1 closed=0"]),
    # Ctrl+B (the branch view) rather than Cmd+C, and that took a failed run to work out: the shipped
    # default scheme is tc-classic, which does not bind Cmd+C at all — the panel copies files through
    # the Edit *menu* and the responder chain there, a path this probe deliberately does not use. So
    # Cmd+C proved nothing in either direction. Ctrl+B is bound in the keymap, which is the route that
    # broadcasts to every view in the window, and it is exactly the key section 8 of the plan warns
    # about: aimed at a terminal it must not open a directory branch.
    #
    # The control comes first and matters as much as the claim: without it, "the panel did not take
    # the key" would also pass in a build where the panel takes no keys at all.
    "raw-keyboard-panel": ("/Users/admin/key-panel.txt", ["responder=PanelListView", "claimed=true"]),
    "raw-keyboard-cmdline": ("/Users/admin/key-cmdline.txt", ["claimed=false", "!responder=PanelListView"]),
    "raw-keyboard": ("/Users/admin/key-container.txt",
                               ["responder=CommandLineView", "claimed=false"]),
    # A shell is running and the pseudo-terminal has a believable size. The columns are why the dock
    # exists: measured, the side panel gives this font 44 (26 at its minimum) and the bottom of the
    # window about 170, and `top` assumes 80.
    "terminal-session-idle": ("/Users/admin/term-idle.txt",
                         ["panels=plugin.terminal.view", "· bottom", "!·  0×0", "!exited"]),
    # The status line follows the running program's own title (OSC 0/1/2), so after `top` it is the
    # terminal reporting what it runs rather than the host guessing from the process table. The
    # rendering itself is judged from the screenshot — nothing outside the plugin can read the buffer,
    # and "does htop look right" is not a question a substring can answer honestly.
    "terminal-session-panels": ("/Users/admin/panels-after.txt", ["left=/Users/admin/pc-demo"]),
    "terminal-session": ("/Users/admin/panels-end.txt", ["left=/Users/admin/pc-demo"]),
    "terminal-session-top": ("/Users/admin/term-top.txt",
                             ["panels=plugin.terminal.view", "· bottom", "!exited"]),
    # `cd /usr/lib` before the move, `pwd` after it. A rebuilt view would carry a fresh shell sitting
    # in the home directory, so this is the promise stated the way a user would notice it.
    "terminal-control": ("/Users/admin/ctl-panel.txt", ["pc-demo"]),
    # Both halves, and the "before" is what stops the "after" passing for the wrong reason: two jobs
    # were really running, and after teardown neither is. The failure modes are distinguishable by the
    # number: with PcCloseView never called, 2 survive; with it called but the plugin not signalling
    # the process group, 1 does — the background job, because SwiftTerm's terminate sends SIGTERM to
    # the shell rather than SIGHUP and a SIGTERMed zsh does not hup its jobs.
    # The precondition, written down: a terminal is in the dock and its shell has reported a size.
    # Without this, "0 jobs after teardown" is also what an empty dock reports.
    "terminal-teardown-dock": ("/Users/admin/td-dock.txt",
                               ["panels=plugin.terminal.view", "zsh ·", "!·  0×0"]),
    "terminal-teardown-before": ("/Users/admin/before.txt", ["2"]),
    "terminal-teardown": ("/Users/admin/after.txt", ["0", "!2"]),
    # One tab, session 1, a shell with a real size.
    # One tab and one pane, so the status line carries no bookkeeping at all — which is the claim:
    # "tab 1/1 · session 1" is noise and must not be there.
    "terminal-tabs-one": ("/Users/admin/tabs-one.txt", ["zsh · ", "!tab ", "!pane ", "!× 0"]),
    # A second tab is a *new* session, not a reused one — otherwise "tabs" would just be a relabelled
    # single terminal.
    # …with a shell that actually started. The first version of this expectation checked only the tab
    # numbering and passed against a second tab reporting 0×0 — a terminal with no columns, whose shell
    # had never been told a size and never would be, since a pseudo-terminal is resized only on change.
    # …with a shell that actually started *and knows how wide it is*. Two earlier versions of this
    # expectation passed against a broken terminal: one checked only the tab numbering (the second tab
    # reported 0×0), and the next only that it was not 0×0 (it reported SwiftTerm's default 80×25 while
    # showing 125 columns, so every line the shell printed wrapped in the wrong place). The size is
    # asserted against the first tab's, because both tabs live in the same view and must agree.
    "terminal-tabs-two": ("/Users/admin/tabs-two.txt", ["tab 2/2 · session 2", "· 125×9 ·"]),
    # …and coming back lands on session 1 again rather than on a fresh one wearing its number.
    "terminal-tabs-back": ("/Users/admin/tabs-back.txt", ["tab 1/2 · session 1"]),
    # The claim that matters, asked of the process table: what was started in the first tab is still
    # running after two tab switches.
    "terminal-tabs-alive": ("/Users/admin/tabs-alive.txt", ["1", "!0"]),
    # The §12 tripwire on a second scenario, because the screenshot of this one showed the left panel
    # in the home folder again — a third sighting. If it is real it will be caught here with the state
    # written down rather than inferred from a picture.
    "terminal-tabs": ("/Users/admin/tabs-panels.txt", ["left=/Users/admin/pc-demo"]),
    # Split: two panes, and the second one is a second session with a size of its own. Both panes are
    # half as tall, which is the part a naive implementation gets wrong — only the focused pane gets
    # resized and the other keeps rendering at the full height it no longer has.
    # A floor on the rows rather than an exact number, because the exact one depends on the dock's
    # height and the font. The floor is what matters: the first version of this passed against a pane
    # one row tall, since NSSplitView gives a new pane the leftovers instead of an even share.
    "terminal-split-two": ("/Users/admin/split-two.txt",
                           ["tab 2/2 · session 2 · pane 2/2",
                            "!×0 ·", "!×1 ·", "!×2 ·", "!· 80×25 ·"]),
    # Collapsed back to one pane, still two tabs: the other session was not closed, only hidden.
    # Collapsed: two tabs still, and no pane bookkeeping because there is only one pane again.
    "terminal-split-one": ("/Users/admin/split-one.txt", ["tab 2/2 · session 2", "!pane "]),
    # …and the job started in it is still running, which is the whole point of "maximise ≠ close".
    "terminal-split": ("/Users/admin/split-alive.txt", ["1", "!0"]),
    # The keyboard went back to the panel, and the dock stayed open — the two halves of "this is a
    # focus toggle, not a visibility toggle".
    "terminal-integration-panel": ("/Users/admin/int-panel.txt", ["responder=PanelListView"]),
    "terminal-integration-term": ("/Users/admin/int-term.txt", ["responder=PCTerminalView"]),
    "terminal-integration-dock": ("/Users/admin/int-dock.txt", ["visible=true"]),
    # The shell's own answer to "where are you".
    "terminal-integration-cwd": ("/Users/admin/int-cwd.txt", ["/Users/admin/pc-demo"]),
    # …and the file name it parsed, whole. A quoting failure would split the path or lose it.
    "terminal-integration": ("/Users/admin/int-names.txt", ["/Users/admin/pc-demo/notes.txt"]),
    "terminal-cmdline-tty": ("/Users/admin/cmdline.txt", ["/dev/ttys", "!not a tty"]),
    "terminal-cmdline": ("/Users/admin/cmdline-cwd.txt", ["/Users/admin/pc-demo"]),
    # One line, whole: the shell parsed it as a single argument. Quoting failure splits it.
    "terminal-drop": ("/Users/admin/drop.txt", ["/Users/admin/pc-demo/it's a file.txt"]),
    # The page says what it must: a switch that is off, and the exact escape sequence the user has to
    # arrange for themselves.
    "terminal-settings": ("/Users/admin/tset.txt",
                          ["Let the active panel follow the terminal", "]7;file://", "add-zsh-hook"]),
    "terminal-follow-set": ("/Users/admin/set.txt", ["panelFollowsTerminal", "true"]),
    # The panel started where the scenario put it…
    "terminal-follow-before": ("/Users/admin/follow-before.txt", ["left=/Users/admin/pc-demo"]),
    # …and followed the shell. The only scenario in which the terminal may steer a panel at all, which
    # is why every other one asserts the panel stays put.
    "terminal-follow-panel": ("/Users/admin/follow-after.txt", ["left=/usr/lib"]),
    # The terminal's own account of where it thinks it is, so a failure says which half broke: the
    # shell not reporting, or the host not being steered.
    # The cleanup is the last thing written, so it is what the guest waits for: killing the app before
    # it resets the setting would leave the next scenario in the run with the terminal steering panels.
    "terminal-follow": ("/Users/admin/unset.txt", ["unset"]),
    "terminal-follow-dock": ("/Users/admin/follow-dock.txt", ["/usr/lib"]),
    # The find bar opened and took the keyboard: after ⌘F the first responder is the search field's
    # editor rather than the terminal. That focus move is the signal, and "claimed" is not — measured,
    # the key is claimed with a file panel focused too, because AppKit finds *something* in the
    # responder chain willing to answer performFindPanelAction:.
    # The bar is *there*, which is steadier than where the keyboard is: focus moves into the search
    # field asynchronously and one run reported the terminal still holding it. "Word" is one of the
    # bar's own option buttons, so it cannot appear unless the bar opened.
    "terminal-find-term": ("/Users/admin/find-term.txt", ["claimed=true"]),
    "terminal-find-bar": ("/Users/admin/find-bar.txt", ["Word"]),
    # The control, restated around what actually distinguishes the two: with a file panel focused,
    # nothing opens and the keyboard stays where it was.
    "terminal-find": ("/Users/admin/find-panel.txt", ["responder=PanelListView"]),
    "terminal-fkeys-panel": ("/Users/admin/fk-panel.txt",
                             ["responder=PanelListView", "keysAreOurs=true"]),
    "terminal-fkeys-term": ("/Users/admin/fk-term.txt", ["keysAreOurs=false"]),
    "terminal-fkeys": ("/Users/admin/fk-back.txt",
                       ["responder=PanelListView", "keysAreOurs=true"]),
    "terminal-reveal-abs": ("/Users/admin/rev-abs.txt", ["left=/Users/admin/pc-demo"]),
    # Still there: a word that names nothing left the panel alone.
    "terminal-reveal": ("/Users/admin/rev-none.txt", ["left=/Users/admin/pc-demo"]),
    # The dialog appeared and named the job. "sleep" is what the foreground process group resolves to,
    # which is the whole mechanism working end to end.
    "terminal-close-ask-alert": ("/Users/admin/close-alert.txt",
                                 ["modal=true", "sleep", "still running"]),
    # …and the tab is still there, with a live shell. A dialog that appears and closes the tab anyway
    # would be worse than no dialog.
    "terminal-close-ask-two": ("/Users/admin/close-two.txt", ["tab 2/2"]),
    "terminal-close-ask-kept": ("/Users/admin/close-after.txt",
                                ["panels=plugin.terminal.view", "!exited", "!tab "]),
    # The other half: a tab with nothing running closes, and the count goes back to one — which is
    # what "no tab bookkeeping in the status line" means once there is a single tab again.
    "terminal-close-ask": ("/Users/admin/close-gone.txt",
                           ["panels=plugin.terminal.view", "!tab ", "!exited"]),
    # The scrollback is on the clipboard as text, and no file went with it: "fileURLs=0" is the half
    # that would have failed if the panel had answered instead.
    "terminal-copy": ("/Users/admin/copy-done.txt", ["PEACH-COPY", "fileURLs=0", "!notes.txt"]),
    "view-drop-same": ("/Users/admin/drop-same.txt",
                       ["plugin.terminal.view container=bottom built=true made=1 closed=0"]),
    # Moved, and the same view: made=1 closed=0 says the drop went through the re-parenting path and
    # not through a rebuild, which for a terminal is the difference between moving it and losing it.
    "view-drop-moved": ("/Users/admin/drop-moved.txt",
                        ["plugin.terminal.view container=sidebar built=true made=1 closed=0"]),
    # …and the side panel is showing it rather than merely holding it.
    "view-drop": ("/Users/admin/drop-side.txt", ["zsh · ", "· sidebar"]),
    # What the model would receive: the output, and the exit status the wrapper reports through
    # pipestatus rather than tee's own.
    "terminal-runshell-out": ("/Users/admin/rs-out.txt", ["PEACH-SHELL-42", "[exit status 0]"]),
    # A tab opened for it, and it is not the login shell.
    "terminal-runshell-dock": ("/Users/admin/rs-dock.txt", ["panels=plugin.terminal.view", "tab 2/2"]),
    # The alias the user's .zshrc defines does *not* apply: a non-interactive shell never read it, so
    # the command fails as an unknown command instead of quietly meaning something else.
    "terminal-runshell": ("/Users/admin/rs-alias.txt", ["!ALIAS-RAN", "!exit status 0"]),
    "terminal-restore": ("/Users/admin/restore-before.txt", ["tab 2/2"]),
    # Two tabs came back, and the one showing is in the folder that was written down rather than in
    # the panel's — which is the difference between restoring and starting fresh.
    "terminal-restored-seed": ("/Users/admin/seed.txt", ["bottom"]),
    "terminal-restored": ("/Users/admin/restored.txt", ["tab 1/2", "/usr/lib"]),
    "terminal-move-side": ("/Users/admin/term-moved.txt", ["· sidebar", "!exited"]),
    "terminal-move": ("/Users/admin/term-mounts.txt",
                             ["plugin.terminal.view container=sidebar built=true made=1 closed=0"]),
    "keys-main": ("/Users/admin/keys-main-done.txt", ["left=/Users/admin/pc-demo"]),
    # The same last-file-to-wait-for that keys-main has had all along. Without it the guest kills the
    # app after the settle time whether or not the script got that far, and these six never did: every
    # one of them wrote nothing at all, for months, while reporting only that a file was empty. The
    # dump above proves the app writes it happily when given the time.
    "keys-find": ("/Users/admin/keys-find-done.txt", ["left="]),
    "keys-settings": ("/Users/admin/keys-settings-done.txt", ["left="]),
    "keys-editor": ("/Users/admin/keys-editor-done.txt", ["left="]),
    "keys-viewer": ("/Users/admin/keys-viewer-done.txt", ["left="]),
    "keys-editorwin": ("/Users/admin/keys-editorwin-done.txt", ["left="]),
    "keys-hotlist": ("/Users/admin/keys-hotlist-done.txt", ["left="]),
    # This one cannot have a trailing dump: `overwritedlg` runs a modal session that never returns to
    # the script, which is why its keyloop is *scheduled* beforehand. So the thing to wait for is the
    # keyloop dump itself, which the timer writes while the dialog is up.
    "keys-overwrite": ("/Users/admin/keyloop-overwrite.txt", ["window:"]),
    # Every line must end in "ok", so a single palette going wrong fails the check — and the numbers
    # stay in the dump because "WRONG" alone does not say which half.
    "tree-colours": ("/Users/admin/treecolours.txt",
                     ["light/shared", "dark/shared", "midnight/shared", "norton/shared",
                      "midnight/panel",
                      # Named, not left to "!WRONG": a row opened *after* the switch is a separate
                      # question from the rows the reload rebuilt, and if that probe ever disappeared
                      # the absence of a WRONG line would look like a pass.
                      "midnight/shared/opened", "!WRONG"]),
    # Every finding of the first run has been judged: the bright surfaces were AppKit helper views at
    # zero alpha, the cursor-row contrast was the audit reading the wrong background, and the one real
    # defect (the terminal status line, black on Norton blue) is fixed. So the expectation is now
    # "nothing" — and the window count is asserted with it, because nothing found by looking at
    # nothing is not the same claim.
    "surface-colours": ("/Users/admin/surfaces.txt", ["windows=32", "findings=0"]),
    # The dump is written last and only by a living app: if the theme change killed it, this file is
    # never written and the scenario fails with an empty report, which is the whole question.
    "plugin-theme-switch": ("/Users/admin/still-alive.txt", ["left="]),
    "keys-probe": ("/Users/admin/probe-after.txt", ["left="]),
    "window-title": ("/Users/admin/title.txt", ["pc-demo"]),
    # The panel exists, is on screen, and is previewing the file the cursor was on. Window titles were
    # the wrong question: a system panel has none, so that check passed without showing anything.
    "quick-look": ("/Users/admin/quicklook.txt", ["exists=true", "visible=true", "item=notes.txt"]),
    # Names, not a count: a thumbnail view that renders empty tiles is exactly the failure to catch.
    "thumbnails": ("/Users/admin/thumbs.txt", ["notes.txt", "table.csv"]),
    # The menu dump was written and never read for content (F-293). Both halves of that row are in it:
    # the system Services submenu, which the panels feed through NSServicesMenuRequestor, and the
    # "Open Terminal Here" item with the command it routes to.
    "keys-main-menu": ("/Users/admin/menu.txt",
                       ["Services", "Open Terminal Here", "cm_OpenTerminal"]),
    "transfer-panel": ("/Users/admin/transfer.txt", ["path=/Users/admin/pc-demo/sub\n"]),
    # The view matters as much as the timing: an NSTextView holding binary content is the defect, and
    # it looks fine until something asks it to lay out.
    "viewer-binary-text": ("/Users/admin/bintext.txt",
                           ["mode=text", "view=TextListerView", "fast=yes"]),
    "viewer-large-memory-text": ("/Users/admin/bigmem.txt", ["mode=text", "view=TextListerView"]),
    # Measured on the host: 139 MB idle, 257 MB with the fix, 434 MB without — the difference being the
    # file decoded into a String the outline then refused for being too long. The verdict's threshold
    # (350 MB) sits between the two with room for the guest to differ.
    "viewer-large-memory": ("/Users/admin/bigmem-rss.txt", ["lean=yes"]),
    # The left panel marks what the right one does not have, or has differently. `both.txt` is identical
    # on both sides and must stay unmarked — otherwise "marked everything" would pass.
    "compare-dirs": ("/Users/admin/compare.txt", ["name=only-left.txt", "name=sub", "!name=both.txt"]),
    "shared-tree-active": ("/Users/admin/tree-active.txt", ["path=/Users/admin/pc-demo/sub\n"]),
    # …and the panel that was not active did not move. Without this the scenario would pass if the tree
    # navigated both, which is precisely the thing to get wrong.
    "shared-tree": ("/Users/admin/tree-other.txt", ["path=/Users/admin/pc-demo\n"]),
    "sftp-attributes": ("/Users/admin/sftp.txt", ["requested=600", "applied=ok"]),
    # 40960 bytes whole; then only the tail after 10000 travels.
    "sftp-download": ("/Users/admin/sftpget.txt", ["full=40960", "resumedAt=10000", "tail=30960"]),
    "sftp-upload": ("/Users/admin/sftpput.txt", ["full=40960", "resumedAt=15000", "tail=25960"]),
    "panel-autorefresh-before": ("/Users/admin/watch-before.txt", ["!auto-appeared.txt"]),
    # CRLF in, CRLF out — shown as <CR> so a terminator that vanished is visible in the report.
    # The rows the outline rendered, not what the parser returned: mapping keys, a nested mapping, the
    # index label for a sequence entry — and no row that came out blank ("BLANK!" is what editdump marks
    # a row with nothing visible in it, which is precisely the old bug's signature).
    "editor-yaml-outline": ("/Users/admin/yaml-outline.txt",
                            ["version", "services", "web", "image", "ports", "[0]", "db", "!BLANK!",
                             # The caret is at the top after loading, so the breadcrumb must say so.
                             "crumb@0=version", "crumb@mid=services \u203a web"]),
    # Elements are labelled by their identifying attribute, so two <server> rows are told apart.
    "editor-xml-outline": ("/Users/admin/xml-outline.txt",
                           ["server #web-1", "port", "tls", "server #web-2", "!BLANK!",
                            "crumb@0=", "crumb@mid=server #web-1"]),
    # Where the caret went, not what a function returned. `stack.yml` line 4 is `image: nginx` inside
    # `services.web`, so: in → `ports`, next → nothing (beep), out → `web`, and the copied path is a yq
    # expression. "NOT WIRED" is what the report says for a menu item that cannot fire.
    "editor-structure": ("/Users/admin/structure.txt",
                         ["!NOT WIRED",
                          "Go to First Child: sel=", "said=ports",
                          # The path is copied *after* the move out, so it is `web`'s, not `image`'s —
                          # the report corrected this expectation, not the other way round.
                          "clipboard=.services.web",
                          "Copied: .services.web",
                          "Select Enclosing Node: sel=",
                          # The arrow keys, so a lost key equivalent is visible as text.
                          "Go to Enclosing Node|arrow",
                          # A YAML file offers only the two escaping transforms; minify and sort keys are
                          # JSON's. The menu being format-dependent is the assertion here.
                          "transforms=escapeAsJSONString,unescapeJSONString",
                          # Folding (F-371): fragments must *drop* when a node is folded and come back
                          # when it is unfolded, and a caret placed inside a fold must open it.
                          "Fold Node: sel=", "Fold Top Level:", "Unfold All:",
                          "caretIntoFold: folds=0",
                          "!NO SUCH ITEM"]),
    # The same scenario also exercises the transformations (F-370), because they need a *JSON* document:
    # keys sorted, then that minified to one line, then converted to YAML, then the whole thing escaped as
    # a JSON string. Each step reports whether the text actually changed and whether undo is available —
    # a transformation that clears the undo stack is the defect this project has shipped before.
    "editor-validate": ("/Users/admin/validate.txt",
                        ["!NOT WIRED", "!NO SUCH ITEM", "Trailing comma",
                         "transforms=minify,sortKeys,escapeAsJSONString,unescapeJSONString,jsonToYAML",
                         "Sort Keys", "changed=true", "undo=true",
                         "Minify", "Convert JSON to YAML", "Escape as JSON String"]),
    # The comment must be on the *new* name and gone from the old one — read from the table, which is
    # what the column draws.
    "comment-carry": ("/Users/admin/comment.txt",
                      ["set=true", "beforeRename=carried through the rename",
                       "afterRename=carried through the rename", "oldName=<none>",
                       "renderedCell=carried through the rename"]),
    # The plugin's own field, read out of the host's view tree: the comment set through the host's path
    # has to be what the plugin shows.
    "notes-sidebar-field": ("/Users/admin/sidebar.txt",
                      ["field=a comment from the host side", "!ERROR"]),
    # The umlauts are the point: a UTF-8 read of a UTF-16 file does not produce mangled text, it fails
    # outright, so the field was empty. "!field=" guards exactly that.
    "tc-comment-sidebar": ("/Users/admin/tc-sidebar.txt",
                          ["field=Grüße aus Zürich", "!field= placeholder", "!ERROR"]),
    "notes-sidebar": ("/Users/admin/sidebar-back.txt",
                           ["hostComment=edited in the plugin", "column=edited in the plugin"]),
    # The line number the note was bound to, and the text of that line read out of the document — so the
    # check cannot pass by echoing the note back at itself. "!marksgroup=Notes count=0" guards the way
    # this fails silently: a group that is present but empty.
    "viewer-note-lines": ("/Users/admin/note-lines.txt",
                          ["marksgroup=Notes count=1", "mark line=3", "the annotated line",
                           # …and the panel itself, rendered: the tab's title and the row it drew.
                           "label=Notes", "!No marks.",
                           "!marksgroup=Notes count=0", "!ERROR"]),
    # Line 2 — not line 3, which already has a note, and not line 1, which is where the caret starts and
    # would be right even if the line were never worked out at all.
    "viewer-note-write": ("/Users/admin/note-write.txt",
                          ["window=Note — annotated.txt line 2", "!line 1", "!line 3", "!ERROR"]),
    # Both AI actions, so a menu that lost its plugin entries entirely cannot pass, and the Notes
    # plugin's entry beside them so the check is about the surface and not about one plugin.
    "plugin-context-menu": ("/Users/admin/ctxmenu.txt",
                            ["Suggest a comment", "Suggest a name", "Summarize", "!ERROR"]),
    # The alert must be there, must be the verification one, and must say the file matched. "!did not
    # match" guards the other direction: an alert that fires but reports a mismatch for a good copy would
    # be just as wrong and would still contain the word "verified".
    "bg-copy-verify": ("/Users/admin/verify.txt",
                       ["modal=true", "Verify After Copy", "verified", "!did not match", "!ERROR"]),
    # crlf.json is 300004 lines with Windows endings, and .json above 4 MB opens in the app's own ranged
    # code view. The dump reports what that view thinks its line count is; what matters is that it is
    # not 1: that number *is* the defect, and any plausible
    # correct answer is enormous.
    "viewer-crlf-lines": ("/Users/admin/crlf-lines.txt", ["lines=300004", "!lines=1", "!ERROR"]),
    # One name before, everything in between, that one name again afterwards.
    #
    # "marked=1\n" with the line break, not "marked=1": the checks are substring matches, and "marked=1"
    # is a substring of "marked=10" — which is exactly what the unfixed code produced. The scenario
    # reported "ok" for the broken build until the mutation run showed the number.
    "selection-restore": ("/Users/admin/sel-after.txt",
                          ["marked=1\n", "name=hosts.txt", "!marked=10", "!ERROR"]),
    # The summary has to be *there*: a crash leaves no report at all, which is how the crash announced
    # itself in the first place.
    "viewer-folder": ("/Users/admin/folder-view.txt", ["status=", "Folder", "!ERROR"]),
    # The hit, and the preview saying where the term was: a row whose text is nowhere in the file needs
    # to explain itself.
    "find-comments": ("/Users/admin/found.txt",
                      ["count=1", "table.csv", "comment: superseded by the 2026 export", "!ERROR"]),
    # Read as UTF-16, the multi-line comment as two lines, still UTF-16 after writing, and the untouched
    # comment intact.
    "tc-descript": ("/Users/admin/tc.txt",
                    ["read16=Grüße aus Zürich", "readMulti=erste Zeile⏎zweite Zeile",
                     "bomAfterWrite=FFFE", "kept=erste Zeile⏎zweite Zeile",
                     "written=geändert durch die App"]),
    "editor-lines": ("/Users/admin/lines.txt",
                     ["endings=CRLF", "undo=true", "keep me<CR>",
                      # Four lines in the fixture, and the status line must say four — not "1 line(s)",
                      # which is what splitting CRLF text on "\n" produced.
                      "Sort A→Z — 4 line(s)"]),
}

# What AppKit prints when it gives up on a constraint set. One message spans many lines; the first
# constraint in the list is stable enough to name the offender.
CONFLICT_HEADER = "Unable to simultaneously satisfy constraints"


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def ssh_guest(ip, script):
    return sh(["ssh", *SSH, f"{GUEST}@{ip}", script])


def resolve_app(explicit):
    if explicit:
        return explicit
    r = sh(["xcodebuild", "-project", str(REPO / "PeachCommander.xcodeproj"),
            "-scheme", "PeachCommander", "-configuration", "Debug", "-showBuildSettings"])
    for line in r.stdout.splitlines():
        if "BUILT_PRODUCTS_DIR" in line:
            return str(Path(line.split("=", 1)[1].strip()) / APPNAME)
    sys.exit("could not resolve built .app; pass --app")


def parse_vnc(logfile: Path):
    for _ in range(60):
        if logfile.exists():
            m = re.search(r"vnc://[^\s]*", logfile.read_text(errors="ignore"))
            if m:
                url = m.group(0)[len("vnc://"):]
                pw = url.split(":", 1)[1].split("@", 1)[0]
                hostport = url.split("@", 1)[1]
                host = hostport.split(":", 1)[0]
                port = re.match(r"\d+", hostport.split(":", 1)[1]).group(0)
                return host, port, pw
        time.sleep(1)
    sys.exit("no VNC endpoint in tart log")


def wait_ip(vm, timeout=180):
    for _ in range(timeout // 2):
        r = sh(["tart", "ip", vm])
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
        time.sleep(2)
    sys.exit(f"no IP for {vm}")


def boot(app: str, run: str):
    sh(["tart", "delete", run])
    say(f"cloning {GOLDEN} -> {run}")
    if sh(["tart", "clone", GOLDEN, run]).returncode != 0:
        sys.exit(f"could not clone {GOLDEN} — is the golden VM prepared? See Tools/vm/README.md")
    log = Path(f"/tmp/tart-{run}.log")
    log.unlink(missing_ok=True)
    # `--no-graphics` as well as `--vnc-experimental`: with the VNC flag alone, tart *opens* the vnc://
    # URL, which launches Screen Sharing — and it never closes. One dead window per run accumulates in a
    # single Screen Sharing process, 136 of them by the time anyone looked. The VNC server itself is
    # unaffected: the log line changes from "Opening vnc://…" to "VNC server is running at vnc://…",
    # which `parse_vnc` still matches, and a vncdo capture through it returns the full desktop. Measured
    # both ways before this line was changed.
    subprocess.Popen(["tart", "run", run, "--vnc-experimental", "--no-graphics"],
                     stdout=log.open("w"), stderr=subprocess.STDOUT)
    host, port, pw = parse_vnc(log)
    ip = wait_ip(run)
    for _ in range(60):
        if ssh_guest(ip, "true").returncode == 0:
            break
        time.sleep(2)
    say(f"guest {ip}, VNC {host}:{port}")

    # Build the plugins into the bundle before syncing, the way make-dmg.sh does for a release. A Debug
    # build has no `Contents/PlugIns`, so until now the VM ran an app with *no plugins at all* — every
    # plugin surface in this app was unverified on screen, and a scenario touching one would have passed
    # by doing nothing. About a minute for all fifteen.
    say("building plugins into the bundle…")
    sh([str(REPO / "Tools/build-all-plugins.sh"), str(Path(app) / "Contents/PlugIns")])
    # The bundle must not be rebuilt while it is being copied. Building in another terminal during a run
    # produced an app that launched and then did nothing — no automation at all — and every scenario that
    # writes a report came back empty. That looked exactly like a product defect for half an hour.
    binary = Path(app) / "Contents/MacOS" / Path(app).stem
    before = binary.stat() if binary.exists() else None
    sh(["rsync", "-a", "--delete", "-e", "ssh " + " ".join(SSH),
        app.rstrip("/") + "/", f"{GUEST}@{ip}:pc-test/{APPNAME}/"])
    after = binary.stat() if binary.exists() else None
    if before and after and (before.st_mtime, before.st_size) != (after.st_mtime, after.st_size):
        sys.exit("the app binary changed while it was being copied — something rebuilt it mid-run; "
                 "start the suite again with nothing else touching the build")
    sh(["scp", *SSH, str(Path(__file__).with_name("regress-guest.sh")), f"{GUEST}@{ip}:regress-guest.sh"])
    ssh_guest(ip, "chmod +x regress-guest.sh")
    # Structured fixtures for the outline scenarios (F-368) are files, not printf: YAML and XML are
    # significant-whitespace, quote-heavy formats, and generating them through python → ssh → sh → printf
    # is how the first two attempts at this produced garbage on the guest.
    ssh_guest(ip, "mkdir -p pc-demo")
    for fixture in sorted((Path(__file__).with_name("fixtures")).glob("*")):
        sh(["scp", *SSH, str(fixture), f"{GUEST}@{ip}:pc-demo/{fixture.name}"])
    # An SFTP target for the attribute scenario (F-364): the guest talks to its own sshd, authenticating
    # with a key it generates for itself. Nothing types a password, and the app picks the key up from
    # ~/.ssh/id_ed25519 on its own.
    ssh_guest(ip, "test -f ~/.ssh/id_ed25519 || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519; "
                  "grep -qf ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys 2>/dev/null || "
                  "cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys; "
                  "chmod 600 ~/.ssh/authorized_keys; "
                  "mkdir -p ~/sftp-demo && printf 'x' > ~/sftp-demo/perm.txt && "
                  # A source folder and an empty target for the sync-over-SFTP scenario (F-193).
                  "rm -rf ~/sync-src ~/sync-dst && mkdir -p ~/sync-src ~/sync-dst && "
                  "printf 'one\\n' > ~/sync-src/alpha.txt && "
                  "mkdir -p ~/sync-src/sub && printf 'two\\n' > ~/sync-src/sub/beta.txt && "
                  "chmod 644 ~/sftp-demo/perm.txt; "
                  # 40 KB of known content: more than one 64 KB read would be silly, less than one is
                  # what a single-chunk transfer looks like — enough to tell a tail from a whole file.
                  "python3 -c \"open('$HOME/sftp-demo/big.txt','w').write('peach'*8192)\"; true")
    # A `descript.ion` exactly as Total Commander writes one — UTF-16 LE with a BOM and a multi-line
    # comment using TC's registered 0x04 0xC2 extension (F-374). Copied as *bytes* from the repository:
    # generating it through python -> ssh -> sh ate one escaping layer and produced a real line break where
    # the format wants a literal backslash-n, and the scenario then blamed the parser for it.
    ssh_guest(ip, "mkdir -p pc-tc && printf x > pc-tc/tc-utf16.txt && printf x > pc-tc/tc-multi.txt")
    sh(["scp", *SSH, str(Path(__file__).with_name("fixtures-tc") / "descript.ion"),
        f"{GUEST}@{ip}:pc-tc/descript.ion"])
    # A second, untouched copy. `tc-descript` *writes* a comment into pc-tc to prove the round trip, so a
    # later scenario reading the original text out of that folder gets whatever that one left behind —
    # which is how `tc-comment-sidebar` passed alone and failed in the full suite.
    ssh_guest(ip, "mkdir -p pc-tc-ro && printf x > pc-tc-ro/tc-utf16.txt && printf x > pc-tc-ro/tc-multi.txt")
    sh(["scp", *SSH, str(Path(__file__).with_name("fixtures-tc") / "descript.ion"),
        f"{GUEST}@{ip}:pc-tc-ro/descript.ion"])
    # A listening witness for the viewer's network block (F-116), plus a document that tries to reach it.
    # The self-test request is what makes a later "no hit" mean anything: without it, a dead server and a
    # working block produce the same empty log, and the scenario passes hardest when it proves least.
    sh(["scp", *SSH, str(Path(__file__).with_name("beacon-server.py")), f"{GUEST}@{ip}:beacon-server.py"])
    ssh_guest(ip, "rm -f ~/beacon-hits.log; pkill -f beacon-server.py; "
                  "nohup python3 ~/beacon-server.py >/dev/null 2>&1 & sleep 2; "
                  "curl -s -o /dev/null http://127.0.0.1:8731/selftest.png; "
                  # Its own folder: a file added to pc-demo would change what every other scenario's
                  # screenshot shows, and those are compared against a baseline.
                  "mkdir -p pc-beacon && printf '# beacon\\n\\n"
                  "![tracker](http://127.0.0.1:8731/viewer.png)\\n' > pc-beacon/beacon.md")
    # Two folders that differ, for the Compare Directories scenario: one file only on the left, one only
    # on the right, one in a subfolder on both, and one that differs in content but not in name.
    ssh_guest(ip, "rm -rf pc-cmp && mkdir -p pc-cmp/a/sub pc-cmp/b/sub && "
                  "printf 'same\\n' > pc-cmp/a/both.txt && printf 'same\\n' > pc-cmp/b/both.txt && "
                  "printf 'x\\n' > pc-cmp/a/only-left.txt && printf 'y\\n' > pc-cmp/b/only-right.txt && "
                  "printf 'deep\\n' > pc-cmp/a/sub/nested.txt")
    # A large text file for the viewer's memory scenario (F-112). Big enough that materialising it is
    # visible in the process's resident size — the point of the virtual view is that it is not.
    ssh_guest(ip, "python3 -c \"import pathlib;"
                  "line=(b'the quick brown fox jumps over the lazy dog '*2+b'\\n');"
                  "f=open('$HOME/pc-big.txt','wb');"
                  "[f.write(line) for _ in range(2000000)]; f.close()\"")
    # A binary file for the viewer's text mode (Viewer). Uniformly distributed bytes on purpose: that
    # is 3.5 % control bytes, *under* the heuristic's 5 % threshold, so it is the case the byte counting
    # alone lets through — the decode check is what has to catch it.
    ssh_guest(ip, "python3 -c \"import pathlib; pathlib.Path('$HOME/pc-demo-bin.dat')"
                  ".write_bytes(bytes((i*7919+13)%256 for i in range(900000)))\"")
    # A crafted archive for the traversal scenario (F-131): a member stored as "../escaped.txt". Built
    # with python's zipfile, which writes the name through unchanged — the app's own ZipWriter would do
    # too, but a fixture made by the thing under test proves less. It gets its own tree, with the
    # destination one level down, so the file has somewhere to escape *to* that still belongs to this
    # scenario and cannot be confused with litter from an earlier run.
    ssh_guest(ip, "rm -rf pc-slip && mkdir -p pc-slip/target && python3 -c \""
                  "import zipfile; z=zipfile.ZipFile('$HOME/pc-slip/evil.zip','w'); "
                  "z.writestr('harmless.txt','fine'); "
                  "z.writestr('../escaped.txt','should never land here'); z.close()\"")
    # A small, fixed demo tree: the scenarios need something to show, and it must not vary between
    # runs or the screenshots become impossible to compare.
    ssh_guest(ip, "mkdir -p pc-cfg pc-demo/sub && "
                  "printf 'notes, for the viewer scenario\\n' > pc-demo/notes.txt && "
                  "printf 'a,b\\n1,2\\n' > pc-demo/table.csv && "
                  # Unsorted, with a duplicate: `sort -u` over it has a visible, checkable result.
                  "printf 'beta.example\\nalpha.example\\nbeta.example\\n' > pc-demo/hosts.txt && "
                  # CRLF, a duplicate, a blank line and trailing spaces: one file for every operation.
                  "printf 'keep me  \\r\\n\\r\\nkeep me\\r\\ndrop this\\r\\n' > pc-demo/messy.txt && "
                  "printf 'x' > pc-demo/sub/nested.txt && "
                  # A name with a space and an apostrophe, for the terminal's drop quoting: a naive
                  # implementation turns this one file into three arguments.
                  "printf 'dropped\\n' > \"pc-demo/it's a file.txt\" && "
                  # A JSON file with Windows line endings, deliberately over 4 MB: below that the code
                  # view is an NSTextView, which AppKit lines up correctly, and only above it does the
                  # app's own ranged view take over. That one built its ranges by comparing each
                  # Character against "\\n" — and a CRLF is one Character equal to neither — so a file
                  # like this rendered as a single line, with go-to-line and the marks panel addressing
                  # nothing (F-110). Generated in the guest — 6 MiB, comfortably past the 4 MiB threshold;
                  # a first attempt at 4.0 MB was *below* it and quietly tested the AppKit path instead.
                  "python3 -c \"open('pc-demo/crlf.json','w',newline='').write("
                  "'{\\\\r\\\\n' + ''.join('  \\\\\"k%d\\\\\": %d,\\\\r\\\\n' % (i, i) "
                  "for i in range(300000)) + '  \\\\\"last\\\\\": 0\\\\r\\\\n}\\\\r\\\\n')\" && "
                  # A file with enough lines that "line 3" is a distinguishable place, and a note bound
                  # to it seeded straight into the plugin's store (F-379). Seeded rather than typed:
                  # the note editor is a plugin window, and the scenario is about whether the *viewer*
                  # finds an existing annotation, not about typing into a text field.
                  "printf 'first line\\nsecond line\\nthe annotated line\\nfourth line\\n' "
                  "> pc-demo/annotated.txt && "
                  "mkdir -p ~/\"Library/Application Support/PeachCommander/notes\" && "
                  "printf 'a note about the third line\\n' "
                  "> ~/\"Library/Application Support/PeachCommander/notes/f379.md\" && "
                  "printf '{\"notes\":[{\"key\":\"/Users/admin/pc-demo/annotated.txt#L3\",\"file\":\"f379.md\","
                  "\"title\":\"a note about the third line\",\"updated\":1}]}' "
                  "> ~/\"Library/Application Support/PeachCommander/notes/index.json\" && "
                  "printf '[Colors]\\nAppearance=dark\\n[Operation]\\nVerifyAfterCopy=1\\n' > pc-cfg/peachcmd.ini && "
                  "defaults write com.apple.dock autohide -bool true; killall Dock 2>/dev/null; "
                  "defaults write -g AppleLanguages '(\"en-US\", \"en\")'; "
                  "killall cfprefsd 2>/dev/null; true")

    # The OSC 7 hook the terminal's settings page tells the user to add by hand — set up here because
    # the app must never write it, which is the whole point of that setting. Harmless for every other
    # scenario: acting on it is off by default.
    #
    # In a here-document of its own rather than inside the chain above. The first attempt wove it into
    # that `printf ... && printf ...` string and it never arrived; an external check asking the guest
    # directly said `0`, which is how the terminal came to be "not following" a shell that had never
    # been asked to speak. Escapes surviving python → ssh → sh → zsh is a bet this harness has lost
    # before; a quoted here-document takes the bet off the table.
    # An alias that only an interactive shell would ever see, so a scenario can prove the assistant's
    # command line is not silently rewritten by the user's dotfiles.
    ssh_guest(ip, "printf 'alias pcalias=\\'echo ALIAS-RAN\\'\\n' >> ~/.zshrc")
    ssh_guest(ip, "cat >> ~/.zshrc <<'PCZSHRC'\n"
                  "autoload -Uz add-zsh-hook\n"
                  "_pc_osc7() { printf '\\033]7;file://%s%s\\007' \"$HOST\" \"${PWD// /%20}\" }\n"
                  "add-zsh-hook precmd _pc_osc7\n"
                  "PCZSHRC")
    return ip, host, port, pw


def run_scenario(ip, host, port, pw, name, script, settle, out: Path):
    body = "\n".join(script)
    ssh_guest(ip, f"cat > ~/auto.txt <<'PCEOF'\n{body}\nPCEOF")
    # Fresh session state per scenario: a persisted panel directory or view mode from the previous one
    # would make this scenario show something else entirely. (Learned the hard way — twice.)
    # The guest-side half is a script, not an ssh one-liner: the log predicate carries quotes at three
    # levels and passing it inline produced an empty capture that read as "no conflicts".
    # Hand the guest the report this scenario writes, so it waits for the file instead of trusting a
    # fixed sleep. Without it, a slow launch late in the suite produced an empty report and every
    # expectation was reported as wrong — three times, for three different scenarios.
    expect = REPORTS.get(name, (None, None))[0] or ""
    # Clear old crash reports first, so whatever is there afterwards belongs to this scenario.
    ssh_guest(ip, "rm -f ~/Library/Logs/DiagnosticReports/PeachCommander*.ips; true")
    text = ssh_guest(ip, f"./regress-guest.sh {name} {settle} {expect}").stdout
    shot = out / f"{name}.png"
    sh([VNCDO, "-s", f"{host}::{port}", "-p", pw, "capture", str(shot)])
    log, _, a11y = text.partition("===A11Y===")
    (out / f"{name}.log").write_text(log)
    if a11y.strip():
        (out / f"{name}-a11y.txt").write_text(a11y.strip() + "\n")
    # A crash used to leave nothing behind but an empty report and a screenshot of the desktop, and
    # the report that says *why* was deleted with the VM clone at the end of the run. Fetching it
    # costs one ssh call and is the difference between reading the answer and guessing at it.
    crash = ssh_guest(ip, "cat ~/Library/Logs/DiagnosticReports/PeachCommander*.ips 2>/dev/null; true").stdout
    if crash.strip():
        (out / f"{name}-crash.ips").write_text(crash)
        say(f"{name}: CRASHED — report saved to {name}-crash.ips")
    ssh_guest(ip, "pkill -x PeachCommander; true")
    return conflicts(log), a11y


def conflicts(log_text: str):
    """The app's own view classes named in each conflict message, in order.

    Naming them rather than only counting: a number that changes says nothing about which view
    regressed, and the whole point is to be able to fix them one at a time. Only classes with the
    app's module prefix are reported — every conflict also mentions AppKit's own controls, and those
    are the symptom rather than the cause.
    """
    out = []
    lines = log_text.splitlines()
    for i, line in enumerate(lines):
        if CONFLICT_HEADER not in line:
            continue
        involved = []
        for candidate in lines[i:i + 14]:
            if CONFLICT_HEADER in candidate and candidate is not lines[i]:
                break
            involved += re.findall(r"PeachCommander\.(\w+):0x", candidate)
        out.append(sorted(set(involved))[0] if involved else "unknown")
    return out


def say(msg):
    print(f"\033[1;36m[regress]\033[0m {msg}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app")
    ap.add_argument("--out", default=str(REPO / "docs/generated/layout-regression"))
    ap.add_argument("--keep", action="store_true", help="leave the clone running")
    ap.add_argument("--update-baseline", action="store_true",
                    help="write the measured counts as the new baseline")
    ap.add_argument("--only", help="run only these scenarios (comma-separated, kept in file order). A "
                                   "list, because the defects that need a *sequence* are exactly the ones "
                                   "a single scenario cannot show — settings persist in the guest's "
                                   "peachcmd.ini between scenarios — and reproducing one otherwise means "
                                   "waiting for the whole suite")
    args = ap.parse_args()

    app = resolve_app(args.app)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    run = "pc-regress"
    ip, host, port, pw = boot(app, run)

    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    measured, failures = {}, []
    try:
        for name, script, settle in SCENARIOS:
            if args.only and name not in [s.strip() for s in args.only.split(",")]:
                continue
            found, a11y = run_scenario(ip, host, port, pw, name, script, settle, out)
            measured[name] = found
            for name_ in KEYBOARD_REPORTS.get(name, []):
                text = ssh_guest(ip, f"cat /Users/admin/{name_} 2>/dev/null").stdout
                (out / name_).write_text(text)
                if name_ not in KEYBOARD_GATES:
                    say(f"{name}: {name_} ({len(text.splitlines())} lines)")
                    continue
                if not text.strip():
                    failures.append(f"{name}: {name_} is empty")
                    say(f"{name}: {name_} EMPTY — the window never wrote it")
                    continue
                problems = []
                fields = dict(l.split(": ", 1) for l in text.splitlines() if ": " in l)
                if fields.get("loopClosed") != "true":
                    problems.append("the key-view loop is not closed")
                for key in ("unreachable", "unlabelled"):
                    if fields.get(key, "0") != "0":
                        problems.append(f"{fields[key]} {key}")
                missing = [w for w in KEYBOARD_GATES[name_] if w not in text]
                if missing:
                    problems.append("labels missing: " + ", ".join(missing))
                if problems:
                    failures.append(f"{name}: {name_}: " + "; ".join(problems))
                    say(f"{name}: KEYBOARD PROBLEM — " + "; ".join(problems))
                else:
                    stops = len([l for l in text.splitlines() if "tab[" in l])
                    say(f"{name}: keyboard ok ({stops} stops, all reachable and labelled)")
            if name in EXTERNAL_CHECKS:
                command, expected = EXTERNAL_CHECKS[name]
                actual = ssh_guest(ip, command).stdout.strip()
                (out / f"{name}-external.txt").write_text(f"{command}\n{actual}\n")
                if actual != expected:
                    failures.append(f"{name}: {command} says {actual!r}, expected {expected!r}")
                    say(f"{name}: EXTERNAL CHECK FAILED — {command} says {actual!r}, "
                        f"expected {expected!r}")
                else:
                    say(f"{name}: external check ok ({command} → {actual})")
            # A scenario may leave more than one report; `<name>-<suffix>` entries belong to it too.
            for key in [name] + [k for k in REPORTS if k.startswith(name + "-")]:
                if key not in REPORTS:
                    continue
                path, expected = REPORTS[key]
                report = ssh_guest(ip, f"cat {path} 2>/dev/null").stdout
                (out / f"{key}-report.txt").write_text(report)
                # An empty report is a different failure from a wrong one: the app did not get that far.
                # Reporting it as "every expectation is wrong" sent me looking at the wrong code twice.
                if not report.strip():
                    failures.append(f"{key}: report EMPTY — {path} was never written "
                                    f"(the app may not have finished; see {key}.log)")
                    say(f"{key}: REPORT EMPTY — {path} was never written")
                    continue
                # "!x" means x must NOT be there — otherwise the check could pass for the wrong reason.
                wrong = [e for e in expected
                         if (e[1:] in report) if e.startswith("!")] + \
                        [e for e in expected if not e.startswith("!") and e not in report]
                if wrong:
                    failures.append(f"{key}: report wrong about {wrong!r}")
                    say(f"{key}: REPORT WRONG about {wrong!r}")
                else:
                    say(f"{key}: report ok ({report.splitlines()[0] if report else 'empty'})")
            if a11y.strip():
                missing = [label for label in REQUIRED_A11Y if label not in a11y]
                if missing:
                    failures.append(f"{name}: accessibility labels missing: {', '.join(missing)}")
                    say(f"{name}: MISSING accessibility labels: {', '.join(missing)}")
                else:
                    rows = len([l for l in a11y.splitlines() if l.strip()])
                    say(f"{name}: accessibility tree has {rows} rows, all required labels present")
            allowed = baseline.get(name, {}).get("count")
            state = f"{len(found)} conflict(s)"
            if allowed is not None and len(found) > allowed:
                failures.append(f"{name}: {len(found)} conflicts, baseline {allowed}")
                state += f" — OVER baseline {allowed}"
            elif allowed is not None and len(found) < allowed:
                state += f" — better than baseline {allowed}"
            say(f"{name}: {state}")
    finally:
        if not args.keep:
            sh(["tart", "stop", run])
            sh(["tart", "delete", run])

    if (out / "menu.txt").exists():
        audit = sh([sys.executable, str(REPO / "Tools/check-hotkeys.py"),
                    "--menu", str(out / "menu.txt"),
                    "--window-menu", str(out / "menu-editor.txt")])
        for line in audit.stdout.strip().splitlines():
            say("hotkeys: " + line.strip())
        if audit.returncode != 0:
            failures.append("hotkeys: the shortcut audit found problems (see above)")

    report = ["# Layout regression report", "",
              "Generated by `Tools/vm/regress.py`. Counts are Auto Layout conflicts AppKit reported",
              "while the view was on screen; the baseline in `docs/metadata/layout-baseline.json` may",
              "only go down.", "",
              "| View | Conflicts | Baseline | Views involved | Screenshot |",
              "| --- | --- | --- | --- | --- |"]
    for name, found in measured.items():
        allowed = baseline.get(name, {}).get("count", "—")
        involved = ", ".join(sorted(set(found))) or "—"
        report.append(f"| {name} | {len(found)} | {allowed} | {involved} | `{name}.png` |")
    (out / "report.md").write_text("\n".join(report) + "\n")
    say(f"report: {out / 'report.md'}")

    if args.update_baseline:
        BASELINE.write_text(json.dumps(
            {name: {"count": len(found), "views": sorted(set(found))}
             for name, found in measured.items()}, indent=2) + "\n")
        say(f"baseline written: {BASELINE}")
        return 0

    if failures:
        for f in failures:
            print(f"FAIL {f}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
