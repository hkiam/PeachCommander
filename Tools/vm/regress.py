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
    # Switching the side panel's built-in pages on and off (F-476). Four claims, and the second is the
    # one the feature exists for: with Log showing, switching *Info* off must leave Log showing. The
    # panel used to read its page straight out of `selectedSegment`, so removing a page in front of the
    # selected one silently handed the user a different page under the right label.
    #
    # **Activities is switched on for that step on purpose, and it is the difference between a test and
    # a coincidence.** With only Info and Log on, removing Info makes Log the *first* tab — so a build
    # that had lost the selection entirely and fell back to "the first tab" would answer "Log" too and
    # the assertion could not fail. Three pages on puts Log at index 2 with Activities in front of it,
    # so falling back answers Activities and keeping the identity answers Log. (Found by running the
    # weaker version locally and noticing that `previewtab` had not even matched.)
    #
    # The middle of the script toggles with the panel *closed*, because a collapsed panel is `width == 0`
    # and that is the state this file has produced seven Auto Layout conflicts in before. Plugin tabs are
    # asserted only through `pages=`, which lists built-ins: the VM's plugin set is not this scenario's
    # subject, and every built-in being off with the plugin tabs still there is the point of `-empty`.
    # Macros (F-478). Four dialogs and a window that unit tests cannot see, all of them modal or
    # near enough — see SCENARIO_ENV for why each one must carry its environment or hang the run.
    #
    # Every scenario seeds `macros.json` the way a user does, through `cm_MacroEditor`, so the eight
    # shipped examples are what is being exercised rather than a fixture that could drift from them.
    # The editor window it opens is closed again before anything is measured.

    # The gate, and the rows a person actually reads. `clean-temp` is the deleting example, so this
    # also asserts that a macro is held to the most demanding thing in it: it is *proposed*, not run.
    # Nothing is selected, so the second row stands in for what the first step will select — the one
    # phrase in the set that is built out of another phrase.
    ("macro-confirm", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "cmd cm_MacroEditor", "wait 1500", "closeeditor", "wait 800",
                       "cmd mc_clean-temp", "wait 2500"], 10),
    # Asking happens before the plan is built, and the answer is in the plan. Two reports, because
    # those are two claims: that the question was put, and that what was typed reached the rows.
    ("macro-ask", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "cmd cm_MacroEditor", "wait 1500", "closeeditor", "wait 800",
                   "cmd mc_file-into-named-folder", "wait 2500"], 10),
    # Both records the recorder reads. The copy goes through the Automation Core, so it lands in the
    # audit log; the panel half is covered by unit tests, since no verb drives an F5.
    ("macro-record",
     ["probe /Users/admin/macro-made.txt|mkdir -p /Users/admin/macro-src /Users/admin/macro-dst "
      "&& echo payload > /Users/admin/macro-src/data.txt && echo made", "wait 600",
      "active left", "left /Users/admin/macro-src", "wait 1200",
      # Through the Core, so it lands in the audit log — which is the source this scenario is about.
      # The destination has to exist: a `move`/`copy` to a folder that is not there is refused now,
      # and the refusal would be recorded as a failed action the recorder then greys out.
      "aitool copy:confirm|{\"sources\":[\"/Users/admin/macro-src/data.txt\"],"
      "\"destination\":\"/Users/admin/macro-dst\"}|/Users/admin/macro-copy.json", "wait 1500",
      "cmd cm_MacroFromRecentActions", "wait 2500"], 10),
    # The manager: a list with buttons, and the one window here whose layout was wrong while AppKit
    # reported nothing — a stack view lays its buttons out past its own trailing edge without ever
    # producing a conflict, so the count this suite leans on could not see it.
    #
    # Its own dump rather than `a11ydump`, for two reasons found by trying that first: the tree came
    # back holding the table and nothing else (the stack views contribute no accessible children until
    # a client attaches), and a tree cannot report a *measurement*. `toolbar-fits` is the measurement,
    # and it was verified by putting the defect back: 620 wide against a 683-wide toolbar, `NO`, and
    # zero conflicts.
    ("macro-manager", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "cmd cm_MacroEditor", "wait 1500", "closeeditor", "wait 800",
                       "cmd cm_MacroManager", "wait 2000",
                       "macromanagerdump /Users/admin/macro-manager.txt", "wait 800"], 10),
    ("side-panel-tabs", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "previewpanel on", "wait 1200",
                         "previewtabsdump /Users/admin/side-tabs-default.txt", "wait 300",
                         "setbool Layout.PreviewTabActivities|1", "wait 700",
                         "setbool Layout.PreviewTabLog|1", "wait 700",
                         "previewtab Log", "wait 700",
                         "setbool Layout.PreviewTabInfo|0", "wait 800",
                         "previewtabsdump /Users/admin/side-tabs-selection.txt", "wait 300",
                         "previewpanel off", "wait 600",
                         "setbool Layout.PreviewTabActivities|0", "wait 700",
                         "setbool Layout.PreviewTabLog|0", "wait 700",
                         "previewpanel on", "wait 800",
                         "previewtabsdump /Users/admin/side-tabs-empty.txt", "wait 300",
                         "cmd cm_SidePanelInfo", "wait 800",
                         "previewtab Info", "wait 600",
                         "previewtabsdump /Users/admin/side-tabs.txt", "wait 400"], 22),
    ("find-files", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "findtab 0", "wait 2000"], 10),
    ("settings", ["active left", "left /Users/admin", "wait 1000",
                  "settingspage Layout", "wait 2500"], 10),
    ("viewer-text", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "focus notes.txt", "wait 500", "cmd cm_List", "wait 2000"], 10),
    # Who owns a *bare* keystroke: the menu bar, or what the person is typing into. The keymap binds
    # `DELETE=cm_Delete` and `KeymapMenu.apply` puts it on File ▸ Delete as a modifier-less accelerator,
    # which AppKit matches app-wide before any window sees the key — so Del in the Find dialog's text
    # field asked to move the panel's file to the Trash. Both halves are checked: the keys that must stop
    # leaking (Del in a dialog, Del in the command line, F5 in a dialog) and the ones that must not
    # change (a function key inside the file manager, a ⌘ chord anywhere, and Del on a focused panel —
    # which is the command doing its job, caught as a modal and aborted so nothing is deleted).
    #
    # The panel step comes first, while the file manager is still the only window there is: the Find
    # dialog has no "close" verb, and a check that needs the main window to be key cannot run behind it.
    ("menu-key-guard", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "focus notes.txt", "wait 700",
                        "keysend DELETE|asis+menu|/Users/admin/mk-panel-del.txt",
                        "modaldump /Users/admin/mk-panel-modal.txt", "wait 3000",
                        "focuscmdline", "wait 700",
                        "keysend DELETE|asis+menu|/Users/admin/mk-cmdline-del.txt", "wait 500",
                        "keysend F2|asis+menu|/Users/admin/mk-cmdline-f2.txt", "wait 700",
                        "findtab 0", "wait 2000",
                        "keysend DELETE|field+menu|/Users/admin/mk-find-del.txt", "wait 500",
                        "keysend DELETE|field|/Users/admin/mk-find-typed.txt", "wait 500",
                        "keysend F5|field+menu|/Users/admin/mk-find-f5.txt", "wait 500",
                        "keysend W+a|field+menu|/Users/admin/mk-find-cmda.txt", "wait 700"], 10),
    # A Total Commander menu file, as TC actually writes one: Windows-1252 bytes and CRLF
    # line endings (F-257). Both halves were broken and neither could be seen from outside —
    # the file was read as strict UTF-8, so it decoded to nothing and the app fell back to the
    # built-in menu, and `split(separator: "\n")` does not split a CRLF file in Swift at all.
    # `printf` writes the bytes, so the encoding comes from the guest's shell and not from this
    # file. Then: the em_ entry must actually run its program (it used to be dispatched to the
    # cm_ registry, which logged "Unknown command" and did nothing — and em_ is the only way a
    # %P parameter reaches a menu entry), a numeric TC id this app has no command for must be
    # greyed out rather than enabled-and-dead, and deleting the file must bring the built-in
    # menu back. The last one is also this scenario's cleanup: a menu file left in ~/pc-cfg
    # would replace the menu bar for every scenario after it.
    ("menu-file", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                   "probe /Users/admin/menu-file-seed.txt|"
                   "printf '[em_Marke]\\r\\ncmd=/usr/bin/touch\\r\\n"
                   "param=%%P/menu-file-marker.txt\\r\\nmenu=Marke\\r\\n' > ~/pc-cfg/usercmd.ini && "
                   "printf 'POPUP \\042\\046Pr\\374fung\\042\\r\\n"
                   "\\tMENUITEM \\042Marke setzen\\042, em_Marke\\r\\n"
                   "\\tMENUITEM \\042Unbekannt\\042, 2400\\r\\nEND_POPUP\\r\\n' "
                   "> ~/pc-cfg/default.mnu && wc -c < ~/pc-cfg/default.mnu",
                   "wait 800", "reloadmenu", "wait 1500",
                   "menudump /Users/admin/menu-file-dump.txt", "wait 400",
                   # 2.5s, not 1.5: running the em_ command is asynchronous (panel state off the
                   # main actor, then a shell), and on a machine loaded by the rest of the suite the
                   # program had not run yet when the app was stopped — measured once, locally.
                   "menuclick em_Marke|/Users/admin/menu-file-click.txt", "wait 2500",
                   "probe /Users/admin/menu-file-clean.log|"
                   "rm -f ~/pc-cfg/default.mnu ~/pc-cfg/usercmd.ini && echo removed",
                   "wait 600", "reloadmenu", "wait 1500",
                   "menudump /Users/admin/menu-file-restored.txt", "wait 500"], 12),
    # Esc closing the viewer once the reader has clicked something. It only worked while the container
    # view held the focus, and the text area, the symbol filter and the native find bar each keep the
    # key — so Esc stopped closing the window as soon as anyone touched the content, which is the state
    # a viewer is normally in. The report names the focused responder because a check that Esc closed a
    # window nobody had clicked into proves nothing. The find bar is the exception that must survive:
    # there the first Esc dismisses the bar and the window stays, and the second one closes it.
    ("viewer-esc", ["view /Users/admin/pc-demo/notes.txt", "wait 1800",
                    "listeresc text|/Users/admin/esc-text.txt", "wait 700",
                    "view /Users/admin/pc-demo/notes.txt", "wait 1800",
                    "listeresc filter|/Users/admin/esc-filter.txt", "wait 700",
                    "view /Users/admin/pc-demo/notes.txt", "wait 1800",
                    "listeresc filtertext|/Users/admin/esc-typed.txt", "wait 700",
                    "listeresc filter|/Users/admin/esc-typed2.txt", "wait 700",
                    "view /Users/admin/pc-demo/notes.txt", "wait 1800",
                    "listeresc findbar|/Users/admin/esc-find.txt", "wait 700",
                    "listeresc text|/Users/admin/esc-find2.txt", "wait 700"], 10),
    # The symbol sidebar for a language with no grammar (F-405). Swift had none — the app's own language —
    # and the toggle was dead, which looks exactly like "this file has no symbols". `editdump` reads the
    # rows actually rendered into the live outline and `listerdump` reports whether the viewer's button can
    # be pressed at all, which is the half a screenshot cannot show.
    ("swift-outline", ["editdump /Users/admin/pc-demo/outline.swift /Users/admin/swift-outline.txt",
                       "wait 2500",
                       "view /Users/admin/pc-demo/outline.swift", "wait 2200",
                       "listerdump /Users/admin/swift-viewer.txt", "wait 500"], 10),
    # And a second scanner language, to catch a table that lost an entry: Go's receiver form is the one
    # rule whose absence turns a method's name into its receiver.
    ("go-outline", ["editdump /Users/admin/pc-demo/outline.go /Users/admin/go-outline.txt",
                    "wait 2500"], 10),
    # Markdown headings and the HTML element tree, the two outlines whose sources are not declarations.
    # Both fixtures carry the case that breaks them: a fenced shell block full of `#` lines, and a page
    # written with void elements and paragraphs that never close.
    ("markdown-outline", ["editdump /Users/admin/pc-demo/outline.md /Users/admin/md-outline.txt",
                          "wait 2500"], 10),
    # A Mac with no developer toolchain, which is what the guest is (Tools/vm/README.md: the app is built
    # on the host, "no Xcode needed in the guest"). `/usr/bin/git` there is the Command Line Tools *shim*:
    # running it opens the installer. The Git plugin used to invoke that path from a **column value**, so
    # scrolling through a folder could put an installer dialog on screen (F-415). The folder below even
    # looks like a repository — it has a `.git` directory — and the plugin must still stay quiet: an empty
    # column and no modal window. `modal=false` is the assertion that matters; the probe records what the
    # guest's git situation actually is, so the report says why rather than only that.
    ("git-no-toolchain", ["probe /Users/admin/git-env.txt|"
                          "{ /usr/bin/xcode-select -p 2>&1 | head -1; "
                          "ls /Library/Developer/CommandLineTools/usr/bin/git 2>&1 | head -1; } && "
                          "mkdir -p ~/pc-gitfake/.git && printf x > ~/pc-gitfake/file.txt && "
                          "ls ~/pc-gitfake",
                          "wait 700",
                          "active left", "left /Users/admin/pc-gitfake", "wait 1300",
                          "column git_status", "wait 1500",
                          "focus file.txt", "wait 600",
                          "rowdump /Users/admin/git-row.txt", "wait 500",
                          "modaldump /Users/admin/git-modal.txt", "wait 2500",
                          "panelsdump /Users/admin/git-no-toolchain.txt", "wait 500"], 13),
    # Formatting a file with very long lines used to freeze the window (F-414). The mapping from character
    # index to UTF-16 offset in the code view's drawing path was quadratic in the line length — asked once
    # per syntax token — so a 2 MB JSON Lines log with thirty ~68,000-character records needed 193,934 ms to
    # build thirty lines, against 126 ms after the fix. The report carries a *word* rather than the number,
    # because an expectation cannot compare numbers and the number varies with the machine; the threshold
    # (3 s for thirty lines) sits a hundredfold below the defect and a twentyfold above the fix.
    ("viewer-long-lines", ["probe /Users/admin/longline-seed.txt|mkdir -p ~/pc-longline && "
                           "python3 -c \"import json,io;"
                           "rec=lambda i:json.dumps([{'i':i,'blob':[{'k%d'%j:'v'*40} for j in range(600)]}]);"
                           "open('/Users/admin/pc-longline/big.jsonl','w')"
                           ".write(''.join(rec(i)+chr(10) for i in range(30)))\" && "
                           "wc -c < ~/pc-longline/big.jsonl",
                           "wait 900",
                           "view /Users/admin/pc-longline/big.jsonl", "wait 2500",
                           "listermode code|/Users/admin/longline-mode.txt", "wait 1200",
                           "listerformat /Users/admin/longline.txt", "wait 800"], 14),
    # JSON Lines (F-412), which is not one JSON document: one complete value per line. The validator used
    # to hand the whole file to a JSON parser, which reports the *second record* as garbage after the end
    # of the first — so every valid .jsonl was marked broken. And there was no formatter for it at all,
    # which was the safer half: the JSON one would have pretty-printed the file into something that is no
    # longer JSON Lines. Three answers in one scenario: a valid file is valid, a bad record is named by its
    # own line, and formatting keeps one record per line — with the *formatter's name* in the report,
    # because the text alone would not say which of the two ran.
    ("jsonl", ["probe /Users/admin/jsonl-seed.txt|mkdir -p ~/pc-jsonl && "
               "printf '{\"id\":1,\"name\":\"alpha\"}\\n{\"id\":2,\"name\":\"beta\"}\\n' "
               "> ~/pc-jsonl/good.jsonl && "
               "printf '{\"id\":1}\\n{\"id\":2,}\\n' > ~/pc-jsonl/bad.jsonl && "
               "printf '{  \"b\" : 2,  \"a\" : 1 }\\n{\"c\":[1,   2]}\\n' > ~/pc-jsonl/messy.jsonl && "
               "ls ~/pc-jsonl | wc -l",
               "wait 700",
               "editvalidate /Users/admin/pc-jsonl/bad.jsonl|/Users/admin/jsonl-bad.txt", "wait 900",
               "editformat /Users/admin/pc-jsonl/messy.jsonl|/Users/admin/jsonl-format.txt", "wait 900",
               "editvalidate /Users/admin/pc-jsonl/good.jsonl|/Users/admin/jsonl.txt", "wait 900"], 12),
    # A delimited file with no header line (F-411). Its first line used to become the column titles, so
    # the first record was gone from the table — not filterable, not sortable, not findable — and nothing
    # said so. The dump reports the *cells*, so `label=1` is the assertion: the first record is a row.
    # Its own folder, because pc-demo is what every screenshot baseline shows.
    ("csv-no-header", ["probe /Users/admin/csv-seed.txt|mkdir -p ~/pc-csvnh && "
                       "printf '1,2,3\\n4,5,6\\n7,8,9\\n' > ~/pc-csvnh/nohdr.csv && "
                       "wc -l < ~/pc-csvnh/nohdr.csv",
                       "wait 700",
                       "view /Users/admin/pc-csvnh/nohdr.csv", "wait 2500",
                       "listerdump /Users/admin/csv-nohdr.txt", "wait 500"], 11),
    # The same outline, in the *viewer* — where Markdown is normally read, because the viewer renders it
    # (F-410). It was unavailable there: the sidebar is built from a text view and the rendered page has
    # none, so the toggle was simply dead and the reader had to switch to the source to get an outline of
    # the document in front of them. And an entry that cannot be clicked to any effect is no better, so
    # the navigation is measured in the page itself: `scrolled` is the app's own verdict on whether the
    # view moved, `headingTop` where the heading ended up. Its own folder and its own file, long enough to
    # have to scroll and with the target in the middle rather than at the end; `pc-demo` is left alone
    # because every screenshot baseline shows it.
    ("viewer-md-outline", ["probe /Users/admin/md-nav-seed.txt|mkdir -p ~/pc-mdnav && "
                           "{ printf 'Titel\\n=====\\n\\n'; "
                           "for i in $(seq 1 150); do printf 'Zeile %s im ersten Teil.\\n' $i; done; "
                           "printf '\\n## Ziel\\n\\n'; "
                           "for i in $(seq 1 150); do printf 'Zeile %s im zweiten Teil.\\n' $i; done; } "
                           "> ~/pc-mdnav/long.md && wc -l < ~/pc-mdnav/long.md",
                           "wait 800",
                           "view /Users/admin/pc-mdnav/long.md", "wait 2500",
                           "listersymbol Ziel|/Users/admin/md-viewer-nav.txt", "wait 1500",
                           "listerdump /Users/admin/md-viewer.txt", "wait 500"], 12),
    ("html-outline", ["editdump /Users/admin/pc-demo/outline.html /Users/admin/html-outline.txt",
                      "wait 2500"], 10),
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
    ("filter-dialog", ["editfilterdlg /Users/admin/pc-demo/hosts.txt", "wait 2000"], 9),
    # Zooming a picture in the viewer (F-389). Three things a screenshot cannot state: the level is a
    # number and the commands move it, "actual size" is 100% of the image's own pixels rather than the
    # fitted rendering the old code called by that name, and the picture is *drawn* — `drawn=yes` compares
    # the pixel on screen against the pixel in the file, which is how the quick preview's missing document
    # view was caught while every other number looked perfect. The text representation is the control: the
    # same command has to be refused there, with the menu item withheld rather than dead.
    #
    # The fitted percentage is deliberately not asserted: it depends on the window, which depends on the
    # screen. `docFrame` is the fixture's own 3000x2000 and does not.
    ("viewer-zoom", ["active left", "left /Users/admin/pc-demo/Images", "wait 2000",
                     "focus big.png", "wait 900",
                     "cmd cm_List", "wait 2500",
                     "listerzoom state|/Users/admin/zoom-open.txt", "wait 500",
                     "listerzoom actual|/Users/admin/zoom-100.txt", "wait 500",
                     "listerzoom in|/Users/admin/zoom-in.txt", "wait 500",
                     "listermode text|/Users/admin/zoom-repr.txt", "wait 1500",
                     "listerzoom in|/Users/admin/zoom-text.txt", "wait 500",
                     "listermode image|/Users/admin/zoom-repr2.txt", "wait 1500",
                     "listerzoom fit|/Users/admin/zoom-fit.txt", "wait 700"], 13),
    # The same four commands in the quick preview (F-389), where they are buttons rather than menu items —
    # pressed through the button itself, so a control that is hidden, disabled or wired to nothing cannot
    # pass. Both sizes matter: a photograph has to arrive fitted and a 16x16 icon has to be left alone at
    # 100%, which is the case that "scale proportionally up or down" gets wrong on its own. A plain text
    # file is the control: it must stay on QuickLook's route with no zoom controls at all.
    ("preview-zoom", ["active left", "left /Users/admin/pc-demo/Images", "wait 2000",
                      "previewpanel on", "wait 1500",
                      "focus icon.png", "wait 1800",
                      "previewzoom state|/Users/admin/pz-icon.txt", "wait 500",
                      "focus big.png", "wait 1800",
                      "previewzoom state|/Users/admin/pz-big.txt", "wait 500",
                      "previewzoom actual|/Users/admin/pz-100.txt", "wait 500",
                      "previewzoom fit|/Users/admin/pz-fit.txt", "wait 500",
                      "focus photo_1.txt", "wait 1800",
                      "previewzoom state|/Users/admin/pz-text.txt", "wait 700"], 12),
    # The *other* quick preview (F-118 + F-389): Ctrl+Q turns the inactive panel into a preview area, so
    # with the right panel active it is the **left** one — which is where the zoom was asked for. Same
    # class as the sidebar's preview, hence the same report; the point of the scenario is that the third
    # place a preview appears got the feature too, rather than two out of three.
    ("quickview-zoom", ["active right", "left /Users/admin/pc-demo/Images",
                        "right /Users/admin/pc-demo/Images", "wait 2000",
                        "cmd cm_SrcQuickview", "wait 1500",
                        "focus big.png", "wait 2200",
                        "quickviewzoom state|/Users/admin/qv-big.txt", "wait 500",
                        "quickviewzoom actual|/Users/admin/qv-100.txt", "wait 500",
                        "focus photo_1.txt", "wait 2000",
                        "quickviewzoom state|/Users/admin/qv-text.txt", "wait 700"], 12),
    # The built-in line operations over a CRLF file with duplicates, blanks and trailing spaces
    # (F-359) — the terminator surviving is the part that fails silently.
    ("editor-lines", ["editlines /Users/admin/pc-demo/messy.txt|/Users/admin/lines.txt",
                      "wait 2000"], 9),
    # Saving must not leave a `.bak` behind unless the user asked for one, and must leave one when they
    # did (F-387). Both ends in a single run, on two files created for it, because the question is what
    # is in the folder afterwards — a setting read back from the config would only prove the checkbox.
    # The "on" report is written last: the harness stops the app as soon as the primary report appears.
    ("editor-backup", ["mkfile /Users/admin/bak-off.txt", "mkfile /Users/admin/bak-on.txt", "wait 500",
                       "editsave /Users/admin/bak-off.txt|typed-|/Users/admin/bak-kept-off.txt",
                       "wait 1500",
                       "setbool Editor.CreateBackups|1",
                       "editsave /Users/admin/bak-on.txt|typed-|/Users/admin/bak-kept-on.txt",
                       "wait 2000"], 9),
    # Dropping something onto the button bar (F-010). The drag itself cannot be scripted, but the entry
    # point the bar view calls can — and what matters is the other end: the button has to reach
    # default.bar, or it is gone at the next launch. That file is read by the shell afterwards.
    # The dump at the end is what the guest waits for. Without it this scenario had only its settle time,
    # and in a full run — where a launch can take ten seconds — the external check read a `default.bar`
    # the app had never got round to writing, which reads as "the drop is broken" rather than "the app
    # was still starting". Measured in the first full run: the screenshot showed empty panels.
    ("toolbar-drop", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "bardrop /System/Applications/Calculator.app", "wait 1500",
                      "bardump /Users/admin/bar.txt", "wait 400"], 10),
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
    # The terminal in the *sidebar*, with the host's commands still finding it there (F-388). Each of
    # them opened the bottom dock and looked for the terminal in it, so once it had been moved away they
    # opened an empty strip and otherwise appeared to do nothing. Three claims, in the order a user meets
    # them: moving it shows it where it landed instead of leaving the sidebar on whichever tab it had;
    # Split from the menu reaches it there and does *not* open the empty dock; and moving it back
    # attaches it again. `attached=` is asked because a panel can be listed, selected and still draw
    # nothing — the container that lost the view used to take it back out of the one that had adopted it.
    #
    # `moveview` is the menu item's path rather than the `placeview` primitive underneath it: showing the
    # view where it landed is the half that was missing, and only the menu path has it.
    ("terminal-elsewhere", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                            "dock on", "wait 3000",
                            "previewpanel on", "wait 1200",
                            "moveview plugin.terminal.view|sidebar", "wait 2000",
                            "dockdump /Users/admin/te-sidebar.txt", "wait 300",
                            "cmd cm_TerminalSplit", "wait 2000",
                            "dockdump /Users/admin/te-split.txt", "wait 300",
                            "moveview plugin.terminal.view|bottom", "wait 2000",
                            "mountdump /Users/admin/te-mounts.txt", "wait 300",
                            # Own the placement you touched: an override is persisted, and every
                            # scenario after this one expects the terminal in the dock (terminal-move).
                            "placeview plugin.terminal.view|default", "wait 1000",
                            "dockdump /Users/admin/te-back.txt", "wait 500"], 20),
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
    # Set, not toggled: `cm_TreeShared` and `cm_SrcTree` flip a state that the guest's peachcmd.ini
    # remembers between scenarios, so this audit used to get whichever tree the previous scenario left
    # behind — and with the panel tree off it read an unpainted view and reported the *app's* colours as
    # wrong. It passes alone and failed in the full suite, which is the worst shape a check can have.
    ("tree-colours", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "treevisible shared|1", "wait 1000",
                      "treevisible panel|1", "wait 1200",
                      "treecolors /Users/admin/treecolours.txt", "wait 600"], 14),
    # The rest of the surfaces (F-015). `tree-colours` knows what the tree should be and checks it;
    # this one knows nothing about any widget and reports surfaces that break the two properties the
    # tree defect broke — a bright box in a dark window, and text too close to what is behind it.
    #
    # As much as possible on screen first, because the audit can only see what is mounted: both trees,
    # the preview panel, the bottom area with its terminal, and the settings window, which is a second
    # window and so a second chance for a palette to have been forgotten.
    # Set, not toggled — the same lesson `tree-colours` above already learned, and unlearning it here
    # cost a full-suite failure. `cm_TreeShared` and `cm_SrcTree` flip a state the guest's peachcmd.ini
    # remembers, so after `tree-colours` (which switches both trees ON) these two switched them back
    # OFF. A hidden tree is a zero-width `PanelTreeView` with a scroll view pinned to both its edges,
    # which is an Auto Layout conflict — so this scenario reported one conflict in the full suite and
    # none when run alone, on any build.
    ("surface-colours", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "treevisible shared|1", "wait 800",
                         "treevisible panel|1", "wait 800",
                         "previewpanel on", "wait 1000",
                         # The Git panel is mounted on purpose (F-431): it was white in every dark palette
                         # for four commits, with white labels on top, and the audit had been saying so —
                         # nobody had asked it about a view that has to be *opened* first. The guest has no
                         # usable git, so the panel says "not a repository" — and gets painted, which is all
                         # the audit needs.
                         "presentview plugin.git.panel", "wait 1500",
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
    # The eject command is reachable from the main menu (F-006). Ejecting itself cannot be shown in
    # this VM — there is no removable volume to eject — so what is checked is the half that was
    # missing for the user: that the command exists and is offered somewhere findable.
    ("eject-menu", ["active left", "left /Users/admin/pc-demo", "wait 1500",
                    "menudump /Users/admin/menu-eject.txt", "wait 500"], 10),
    # A plugin drive is a drive, not a view switch (F-385). Reported by a user: picking TaskManager in
    # the drive bar changed the listing and nothing else — the chip stayed on the last real volume, the
    # tab was titled "/" and the breadcrumb claimed the startup disk's root, because all three read the
    # panel's path and inside such a mount that path is the mount's own "/".
    #
    # Three dumps, because each stage can pass for the wrong reason. Mounted: the drive names itself
    # everywhere. A second tab: the chip and the breadcrumb must *leave* the drive while the first tab
    # keeps its name — that tab is where a switch back has to find it — and the new tab must anchor to
    # the directory the mount was entered from, not to the "/" it would inherit at face value. Back:
    # the drive is re-entered, which is the part that lives in the tab rather than in the panel and is
    # the reason a restart can restore it at all. The screenshot cannot tell these apart; only the
    # names can.
    ("drive-plugin", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "pfxmount TaskManager", "wait 2500",
                      "drivebardump /Users/admin/drive-mounted.txt", "wait 400",
                      "cmd cm_OpenNewTab", "wait 1500",
                      "drivebardump /Users/admin/drive-second.txt", "wait 400",
                      "cmd cm_NextTab", "wait 2500",
                      "drivebardump /Users/admin/drive-back.txt", "wait 400"], 16),
    # A directory big enough to arrive in more than one batch (F-474). `LocalFS` yields 4096 entries at
    # a time, so 5,000 files is two batches — which means one partial listing is painted before the
    # final one. What this asserts is the part that a unit test cannot: that going through the partial
    # path leaves the panel with exactly the right listing at the end. A batch appended twice, or the
    # last one dropped, shows up here as a wrong count and nowhere else.
    #
    # The probe reports the count it built, so a fixture that failed to build cannot be mistaken for a
    # panel that listed wrongly.
    ("big-listing", ["probe /Users/admin/big-seed.txt|"
                     "/usr/bin/python3 -c \"import os; d=os.path.expanduser('~/pc-big'); "
                     "os.makedirs(d, exist_ok=True); [open(os.path.join(d,'f%05d.txt'%i),'w').close() "
                     "for i in range(5000)]\" && ls ~/pc-big | wc -l | tr -d ' '",
                     "active left", "left /Users/admin/pc-big", "wait 4000",
                     "dump /Users/admin/big-listing.txt"], 20),
    # S3 as a drive, in the running app (F-457). The plugin's own tests drive it through
    # `PFXFileSystem`; this is the only place the *user's* route runs — a saved profile becomes a chip
    # in the drive bar, clicking it connects that profile, and the bucket list is the root of the mount.
    #
    # This scenario was written for F-456, failed three runs, and is what found the defect F-457 fixed:
    # `PfxConnect` takes no argument, so the plugin could not tell which chip was clicked and fell back
    # to its dialog — and the run hung on a modal window nothing here can answer. It only passes now
    # because the host hands the volume id over.
    #
    # Anonymous on purpose: a signed connection would need the secret in the guest's Keychain, and
    # nothing here can type into a Keychain prompt. The fixture serves unsigned reads, which is what a
    # public bucket is.
    #
    # The profile and the server are set up BEFORE the app launches, in the guest-preparation block
    # below — NOT with a `probe`. That was the first attempt and it cannot work: a probe runs inside
    # the already-running app, and by then the plugin has been loaded and asked for its volumes, so
    # there is no chip to mount.
    ("s3-mount", ["probe /Users/admin/s3-probe.txt|"
                  "if curl -fsS -o /dev/null http://127.0.0.1:9200/ 2>/dev/null; then echo fixture-up; "
                  "elif test -f ~/s3server.py; then echo fixture-dead; else echo fixture-missing; fi",
                  "active left", "pfxmount S3Fixture", "wait 3000",
                  "dump /Users/admin/s3-panel.txt"], 18),
    # The Task Manager as a *file* manager (F-390, F-391, F-392, F-393, F-394). One scenario, because
    # each step needs the one before it: a process must be holding a file open before "which processes
    # have this open" can answer, and the answer is what puts the cursor on that process so entering it
    # can list what it holds. The holder is started through `probe` rather than baked into the fixture
    # tree — it has to be alive DURING the scenario, and a background `tail` started here is. The file
    # it holds is made by the scenario too: the first version held a file from the demo tree, and when
    # the guest turned out not to have that tree the search correctly found nobody — a scenario that
    # depends on fixtures it does not create fails for a reason that is not the feature.
    ("process-files", ["mkfile /Users/admin/tm-target.txt",
                       "probe /Users/admin/tm-holder.txt|nohup tail -f /Users/admin/tm-target.txt >/dev/null 2>&1 & sleep 1; pgrep -x tail >/dev/null && echo holder-running || echo holder-missing",
                       "active left", "pfxmount TaskManager", "wait 3000",
                       "procfile /Users/admin/tm-target.txt", "wait 900",
                       "prochldump /Users/admin/tm-handles.txt", "wait 400",
                       "rowdump /Users/admin/tm-row.txt", "wait 400",
                       # The search left the cursor on the holder, so this enters THAT process.
                       "enter", "wait 1500",
                       "dump /Users/admin/tm-openfiles.txt"], 16),
    # A refresh must not take the user's place in the list (F-398). Scrolled a hundred rows down with
    # the cursor untouched — the case that used to snap back to the top within two seconds — and asked
    # again after three refresh cycles. `scrollto` puts the target row at the TOP of the viewport, so
    # the expected first row does not depend on the guest's window height.
    ("panel-place", ["active left", "pfxmount TaskManager", "wait 3000",
                     "scrollto 100", "wait 800",
                     "viewdump /Users/admin/place-before.txt", "wait 6000",
                     "viewdump /Users/admin/place-after.txt"], 16),
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
    # Same treatment as `toolbar-drop`: the panel dump is a file the guest can wait for, so the external
    # check reads `session.ini` after both panels have actually loaded rather than after a fixed sleep.
    ("session-save", ["active left", "left /Users/admin/pc-demo", "wait 800",
                      "right /Users/admin/sync-src", "wait 2000",
                      "panelsdump /Users/admin/session-panels.txt", "wait 400"], 10),
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
    # Markdown and HTML are a plugin's now (F-465…F-469), and three things about that can only be
    # judged in a real WebKit. The fixtures are made by the scenario rather than baked into the demo
    # tree, so what each one proves is next to what it renders.
    #
    # A diagram and a formula, drawn with engines that ship inside the plugin. The report names the
    # rendered kinds; the screenshot is what says they are actually *drawn*.
    ("markdown-diagram", ["probe /Users/admin/md-rich-seed.txt|mkdir -p ~/pc-md && "
                          "{ printf '# Diagramm und Formel\\n\\n'; "
                          "printf '```mermaid\\ngraph LR\\n  A[Datei] --> B[Plugin]\\n```\\n\\n'; "
                          "printf 'Inline $E = mc^2$ und abgesetzt:\\n\\n$$\\n\\\\sum_{i=1}^{n} i\\n$$\\n'; } "
                          "> ~/pc-md/rich.md && wc -l < ~/pc-md/rich.md",
                          "wait 800",
                          "view /Users/admin/pc-md/rich.md", "wait 5000",
                          "listerdump /Users/admin/md-rich.txt", "wait 500"], 12),
    # The rule whose loss would be a security defect: the page runs the two engines, so a document's
    # own script must not run with them, and an image on a server must not be fetched. The witness for
    # the second half is the beacon server — see EXTERNAL_CHECKS.
    ("markdown-html-escape", ["probe /Users/admin/md-escape-seed.txt|mkdir -p ~/pc-mdesc && "
                              "{ printf '# Roh-HTML\\n\\n<script>document.title=\"RAN\"</script>\\n\\n'; "
                              "printf '![p](http://127.0.0.1:8899/mdesc.png)\\n'; } "
                              "> ~/pc-mdesc/raw.md && wc -c < ~/pc-mdesc/raw.md",
                              "wait 800",
                              "view /Users/admin/pc-mdesc/raw.md", "wait 4000",
                              "listerdump /Users/admin/md-escape.txt", "wait 500"], 12),
    # And the other half of the two-configuration rule: a foreign .html file may run nothing at all.
    # Its own script tries to replace the sentence in the page; the dump reports the window's title,
    # which that script also tries to change.
    ("html-no-javascript", ["probe /Users/admin/md-html-seed.txt|mkdir -p ~/pc-mdhtml && "
                            "{ printf '<!DOCTYPE html><html><head><title>QUIET</title></head><body>\\n'; "
                            "printf '<p id=\"v\">unchanged</p>\\n'; "
                            "printf '<script>document.getElementById(\"v\").textContent=\"SCRIPTS RAN\";"
                            "document.title=\"SCRIPTS RAN\";</script>\\n</body></html>\\n'; } "
                            "> ~/pc-mdhtml/page.html && wc -c < ~/pc-mdhtml/page.html",
                            "wait 800",
                            "view /Users/admin/pc-mdhtml/page.html", "wait 4000",
                            "listerdump /Users/admin/md-html.txt", "wait 500"], 12),
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
    # Searching inside archives (F-153/F-463). The term sits in a config file inside a .tar.gz
    # and nowhere else in the tree, so a hit can only come from going in — this is the reported
    # defect, which used to report nothing at all because the engine's own extension list knew
    # the zip family only. `broken.tar.gz` is there so the other half is covered too: a search
    # that could not look somewhere has to say so instead of quietly returning fewer rows.
    ("find-archives", ["active left", "left /Users/admin/pc-demo/Archives", "wait 1200",
                       "findarchives *.*|swordfish|/Users/admin/pc-demo/Archives|/Users/admin/arch-found.txt",
                       "wait 1000",
                       "findfeedarchives *.*|swordfish|/Users/admin/pc-demo/Archives|/Users/admin/arch-panel.txt",
                       "wait 1200"], 11),
    # What the two search fields remember (F-406). Three searches in one dialog: the second must sit
    # above the first, re-running the first must promote it rather than duplicate it, and Clear must
    # leave both dropdowns empty. A dropdown is a list AppKit draws in a window of its own, so the
    # report is what the combo boxes actually offer — a file on disk would not prove the field sees it.
    ("find-history", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "findsearch *.csv|superseded", "wait 2500",
                      "findsearch *.txt|", "wait 2500",
                      "findhistory /Users/admin/fh-after.txt", "wait 600",
                      "findsearch *.csv|", "wait 2500",
                      "findhistory /Users/admin/fh-promoted.txt", "wait 600",
                      "findhistoryclear /Users/admin/fh-cleared.txt", "wait 800"], 12),
    # The search that found the file, continued in the viewer (F-407). Three claims: the term arrives in
    # the viewer's own search *and* in the find bar, the reader lands on the first hit rather than at the
    # top of the file, and a term they retype is theirs — a reload does not put the seeded one back. The
    # find bar's value is read from the window, not from the find pasteboard alone: that pasteboard is
    # system-wide and survives the previous scenario, so it would report a pass for a build that seeded
    # nothing at all.
    # The term has to be in a file's *contents*, and one file's only: the first version searched for
    # "superseded", which exists in the demo tree as a *comment* set by `find-comments` and in no file at
    # all — so the search found nothing, no viewer opened, and the report said "ERROR: no viewer". Found
    # by the first VM run of this scenario, which is what it is for. `report.txt` names exactly one file,
    # and "Revenue" sits on its fourth line, so "landed on the hit" is not the same as "opened the file".
    ("find-seeded-viewer", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                            "findviewhit report.txt|Revenue|/Users/admin/pc-demo|/Users/admin/seed-on.txt",
                            "wait 1200",
                            "listerretype Quarterly|/Users/admin/seed-retyped.txt", "wait 800",
                            "listerreload /Users/admin/seed-reloaded.txt", "wait 1000"], 13),
    # The same feature switched off in Settings, which is the half a checkbox can silently stop doing:
    # nothing is seeded, and the viewer opens where it always did.
    ("find-seed-off", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "setbool Viewer.SearchFromFind|0", "wait 600",
                       "findviewhit report.txt|Revenue|/Users/admin/pc-demo|/Users/admin/seed-off.txt",
                       "wait 1200"], 12),
    # "Find text" with no checkbox in front of it (F-407): the field is live from the moment the dialog
    # opens, what is in it is searched for, and an empty one searches names only. Typed through the field
    # editor, because assigning `stringValue` posts no change notification and would pass with the
    # options dead.
    ("find-text-field", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "findtab 0", "wait 1500",
                         "findtext |/Users/admin/ft-empty.txt", "wait 600",
                         "findtext superseded|/Users/admin/ft-typed.txt", "wait 600",
                         "findtext |/Users/admin/ft-cleared.txt", "wait 800"], 12),
    # Switching *to* System after a named palette (F-409). Two defects in one sequence: the palette used
    # to be resolved from the app's own overridden appearance, so Light → Midnight → System kept the dark
    # colours under a light window until the next launch; and repainting the Settings sidebar reloaded it,
    # which dropped its selection and threw the reader from Colors back to Layout. The check is that the
    # palette and the system appearance agree — true in either mode, unlike a hex value — and that the
    # page the reader was on is still the page.
    # `Colors.Appearance` is stated rather than inherited: the guest's config had it at "dark", which
    # short-circuits `appearanceIsDark` before the OS is ever consulted — so the first VM run of this
    # scenario passed while exercising none of the code it exists to check.
    ("theme-system", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "setstring Colors.Appearance|system", "wait 600",
                      "settingspage Colors", "wait 1200",
                      "theme light", "wait 600",
                      "theme midnight", "wait 600",
                      "themestate /Users/admin/theme-midnight.txt", "wait 400",
                      "theme system", "wait 900",
                      "settingspagedump /Users/admin/theme-page.txt", "wait 400",
                      "themestate /Users/admin/theme-system.txt", "wait 600"], 12),
    # Searching the settings by name, across the pages (F-408). Three claims: a query finds the setting
    # wherever it lives, a word that is only in the *note* under a control still finds that control, and
    # choosing a result lands on the page with the control on screen and something pointing at it. Typed
    # through the field editor, because assigning `stringValue` posts no change notification and a
    # scenario built on that would pass with the search dead.
    # Named "search-settings" rather than "settings-search": a scenario claims every report key that
    # starts with its own name and a dash, so the `settings` scenario adopted all four of these and
    # failed on reports it never writes. Found by the first full VM run — the targeted run could not see
    # it, because the scenario that does the claiming was not in it.
    ("search-settings", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "settingsearch hidden|/Users/admin/ss-hidden.txt", "wait 700",
                         "settingsearch backup|/Users/admin/ss-backup.txt", "wait 700",
                         "settingsearch mainframe|/Users/admin/ss-none.txt", "wait 700",
                         "settingsopen hidden|1|/Users/admin/ss-open.txt", "wait 1200"], 13),
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
    # The same dump as keys-main, but with one more thing on screen. Written to answer "which view breaks
    # the chain" and kept because they answered it: a *hidden* view is skipped when AppKit builds the key
    # loop, and un-hiding one does not make it build a new one — so switching the preview panel or the
    # shared tree on left fourteen controls unreachable, and whichever scenario left one of them on
    # decided whether `keys-main` passed. Both states now have a gate of their own.
    # Does anything in this app ask macOS for the local network? The consent panel appears about forty
    # seconds after launch in the guest, steals the application's activation and has cost two wrong
    # diagnoses. This scenario does nothing but wait past that moment and leave a report, so the
    # *screenshot* answers the question — run once with the plugins in the bundle and once with them
    # removed (`--app` at a stripped copy), and the difference names the culprit.
    # Settle 70, not 12: the guest sleeps the settle time and then waits at most forty seconds more for
    # the report, so a scenario that deliberately idles for sixty could never deliver one — it reported
    # "never written" on every run since it was written, which is a gate that only ever says no. The
    # settle has to cover the wait it exists to perform.
    ("netpanel-watch", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "wait 60000",
                        "panelsdump /Users/admin/netpanel-watch-done.txt", "wait 500"], 70),
    ("keys-preview", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                            "previewpanel on", "wait 1500",
                            "keyloop /Users/admin/keyloop-keys-preview.txt", "wait 400",
                            "panelsdump /Users/admin/keys-preview-done.txt", "wait 300"], 12),
    ("keys-tree", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                         "sharedtree on", "wait 1500",
                         "keyloop /Users/admin/keyloop-keys-tree.txt", "wait 400",
                         "panelsdump /Users/admin/keys-tree-done.txt", "wait 300"], 12),
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
    # The history palette (F-402). It is a window built in code with a search field that keeps focus and
    # a table it drives from there, so both halves of the keyboard question apply: the loop has to be
    # closed *and* the controls have to announce themselves. `history` both opens it and dumps it, so the
    # window is certainly up before the keyloop is read.
    ("keys-history", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                      "history /Users/admin/history-open.txt", "wait 1200",
                      "keyloop /Users/admin/keyloop-history.txt",
                      "a11ydump /Users/admin/a11y-history.txt", "wait 500",
                   "panelsdump /Users/admin/keys-history-done.txt", "wait 300"], 14),
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
    # Go To takes arithmetic (F-400) and a dialog's field owns the clipboard (F-401). Both live in the
    # hex editor, so one scenario: the same window has to be up for either question, and the second one
    # needs the window's own menu bar installed, which only happens once it is key.
    #
    # The fixture is made here rather than baked into the demo tree — a scenario that depends on
    # fixtures it does not create fails for a reason that is not the feature. 8 KB, so 0x1000+15+1 is
    # inside it.
    #
    # `hexclip` runs LAST because the guest waits for this scenario's own report, and the clipboard is
    # the half that cannot be reached any other way: `answer` never shows the dialog, so there is no
    # field to type in, which is why this class of defect had no coverage at all.
    ("hex-clipboard",
     ["probe /Users/admin/hex-made.txt|/usr/bin/python3 -c \"open('/Users/admin/hexfix.bin','wb').write(bytes(range(256))*32)\" && echo made",
      "hexgoto /Users/admin/hexfix.bin|0x1000 + 15 + 1|/Users/admin/hex-clipboard-goto.txt", "wait 800",
      "menudump /Users/admin/hex-clipboard-menu.txt", "wait 400",
      "hexclip /Users/admin/hexfix.bin|COPY-ME|/Users/admin/hex-clipboard.txt", "wait 600"], 12),
    # The global history palette (F-402). One scenario, because every question depends on the one before
    # it: something has to have been visited before there is a history, the history has to hold an
    # operation before repeating one means anything, and the palette has to be open for either.
    #
    # `historyreset` first, so the list is this scenario's own work and not whatever the launch happened
    # to visit — the same lesson as the per-scenario session reset.
    #
    # The repeat is proved by *removing* the copy first: "the file is in the destination" would pass for
    # a build whose repeat does nothing at all, since the original copy already put it there.
    ("history-palette",
     ["historyreset",
      "probe /Users/admin/hist-made.txt|mkdir -p /Users/admin/hist-src /Users/admin/hist-dst && echo payload > /Users/admin/hist-src/data.txt && echo made",
      "left /Users/admin/hist-src", "wait 900",
      "right /Users/admin/hist-dst", "wait 900",
      "active left", "focus data.txt", "wait 400",
      # The guest seeds `VerifyAfterCopy=1` for bg-copy-verify, and that ends every FOREGROUND copy with
      # an NSAlert — an app-modal session no script can dismiss, which is what made every report of this
      # scenario empty for three runs. Off for the copy, back on afterwards so a later scenario in the
      # same run still finds what it seeded.
      "setbool Operation.VerifyAfterCopy|0", "wait 300",
      # F5 with the target answered from the script: the dialog is modal, so `answer` is the only way
      # past it (see the F-399 entry in STATE.md).
      "answer /Users/admin/hist-dst", "cmd cm_Copy", "wait 2500",
      "setbool Operation.VerifyAfterCopy|1", "wait 200",
      "probe /Users/admin/history-copied.txt|ls /Users/admin/hist-dst && rm -f /Users/admin/hist-dst/data.txt && echo removed=$(ls /Users/admin/hist-dst | wc -l | tr -d ' ')",
      # A file has to be *opened* for the history to hold one — copying it is an operation, not an open.
      "cmd cm_List", "wait 1800", "closeviews", "wait 600",
      "historymenu /Users/admin/history-palette-menu.txt", "wait 400",
      "historytype data|/Users/admin/history-palette-search.txt", "wait 400",
      # Clear the search before anything else is measured: a filter does not reset it, and every
      # expectation after this would otherwise be about "data" rather than about the filter.
      "historytype |/Users/admin/history-palette-cleared.txt", "wait 300",
      "historyfilter 3|/Users/admin/history-palette-ops.txt", "wait 400",
      "historykey open|/Users/admin/history-palette-open.txt", "wait 3500",
      "probe /Users/admin/history-palette-repeat.txt|ls /Users/admin/hist-dst",
      # Packing comes AFTER the repeat, and the order is the point: while it stood before it, the newest
      # operation row was the pack, so "repeat the top operation" repeated something that cannot be
      # repeated and the copy was never re-run. Through the pack dialog's own scripted answer
      # (`packanswer`) — the dialog is modal, so nothing could reach this path before that existed.
      #
      # A **zip**, on purpose. Zip used to shell out to a `7z` binary that a stock macOS does not carry,
      # so packing one failed here — which is how the missing fallback (F-132) was found at all. The
      # guest has never had Homebrew on it, so this is the one place that proves a zip can be packed on
      # an untouched Mac. F5-style, so the archive lands in the OTHER panel.
      "packanswer bundle|zip", "cmd cm_PackFiles", "wait 3000",
      "probe /Users/admin/history-packed.txt|ls /Users/admin/hist-dst",
      # Last, because the guest waits for this scenario's own report.
      "historyflush", "historyfilter 0|/Users/admin/history-palette.txt", "wait 400"], 14),

    # F-435, the crash a user hit mid-session. A named `cm_*_handler` func does NOT inherit the
    # `@MainActor` on `CommandHandler` — that reaches closure literals only — and
    # `WindowControllerProtocol`'s requirements were synchronous, so their witnesses had nowhere to
    # hop. Both commands below therefore ran on the cooperative pool and reached straight into
    # AppKit: `cm_SwitchHidSys` into `NSTableView.reloadData`, `cm_SwitchPanel` into
    # `NSMenu.itemArray` under `markActiveViewMode`. The panel had been showing the wrong content
    # for a while before it aborted, which is why the dump matters as much as the survival.
    #
    # Twenty pairs, not one: it is a race against whatever the main thread is drawing, and a single
    # toggle passes on a buggy build about as often as not. Locally the pre-fix binary died with
    # SIGABRT inside these; the fixed one runs all forty. The count is EVEN on purpose — hidden files
    # are persisted to `Configuration/ShowHiddenSystem` and the active panel is remembered, so an odd
    # count would hand every scenario after this one a different world.
    #
    # Its own directory rather than pc-demo, with one visible file and one dotfile, so the "hidden
    # files ended up off again" half is asserted against something this scenario controls instead of
    # leaving a dotfile in the tree every other scenario dumps.
    ("hidden-files-race",
     ["probe /Users/admin/hf-race-seed.txt|"
      "mkdir -p ~/hf-race && touch ~/hf-race/visible.txt ~/hf-race/.dotfile && ls -a ~/hf-race | wc -l",
      "active left", "left /Users/admin/hf-race", "wait 1200",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      "cmd cm_SwitchHidSys", "cmd cm_SwitchPanel",
      # Last, because the guest waits for this scenario's own report — and because a crash means it
      # never arrives, which is exactly how this scenario fails.
      "wait 1500", "dump /Users/admin/hidden-files-race.txt", "wait 500"], 12),

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
    # The em_ item's program ran and its %P expanded to the active panel: the app is only the
    # messenger, the file is the fact.
    "menu-file": ("test -f ~/pc-demo/menu-file-marker.txt && echo yes || echo no", "yes"),
    "toolbar-drop": ("grep -c '^cmd[0-9]*=.*Calculator.app$' ~/pc-cfg/default.bar 2>/dev/null || echo 0",
                     "1"),
    # Both panel paths in the file a restart reads.
    # Both paths present. Counting mentions was wrong — each path appears under more than one key —
    # so this asks the question directly and answers it in one word.
    "session-save": ("grep -q pc-demo ~/pc-cfg/session.ini && grep -q sync-src ~/pc-cfg/session.ini "
                     "&& echo both || echo missing", "both"),
    # The drive reached the file a restart reads (F-385), asked of the machine after the app is gone.
    # A tab used to be remembered as its path alone, and inside a plugin drive that path is "/" — so
    # the session restored the startup disk's root and called it the same tab. One line, in the left
    # panel: the right one writes the key empty, which is what makes counting the answer here.
    "drive-plugin": ("grep -c '^Tab0Drive=pfxmount:' ~/pc-cfg/session.ini 2>/dev/null || echo 0", "1"),
    "sftp-attributes": ("stat -f %Lp ~/sftp-demo/perm.txt", "600"),
    # Three distinct answers, so the interesting failure cannot hide: "viewer-fetched" means the block is
    # not working, "server-not-running" means the witness died and the run proves nothing, and only
    # "only-selftest" means the document was rendered and reached nobody.
    "viewer-beacon": ("if grep -q viewer.png ~/beacon-hits.log 2>/dev/null; then echo viewer-fetched; "
                      "elif grep -q selftest ~/beacon-hits.log 2>/dev/null; then echo only-selftest; "
                      "else echo server-not-running; fi", "only-selftest"),
    # The same three answers for the plugin's own page, which now runs JavaScript: an engine in the
    # page must not make a remote image reachable that was not reachable before.
    "markdown-html-escape": ("if grep -q mdesc.png ~/beacon-hits.log 2>/dev/null; then echo image-fetched; "
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
    # Named on purpose, unlike the ordinary AppKit windows above: both labels are set in code
    # (`setAccessibilityLabel`), so a refactor that drops them is exactly what this catches.
    "keyloop-history.txt": ["Search the history", "History entries"],
    "keyloop-keys-preview.txt": [],
    "keyloop-keys-tree.txt": [],
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
    "keys-history": ["keyloop-history.txt", "a11y-history.txt"],
    "keys-preview": ["keyloop-keys-preview.txt"],
    "keys-tree": ["keyloop-keys-tree.txt"],
    "keys-overwrite": ["keyloop-overwrite.txt"],
}

