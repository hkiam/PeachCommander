#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-hotkeys.py — are the shortcuts plausible, or do they quietly shadow each other?

`check-keymap.sh` answers "does every command named in a scheme exist". It says nothing about *keys*,
and a key bound twice is the failure nobody notices: AppKit picks one and the other binding is simply
dead. The help even documented one such case (Cmd+Shift+D for both "Download from URL" and Go ▸ Desktop),
which is what prompted this.

Four questions, each about a different way a shortcut can be a lie:

  1. Is a key bound to two different commands *within* one scheme file? One of them never fires.
  2. Does a scheme binding collide with a menu-bar key equivalent for a different command? The menu is
     offered the key first, so the scheme entry is dead — and it is the scheme the user edited.
  3. Do two menu items share a key equivalent? AppKit takes the first in menu order.
  4. Is a shortcut one macOS keeps for itself (Cmd+Tab, Cmd+Space, ⌥⌘Esc …)? Then it never arrives.

The menu side is read from a dump of the **running** menu bar (`menudump`, produced by Tools/vm/regress.py)
rather than from the source: what is bound is what the built menu says, not what the code seems to say.

Usage:
    Tools/check-hotkeys.py [--menu docs/generated/layout-regression/menu.txt]
"""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCHEMES = [REPO / "Sources/PCApp/Resources/keymap-tc-classic.ini",
           REPO / "Sources/PCApp/Resources/keymap-macos.ini"]
DEFAULT_MENU = REPO / "docs/generated/layout-regression/menu.txt"

# Combinations macOS reserves; an app can bind them and they will not arrive (or will do the system's
# thing as well). Spelled in the schemes' own notation.
RESERVED = {
    "W+TAB": "macOS app switcher",
    "W+SPACE": "Spotlight",
    "W+S+TAB": "macOS app switcher (backwards)",
    "C+W+SPACE": "Character Viewer",
    "A+W+ESC": "Force Quit",
    "C+W+Q": "lock screen",
    # The whole Ctrl+F1…F8 range belongs to Full Keyboard Access, which is exactly what a keyboard-only
    # user has switched on — so these are the shortcuts that fail for the people who need them most.
    "C+F1": "Full Keyboard Access toggle",
    "C+F2": "menu-bar focus (Full Keyboard Access)",
    "C+F3": "Dock focus (Full Keyboard Access)",
    "C+F4": "window focus (Full Keyboard Access)",
    "C+F5": "toolbar focus (Full Keyboard Access)",
    "C+F6": "focus next window/panel (Full Keyboard Access)",
    "C+F7": "keyboard-navigation mode (Full Keyboard Access)",
    "C+F8": "status-menu focus (Full Keyboard Access)",
}

# Decisions, not oversights. Each entry says which check it silences and why, so the next reader can
# disagree with the reason rather than wonder whether anybody noticed.
# Items macOS injects into any menu titled "Edit". They are not ours, their shortcuts come from the
# user's system settings, and nothing in this repository can rebind them.
SYSTEM_INJECTED = {"AutoFill", "Start Dictation…", "Start Dictation...", "Emoji & Symbols"}

ACCEPTED = {
    ("keymap-tc-classic", "C+F1"): "faithful Total Commander mapping; taken by macOS keyboard navigation "
                                   "when that is on — the macOS scheme uses Cmd+1/2/3 instead",
    ("keymap-tc-classic", "C+F2"): "as above",
    ("keymap-tc-classic", "C+F3"): "as above",
    ("keymap-tc-classic", "C+F4"): "as above",
    ("keymap-tc-classic", "C+F5"): "as above",
    ("keymap-tc-classic", "C+F6"): "as above",
    ("keymap-tc-classic", "C+F8"): "as above",
    # The Edit menu reaches the same command through the responder chain (PanelListView.copy(_:) runs
    # cm_CopyToClipboard), so the scheme entry and the menu item do one and the same thing.
    # The menu inherits its shortcuts from the active scheme (KeymapMenu.apply), so the default
    # TC Classic scheme puts the Ctrl+F row on these items too. The commands stay reachable from the
    # menu itself — Ctrl+F2 focuses the menu bar, which is how a keyboard user gets there anyway — and
    # the macOS scheme offers Cmd+1/2/3.
    ("menu", "C+F1"): "View ▸ Brief, from the TC Classic scheme; see the scheme entries above",
    ("menu", "C+F2"): "View ▸ Full, from the TC Classic scheme",
    ("menu", "C+F8"): "View ▸ Tree, from the TC Classic scheme",
    ("keymap-macos", "W+C"): "Edit ▸ Copy routes to the same command via the responder chain",
    ("keymap-macos", "W+X"): "Edit ▸ Cut routes to the same command",
    ("keymap-macos", "W+V"): "Edit ▸ Paste routes to the same command",
    ("keymap-macos", "W+A"): "Edit ▸ Select All routes to the same command",
    ("keymap-tc-classic", "W+C"): "as above",
    ("keymap-tc-classic", "W+X"): "as above",
    ("keymap-tc-classic", "W+V"): "as above",
    ("keymap-tc-classic", "W+A"): "as above",
}

MODIFIER_ORDER = ["C", "A", "S", "W"]


def canonical(token: str) -> str:
    """One spelling for a shortcut, so both sides can be compared.

    Modifiers sorted into a fixed order, the key uppercased. `S` is dropped for a letter written in
    upper case, because a menu item's key equivalent expresses Shift that way and a scheme file with
    `S+` means the same thing.
    """
    parts = [p.strip() for p in token.strip().split("+") if p.strip()]
    if not parts:
        return ""
    key = parts[-1].upper()
    mods = {p.upper() for p in parts[:-1]}
    return "+".join([m for m in MODIFIER_ORDER if m in mods] + [key])


def read_scheme(path: Path) -> dict:
    """key -> [commands] for one scheme file."""
    bindings = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line[0] in ";#[":
            continue
        if "=" not in line:
            continue
        key, _, command = line.partition("=")
        key, command = canonical(key), command.strip()
        if not key or not command:
            continue
        bindings.setdefault(key, []).append(command)
    return bindings


MENU_ITEM = re.compile(r"^  (?P<title>.*?)(?:  \[(?P<cmd>cm_\w+)\])?(?:  key=(?P<key>\S+))?"
                       r"(?P<disabled>  disabled)?$")


def read_menu(path: Path):
    """(key -> [(menu, title, command)]) from a dump of the running menu bar."""
    if not path.exists():
        return None
    items, menu = {}, "?"
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            menu = line[2:].strip()
            continue
        if line.strip() == "----" or not line.startswith("  "):
            continue
        m = MENU_ITEM.match(line)
        if not m or not m.group("key"):
            continue
        if m.group("title").strip() in SYSTEM_INJECTED:
            continue
        items.setdefault(canonical(m.group("key")), []).append(
            (menu, m.group("title").strip(), m.group("cmd") or ""))
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--menu", default=str(DEFAULT_MENU),
                    help="dump of the running menu bar (Tools/vm/regress.py writes it)")
    args = ap.parse_args()

    problems, notes, accepted = [], [], []
    schemes = {path.stem: read_scheme(path) for path in SCHEMES}

    def report(scheme: str, key: str, message: str):
        """A finding, unless it is a recorded decision."""
        if (scheme, key) in ACCEPTED:
            accepted.append(f"{scheme}: {key} — {ACCEPTED[(scheme, key)]}")
        else:
            problems.append(message)

    for name, bindings in schemes.items():
        for key, commands in sorted(bindings.items()):
            unique = sorted(set(commands))
            if len(unique) > 1:
                report(name, key,
                       f"{name}: {key} is bound to {', '.join(unique)} — one of them never fires")
            elif len(commands) > 1:
                notes.append(f"{name}: {key} is listed {len(commands)} times for {unique[0]}")
            if key in RESERVED:
                report(name, key, f"{name}: {key} is {RESERVED[key]} — the app never sees it "
                                  f"(bound to {unique[0]})")

    menu = read_menu(Path(args.menu))
    if menu is None:
        notes.append(f"no menu dump at {args.menu} — run Tools/vm/regress.py to compare against the "
                     f"menu bar (checks 3 and 4 skipped)")
    else:
        for key, entries in sorted(menu.items()):
            if len(entries) > 1:
                where = "; ".join(f"{m} ▸ {t}" for m, t, _ in entries)
                report("menu", key,
                       f"menu: {key} is on {len(entries)} items — AppKit takes the first: {where}")
            if key in RESERVED:
                report("menu", key,
                       f"menu: {key} is {RESERVED[key]} — {entries[0][0]} ▸ {entries[0][1]} "
                       f"never receives it")
        # A scheme binding shadowed by a menu item for a *different* command.
        for name, bindings in schemes.items():
            for key, commands in sorted(bindings.items()):
                for menu_name, title, menu_cmd in menu.get(key, []):
                    if menu_cmd and menu_cmd in commands:
                        continue        # same command, two routes — that is how it should be
                    report(name, key,
                           f"{name}: {key} → {commands[0]} is shadowed by the menu item "
                           f"{menu_name} ▸ {title}" + (f" [{menu_cmd}]" if menu_cmd else ""))

    for line in accepted:
        print(f"  accepted: {line}")
    for line in notes:
        print(f"  note: {line}")
    for line in problems:
        print(f"  ⚠️  {line}")
    total = sum(len(b) for b in schemes.values())
    print(f"schemes={len(schemes)} bindings={total} "
          f"menu_shortcuts={0 if menu is None else sum(len(v) for v in menu.values())} "
          f"accepted={len(accepted)} problems={len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
