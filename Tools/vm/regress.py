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
    ("keys-editorwin", ["active left", "left /Users/admin/pc-demo", "wait 1200",
                        "editdump /Users/admin/pc-demo/notes.txt /Users/admin/ed.txt", "wait 1800",
                        "keyloop /Users/admin/keyloop-editorwin.txt",
                        "a11ydump /Users/admin/a11y-editorwin.txt", "wait 500"], 11),
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
    "sftp-attributes": ("stat -f %Lp ~/sftp-demo/perm.txt", "600"),
    # The downloaded file must be byte-identical to the original — asked of `cmp`, not of the downloader.
    "sftp-download": ("cmp -s ~/sftp-demo/big.txt ~/got.txt && echo identical || echo differs",
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
    "keys-editorwin": ["keyloop-editorwin.txt", "a11y-editorwin.txt"],
    "keys-hotlist": ["keyloop-hotlist.txt", "a11y-hotlist.txt"],
    "keys-overwrite": ["keyloop-overwrite.txt"],
}

REPORTS = {
    "editor-filter": ("/Users/admin/filter.txt",
                      ["outcome=replaced", "undo=true", "alpha.example\nbeta.example\n"]),
    # The file must be in the listing afterwards — and, so the check cannot pass for the wrong reason,
    # absent before it was created (an expectation starting with "!" must NOT appear).
    "panel-autorefresh": ("/Users/admin/watch-after.txt", ["auto-appeared.txt"]),
    "sftp-attributes": ("/Users/admin/sftp.txt", ["requested=600", "applied=ok"]),
    # 40960 bytes whole; then only the tail after 10000 travels.
    "sftp-download": ("/Users/admin/sftpget.txt", ["full=40960", "resumedAt=10000", "tail=30960"]),
    "panel-autorefresh-before": ("/Users/admin/watch-before.txt", ["!auto-appeared.txt"]),
    # CRLF in, CRLF out — shown as <CR> so a terminator that vanished is visible in the report.
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
    # An SFTP target for the attribute scenario (F-364): the guest talks to its own sshd, authenticating
    # with a key it generates for itself. Nothing types a password, and the app picks the key up from
    # ~/.ssh/id_ed25519 on its own.
    ssh_guest(ip, "test -f ~/.ssh/id_ed25519 || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519; "
                  "grep -qf ~/.ssh/id_ed25519.pub ~/.ssh/authorized_keys 2>/dev/null || "
                  "cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys; "
                  "chmod 600 ~/.ssh/authorized_keys; "
                  "mkdir -p ~/sftp-demo && printf 'x' > ~/sftp-demo/perm.txt && "
                  "chmod 644 ~/sftp-demo/perm.txt; "
                  # 40 KB of known content: more than one 64 KB read would be silly, less than one is
                  # what a single-chunk transfer looks like — enough to tell a tail from a whole file.
                  "python3 -c \"open('$HOME/sftp-demo/big.txt','w').write('peach'*8192)\"; true")
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
                    "--menu", str(out / "menu.txt")])
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