# Reports a scenario must have written, and what has to be in them ("!x" = must NOT be there).
#
# A scenario also claims every key that starts with "<its name>-" — that is how `notes-sidebar` owns
# `notes-sidebar-back`. So a *scenario* whose name extends another one's gets adopted by it, and its
# report is checked before it has run: name new scenarios so they are not a prefix-extension of an
# existing one. (Cost a run: "notes-sidebar-tc" passed alone and failed in company.)
REPORTS = {
    # F-478. The confirmation is the promise the whole feature rests on, so it is asserted as three
    # separate claims: the macro was *proposed* rather than run, its steps are the rows, and the row
    # that cannot be resolved yet says what it is waiting for instead of guessing. `answer: cancelled`
    # is the probe's own record that nothing was carried out — without it "the Trash is empty" would
    # pass for a build that never got as far as asking.
    "macro-confirm": ("/Users/admin/macro-confirm.txt",
                      ["Put the temporary files in the Trash", "row 1: Select *.tmp",
                       "row 2: Move what an earlier step selects to the Trash",
                       "answer: cancelled"]),
    # The question was put, with the macro's own wording and its default.
    "macro-ask": ("/Users/admin/macro-ask.txt", ["ask: Folder name = Archive"]),
    # And the answer reached the rows *before* they were approved, which is the design and not a
    # detail: a macro that asked when it reached the step would have been approved on a guess.
    "macro-ask-plan": ("/Users/admin/macro-ask-plan.txt",
                       ["row 1: Create the folder “Rechnungen”", "!Archive"]),
    # Both halves of the recorder: the action is offered as a readable row, and keeping it writes a
    # macro. The row naming the file is what distinguishes this from a list of "copy" entries.
    "macro-record": ("/Users/admin/macro-record.txt",
                     ["title: Recorded", "row 1: Copy data.txt into “macro-dst”"]),
    # The manager's buttons, by name. A stack view lays its buttons out past its own trailing edge
    # without producing a single Auto Layout conflict, so the count this suite leans on cannot see a
    # clipped toolbar; the accessibility tree can, because a button that is not there is not named.
    # The measurement first: the toolbar fits inside the window it opens at. Then that the list is
    # the shipped examples, and that the deleting one is shown as deleting — which is the difference
    # between choosing a macro for a key and finding out afterwards.
    "macro-manager": ("/Users/admin/macro-manager.txt",
                      ["toolbar-fits=yes", "!toolbar-fits=NO",
                       "buttons=Rename…|Duplicate|Delete|Move Up|Move Down|Add Button",
                       "row=mc_clean-temp|2|deletes", "row=mc_stage-by-month|3|changes files",
                       "row=mc_file-into-named-folder|2|changes files"]),
    # F-435: survival is half of it — a crash means this file never appears and the scenario fails on
    # its absence. The other half is the panel still showing what it was on, because wrong panel
    # content was the symptom that came *before* the crash. After an even number of toggles hidden
    # files are off again, so the seeded dotfile must NOT be listed.
    "hidden-files-race": ("/Users/admin/hidden-files-race.txt",
                          ["path=/Users/admin/hf-race", "visible.txt", "!.dotfile"]),
    # F-402: the palette lists what the session actually did — a file that was copied, the folders both
    # panels visited, and the copy itself as an operation. The search half is a separate report because
    # the ordering is the thing that was wrong first: a long path matched "data" everywhere.
    "history-palette": ("/Users/admin/history-palette.txt",
                        ["responder=NSTextView", "row=folder|hist-src", "row=folder|hist-dst",
                         "row=operation|"]),
    "history-palette-search": ("/Users/admin/history-palette-search.txt",
                               ["query=data", "row=file|data.txt"]),
    # The search really was cleared, so the reports after it are about their filter and nothing else.
    "history-palette-cleared": ("/Users/admin/history-palette-cleared.txt", ["query=\n"]),
    "history-palette-ops": ("/Users/admin/history-palette-ops.txt",
                            ["filter=Operations", "row=operation|"]),
    # Repeating the recorded copy puts the file back after it was removed. The removal is asserted in
    # the same file, or "data.txt is there" would pass for a build that repeats nothing.
    "history-palette-copied": ("/Users/admin/history-copied.txt", ["data.txt", "removed=0"]),
    # The pack really produced an archive, in the panel the history names.
    "history-palette-packed": ("/Users/admin/history-packed.txt", ["bundle.zip", "data.txt"]),
    "history-palette-repeat": ("/Users/admin/history-palette-repeat.txt", ["data.txt"]),
    # The palette's actions are real menu items, which is what keeps them off the panel's shortcuts and
    # findable by a screen reader (the F-401 lesson).
    "history-palette-menu": ("/Users/admin/history-palette-menu.txt",
                             ["Copy Path  key=A+W+C", "Pin or Unpin  key=W+P",
                              "Remove from History  key=W+BACKSPACE"]),
    # F-401, both directions in one file: with the Go To field being edited ⌘C copies the FIELD, and
    # with nothing focused the same action still copies the document's bytes. Either half alone would
    # pass for a build that had simply swapped one wrong answer for the other.
    "hex-clipboard": ("/Users/admin/hex-clipboard.txt",
                      ["responder=NSTextView", "copied=COPY-ME",
                       "fieldAfterPaste=PASTED-FROM-CLIPBOARD", "copiedWithoutField=00 01 02 03"]),
    # F-400: 0x1000 + 15 + 1 = 4112, through the dialog's own parsing. `answersleft=0` says the dialog
    # really asked — otherwise this would pass because nothing consumed the answer.
    "hex-clipboard-goto": ("/Users/admin/hex-clipboard-goto.txt", ["caret=4112", "answersleft=0"]),
    # F-401's other half: the items were not there at all before, which no screenshot of a menu would
    # have said either.
    "hex-clipboard-menu": ("/Users/admin/hex-clipboard-menu.txt",
                           ["Cut  key=W+X", "Paste  key=W+V"]),
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
    # F-476. `pages=` lists only the built-ins, so these say nothing about which plugins the VM has.
    # The default is Info alone — the negative matters as much, because "pages contains info" would
    # pass for the three-page panel this replaces.
    "side-panel-tabs-default": ("/Users/admin/side-tabs-default.txt",
                                ["pages=info\n", "selected=Info"]),
    # The whole reason for the rewrite: Log was showing at index 2, Info was switched off in front of it,
    # and Log is still what is showing. Reading the page out of the segment index answers "Activities"
    # here, and so does falling back to the first tab — which is why Activities is on for this step.
    "side-panel-tabs-selection": ("/Users/admin/side-tabs-selection.txt",
                                  ["pages=activities,log\n", "selected=Log"]),
    # Every built-in off is a legal state, and the toggles that got here ran while the panel was
    # collapsed. A plugin tab may well be selected — that is rule 2, not a failure — so nothing is
    # claimed about `selected`.
    "side-panel-tabs-empty": ("/Users/admin/side-tabs-empty.txt", ["pages=\n"]),
    # Back from nothing through the View menu, which is the only route left once the tab strip is gone.
    "side-panel-tabs": ("/Users/admin/side-tabs.txt", ["pages=info\n", "selected=Info"]),
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
    # F-388. `terminalShowing` is read from wherever the terminal is, so one line carries both halves of
    # the move: the sidebar came up on the terminal, and the dock stayed shut rather than opening empty.
    # The last dump also exercises the reopening rule — the dock was asked for earlier in this run, so
    # the terminal coming back to it brings the dock back with it.
    "terminal-elsewhere": ("/Users/admin/te-back.txt",
                           ["visible=true", "selected=plugin.terminal.view", "attached=yes",
                            "terminalShowing=true"]),
    "terminal-elsewhere-sidebar": ("/Users/admin/te-sidebar.txt",
                                   ["visible=false", "attached=none", "terminalShowing=true"]),
    # Split from the menu with the terminal in the sidebar: the dock must stay out of it.
    "terminal-elsewhere-split": ("/Users/admin/te-split.txt",
                                 ["visible=false", "attached=none", "terminalShowing=true"]),
    "terminal-elsewhere-mounts": ("/Users/admin/te-mounts.txt",
                                  ["plugin.terminal.view container=bottom built=true made=1 closed=0"]),
    "keys-main": ("/Users/admin/keys-main-done.txt", ["left=/Users/admin/pc-demo"]),
    "keys-preview": ("/Users/admin/keys-preview-done.txt", ["left="]),
    "netpanel-watch": ("/Users/admin/netpanel-watch-done.txt", ["left="]),
    "keys-tree": ("/Users/admin/keys-tree-done.txt", ["left="]),
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
    "keys-history": ("/Users/admin/keys-history-done.txt", ["left="]),
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
    # defect (the terminal status line, black on Norton blue) is fixed. So the expectation is
    # "nothing" — plus proof that the nothing was found by looking, because `findings=0` is also true
    # of a run that audited no surface at all.
    #
    # That proof used to be `windows=32`, and a count was the wrong shape for it. The number is
    # palettes × (visible windows + hidden plugin views), so it moves whenever a palette, a window or
    # a plugin view is added — and it did, to 40, for reasons that had nothing to do with this audit.
    # It was measured at 40 on a build with none of the work that was suspected of moving it, so the
    # pin had simply gone stale and the scenario had been failing on arithmetic.
    #
    # The surfaces are named instead. These three are the ones the scenario goes out of its way to put
    # on screen, so each is a claim rather than a tally: the Settings window (a second window, and a
    # second chance for a palette to have been forgotten), the Git panel (F-431 — white in every dark
    # palette for four commits, because nobody had asked the audit about a view that has to be opened
    # first), and the dock's terminal. `windows=` stays in the dump, where it is worth reading and
    # costs nothing when it moves.
    "surface-colours": ("/Users/admin/surfaces.txt",
                        ["findings=0", "audited: Settings", "audited: side:Git",
                         "audited: dock:plugin.terminal.view"]),
    # The dump is written last and only by a living app: if the theme change killed it, this file is
    # never written and the scenario fails with an empty report, which is the whole question.
    "plugin-theme-switch": ("/Users/admin/still-alive.txt", ["left="]),
    "keys-probe": ("/Users/admin/probe-after.txt", ["left="]),
    "eject-menu": ("/Users/admin/menu-eject.txt", ["Eject Volume"]),
    # Coming back to the tab re-enters the drive: the chip, the tab and the breadcrumb all name it
    # again, and the second tab is still there beside it under its own name.
    # What the process is holding open, listed as real file rows: the entry name is the file's path
    # with ":" for "/" (the host's own convention for a name containing a slash), and the panel path
    # names the process we entered — which is the process the file search found, not a row picked by
    # position.
    # The bucket is a directory at the root of the mount, which is the whole path model. `path=/` says
    # the panel really is inside the plugin's filesystem rather than somewhere on the guest's disk.
    # Exactly five thousand, after a listing that went through a partial paint. The count is the whole
    # assertion: a double-appended batch or a dropped last one is invisible in a screenshot.
    "big-listing": ("/Users/admin/big-listing.txt",
                    ["path=/Users/admin/pc-big", "count=5000", "f00000.txt", "f04999.txt"]),
    # The probe's own count. The comment on the scenario claimed this told a fixture that failed to
    # build apart from a panel that listed wrongly — but nothing read it, so it told nobody anything.
    "big-listing-seed": ("/Users/admin/big-seed.txt", ["5000"]),
    # `path=/\n` and not `path=/`: the panel that never mounted reports `path=/Users/admin`, which
    # *contains* `path=/`, so the unanchored form passed whether the mount happened or not. It is the
    # only line here that says the panel is inside the plugin's filesystem at all, and for two runs it
    # said it about a panel still sitting in the home directory.
    "s3-mount": ("/Users/admin/s3-panel.txt", ["path=/\n", "demo-bucket"]),
    # Whether the fixture server was even up when the app tried. Asked separately, because "no buckets"
    # is the correct answer to a dead server and the wrong answer to the question this scenario asks.
    "s3-mount-fixture": ("/Users/admin/s3-probe.txt", ["fixture-up"]),
    "process-files": ("/Users/admin/tm-openfiles.txt",
                      ["path=/tail (", ":Users:admin:tm-target.txt"]),
    # Asked first, because everything below it is about a process holding a file: if the holder never
    # started, "nobody has this open" is the right answer to the wrong question, and this line is what
    # tells the two apart.
    "process-files-holder": ("/Users/admin/tm-holder.txt", ["holder-running"]),
    # The other direction (F-390): exactly one process holds that file, it is the `tail`, and it holds
    # it for reading — "r" and not "w", which is the distinction the three colours are made of.
    "process-files-handles": ("/Users/admin/tm-handles.txt", ["count=1", "tail (", "\tr\t"]),
    # The columns, on the row the search landed on (F-392, F-393, F-394). `Apple` is asserted because
    # /usr/bin/tail is Apple-signed on every macOS, and the signature is read from the file, so it is
    # the one column that must be filled for any process at all. The memory column is asserted as a
    # rendered size ("MB"/"KB"), which is the host formatting bytes the plugin sent raw.
    "process-files-row": ("/Users/admin/tm-row.txt",
                          ["taskman.signed\tApple", "taskman.user\tadmin", "taskman.command\t/usr/bin/tail",
                           "B\n"]),
    # Before: the view sits where it was scrolled, a hundred rows down. After three refreshes: still
    # there. `!firstVisible=0` is the regression itself — the list jumping back to the top — and the
    # positive claim keeps the check from passing on an empty or truncated report.
    "panel-place": ("/Users/admin/place-after.txt", ["firstVisible=98", "!firstVisible=0"]),
    "panel-place-before": ("/Users/admin/place-before.txt", ["firstVisible=98"]),
    "drive-plugin": ("/Users/admin/drive-back.txt",
                     ["path=/\n", "current=TaskManager", "tabs=*TaskManager|pc-demo",
                      "crumb=TaskManager"]),
    "drive-plugin-mounted": ("/Users/admin/drive-mounted.txt",
                             ["path=/\n", "current=TaskManager", "tabs=*TaskManager",
                              "crumb=TaskManager",
                              # F-386: what each chip is showing. The plugin drive draws the emoji
                              # the plugin supplied and the guest's boot disk draws the system's own
                              # icon — the two ends of the rule, and neither names a volume, so this
                              # does not depend on what the guest's disk is called.
                              "TaskManager:pluginDrive:plugin", ":startupDisk:system"]),
    # The negative is the point: on the second tab the panel is *not* on the drive, while the first tab
    # goes on carrying its name. Without it, a build that simply left the chip lit forever would pass
    # the other two dumps. The volume the chip falls back to is deliberately not named — that is the
    # guest's boot disk, and its name is not this scenario's business.
    "drive-plugin-second": ("/Users/admin/drive-second.txt",
                            ["tabs=TaskManager|*pc-demo",
                             "crumb=/ > Users > admin > pc-demo", "!current=TaskManager"]),
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
    # The symbol outline for a language with no grammar (F-405). The tags are part of the answer: "C" for
    # the type, "m" for a method inside it, "E" for an extension, "ƒ" for a file-scope function. A scanner
    # that found every name and got the nesting wrong would produce the same list with "ƒ" throughout.
    # The *primary* entry is the last file the scenario writes, and that is not a detail: the guest waits
    # for the primary report and the app is killed once the settle time is up, so anything written after
    # it is a race. `check-scenario-reports.py` had been warning about this scenario, `viewer-esc` and
    # `menu-key-guard` for months; the first full run on a loaded machine turned all three warnings into
    # failures at once, with every later report empty. The viewer's button being pressable is the whole
    # bug report anyway, so it is no loss to lead with it.
    "swift-outline": ("/Users/admin/swift-viewer.txt",
                      ["symboltoggle=enabled", "Code · Swift", "!ERROR"]),
    "swift-outline-tree": ("/Users/admin/swift-outline.txt",
                           ["count=", "[C  Machine]", "[m  greet]", "[E  Machine]", "[ƒ  topLevel]",
                            "status=Swift", "crumb@mid=Machine", "!BLANK!",
                            # The negative cases in the fixture: a declaration keyword in a comment or a
                            # string is not a declaration.
                            "!Commented", "!InAString"]),
    # `Greet`, not `m`: a missing receiver rule reports the receiver as the method's name.
    "go-outline": ("/Users/admin/go-outline.txt",
                   ["[C  Machine]", "[m  Greet]", "[ƒ  main]", "status=Go", "!BLANK!"]),
    # Markdown: the headings, the breadcrumb they feed, and — the point — nothing from the fenced block.
    # No developer toolchain in the guest: the column is there and empty, and nothing was put on screen
    # (F-415). Primary = the panel dump, written last.
    "git-no-toolchain": ("/Users/admin/git-no-toolchain.txt", ["pc-gitfake", "!ERROR"]),
    # The row carries the column but no status — the plugin found no git and said nothing.
    "git-no-toolchain-row": ("/Users/admin/git-row.txt",
                             ["git.git_status", "!Modified", "!Untracked", "!Geändert"]),
    # And no installer dialog: this is the defect, not the empty column.
    "git-no-toolchain-modal": ("/Users/admin/git-modal.txt", ["modal=false"]),
    # The formatted long-line file draws at a linear cost, and the JSON Lines formatter is what ran (F-414).
    "viewer-long-lines": ("/Users/admin/longline.txt",
                          ["formatter=JSON Lines", "formatted=1", "line_build=fast", "!line_build=slow"]),
    # JSON Lines (F-412). Primary = the valid file, written last: "valid" is the answer that used to be
    # wrong for every .jsonl in existence. The parser's name is in the note, and the caret stays put.
    "jsonl": ("/Users/admin/jsonl.txt", ["problemLine=-", "JSONSerialization", "caret=0", "!ERROR"]),
    # The bad record is named by its own line — not by an offset into a file the reader would have to count.
    # `problemLine` rather than the note: the note is a translated sentence, and a gate that matches
    # translated prose passes or fails by which language the guest runs in.
    "jsonl-bad": ("/Users/admin/jsonl-bad.txt", ["problemLine=2", "!caret=0"]),
    # Formatting normalised each record and kept one per line, and it was the JSON Lines formatter.
    "jsonl-format": ("/Users/admin/jsonl-format.txt",
                     ["formatter=JSON Lines", "text={\"a\":1,\"b\":2}", "{\"c\":[1,2]}"]),
    # The headerless CSV (F-411): the plugin is what renders it, and every one of the nine values is a
    # cell. `label=1` is the first record's first field — as a column title it would not be in the dump.
    "csv-no-header": ("/Users/admin/csv-nohdr.txt",
                      ["CSV Lister", "label=1", "label=5", "label=9", "!ERROR"]),
    # The viewer's outline for rendered Markdown (F-410). The dump answers "can it be opened at all and
    # what does it hold" — including the underlined (setext) heading, which the renderer used to draw as a
    # paragraph and a rule.
    # Markdown and HTML through the plugin. What the dump can say is which representation actually
    # drew the file — a plugin, named — and that the outline is alive for it; the diagram and the
    # formula themselves are judged from the screenshot, because nothing outside the page can read
    # an SVG WebKit produced.
    "markdown-diagram": ("/Users/admin/md-rich.txt",
                         ["status=Plugin", "Markdown and HTML", "symboltoggle=enabled",
                          "[H  Diagramm und Formel]", "!ERROR"]),
    # Raw HTML shown as text rather than run: the title stays the file's name, and the outline still
    # has the heading. The image on a server is the beacon server's business (EXTERNAL_CHECKS).
    "markdown-html-escape": ("/Users/admin/md-escape.txt",
                             ["status=Plugin", "raw.md", "!RAN", "!ERROR"]),
    # A foreign .html file: its own script tries to replace both the sentence and the title, and the
    # dump reports the title the window carries.
    "html-no-javascript": ("/Users/admin/md-html.txt",
                           ["status=Plugin", "page.html", "!SCRIPTS RAN", "!ERROR"]),
    "viewer-md-outline": ("/Users/admin/md-viewer.txt",
                          ["symboltoggle=enabled", "[H  Titel]", "[H  Ziel]", "!ERROR"]),
    # And the click: the page moved, and the heading came to rest at the top of the view.
    "viewer-md-outline-nav": ("/Users/admin/md-viewer-nav.txt",
                              ["found=1", "anchor=ziel", "scrolled=yes", "headingTop=0"]),
    "markdown-outline": ("/Users/admin/md-outline.txt",
                         ["[H  PeachCommander]", "[H  Building]", "[H  Requirements]",
                          "[H  Underlined Section]", "crumb@0=PeachCommander", "!nor this", "!BLANK!"]),
    # HTML: `meta` is a leaf and `b` does not exist — a `<meta>` pushed as an open element swallows the
    # page, and `if (a < b)` in a script opens an element called b.
    "html-outline": ("/Users/admin/html-outline.txt",
                     ["head", "meta", "body", "header #top", "main #content", "script",
                      "!  b]", "!BLANK!"]),
    # The bare-key guard. Titles are localized and the command names are not, so the checks are on
    # "|cm_…" and on `menuClaimed` — which is AppKit's own answer about whether the item fired.
    #
    # The panel keeps the key: this is the command working, and the modal proves it reached the engine.
    # Aborted by `modaldump`, so the scenario deletes nothing.
    # Primary = the last file written (see `swift-outline` above): the ⌘A check is what the guest waits
    # for, so everything before it has been written by the time the app is stopped.
    "menu-key-guard": ("/Users/admin/mk-find-cmda.txt",
                       ["menuClaimed=yes", "!ERROR"]),
    "menu-key-guard-panel-del": ("/Users/admin/mk-panel-del.txt",
                                 ["responder=PanelListView", "|cm_Delete", "menuClaimed=yes", "!ERROR"]),
    "menu-key-guard-panel-modal": ("/Users/admin/mk-panel-modal.txt", ["modal=true"]),
    # Del in a text field: refused whether the field is in another window or in the file manager itself.
    "menu-key-guard-find-del": ("/Users/admin/mk-find-del.txt",
                                ["responder=NSTextView", "|cm_Delete", "menuClaimed=no", "!ERROR"]),
    "menu-key-guard-cmdline-del": ("/Users/admin/mk-cmdline-del.txt",
                                   ["responder=NSTextView", "|cm_Delete", "menuClaimed=no", "!ERROR"]),
    # And the other half of "refused": the keystroke has to end up somewhere. Sent through the whole
    # dispatch rather than to the menu bar, Del deletes the character in front of the caret — "abc"
    # becomes "bc", which is all a person pressing that key wanted.
    "menu-key-guard-find-typed": ("/Users/admin/mk-find-typed.txt",
                                  ["field=[abc]→[bc]", "!ERROR"]),
    # F5 is Copy: a dialog's keystroke must not start a file operation behind it either.
    "menu-key-guard-find-f5": ("/Users/admin/mk-find-f5.txt",
                               ["|cm_Copy", "menuClaimed=no", "!ERROR"]),
    # The two deliberate exceptions. A function key inside the file manager still commands the panels even
    # with the command line focused, and a ⌘ chord belongs to the menu wherever it is pressed — without
    # these the fix would have taken the keyboard away from the file manager to protect it.
    "menu-key-guard-cmdline-f2": ("/Users/admin/mk-cmdline-f2.txt",
                                  ["responder=NSTextView", "menuClaimed=yes", "!ERROR"]),
    # (`mk-find-cmda.txt` is the primary entry above — a ⌘ chord is still the menu's, everywhere.)
    # Esc from the text area and from the symbol filter: the focus line is half the check, because
    # "closed=yes" is what a viewer whose focus never moved would also report.
    # Primary = the last file written (see `swift-outline` above).
    "viewer-esc": ("/Users/admin/esc-find2.txt",
                   ["findbar=closed→closed", "closed=yes", "!ERROR"]),
    "viewer-esc-text": ("/Users/admin/esc-text.txt",
                        ["focus=ViewerTextView", "closed=yes", "!closed=no", "!ERROR"]),
    "viewer-esc-filter": ("/Users/admin/esc-filter.txt",
                          ["editing NSSearchField", "closed=yes", "!closed=no", "!ERROR"]),
    # A filter with something in it is the other thing Esc means locally: the text goes, the window stays,
    # and the Esc after that closes it. The "typed" pair is the check — a build that closed the window on
    # the first Esc would also report an empty filter afterwards.
    "viewer-esc-typed": ("/Users/admin/esc-typed.txt",
                         ["typed=[o]→[]", "closed=no", "!ERROR"]),
    "viewer-esc-typed-again": ("/Users/admin/esc-typed2.txt", ["closed=yes", "!ERROR"]),
    # The find bar is the one thing Esc means locally: open before, gone after, window still up. Both
    # sides of the arrow matter — "closed" alone would also describe a find bar that never opened.
    "viewer-esc-findbar": ("/Users/admin/esc-find.txt",
                           ["findbar=open→closed", "closed=no", "!ERROR"]),
    # (`esc-find2.txt` is the primary entry above: the second Esc closes the window.)
    # The hit, and the preview saying where the term was: a row whose text is nowhere in the file needs
    # to explain itself.
    # The hit has to name the archive it came from — `app.conf` alone would not say the walk
    # went inside — and the run has to admit the one archive it could not read. The count is
    # checked rather than the sentence: that line is translated, so its words would make the
    # check depend on the guest's locale instead of on the behaviour.
    # Primary is the panel dump because it is the *last* file the scenario writes: the guest
    # waits for the primary, so anything written after it would be a race the app loses on a
    # slow launch. That the hit survives being sent to a panel is the stronger claim anyway —
    # `ResultsFS` resolved every row with `lstat`, so a path inside an archive used to be
    # dropped without a word and the panel came up short.
    "find-archives": ("/Users/admin/arch-panel.txt",
                      ["backup.tar.gz/etc/app.conf", "count=1", "!ERROR"]),
    "find-archives-found": ("/Users/admin/arch-found.txt",
                            ["backup.tar.gz/etc/app.conf", "skipped=1", "count=1", "!ERROR"]),
    "find-comments": ("/Users/admin/found.txt",
                      ["count=1", "table.csv", "comment: superseded by the 2026 export", "!ERROR"]),
    # F-409: both of these had only a settle time and an external check, so a slow launch failed them
    # with a message about the *feature*. The reports are what the guest waits for; the external checks
    # then read a config file that the app has demonstrably reached.
    # The menu file (F-257). Primary = the restored dump, which is the last file written: the
    # cleanup that restores the built-in menu is the same step, so the guest must not stop the
    # app before it has run.
    "menu-file": ("/Users/admin/menu-file-restored.txt", ["# Start", "!Pr\u00fcfung"]),
    # The bar built from the file: the caption's umlaut survived the code page, the em_ item
    # carries its command, and the TC id nothing here implements is disabled rather than live.
    "menu-file-menu": ("/Users/admin/menu-file-dump.txt",
                       ["# Pr\u00fcfung", "[em_Marke]", "Unbekannt  disabled"]),
    # Clicking it goes through the item's own target/action, which is what was mis-wired.
    "menu-file-click": ("/Users/admin/menu-file-click.txt", ["found=1", "enabled=1", "sent=1"]),
    "toolbar-drop": ("/Users/admin/bar.txt", ["Calculator", "!ERROR"]),
    "session-save": ("/Users/admin/session-panels.txt",
                     ["left=/Users/admin/pc-demo", "right=/Users/admin/sync-src", "!ERROR"]),
    # F-409. The primary report is the state after the switch to System, which is the last file written.
    # "agrees" is the whole finding: before the fix the palette said dark and the window said light.
    "theme-system": ("/Users/admin/theme-system.txt",
                     ["theme=system", "appAppearance=follows OS", "agrees=true", "!ERROR"]),
    # The control: a named dark palette must still *be* dark, or "agrees" could pass by never being dark.
    "theme-system-midnight": ("/Users/admin/theme-midnight.txt",
                              ["theme=midnight", "paletteIsDark=true", "agrees=true", "!ERROR"]),
    # And the reader is still where they were, rather than back on the first page.
    "theme-system-page": ("/Users/admin/theme-page.txt",
                          ["page=Colors", "mounted=Colors", "!row=0", "!ERROR"]),
    # F-408. The primary report is the navigation, which is the last file written. "indexed" is part of
    # the check: an index that harvested nothing would report zero and every search would look like a
    # query with no answer.
    "search-settings": ("/Users/admin/ss-open.txt",
                        ["page=Display", "searchCleared=true", "results=false",
                         "control=Show hidden files", "visible=true", "tinted=true", "!ERROR"]),
    "search-settings-hidden": ("/Users/admin/ss-hidden.txt",
                               ["query=hidden", "count=1", "|Show hidden files|Display", "!ERROR"]),
    # "backup" is not in the checkbox's title — it is in the sentence under it and in the action it calls.
    "search-settings-backup": ("/Users/admin/ss-backup.txt",
                               ["query=backup", "|Edit/View", "!count=0", "!ERROR"]),
    "search-settings-none": ("/Users/admin/ss-none.txt", ["query=mainframe", "count=0", "!ERROR"]),
    # F-407. The primary report is the last file written, so the guest waits for the retype-and-reload
    # check rather than for the seed it is about to be compared against.
    "find-seeded-viewer": ("/Users/admin/seed-reloaded.txt",
                           ["term=Quarterly", "!term=Revenue", "!ERROR"]),
    "find-seeded-viewer-on": ("/Users/admin/seed-on.txt",
                              ["term=Revenue", "findbar=open", "selected=Revenue",
                               "focus=ViewerTextView", "!line=1", "!ERROR"]),
    "find-seeded-viewer-retyped": ("/Users/admin/seed-retyped.txt",
                                   ["term=Quarterly", "selected=Quarterly", "!ERROR"]),
    # Switched off: no term and no find bar, on a file that *does* contain the term — searching for
    # something absent would leave the same empty report and pass for the wrong reason.
    "find-seed-off": ("/Users/admin/seed-off.txt",
                      ["term=\n", "findbar=closed", "selected=\n", "!term=Revenue", "!ERROR"]),
    # The field is the switch now. "contentTerm" is what the search would actually run with, so an empty
    # field must produce none and a filled one must produce exactly what was typed.
    "find-text-field": ("/Users/admin/ft-cleared.txt",
                        ["typed=[]", "fieldEnabled=true", "contentTerm=-", "hex=off",
                         "notContaining=off", "labelsFit=true", "!ERROR"]),
    # The label column is measured from the longest label, so it must fit whatever language the guest
    # runs in rather than the 90 pt that fitted the English one.
    "find-text-field-empty": ("/Users/admin/ft-empty.txt",
                              ["typed=[]", "fieldEnabled=true", "contentTerm=-", "labelsFit=true",
                               "!ERROR"]),
    "find-text-field-typed": ("/Users/admin/ft-typed.txt",
                              ["typed=[superseded]", "contentTerm=superseded", "hex=on",
                               "wholeWord=on", "notContaining=on", "comments=on", "!ERROR"]),
    # F-406. The primary report is the one after Clear, because that is the last file written and the
    # guest waits for it; the two before it are what there was to clear. Each dump asserts the *order*:
    # "names=*.txt,*.csv" would also fail for a build that remembered both and sorted them by name.
    "find-history": ("/Users/admin/fh-cleared.txt",
                     ["names=\n", "texts=\n", "!*.csv", "!superseded", "!ERROR"]),
    "find-history-after": ("/Users/admin/fh-after.txt",
                           ["names=*.txt,*.csv", "texts=superseded", "!ERROR"]),
    # The third search re-used the first mask: it moves to the front instead of appearing twice, and the
    # content term is untouched because that search had none.
    "find-history-promoted": ("/Users/admin/fh-promoted.txt",
                              ["names=*.csv,*.txt", "texts=superseded", "!ERROR"]),
    # Read as UTF-16, the multi-line comment as two lines, still UTF-16 after writing, and the untouched
    # comment intact.
    "tc-descript": ("/Users/admin/tc.txt",
                    ["read16=Grüße aus Zürich", "readMulti=erste Zeile⏎zweite Zeile",
                     "bomAfterWrite=FFFE", "kept=erste Zeile⏎zweite Zeile",
                     "written=geändert durch die App"]),
    # F-387: the file the editor typed into is written either way, so "bak=" is the whole finding. The
    # default is checked *before* the setting is touched, since a default that only holds on a fresh
    # config is not the default a user meets.
    "editor-backup": ("/Users/admin/bak-kept-on.txt", ["bak=true", "dirty=false", "typed-auto"]),
    "editor-backup-off": ("/Users/admin/bak-kept-off.txt", ["bak=false", "dirty=false", "typed-auto"]),
    # F-389, the viewer. The primary report is the fit at the end; the levels before it are the claims.
    "viewer-zoom": ("/Users/admin/zoom-fit.txt",
                    ["mode=image", "fitting=true", "drawn=yes", "docFrame=3000x2000"]),
    "viewer-zoom-open": ("/Users/admin/zoom-open.txt",
                         ["mode=image", "fitting=true", "drawn=yes", "!level=100%",
                          "menuZoomIn=true", "menuZoomFit=true"]),
    # "Actual size" is the whole point of the rework: 100%, and the picture still on screen.
    "viewer-zoom-actual": ("/Users/admin/zoom-100.txt",
                           ["level=100%", "fitting=false", "drawn=yes"]),
    "viewer-zoom-in": ("/Users/admin/zoom-in.txt", ["level=150%", "fitting=false", "drawn=yes"]),
    # The control: no zoom on text, and the menu says so rather than offering a dead item.
    "viewer-zoom-text": ("/Users/admin/zoom-text.txt",
                         ["refused=in", "mode=text", "menuZoomIn=false", "menuZoomFit=false"]),
    # F-389, the quick preview. A 16x16 icon is left at its own size; a 3000x2000 photograph arrives
    # fitted; a text file keeps QuickLook and gets no controls.
    "preview-zoom": ("/Users/admin/pz-text.txt", ["route=quicklook", "bar=hidden"]),
    "preview-zoom-icon": ("/Users/admin/pz-icon.txt",
                          ["route=image", "bar=shown", "level=100%", "fitting=false",
                           "pixels=16x16", "drawn=yes"]),
    "preview-zoom-big": ("/Users/admin/pz-big.txt",
                         ["route=image", "fitting=true", "pixels=3000x2000", "drawn=yes",
                          "!level=100%"]),
    "preview-zoom-actual": ("/Users/admin/pz-100.txt", ["level=100%", "fitting=false", "drawn=yes"]),
    "preview-zoom-fit": ("/Users/admin/pz-fit.txt", ["fitting=true", "drawn=yes"]),
    "quickview-zoom": ("/Users/admin/qv-text.txt", ["route=quicklook", "bar=hidden"]),
    "quickview-zoom-big": ("/Users/admin/qv-big.txt",
                           ["route=image", "bar=shown", "fitting=true", "pixels=3000x2000",
                            "drawn=yes", "!level=100%"]),
    "quickview-zoom-actual": ("/Users/admin/qv-100.txt", ["level=100%", "fitting=false", "drawn=yes"]),
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


def must(cmd, what, **kw):
    """Run a setup step and STOP if it failed.

    `sh` returns its result and nobody looked at it, which is how a run reached the scenarios with an
    app bundle that had no binary in it and no AI plugin: both steps failed, said so on a stderr
    nobody read, and the suite then reported the consequences as product defects. A setup step that
    failed has no honest continuation."""
    r = sh(cmd, **kw)
    if r.returncode != 0:
        sys.exit(f"{what} failed ({' '.join(str(c) for c in cmd)}):\n"
                 + (r.stderr or r.stdout or "").strip()[-2000:])
    return r


def ssh_guest(ip, script):
    return sh(["ssh", *SSH, f"{GUEST}@{ip}", script])


def resolve_app(explicit):
    """The built app to send to the guest — and it must actually be one.

    This used to ask `xcodebuild -showBuildSettings`, which answers with the *default* DerivedData
    path. Everything else in this project builds into `build/` (Tools/build.sh passes
    -derivedDataPath), so on a machine that has never built through Xcode's UI that path is an empty
    directory. An empty directory is not an error: `build-all-plugins.sh` created `Contents/PlugIns`
    inside it, rsync copied that skeleton happily, and the guest received an app bundle with no
    binary in it. Every scenario then came back "report EMPTY" and every screenshot showed the
    desktop — which reads exactly like a broken app, and cost an hour of looking for one.

    So: the repo's own build tree first, and whatever is chosen has to contain the executable.
    """
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    else:
        candidates.append(REPO / "build/Build/Products/Debug" / APPNAME)
        r = sh(["xcodebuild", "-project", str(REPO / "PeachCommander.xcodeproj"),
                "-scheme", "PeachCommander", "-configuration", "Debug", "-showBuildSettings"])
        for line in r.stdout.splitlines():
            if "BUILT_PRODUCTS_DIR" in line:
                candidates.append(Path(line.split("=", 1)[1].strip()) / APPNAME)
    for cand in candidates:
        if (cand / "Contents/MacOS" / cand.stem).exists():
            return str(cand)
    sys.exit("no built app with a binary in it — looked at:\n  "
             + "\n  ".join(str(c) for c in candidates)
             + "\nbuild one with Tools/build.sh, or pass --app")


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
    must([str(REPO / "Tools/build-all-plugins.sh"), str(Path(app) / "Contents/PlugIns")],
         "building the plugins into the bundle")
    # The bundle must not be rebuilt while it is being copied. Building in another terminal during a run
    # produced an app that launched and then did nothing — no automation at all — and every scenario that
    # writes a report came back empty. That looked exactly like a product defect for half an hour.
    binary = Path(app) / "Contents/MacOS" / Path(app).stem
    before = binary.stat() if binary.exists() else None
    must(["rsync", "-a", "--delete", "-e", "ssh " + " ".join(SSH),
          app.rstrip("/") + "/", f"{GUEST}@{ip}:pc-test/{APPNAME}/"], "copying the app to the guest")
    after = binary.stat() if binary.exists() else None
    if before and after and (before.st_mtime, before.st_size) != (after.st_mtime, after.st_size):
        sys.exit("the app binary changed while it was being copied — something rebuilt it mid-run; "
                 "start the suite again with nothing else touching the build")
    # The sample tree every "left /Users/admin/pc-demo" scenario navigates to. `capture.py` has always
    # created it and this script never did, so those scenarios have been looking at an empty panel —
    # which for a layout scenario still reports zero conflicts, and for a report scenario reads as the
    # feature failing. Found while writing `process-files`: it held a file from that tree open, and the
    # search correctly answered that nobody had it open, because neither the file nor the tree existed.
    say("creating the demo tree in the guest…")
    must([str(Path(__file__).with_name("demo-content.sh")), ip], "creating the demo tree")
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
    # The S3 fixture server, taken from Tests/ rather than copied into Tools/vm/fixtures: a second copy
    # is a second thing to keep in step, and this one already has a suite holding it honest.
    sh(["scp", *SSH,
        str(Path(__file__).resolve().parents[2] / "Tests/PCPluginHostTests/Fixtures/s3server.py"),
        f"{GUEST}@{ip}:s3server.py"])
    # …with its bucket tree, its saved profile and the server itself, all before the app launches. The
    # profile has to exist first: the plugin is asked for its drive volumes while it loads, so one
    # written later produces no chip and `pfxmount` has nothing to find.
    ssh_guest(ip, "rm -rf ~/s3-root && mkdir -p ~/s3-root/demo-bucket/docs && "
                  "printf 'hello from s3' > ~/s3-root/demo-bucket/hello.txt && "
                  "printf 'nested' > ~/s3-root/demo-bucket/docs/note.txt && "
                  "mkdir -p ~/pc-cfg/s3 && "
                  "printf '%s' "
                  "'[{\"accessKeyID\":\"\",\"anonymous\":true,\"host\":\"127.0.0.1:9200\",'"
                  "'\"name\":\"S3Fixture\",\"pathStyle\":true,\"region\":\"us-east-1\",'"
                  "'\"useTLS\":false}]' > ~/pc-cfg/s3/profiles.json && "
                  "pkill -f s3server.py; "
                  "(nohup /usr/bin/python3 ~/s3server.py ~/s3-root 9200 >/dev/null 2>&1 &) ; "
                  "sleep 2; curl -fsS -o /dev/null http://127.0.0.1:9200/ && echo s3-fixture-up || "
                  "echo s3-fixture-DOWN")
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
                  # The System Monitor plugin's *network* module, switched off before anything runs.
                  # Under ~/pc-cfg, because that is the -ConfigRoot regress-guest.sh launches with and
                  # the plugin honours it; seeding the standard Application Support path instead did
                  # nothing at all, and the run looked exactly as it had before.
                  #
                  # It samples interface counters through getifaddrs, and macOS answers that with the
                  # local-network consent panel — a SYSTEM modal, in our process, that nothing in a
                  # script can dismiss. It appears about forty seconds after the first launch, so the
                  # first scenario of a run passed and the second one wrote *nothing at all*: every
                  # report empty, with the app apparently alive. Cost one full run to find, and only
                  # the screenshot said why (`history-palette.png`, the alert standing over the panels).
                  #
                  # The rest of the medium profile stays on, so the drive bar still shows CPU/RAM/GPU
                  # the way the documentation screenshots expect.
                  "mkdir -p ~/pc-cfg/systemmonitor && "
                  "printf '%s' '{\"enabled\":true,\"scale\":1,\"profile\":\"medium\",\"modules\":["
                  "{\"id\":\"cpu\",\"enabled\":true,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#FF9F0A\"},"
                  "{\"id\":\"gpu\",\"enabled\":true,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#BF5AF2\"},"
                  "{\"id\":\"memory\",\"enabled\":true,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#30D158\"},"
                  "{\"id\":\"network\",\"enabled\":false,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#5E5CE6\"},"
                  "{\"id\":\"battery\",\"enabled\":true,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#0A84FF\"},"
                  "{\"id\":\"disk\",\"enabled\":false,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#64D2FF\"},"
                  "{\"id\":\"sensors\",\"enabled\":false,\"showValue\":true,\"showGraph\":false,\"showLabel\":true,\"colorHex\":\"#FF453A\"}]}' "
                  "> ~/pc-cfg/systemmonitor/config.json && "
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


# Plugins a scenario needs switched ON, which ship switched off.
#
# `plugin-context-menu` asserts the AI plugin's context items and went red the day that plugin's
# default changed (F-448) — it was testing a *plugin's* contributions and had no way to say which
# plugin it meant. This is that way.
#
# Written per scenario and removed afterwards, in the same breath as the session reset below: a
# plugins.ini left behind would enable the plugin for every scenario after it, changing what each one
# sees — an extra menu, an extra column, an extra sidebar view — and `surface-colours` counts
# surfaces. `Enabled=` is additive rather than an allow-list (PluginConfig.isEnabled is
# `enabledByDefault || enabled.contains`), so naming one plugin here leaves every default-on plugin
# exactly as it was.
PLUGINS_ON = {
    # **Both**, and the second one is the whole scenario. The three items it asserts — "Summarize",
    # "Suggest a name", "Suggest a comment" — are contributed by the *AI On-Device* bundle
    # (Plugins/AILocal/Info.plist), not by the chat. Naming only the chat here left the plugin that
    # owns them switched off.
    #
    # It passed anyway, which is the part worth writing down. `adoptOnDeviceAssistantIfNeeded()`
    # switches the on-device plugin on **once** for anyone who had the assistant enabled and no cloud
    # model, and records `AI.OnDeviceAdopted` in `peachcmd.ini` — a file that survives between
    # scenarios, because the guest strips only its view-mode lines. So the migration fired on the
    # first app launch in a fresh clone and the items appeared; every later scenario found the flag
    # already set, skipped it, and got the plugins.ini the harness had just written, which named the
    # wrong plugin. The scenario therefore passed as the first thing in a run and failed as anything
    # else — measured: `--only plugin-context-menu` green, `--only main-window,plugin-context-menu`
    # red, with no other change.
    "plugin-context-menu": ["AI Assistant", "AI On-Device"],
}


# Environment a scenario needs the app launched with.
#
# Every headless dialog in this app is answered through one of these — the AI plugins' sheets and all
# four of the macro ones — and until now the harness had no way to set one, because `open` hands the
# app arguments and not the caller's environment. `regress-guest.sh` passes them as `-KEY value`
# arguments, which is the one channel that arrives — `launchctl setenv` from an ssh session lands in a
# different launchd domain than the auto-logged-in one the app runs in, measured after a full run
# reported four empty reports. `AutomationProbe` reads the environment first and then the arguments,
# so a local run keeps its natural spelling.
#
# A macro dialog is a *modal*: without its variable the script runs on inside the modal's nested
# runloop and `quit` never lands, so the scenario does not fail — it hangs. Which is why every macro
# scenario below sets one, and why a new one must.
SCENARIO_ENV = {
    "macro-confirm": {"PC_MACRO_CONFIRM_DUMP": "/Users/admin/macro-confirm.txt"},
    # The answer, and then the plan it has to appear in — the whole point of asking before the plan
    # is built rather than when the step is reached.
    "macro-ask": {"PC_MACRO_ASK": "Folder name=Rechnungen",
                  "PC_MACRO_ASK_DUMP": "/Users/admin/macro-ask.txt",
                  "PC_MACRO_CONFIRM_DUMP": "/Users/admin/macro-ask-plan.txt"},
    "macro-record": {"PC_MACRO_RECORD": "Recorded",
                     "PC_MACRO_RECORD_KEEP": "1",
                     "PC_MACRO_RECORD_BUTTON": "0",
                     "PC_MACRO_RECORD_DUMP": "/Users/admin/macro-record.txt"},
}


def run_scenario(ip, host, port, pw, name, script, settle, out: Path):
    body = "\n".join(script)
    ssh_guest(ip, f"cat > ~/auto.txt <<'PCEOF'\n{body}\nPCEOF")
    # Plugins this scenario needs on, and *off* for every other one — see PLUGINS_ON.
    wanted = PLUGINS_ON.get(name)
    if wanted:
        ssh_guest(ip, "mkdir -p ~/pc-cfg && printf '[Plugins]\\nEnabled=%s\\n' > ~/pc-cfg/plugins.ini"
                  % ";".join(wanted))
    else:
        ssh_guest(ip, "rm -f ~/pc-cfg/plugins.ini; true")
    # …and the environment its dialogs are answered through. Written and removed in the same breath,
    # for the same reason: one left behind answers the next scenario's dialogs.
    environment = SCENARIO_ENV.get(name)
    if environment:
        lines = "\n".join(f"{k}={v}" for k, v in environment.items())
        ssh_guest(ip, f"cat > ~/pc-env.txt <<'PCENV'\n{lines}\nPCENV")
    else:
        ssh_guest(ip, "rm -f ~/pc-env.txt; true")
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
