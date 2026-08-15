#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""capture.py — reproducible documentation screenshots via the VM harness.

Reads docs/metadata/screenshot-specs.yml, boots a throwaway macOS VM (a clone of
the golden image), deploys the Debug .app + a consistent demo tree, then cycles
the app through each screenshot state using the DEBUG -AutomationScript hook and
captures the hypervisor framebuffer over VNC (light and, where asked, dark).
Detail crops are cut from the full shot. Every image is registered in
docs/metadata/screenshot-index.yml so it can be regenerated on a new release.

This is the standing method for ALL documentation screenshots (DOCUMENTATION.md §5).

Usage:
  python3 Tools/vm/capture.py [--only id1,id2] [--app PATH] [--keep]
"""
from __future__ import annotations
import argparse, os, re, subprocess, sys, time
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit("need pyyaml: python3 -m pip install --user pyyaml")

REPO = Path(__file__).resolve().parents[2]
SHOTS = REPO / "docs/assets/screenshots"
CROPS = REPO / "docs/assets/crops"
SPECS = REPO / "docs/metadata/screenshot-specs.yml"
INDEX = REPO / "docs/metadata/screenshot-index.yml"
KEY = str(Path.home() / ".ssh/id_ed25519")
SSH = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
       "-o", "LogLevel=ERROR", "-i", KEY]
VNCDO = os.environ.get("VNCDO", str(Path.home() / "Library/Python/3.9/bin/vncdo"))
GOLDEN = "golden"
GUEST = "admin"
APPNAME = "PeachCommander.app"


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def resolve_app(explicit):
    if explicit:
        return explicit
    # The repository's own build directory first. `Tools/build.sh` (and every run in this project) builds
    # with `-derivedDataPath build`, while asking xcodebuild below answers with the *default* DerivedData
    # location — a different bundle, quite possibly an old one. That cost three screenshots: the guest ran
    # an app without the verbs the spec was using, so the script silently did nothing and the shot showed
    # whatever state the app happened to be in.
    local = REPO / "build/Build/Products/Debug" / APPNAME
    if local.exists():
        return str(local)
    r = sh(["xcodebuild", "-project", str(REPO / "PeachCommander.xcodeproj"),
            "-scheme", "PeachCommander", "-configuration", "Debug", "-showBuildSettings"])
    for line in r.stdout.splitlines():
        if "BUILT_PRODUCTS_DIR" in line:
            d = line.split("=", 1)[1].strip()
            return str(Path(d) / APPNAME)
    sys.exit("could not resolve built .app; pass --app")


def ssh_guest(ip, script):
    return sh(["ssh", *SSH, f"{GUEST}@{ip}", script])


def wait_ip(vm, timeout=120):
    for _ in range(timeout // 2):
        r = sh(["tart", "ip", vm])
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
        time.sleep(2)
    sys.exit(f"no IP for {vm}")


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


def vnc_capture(host, port, pw, out: Path):
    out.parent.mkdir(parents=True, exist_ok=True)
    r = sh([VNCDO, "-s", f"{host}::{port}", "-p", pw, "capture", str(out)])
    return r.returncode == 0


"""A demo user theme, installed into the guest's themes/ folder.

Deliberately unlike any shipped palette — a green phosphor look nothing in the app offers — so the
screenshot of it cannot be mistaken for a built-in theme. It names a dozen colours and inherits the
rest from `Base = dark`, which is the case a theme author actually hits. Its id must also stay off
`Theme.reservedPaletteIds`: the earlier "midnight" became a shipped palette, and a user file by
that name is (correctly) skipped.
"""
USER_THEME = """[Theme]
Name = My Terminal
Base = dark

