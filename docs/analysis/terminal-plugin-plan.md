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

The brief says *fully removable*, and that decides it: **vendored**. The cost is honest — SwiftTerm's
sources are pinned in the repository, and picking up upstream fixes is a deliberate update rather than
a version bump. Record the commit it came from next to the sources.

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

1. **Host: the `bottom` container and the dock.** No terminal. Mount the existing System Monitor view
   in it to prove the seam works, then take it out again.
2. **Host: the raw-keyboard rule.** Fix the class of bug from §8, with the command line as the
   first beneficiary and a test that ⌘C in it does not copy files.
3. **Plugin skeleton**: manifest, `PcMakeView`, an empty view in both containers, in
   `build-all-plugins.sh`. Prove removability *before* there is anything to lose.
4. **SwiftTerm vendored + one session, no tabs.** Milestone: `top` renders and resizes correctly;
   `TERM` is what we actually implement.
5. **Lifecycle**: close, quit, disable, orphan scenario (§5). Before tabs, because tabs multiply it.
6. **Tabs**, then **split** (§3–4).
7. **Integration** (§7), in the order: focus toggle → cwd panel→terminal → paths/drop → OSC 7 → command
   line → AI.
8. **Comfort** (§6): scrollback find, theme, ⌘-click.

Stages 1–5 are where the risk is. Stages 6–8 are additive and can stop at any point with something
useful shipped.
