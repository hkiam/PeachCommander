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
    ("preview-panel", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                       "cmd cm_PreviewPanel", "wait 1500"], 9),
    ("find-files", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                    "findtab 0", "wait 2000"], 10),
    ("settings", ["active left", "left /Users/admin", "wait 1000",
                  "settingspage Layout", "wait 2500"], 10),
    ("viewer-text", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                     "focus notes.txt", "wait 500", "cmd cm_List", "wait 2000"], 10),
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
    subprocess.Popen(["tart", "run", run, "--vnc-experimental"],
                     stdout=log.open("w"), stderr=subprocess.STDOUT)
    host, port, pw = parse_vnc(log)
    ip = wait_ip(run)
    for _ in range(60):
        if ssh_guest(ip, "true").returncode == 0:
            break
        time.sleep(2)
    say(f"guest {ip}, VNC {host}:{port}")

    sh(["rsync", "-a", "--delete", "-e", "ssh " + " ".join(SSH),
        app.rstrip("/") + "/", f"{GUEST}@{ip}:pc-test/{APPNAME}/"])
    sh(["scp", *SSH, str(Path(__file__).with_name("regress-guest.sh")), f"{GUEST}@{ip}:regress-guest.sh"])
    ssh_guest(ip, "chmod +x regress-guest.sh")
    # A small, fixed demo tree: the scenarios need something to show, and it must not vary between
    # runs or the screenshots become impossible to compare.
    ssh_guest(ip, "mkdir -p pc-cfg pc-demo/sub && "
                  "printf 'notes, for the viewer scenario\\n' > pc-demo/notes.txt && "
                  "printf 'a,b\\n1,2\\n' > pc-demo/table.csv && "
                  "printf 'x' > pc-demo/sub/nested.txt && "
                  "printf '[Colors]\\nAppearance=dark\\n' > pc-cfg/peachcmd.ini && "
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
    text = ssh_guest(ip, f"./regress-guest.sh {name} {settle}").stdout
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
    ap.add_argument("--only", help="run one scenario by name")
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
            if args.only and name != args.only:
                continue
            found, a11y = run_scenario(ip, host, port, pw, name, script, settle, out)
            measured[name] = found
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
