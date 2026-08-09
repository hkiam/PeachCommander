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
                   "dock on", "wait 900", "dockdump /Users/admin/dock-open.txt", "wait 300",
                   "dock off", "wait 900", "dockdump /Users/admin/dock-shut.txt", "wait 300",
                   "dock on", "wait 900"], 9),
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
                       "mountdump /Users/admin/mounts-after.txt", "wait 400"], 9),
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
                        "mountdump /Users/admin/placed-back.txt", "wait 400"], 9),
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
                   "a11ydump /Users/admin/a11y-main.txt", "wait 500"], 10),
    ("keys-find", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "findtab 0", "wait 1500", "keyloop /Users/admin/keyloop-find.txt",
                   "a11ydump /Users/admin/a11y-find.txt", "wait 500"], 11),
    ("keys-settings", ["active left", "left /Users/admin", "wait 1000",
                       "settingspage Layout", "wait 2500",
                       "keyloop /Users/admin/keyloop-settings.txt",
                       "a11ydump /Users/admin/a11y-settings.txt", "wait 500"], 11),
    ("keys-editor", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "editfilterdlg /Users/admin/pc-demo/notes.txt", "wait 1500",
                     "keyloop /Users/admin/keyloop-editor.txt",
                     "a11ydump /Users/admin/a11y-editor.txt", "wait 500"], 11),
    ("keys-viewer", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "focus notes.txt", "wait 400", "cmd cm_List", "wait 2000",
                     "keyloop /Users/admin/keyloop-viewer.txt",
                     "a11ydump /Users/admin/a11y-viewer.txt", "wait 500"], 11),
    # A structured file, not notes.txt: the editor builds its Structure menu only for JSON/YAML/XML, and
    # those seven shortcuts were unchecked by the hotkey gate until this dump existed.
    ("keys-editorwin", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "editdump /Users/admin/pc-demo/stack.yml /Users/admin/ed.txt", "wait 1800",
                        "keyloop /Users/admin/keyloop-editorwin.txt",
                        "a11ydump /Users/admin/a11y-editorwin.txt",
                        "menudump /Users/admin/menu-editor.txt", "wait 500"], 11),
    ("keys-hotlist", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "hotlistmanage", "wait 1500",
                      "keyloop /Users/admin/keyloop-hotlist.txt",
                      "a11ydump /Users/admin/a11y-hotlist.txt", "wait 500"], 11),
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
    "dock-seam": ("/Users/admin/dock-open.txt",
                  ["visible=true", "stacked=yes", "No plugin provides a view here.",
                   "!height=0"]),
    "dock-seam-shut": ("/Users/admin/dock-shut.txt",
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
    "view-placement": ("/Users/admin/placed.txt",
                       ["plugin.notes.sidebar container=bottom built=true made=1 closed=0"]),
    # …and the dock really shows it, rather than the registry merely believing it does.
    "view-placement-dock": ("/Users/admin/placed-dock.txt",
                            ["panels=plugin.notes.sidebar", "selected=plugin.notes.sidebar"]),
    "view-placement-back": ("/Users/admin/placed-back.txt",
                            ["plugin.notes.sidebar container=sidebar built=true made=1 closed=0"]),
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
    "viewer-large-memory": ("/Users/admin/bigmem.txt", ["mode=text", "view=TextListerView"]),
    # Measured on the host: 139 MB idle, 257 MB with the fix, 434 MB without — the difference being the
    # file decoded into a String the outline then refused for being too long. The verdict's threshold
    # (350 MB) sits between the two with room for the guest to differ.
    "viewer-large-memory-rss": ("/Users/admin/bigmem-rss.txt", ["lean=yes"]),
    # The left panel marks what the right one does not have, or has differently. `both.txt` is identical
    # on both sides and must stay unmarked — otherwise "marked everything" would pass.
    "compare-dirs": ("/Users/admin/compare.txt", ["name=only-left.txt", "name=sub", "!name=both.txt"]),
    "shared-tree": ("/Users/admin/tree-active.txt", ["path=/Users/admin/pc-demo/sub\n"]),
    # …and the panel that was not active did not move. Without this the scenario would pass if the tree
    # navigated both, which is precisely the thing to get wrong.
    "shared-tree-other": ("/Users/admin/tree-other.txt", ["path=/Users/admin/pc-demo\n"]),
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
    "notes-sidebar": ("/Users/admin/sidebar.txt",
                      ["field=a comment from the host side", "!ERROR"]),
    # The umlauts are the point: a UTF-8 read of a UTF-16 file does not produce mangled text, it fails
    # outright, so the field was empty. "!field=" guards exactly that.
    "tc-comment-sidebar": ("/Users/admin/tc-sidebar.txt",
                          ["field=Grüße aus Zürich", "!field= placeholder", "!ERROR"]),
    "notes-sidebar-back": ("/Users/admin/sidebar-back.txt",
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
    text = ssh_guest(ip, f"./regress-guest.sh {name} {settle} {expect}").stdout
    shot = out / f"{name}.png"
    sh([VNCDO, "-s", f"{host}::{port}", "-p", pw, "capture", str(shot)])
    log, _, a11y = text.partition("===A11Y===")
    (out / f"{name}.log").write_text(log)
    if a11y.strip():
        (out / f"{name}-a11y.txt").write_text(a11y.strip() + "\n")
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
