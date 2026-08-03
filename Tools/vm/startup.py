#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""startup.py — film the first seconds after launch, frame by frame.

Why this exists
---------------
"Colour and layout seem to be applied a moment late, and for a few seconds something looks wrong" is a
complaint about a *transition*, and every instrument this project has so far measures a settled state:
regress.py waits for the window to calm down before it captures, precisely so its screenshots are
comparable. So the one thing nobody could see was the launch itself.

This boots a clean clone, starts the app, and captures the framebuffer every `--interval` seconds for
`--frames` frames. Nothing is judged automatically — the point is a strip of pictures a person can look
at, plus the app's own log with timestamps, so "a few seconds" becomes a number.

Usage
-----
    Tools/vm/startup.py [--app PATH] [--frames 14] [--interval 0.4] [--out DIR] [--keep]
                        [--config KEY=VALUE ...]

`--config` writes entries into the guest's peachcmd.ini before launching, so the interesting case can be
measured: a configuration that differs from the defaults is the only one where a late-applied setting is
visible at all.
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import regress  # noqa: E402  — boot(), ssh_guest(), parse_vnc() and the SSH options live there


def write_config(ip, entries):
    """Put `[Section] Key=Value` lines into the guest's config, one -c KEY=VALUE at a time."""
    sections = {}
    for entry in entries:
        key, _, value = entry.partition("=")
        section, _, name = key.partition(".")
        sections.setdefault(section, []).append(f"{name}={value}")
    body = "\n".join(f"[{s}]\n" + "\n".join(v) for s, v in sections.items())
    regress.ssh_guest(ip, f"mkdir -p ~/pc-cfg && cat > ~/pc-cfg/peachcmd.ini <<'PCEOF'\n{body}\nPCEOF")
    return body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app")
    ap.add_argument("--frames", type=int, default=14)
    ap.add_argument("--interval", type=float, default=0.4)
    ap.add_argument("--out", default=str(regress.REPO / "docs/generated/startup"))
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--config", action="append", default=[],
                    help="Section.Key=Value written to peachcmd.ini before launch")
    ap.add_argument("--expect", action="append", default=[],
                    help="key=value the startup probe must report; exits non-zero if it does not")
    args = ap.parse_args()

    app = regress.resolve_app(args.app)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    run = "pc-startup"
    ip, host, port, pw = regress.boot(app, run)

    try:
        if args.config:
            regress.say("config:\n" + write_config(ip, args.config))
        # Terminal is left alone: killing it in the golden image's auto-login session restarted the
        # whole guest, and the app's own window covers it as soon as it draws anyway.
        regress.ssh_guest(ip, "pkill -x PeachCommander; rm -f ~/pc-cfg/session.ini; sleep 1")
        # Launch and start capturing immediately: the frames before the window appears are part of the
        # measurement, because a window that appears late is a different complaint from one that
        # appears wrong.
        start = time.time()
        regress.ssh_guest(ip, "open ~/pc-test/PeachCommander.app --args "
                              "-ConfigRoot $HOME/pc-cfg -AppleLanguages '(en)' "
                              "-StartupProbe $HOME/startup-probe.txt &")
        for i in range(args.frames):
            shot = out / f"frame-{i:02d}.png"
            regress.sh([regress.VNCDO, "-s", f"{host}::{port}", "-p", pw, "capture", str(shot)])
            regress.say(f"frame {i:02d} at {time.time() - start:5.2f}s -> {shot.name}")
            time.sleep(max(0.0, args.interval))
        # The app's own timeline, so the pictures can be tied to what the code was doing.
        marks = regress.ssh_guest(ip, "log show --info --style compact --start "
                                      "\"$(date -v-2M '+%Y-%m-%d %H:%M:%S')\" "
                                      "--predicate 'process == \"PeachCommander\"' 2>/dev/null "
                                      "| head -60").stdout
        (out / "log.txt").write_text(marks)
        regress.say(f"log lines: {len(marks.splitlines())} -> {out / 'log.txt'}")

        # The probe is the actual gate. The pictures show *that* the window looks right once it
        # settles; only this shows what it looked like in the frame it first appeared in.
        probe = regress.ssh_guest(ip, "cat ~/startup-probe.txt 2>/dev/null").stdout
        (out / "probe.txt").write_text(probe)
        if not probe.strip():
            regress.say("probe: EMPTY — the app never wrote it (DEBUG build required)")
            return 1
        values = dict(line.split("=", 1) for line in probe.splitlines() if "=" in line)
        regress.say("probe:\n  " + "\n  ".join(f"{k}={v}" for k, v in values.items()))
        wrong = [(k, v, values.get(k)) for k, _, v in (e.partition("=") for e in args.expect)
                 if values.get(k) != v]
        for key, want, got in wrong:
            regress.say(f"probe: {key} is {got!r}, expected {want!r} — first frame was WRONG")
        if wrong:
            return 1
    finally:
        if not args.keep:
            regress.sh(["tart", "stop", run])
            regress.sh(["tart", "delete", run])
    regress.say(f"frames in {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
