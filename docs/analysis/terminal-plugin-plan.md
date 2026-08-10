# Terminal plugin — design

An embedded terminal, tabbed, able to run full-screen TUI programs (`top`, `htop`, `vim`, Claude Code,
Codex), living in a removable `ptx` plugin that ships in the standard set and is on by default.

This is a plan, not an implementation. Everything below that says "measured" was measured in this
repository or on this machine; everything that says "open" is genuinely undecided.

---

## 1. Do not write the emulator

A terminal that runs `top` and Claude Code is not a text view with a pipe. It needs the parts those
programs actually use: the alternate screen buffer, scroll regions, cursor addressing, 256-colour and
true-colour SGR, bracketed paste, mouse reporting (SGR 1006), wide characters and combining marks,
`TERM=xterm-256color` capabilities that match what we actually implement, and a resize path that sends
`SIGWINCH` with the right `winsize`. Writing that badly is the difference between "it mostly works" and
"`htop` redraws garbage and Claude Code's input line jumps".

**Recommendation: vendor [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (MIT) into the plugin.**
It is pure Swift + AppKit, provides `TerminalView` and a `LocalProcess` PTY driver, and is the emulator
behind several shipping macOS apps.

Vendoring rather than adding a package dependency, for a reason that is structural here: **the app uses
SwiftPM (`project.yml` declares Sparkle, SwiftTreeSitter, Neon, tree-sitter grammars), but plugins do
not.** Every plugin is built by a shell script with a plain `swiftc -emit-library` line
(`Tools/build-notes-plugin.sh` is representative). A plugin therefore cannot consume a package the way
the app can. The two ways out:

| | Emulator in the plugin (vendored) | Emulator in the app (a `PCTerminal` framework) |
|---|---|---|
| Plugin removable | Completely — the emulator goes with it | The framework stays in the app, unused |
| Build | One more source list in the build script | Fits the existing SPM setup |
| App size without the plugin | Unchanged | Carries a terminal emulator nobody uses |
| Licence bookkeeping | `Tools/generate-third-party-notices.py` already covers this | Same |

The brief says *fully removable*, and that decides it. **But not by vendoring** — that conclusion was
wrong, and the repository said so: nothing here has ever carried third-party source. Sparkle, Neon and
the tree-sitter grammars come through SwiftPM pinned in `project.yml`; libssh2 comes through Homebrew
in `bootstrap.sh` with only a shim checked in. There are no submodules.

The premise was right — plugins are built by shell scripts and cannot consume a package the way an
Xcode target does — and the conclusion did not follow. `xcodebuild -resolvePackageDependencies
-clonedSourcePackagesDirPath build/spm` resolves a package **no target depends on**, into a directory
of our choosing, at the revision `project.yml` pins; the build script then compiles from the checkout.
Measured: the plugin builds, 2.5 MB per slice, all four ABI symbols exported, 1874 SwiftTerm symbols
inside, 32 s per architecture.

That also puts SwiftTerm inside machinery that already exists.
`Tools/generate-third-party-notices.py` reads versions straight from `Package.resolved` and *fails* on
a pin with no licence description — it flagged both SwiftTerm and the `swift-argument-parser` that
SwiftTerm's own sample target drags in. Vendored sources would have sat outside all of it.

The costs, stated: the first build needs the network, as it already does for Sparkle; and
`swift-argument-parser` is pinned though nothing links it, so the notices describe it as resolved but
not shipped rather than silencing the check.

Two traps, both found by building rather than reasoning. The plugin's own source must not be called
`terminal.swift` — SwiftTerm has `Terminal.swift`, and on a case-insensitive filesystem the two
intermediate object files overwrite each other, after which the linker reports missing symbols for
types whose file compiled perfectly well. And the module must not be called `Terminal` either, since
SwiftTerm declares a class of that name which a module name of the same name shadows.

**Measured before committing to this**, because "vendor a 25 000-line package into a shell-script build"
is exactly the kind of recommendation that collapses on contact:

| | Measured |
|---|---|
| Builds with plain `swiftc -emit-library`? | **Yes** — 61 sources (core + `Apple/` + `Mac/`, `iOS/` excluded), no errors |
| Time per architecture slice | **32 s** at `-O`; universal is two slices plus `lipo`, so ≈ 64 s |
| Size | **2.4 MB** per slice, ≈ 4.8 MB universal |
| SwiftPM-only constructs in the way? | **None.** No `Bundle.module` (upstream deliberately avoids it), no package dependencies in the `SwiftTerm` target |
| The `Shaders.metal` resource | **Not needed.** `useMetalRenderer` defaults to `false`; the CoreText path is the default and no `.metallib` has to be compiled or shipped |
| Deployment target | SwiftTerm declares macOS 11; our plugins build against **13.0**, arm64 + x86_64 (`Tools/lib/pc-universal.sh`) |
| Licence | MIT, compatible with Apache-2.0 |

Pinned at commit `1ca24414f7c48831d93c01cff01b1b1a47fb9112`.

---

## 2. Where it lives — and why the sidebar alone will not do

The user's instinct was the sidebar. Measured, that is the one place it does not fit:

* the sidebar (`PreviewPanelView`) is **300 pt wide by default, 180 pt minimum**
  (`MainWindowController.previewWidth`, `PreviewResizeHandle.minWidth`);
* measured with `NSFont.monospacedSystemFont`, a cell is 6.80 pt wide at 11 pt and 7.42 pt at 12 pt, so
  the sidebar gives **44 columns at 11 pt and 40 at 12 pt — 26 and 24 at its minimum width**;
* the same font across a 1200 pt window gives **176 and 161 columns**;
* `top` assumes 80, Claude Code is unpleasant below about 100.

So the sidebar cannot host either of the programs the brief names, at any font size, and the bottom of
the window has room to spare.

A terminal wants **width**, and the window is widest across the bottom.

**Recommendation: a new bottom dock spanning the window, plus the sidebar as a secondary mount.**

The host already anticipates this. `ContributionModel.swift` documents the container field as
`"sidebar" | "preview" | "bottombar"`, and `ViewContainerRegistry` says in as many words that "a plugin
can embed a view at nearly any visual seam; today one container is wired, and more attach the same
way". Three are registered (`sidebar`, `titlebar`, `settings`). The bottom one is missing, not
impossible.

```
┌───────────────────────────────────────────────┬──────────┐
│ shared tree │  left panel  │  right panel     │ sidebar  │   ← unchanged
├───────────────────────────────────────────────┴──────────┤
│ ▏zsh ▏build ▏claude ▏+                          ⌄ ✕      │   ← terminal dock: tabs
│ $ ▊                                                       │     full window width
├───────────────────────────────────────────────────────────┤
│ command line                                              │   ← unchanged
│ F3 View  F4 Edit  F5 Copy …                               │
└───────────────────────────────────────────────────────────┘
```

The dock sits **between the panels and the command line**: the command line and the function-key bar
stay where the muscle memory expects them, and the dock's height is a draggable divider, mirroring how
the sidebar's width already works (`PreviewResizeHandle` + a saved `Layout.PreviewWidth`).

The sidebar mount stays available for people who want a narrow shell beside the file list — the same
plugin declares two views, one per container, and the manifest already supports exactly that (see
`Plugins/SystemMonitor/Info.plist`, which declares `titlebar` and `settings`).

### Host work this requires

The dock is generic host furniture, not terminal code:

1. register a `bottom` container in `ViewContainerRegistry` (≈ the three lines the others take);
2. a `BottomDockView` with a height constraint, a divider, and persistence (`Layout.DockHeight`,
   `Layout.DockVisible`) — the sidebar's pattern, rotated;
3. a command `cm_ToggleDock` with a menu item and a key.

Any future plugin (a log tail, a build output, a REPL) can then mount there. That keeps the terminal
plugin removable: pull it out and the dock is simply empty, exactly as the sidebar is with no plugins.

---

## 2a. Placement belongs to the user, not to the manifest

The first draft had each view nailed to the container its manifest names. That is how the host works
today (`ContributionRegistry.viewItems(container:)` filters purely on the declared field, and no
placement preference exists anywhere). It is also the wrong model as soon as there is more than one
dock: where a panel sits is a matter of taste and screen shape, and taste is not something a plugin
author knows.

**The manifest declares the *default*; the user may move it; resetting restores the default.**

That is a generic host feature — every plugin view benefits, not just the terminal.

### Two different drags, and they must not be confused

| | What moves | Who owns it |
|---|---|---|
| **Drag the panel header** | the whole view, from one dock to another | the host |
| **Drag a tab** | one terminal session, between two mounted terminal views | the plugin |

The first is "I want the terminal at the bottom instead of the right". The second is "this Codex
session belongs in the big area, my quick shell can stay narrow". Both are wanted; they are different
mechanisms and only the first is generic.

### How the drag works

* The drag source carries one item — the view contribution's id, on a private pasteboard type. The app
  already does drag and drop in three places (`bardrop`, `buttondrop`, `rowdrop`), so the idiom is
  established.
* **What you grab differs per container, and the first draft got this wrong.** Plugin views in the
  sidebar are not panels with a header: `PreviewPanelView` appends them as extra **segments of an
  `NSSegmentedControl`** next to Info/Activities/Log. The drag source there is the segment, found by
  hit-testing the control; in the dock it is the tab strip's grip.
* Every registered container is an `NSDraggingDestination` that accepts that type and highlights while
  a drag is over it — including containers that are currently *empty*, otherwise there is nowhere to
  drop the first panel.
* On drop, the host writes `Layout.ViewPlacement.<viewId> = <container>` and re-resolves.

### The problem this uncovers

`ViewContainerRegistry.refresh` starts with `live.forEach { $0.close() }` and rebuilds every mount from
scratch. A placement change routed through it would therefore call `PcCloseView` on every plugin view —
**and a terminal's `PcCloseView` is what kills its sessions.** Dragging the terminal from the right to
the bottom would restart `top`, which nobody would call a feature.

Two changes, and both are worth making anyway:

1. **`refresh` becomes incremental.** A mount whose (plugin, viewId) is unchanged is kept and its
   `NSView` is simply re-parented into the new container — moving a view is `addSubview`, not a
   rebuild. Only genuinely new or removed contributions are made and closed.
2. **The plugin keeps sessions outside the view.** Sessions live in a pool owned by the plugin, and a
   view attaches to them; if a view *is* rebuilt for some other reason, the sessions survive and
   reattach. §4 already asks for this so that switching tabs does not restart `top` — the same property
   makes the move safe.
3. **`PreviewPanelView.setViewProviders` has the same defect** — it "tears down previously mounted
   views" and rebuilds the segmented control on every call. Making `refresh` incremental and leaving
   this one alone would fix nothing.
4. **A moved view has to be told it moved.** `PcMakeView` receives the `containerId`, so a plugin can
   already render differently depending on where it was built — but nothing tells it when it is
   *re-parented*. A terminal going from 24 columns in the sidebar to 161 in the dock wants different
   chrome, and re-parenting must therefore push `PcNotifyView(view, "container", <id>)`. The mechanism
   exists (`notifyViews(key:value:)` already sends `theme`, `dir`, `cursorPath`); only the call is
   missing.

### A placement override can name a container that is not there

Containers come and go with the window's furniture, and an override outlives the thing it names. An
override whose container is not registered is **ignored, not honoured** — the view falls back to its
manifest default and stays visible. Dropping it instead would make a view vanish for a reason the user
cannot see.

### Resetting

Two levels, because there are two ways to get lost:

* **Per panel** — "Move back to default" in the panel header's context menu; removes that one override.
* **Everything** — a `cm_ResetLayout` command that clears all placement overrides, and while it is
  there, the dock height and sidebar width too. Reachable from the menu, not only from Settings: a
  layout you cannot see is a layout you cannot fix from a dialog you also cannot see.

Both restore what the manifests declare, which is the only definition of "default" that stays true when
plugins come and go.

### Defaults

* The terminal declares **`bottom`** as its default container — that is where the columns are (§2).
* It also declares a `sidebar` view, but as a *second* contribution the user can enable, not something
  mounted by default. Two terminals on screen out of the box would be presumptuous.
* The dock itself starts **hidden**; the first press opens it, and from then on the state is remembered.
  On by default in the sense the brief asks for — the plugin is installed and active — without taking a
  quarter of the window from someone who never asked for a terminal. *(Decided.)*
* **The toggle is ⌃ + the key left of the `1`** — keyCode 50. That is physically the same key as the US
  layout's backtick, so it is ⌃\` for anyone on a US keyboard and the familiar VS Code / iTerm2 gesture,
  while on a German layout it is a single unshifted key instead of ⌃⇧´ (the backtick there lives on
  Shift + the dead-key ´). **Bind the key code, not the character** — binding the character is what makes
  a shortcut layout-dependent. *(Decided.)*

### Mixing — the point of a session pool

Yes, and it is the reason to build the pool rather than tie sessions to a view: sessions are the
plugin's, views are windows onto them. A quick `zsh` in the narrow sidebar and Codex in the wide dock
is then the normal case, not a special one, and dragging a tab between the two moves the *session* —
the process keeps running, the PTY is resized to the new geometry, and `SIGWINCH` tells the program
about it. That resize is the only tricky part: a full-screen program moving from 40 columns to 160
must redraw, and the ones that do it badly are exactly the ones worth testing (`top`, `htop`, `vim`).

### What this does not cover

The sidebar's three built-in modes (Info, Activities, Log) are not plugin views — they are segments
inside `PreviewPanelView`. Making *them* movable means converting them to the same provider model,
which is a worthwhile tidy-up and a separate piece of work. Until then, "every panel can be docked
anywhere" is true of plugin views and not of those three, and the plan should not pretend otherwise.

---

## 3. Splitting — yes, and it belongs to the plugin

"Two instances one above the other, and then the whole area for one again" needs no host support at
all. The dock hands the plugin one `NSView`; what happens inside is the plugin's business.

* the plugin's root view is an `NSSplitView` (horizontal divider → panes stacked vertically);
* **one pane** is the normal case; **split** adds a second pane showing another session;
* a *maximise* toggle (⌃⇧Return, and a double-click on the divider — the same gesture that centres the
  panel splitter, F-001) collapses to one pane without closing the other session;
* the split is per dock, and tabs belong to the *focused pane*, so two panes can show two tabs of the
  same set.

The layout (pane count, divider position, which tab is in which pane) is part of the plugin's own state
file, not the host's session — a removed plugin must not leave entries behind in `session.ini`.

---

## 4. Tabs and sessions

* A **session** is one PTY plus one child process plus its scrollback. It outlives its view: switching
  tabs must not restart `top`.
* Tabs live in the plugin, drawn to match the panel's own `TabBarView` (26 pt, same theme colours) so
  the dock does not look like a different application.
* New tab inherits the **active panel's directory** by default (see §7), not the last tab's.
* A tab's title follows the running program: the shell's OSC 0/1/2 title, falling back to the process
  name. `zsh` sets it for free; TUI programs set it themselves.
* Closing the last tab hides the dock rather than leaving an empty frame.

---

## 5. Cleanup — the part that is usually wrong

The brief asks for this explicitly, and it is where embedded terminals leak. What "properly cleaned up"
has to mean:

**Per session, on close**

1. `SIGHUP` to the child's **process group**, not the process: a shell that started `make -j8` has
   children, and killing only the shell orphans them. This requires the child to have been started in
   its own session (`setsid`) with the PTY as controlling terminal — SwiftTerm's `LocalProcess` does
   this, and it is the reason the group is addressable at all.
2. Wait up to ~2 s, reaping with `waitpid(WNOHANG)`; on timeout `SIGKILL` the group.
3. Close the master fd **after** the reap, or the read side spins on EOF.
4. Never leave a zombie: every spawned pid is waited for, including when the child dies on its own
   while the tab is open.

**On tab close with something running**

Terminal.app asks before closing a tab whose foreground process is not the shell. Do the same: compare
the PTY's foreground process group (`tcgetpgrp`) against the shell's pid, and confirm when they differ.
Losing an hour-long build to a stray ⌘W is the failure people remember.

**On app quit**

`applicationShouldTerminate` already exists for state flushing. Sessions must be torn down there, in
order, *before* the plugin is unloaded — a `dlclose`d library whose thread is still reading a fd is a
crash on exit. The plugin ABI's `PcCloseView` is the hook, and the host calls it from
`ViewContainerRegistry.refresh` and must also call it on shutdown. **Open: verify that it does today**
— if the process simply exits, nothing has ever noticed.

**On plugin disable / removal**

Same path as quit, plus: no processes may survive the plugin being switched off in Settings. Test this,
because it is exactly the case nobody tries.

**Guard**: a VM scenario that opens a tab, runs `sleep 300`, closes the tab, and then asks `ps` — an
independent witness, as with the sync and beacon scenarios — that no `sleep` remains.

---

## 6. "Comfort like you'd expect" — mostly not ours to build

Autocomplete, history, ⌃R search, syntax colouring of the command line: **these are the shell's, and we
must not reimplement them.** Running the user's real `$SHELL` as a login shell gives all of it for free
and correctly — their `.zshrc`, their completions, their prompt, their aliases. Anything we build
ourselves would be a worse `zsh`.

What is genuinely ours:

| Feature | Why it is ours |
|---|---|
| **Scrollback** with find (⌘F) | The emulator's buffer; the shell has no idea |
| **Copy/paste** incl. bracketed paste | So pasting a multi-line command does not execute it line by line |
| **⌘-click a path** to reveal it in the panel | The bridge to the file manager, which is the whole point |
| **Font and colours** from the app's theme | So it is not a beige box in a dark window |
| **Shell integration** (OSC 7, OSC 133) | Where the cwd sync and "jump to previous prompt" come from |

OSC 7 (the shell reporting its cwd) is what makes §7's "panel follows the terminal" work. It is one
line appended to the user's shell rc — which we must **offer, not do silently**: editing someone's
`.zshrc` behind their back is not acceptable. Offer it once, show the exact line, and let them decline
permanently.

---

## 7. Integration — the reason to embed rather than launch Terminal.app

Today `cm_OpenTerminal` runs `/usr/bin/open -a Terminal <dir>`
(`MainWindowController.openTerminalHere`). That stays for people who want the real thing. The embedded
one earns its place through the seams a separate app cannot reach:

**Directory, both ways**
- *Panel → terminal*: new tabs open in the active panel's directory; `cm_TerminalCdHere` sends `cd` to
  the focused session.
- *Terminal → panel*: with OSC 7 in place, the active panel follows the shell's cwd (opt-in, off by
  default — it is surprising the first time).

