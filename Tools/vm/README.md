# macOS VM test harness

Run Peach Commander inside a disposable macOS VM for deterministic, isolated
testing and clean screenshots — independent of the host display state.

## Why

- **Isolation / reset-to-snapshot** — each run starts from a pristine
  copy-on-write clone of a `golden` VM. State never leaks between runs.
- **Deterministic screenshots** — the VM has a dedicated, always-on framebuffer
  captured over VNC from the host. No `caffeinate -u`, no locked-display issues,
  no Screen-Recording (TCC) grant needed inside the guest.

## Stack

- [`tart`](https://tart.run) — CLI over Apple's Virtualization.framework
  (`brew install cirruslabs/cli/tart`). Apple Silicon only.
- Base image: `ghcr.io/cirruslabs/macos-tahoe-base` (macOS 26, matches host).
  Ships with SSH (`admin`/`admin`), auto-login, no screensaver.
- Host helpers: `sshpass` (one-time key install), `vncdotool` (framebuffer grab).

## Snapshots = clones

`tart` has no live snapshots; instead we keep a configured **golden** VM and
`tart clone golden run-N` per run (APFS copy-on-write — seconds, near-zero disk
until written). "Reset" = delete the clone and re-clone. This is *more* robust
than live snapshots for "every run starts clean".

## One-time setup

```sh
tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest golden   # big, one-time
Tools/vm/prepare-golden.sh golden                               # ssh key, no display sleep, Gatekeeper off
```

## Per test run

```sh
# build the Debug .app on the host (arm64), then:
Tools/vm/run-test.sh [--keep] [--script auto.txt] <path-to-.app> [out.png]
```

Steps: clone golden → boot with VNC → rsync `.app` into guest → launch (optionally
with the DEBUG `-AutomationScript` hook) → capture framebuffer via VNC → delete
clone. `--keep` leaves the clone running for interactive poking (`tart ip <run>`,
then SSH in with `~/.ssh/id_ed25519`).

## Notes

- The app is **built on the host** (Xcode is here) and only the `.app` is copied
  in — same arch (arm64), no Xcode needed in the guest.
- Screenshots come from the **hypervisor framebuffer** (VNC), so they work even
  before/without any TCC grant — the usual macOS screen-capture-permission trap.
- To drive UI, reuse the existing `-AutomationScript` verbs (see
  `MainWindowController.runAutomationScript`) or XCUITest.

## startup.py — the first seconds after launch

`regress.py` deliberately waits for a window to settle before capturing, so its
screenshots stay comparable. That made the launch itself the one thing nobody could
look at — and "colour and layout seem to be applied a moment late" is a complaint
about exactly that.

```sh
Tools/vm/startup.py --config Colors.Theme=norton --config Layout.CommandLine=0 \
                    --expect theme=norton --expect commandLine=false
```

`--config Section.Key=Value` writes the guest's `peachcmd.ini` before launching: a
configuration that differs from the defaults is the only one in which a late-applied
setting is visible at all.

The strip of frames is for looking at. The **gate** is `--expect`: the app is launched
with `-StartupProbe <file>` (DEBUG only), which records what the window looked like *at
the moment it was shown*, and any `--expect key=value` that disagrees fails the run.
Frames cannot do this job — the VNC framebuffer only refreshes on change, so everything
before the first paint captures as black.

Verified by breaking it: with the synchronous pre-paint apply removed, the probe
reported `theme=system`, `commandLine=true`, `panelsVertical=true`, `fontSize=13` —
every configured value still at its built-in default, which is the bug it exists to
catch.

Terminal is left running in the guest on purpose: killing it in the golden image's
auto-login session restarted the whole VM, and the app's own window covers it as soon
as it draws.