[Colors]
WindowBackground          = #0A140A
ListBackground            = #0E1A0E
ListText                  = #7FE07F
SelectedText              = #FFC24A
SelectionFillActive       = #1F5C1F
ActiveCursorFrame         = #66FF66
CursorRowText             = #E8FFE8
ActivePathBarBackground   = #1F5C1F
ActivePathBarText         = #E8FFE8
InactivePathBarBackground = #12220F
InactivePathBarText       = #6FA06F
StatusBarBackground       = #143014
StatusBarText             = #A8E0A8
FunctionButtonBackground  = #143014
FunctionButtonText        = #A8E0A8
TabBarBackground          = #0E1A0E
TabBarActiveChip          = #1F5C1F
TabBarInactiveChip        = #142814
TabBarChipText            = #6FA06F
TabBarActiveChipText      = #E8FFE8
"""


def setup_guest(ip):
    # Force each theme deterministically via the app's own config (-ConfigRoot),
    # not the OS appearance (a relaunched process won't pick that up live).
    # Also hide the Dock so it never intrudes on a capture.
    for theme in ("light", "dark"):
        ssh_guest(ip, f"mkdir -p ~/pc-cfg-{theme} && "
                      f"printf '[Colors]\\nAppearance={theme}\\n' > ~/pc-cfg-{theme}/peachcmd.ini")
    # A user theme file, so a spec can show that themes are extensible — and so the
    # "drop an .ini into themes/ and it shows up" path is exercised by the harness rather than
    # only by unit tests. Installed state, like the demo tree from demo-content.sh, which is why
    # the per-launch reset below leaves themes/ alone.
    for theme in ("light", "dark"):
        ssh_guest(ip, f"mkdir -p ~/pc-cfg-{theme}/themes && "
                      f"cat > ~/pc-cfg-{theme}/themes/my-terminal.ini <<'PCTHEME'\n{USER_THEME}\nPCTHEME")
    ssh_guest(ip, "defaults write com.apple.dock autohide -bool true; "
                  "defaults write com.apple.dock autohide-delay -float 999; killall Dock 2>/dev/null || true")
    # Force the GUEST's system locale to English. Plugin bundles resolve their
    # NSLocalizedString against the OS preferred languages (they ignore the host
    # app's -AppleLanguages), so a German golden VM otherwise renders plugin
    # windows (e.g. System Monitor) in German. killall cfprefsd so processes we
    # launch afterwards read the new global.
    ssh_guest(ip, "defaults write -g AppleLanguages '(\"en-US\", \"en\")'; "
                  "defaults write -g AppleLocale 'en_US'; "
                  "killall cfprefsd 2>/dev/null || true")


def flatten(lines):
    # YAML anchors (e.g. a shared &main preamble) can nest a list inside the
    # script list; flatten one level so every element is a verb string.
    out = []
    for x in lines:
        out.extend(x) if isinstance(x, list) else out.append(x)
    return out


def launch_app(ip, script_lines, theme):
    # write the automation script into the guest, kill any running app, relaunch
    body = "\n".join(flatten(script_lines))
    ssh_guest(ip, f"cat > ~/pc-demo-auto.txt <<'PCEOF'\n{body}\nPCEOF")
    cfg = f"/Users/{GUEST}/pc-cfg-{theme}"
    # Reset per-panel/session state so every shot starts from defaults (details view, default
    # window): the persisted session.ini must not leak view mode / dirs between specs.
    #
    # peachcmd.ini is *rewritten*, not kept. A spec that changes a setting through the app — the
    # `theme` verb does exactly that, on purpose, so the shot shows the real code path — persists it
    # here, and the next spec would inherit it. Regenerating the file is what keeps every spec
    # independent, which is the whole promise of this harness.
    # themes/ survives on purpose: it is installed state, not per-spec state.
    ssh_guest(ip, f"rm -f {cfg}/session.ini {cfg}/workspaces.ini && "
                  f"printf '[Colors]\\nAppearance={theme}\\n' > {cfg}/peachcmd.ini")
    ssh_guest(ip, "pkill -x PeachCommander 2>/dev/null; sleep 1; "
                  "killall Terminal 2>/dev/null; "
                  f"open ~/pc-test/{APPNAME} --args -ConfigRoot {cfg} "
                  f"-AppleLanguages '(en)' "
                  f"-AutomationScript /Users/{GUEST}/pc-demo-auto.txt")


def crop(img: Path, region, out: Path):
    try:
        from PIL import Image
    except ImportError:
        print("  ! PIL not installed; skipping crop", file=sys.stderr)
        return False
    out.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(img)
    x, y, w, h = region
    im.crop((x, y, x + w, y + h)).save(out)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated screenshot ids")
    ap.add_argument("--app", help="path to built .app")
    ap.add_argument("--keep", action="store_true")
    args = ap.parse_args()

    specs = yaml.safe_load(SPECS.read_text())["screenshots"]
    if args.only:
        want = set(args.only.split(","))
        specs = [s for s in specs if s["id"] in want]
    if not specs:
        sys.exit("no matching specs")
    app = resolve_app(args.app)
    if not Path(app).is_dir():
        sys.exit(f"no .app at {app}")

    run = f"pc-cap-{os.getpid()}"
    sh(["tart", "clone", GOLDEN, run])
    logf = Path(f"/tmp/tart-{run}.log")
    # `--no-graphics` too: the VNC flag on its own makes tart *open* the vnc:// URL, and the Screen
    # Sharing window it launches is never closed — they pile up, one per run. The VNC server stays,
    # so the screenshots are unaffected (see the note in regress.py).
    proc = subprocess.Popen(["tart", "run", run, "--vnc-experimental", "--no-graphics"],
                            stdout=open(logf, "w"), stderr=subprocess.STDOUT)
    index_rows = []
    try:
        host, port, pw = parse_vnc(logf)
        ip = wait_ip(run)
        print(f"VM {run} ip={ip} vnc={host}:{port}")
        for _ in range(60):
            if ssh_guest(ip, "true").returncode == 0:
                break
            time.sleep(2)
        # deploy app + demo content
        sh(["rsync", "-a", "--delete", "-e", "ssh " + " ".join(SSH),
            f"{app}/", f"{GUEST}@{ip}:pc-test/{APPNAME}/"])
        ssh_guest(ip, "xattr -dr com.apple.quarantine ~/pc-test 2>/dev/null || true")
        sh([str(REPO / "Tools/vm/demo-content.sh"), ip])
        setup_guest(ip)

        for s in specs:
            sid = s["id"]
            themes = ["dark"] if s.get("dark_only") else (["light", "dark"] if s.get("dark") else ["light"])
            for theme in themes:
                launch_app(ip, s["script"], theme)
                time.sleep(s.get("settle", 9))
                suffix = "" if theme == "light" else "-dark"
                out = SHOTS / f"{sid}{suffix}.png"
                if vnc_capture(host, port, pw, out):
                    # For a crop spec, the referenced image (screenshots/<id>.png)
                    # IS the cropped detail; keep the full framebuffer as -full.
                    if s.get("crop"):
                        full = SHOTS / f"{sid}{suffix}-full.png"
                        out.replace(full)
                        if crop(full, s["crop"], out):
                            print(f"  ✓ {out.relative_to(REPO)} (crop)")
                    else:
                        print(f"  ✓ {out.relative_to(REPO)}")
                    index_rows.append({
                        "id": sid + suffix, "path": str(out.relative_to(REPO)),
                        "feature": s.get("feature", sid), "pages": s.get("pages", []),
                        "theme": theme, "language": "en", "app_version": "0.1.0",
                        "status": "captured",
                        "alt": s.get("alt", sid), "caption": s.get("caption", ""),
                    })
                else:
                    print(f"  ! capture failed for {sid} ({theme})", file=sys.stderr)
    finally:
        proc.terminate()
        if not args.keep:
            sh(["tart", "delete", run])
            print(f"clone {run} removed")

    # merge into screenshot-index.yml
    existing = {}
    if INDEX.exists():
        doc = yaml.safe_load(INDEX.read_text()) or {}
        for row in (doc.get("screenshots") or []):
            existing[row["id"]] = row
    for row in index_rows:
        existing[row["id"]] = row
    INDEX.write_text("# Screenshot registry (see DOCUMENTATION.md §5). Regenerate via Tools/vm/capture.py.\n"
                     + yaml.safe_dump({"screenshots": list(existing.values())}, sort_keys=False, allow_unicode=True))
    print(f"indexed {len(index_rows)} images -> {INDEX.relative_to(REPO)}")


if __name__ == "__main__":
    main()