**Focus**
- One key toggles between panel and terminal and back to where the cursor was (⌃\` is the convention;
  the keymap decides). This is the single most-used integration and must be instant.
- The function-key bar shows terminal labels while the terminal has focus, so F3/F5 do not look armed
  when they are not.

**Selection**
- The panel's "copy names to the command line" gesture (⌃Return in TC) targets the focused terminal
  when the dock is open — properly quoted, through `ShellQuoting`, which already exists and is measured
  through a real shell.
- Dropping files onto the terminal inserts their quoted paths.

**Command line**
- The app's own command line gains an option: run in the embedded terminal instead of detached. Then
  output is visible and interactive commands work — `sudo` prompting for a password is the case that
  fails today.

**Context menu**
- On a folder: "Open in terminal" (new tab there). On a file: nothing — that is what F4 is for.

**AI assistant**
- `run_command` and shell-ish tools could run *visibly* in a terminal tab instead of a hidden process.
  That is a real safety improvement: the user sees what was run. It also interacts with the approval
  gate reworked earlier — worth its own decision, not a side effect.

---

## 8. Keyboard — the known trap

`PanelListView.performKeyEquivalent` carries this comment already:

> performKeyEquivalent is broadcast to every view in the window, so the panel would otherwise swallow
> Cmd+C/V/X/A (mapped to file-clipboard commands) even while the user is typing in the command line.

The existing fix special-cases `window?.firstResponder is NSText`. **A terminal view is not `NSText`,
so it walks straight into the same defect** — ⌘C in the terminal would copy files instead of
interrupting, F5 would start a copy instead of reaching `htop`.

The fix must be a general rule, not a second special case: the host asks the first responder whether it
wants raw keys (a protocol the panel, the command line and any plugin view can adopt), and
`performKeyEquivalent` steps aside when the answer is yes. That is a small host change and it removes a
class of bug rather than one instance.

Menu key equivalents are matched *before* the responder chain (the viewer hit this — see
`ListerWindow.copy`), so ⌘-anything bound in the menu bar will not reach the terminal. That is correct
macOS behaviour and matches Terminal.app; only the app's own non-⌘ bindings (F-keys, plain letters when
"always type to command line" is on) need the rule above.

---

## 9. Removability

* Everything terminal lives in `Plugins/Terminal/` and the built `Terminal.ptxplugin`.
* The host gains only *generic* pieces: the `bottom` container, the dock view, the raw-keyboard rule.
  With the plugin removed, the dock has nothing to show and stays hidden; the keyboard rule affects
  nobody.
* Plugin state (tabs, layout, scrollback limits) lives in the plugin's own file under the config root,
  so removing it leaves nothing in `peachcmd.ini` or `session.ini`.
* It joins `Tools/build-all-plugins.sh` and therefore `verify-shipping.sh`, which fails the release if a
  shipping plugin is missing from the set.

---

## 10. Risks, honestly

| Risk | Weight | What reduces it |
|---|---|---|
| SwiftTerm vendored — upstream fixes need manual pulls | Medium | Pin the commit, record it, revisit per release |
| Plugin build gets a large source list | Low | It is a script; measure the build time and state it |
| `dlclose` with live PTY threads → crash on quit | Low — see below | Do not export `PcSafeToUnload` |
| Orphaned processes | **High** — the host does not tear views down on quit today | Process-group signals, the `ps` scenario in §5, and a teardown hook in `applicationShouldTerminate` |
| Universal build: SwiftTerm must compile for x86_64 too | Medium | `verify-shipping.sh` already fails single-architecture binaries |
| Terminal steals keys the file manager needs (or vice versa) | Medium | §8's general rule, plus a scenario per direction |
| Scrollback memory with a chatty build | Low | A line cap, configurable, defaulted and measured |

**The three questions I had are answered, two of them from the code:**

1. **`PcCloseView` is not called on quit.** `applicationShouldTerminate` (`Sources/PCApp/main.swift`)
   awaits `persistNow()` and replies; nothing tears plugin views down. So today a terminal's children
   would be left to process exit — which is precisely how orphans happen. **The teardown hook in §5 is
   therefore host work, not something the plugin can arrange for itself**, and it belongs in stage 5.
2. **`dlclose` happens only if the plugin exports `PcSafeToUnload`** — `PluginLibrary` keeps the
   library resident otherwise, deliberately ("TC-like pragmatism: otherwise it stays resident to avoid
   unload crashes"). A terminal plugin simply does not export it. The unload crash risk drops to
   nothing; the price is that disabling the plugin frees its views but not its code until the next
   launch, which is the trade the host already makes for every other plugin.
3. **Font metrics measured** — see §2. The estimate was close (7 pt assumed, 6.80–7.42 measured) and
   the conclusion is unchanged.

---

## 11. Order of work

Each stage ends in something demonstrable, in the project's usual way — a measurement, not an opinion.
The first two stages are host work with no terminal in them at all, and §2a moved one of them forward:
the incremental refresh is a *prerequisite* for moving a view, not a refinement of it.

1. **Host: the `bottom` container and the dock.** No terminal. Mount the existing System Monitor view in
   it to prove the seam works, then take it out again. `cm_ToggleDock` on keyCode 50 + ⌃, a draggable
   height divider, `Layout.DockHeight` / `Layout.DockVisible`.
2. **Host: `refresh` and `setViewProviders` become incremental**, and re-parenting pushes
   `PcNotifyView(…, "container", …)`. Demonstrated by moving a mounted view between containers and
   showing that `PcCloseView` is *not* called — a plugin that counts its own make/close calls is the
   witness.
3. **Host: placement overrides + drag and drop + reset.** Only now, because 2 is what makes it safe.
4. **Host: the raw-keyboard rule** (§8), with the command line as the first beneficiary and a test that
   ⌘C in it does not copy files.
5. **Plugin skeleton**: manifest, `PcMakeView`, an empty view in both containers, in
   `build-all-plugins.sh`. Prove removability *before* there is anything to lose.
6. **SwiftTerm vendored + one session, no tabs.** Milestone: `top` renders and resizes correctly; `TERM`
   is what we actually implement.
7. **Lifecycle**: close, quit, disable, orphan scenario (§5). Before tabs, because tabs multiply it.
8. **Tabs**, then **split** (§3–4).
9. **Integration** (§7), in the order: focus toggle → cwd panel→terminal → paths/drop → OSC 7 → command
   line → AI.
10. **Comfort** (§6): scrollback find, theme, ⌘-click.

Stages 1–7 are where the risk is. Stages 8–10 are additive and can stop at any point with something
useful shipped.

---

## 12. The panels and the shell — observed twice, then not again

Honest status, because the first version of this section overstated it.

**What was seen.** In two runs of `terminal-session`, one screenshot showed both panels in the home
folder and one `dump` (which reports the *active* panel) said `/Users/admin` where the scenario had
opened `pc-demo`. A control scenario with the terminal moved out of the dock, so that no shell ever
starts, gave the opened folder three times out of three.

**What happened next.** Instrumentation was added — `panelsdump` reports both panels, which side is
active and who holds the keyboard, so that "the left panel navigated" can be told from "the right
panel became active". Six further runs, three sampling straight after the shell starts and three at
the end of the scenario after `top` has been running, all reported
`active=left left=…/pc-demo right=/Users/admin responder=TerminalSessionView`. It has not reproduced.

**So the claim is downgraded, not withdrawn.** Two sightings against six clean runs is not enough to
call it fixed, and not enough to call the shell guilty either: the control only showed that three runs
without a shell were clean, which six runs *with* one now match. SwiftTerm's `chdir` is in the child,
so the obvious mechanism was ruled out early.

A third sighting followed, again in a screenshot — the tabs scenario, left panel in the home folder.
`panelsdump` was added to that scenario too and answered `left=…/pc-demo` twice running, and the very
next screenshot of the same scenario showed `pc-demo` as well. So across three scenarios and eight
instrumented runs the model has been right every time, and every sighting has come from a run with no
instrumentation in it.

That is worth stating precisely: what has never been observed is the *panel path being wrong when
something was measuring it*. Whether the earlier screenshots caught a real transient or a state left
by a neighbouring scenario is still unknown.

What it is now is a **guarded** unknown, in two scenarios rather than one. A recurrence fails the suite
with the state written down — which panel, which side is active, what holds the keyboard — instead of
being noticed in a picture months later. That is the useful outcome available; hunting an intermittent
that will not appear under measurement is not.

---

## 13. The panel following the terminal — closed, and it was two faults

Both halves now work, and the way it was found is worth keeping.

The settings page carries one switch, off by default, and the exact lines the user must add to
`~/.zshrc` for the shell to report its folder at all — shown in a field they can select and copy, and
**never written by the app**. macOS ships an OSC 7 hook in `/etc/zshrc` guarded by
`[[ $TERM_PROGRAM == Apple_Terminal ]]`, so it fires for Apple's terminal and for nothing else.

It failed for two independent reasons, and the first one hid the second.

**The fixture never landed.** The hook had been woven into the setup's long
`printf … && printf … &&` chain, and its escapes did not survive python → ssh → sh → zsh. Every
attempt to diagnose this from *inside* the app came back empty, which looked like the feature failing.
An external check — asked of the guest over ssh, after the app was dead — answered `0` in one line.
The lesson is the general one: when the question is about the fixture, do not route it through the
thing whose behaviour is in doubt. The hook now goes in through a quoted here-document of its own.

**The payload was never parsed.** With the shell finally speaking, the terminal reported its directory
as `file://Manageds-Virtual-Machine.local/usr/lib` — SwiftTerm hands the sequence's contents over
verbatim, so parsing is the plugin's job, including percent-decoding (`%20` back to a space, which the
suggested hook emits). `URL` does it.

That raised a question worth answering deliberately rather than by accident: **a host that is not this
machine is refused.** An `ssh` session inside the terminal reports the *remote* working directory, and
steering the local panel to a path that happens to exist on both machines is the kind of quietly wrong
that costs somebody an afternoon.

The mutation separates the two concerns cleanly: with the switch off, the terminal still knows it is in
`/usr/lib` — the status line says so — and the panel stays where it was.
