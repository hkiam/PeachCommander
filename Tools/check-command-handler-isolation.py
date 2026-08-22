#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""check-command-handler-isolation.py — will a command handler still touch AppKit on the main thread?

`CommandRegistry.execute` is a nonisolated `async` method on an actor, so its continuation runs on the
cooperative pool. Every handler beyond it drives AppKit, so every handler has to be on the main actor
by the time it gets there. `CommandHandler` is declared `@MainActor` to say so — and that annotation
reaches only *half* of the handlers:

  * `handler: { ctx in ... }` — a closure LITERAL at the argument position infers main-actor isolation
    from the contextual type and hops on entry. Safe, and 112 registrations rely on it.
  * `handler: cm_Foo_handler` — a reference to a separately declared `func` keeps THAT function's own
    isolation. A nonisolated one stays nonisolated; converting it to a `@MainActor` function type
    inserts no hop. It runs wherever the registry's continuation happens to be.

That is not a hypothesis either. It killed the app in a user's session (F-435): `cm_SwitchHidSys`
reached `NSTableView.reloadData` from `com.apple.root.user-initiated-qos.cooperative` while the main
thread was drawing, and AppKit's layout engine raised an exception nobody catches. `cm_SwitchPanel`
was doing the same thing to `NSMenu.itemArray` and had been showing the wrong panel content for a
while before anything crashed.

The compiler will not catch the next one. The project builds in the Swift 5 language mode, where
crossing an isolation boundary is a warning; worse, the warning for a *conformance* is only emitted
for types annotated `@MainActor` explicitly, and `MainWindowController` inherits its isolation from
`NSWindowController` — so the conformance that actually crashed produced no diagnostic at all.

So the rule is held mechanically, and it is three rules:

  1. every named `cm_*_handler` func carries its own `@MainActor`,
  2. `WindowControllerProtocol` is `@MainActor` — its synchronous requirements have nowhere to hop
     otherwise,
  3. `CommandHandler` is still `@MainActor`, or the closure-literal half loses its isolation too.

Usage: Tools/check-command-handler-isolation.py
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
SRC_PATH = REPO / "Sources/PCCommands/PCCommands.swift"
SRC = SRC_PATH.read_text()
REL = SRC_PATH.relative_to(REPO)

lines = SRC.split("\n")
problems = 0

# ---- 1. Every named handler func is main-actor-isolated in its own right.
HANDLER = re.compile(r"^\s*(?:private |public )?(?:static )?func ([A-Za-z0-9_]+_handler)\s*\(")
handlers = 0
for i, line in enumerate(lines):
    m = HANDLER.match(line)
    if not m:
        continue
    handlers += 1
    # The attribute sits on its own line directly above the declaration, past any doc comment.
    j = i - 1
    while j >= 0 and (lines[j].strip().startswith("///") or lines[j].strip().startswith("//")):
        j -= 1
    if j < 0 or lines[j].strip() != "@MainActor":
        print(f"{REL}:{i + 1}: {m.group(1)} is not @MainActor — it will run on the cooperative "
              f"pool and touch AppKit off the main thread (F-435)")
        problems += 1

if handlers == 0:
    print(f"{REL}: found no *_handler funcs at all — this check has stopped checking anything")
    problems += 1

# ---- 2. The protocol whose witnesses are synchronous.
for proto in ("WindowControllerProtocol",):
    m = re.search(r"^(.*)\npublic protocol " + proto + r"\b", SRC, re.M)
    if not m:
        print(f"{REL}: protocol {proto} not found — check needs updating")
        problems += 1
    elif m.group(1).strip() != "@MainActor":
        print(f"{REL}: protocol {proto} is not @MainActor — a synchronous nonisolated witness has "
              f"nowhere to hop and runs main-actor code on the caller's thread (F-435)")
        problems += 1

# ---- 3. The typealias that carries the closure-literal half.
if not re.search(r"public typealias CommandHandler = @MainActor ", SRC):
    print(f"{REL}: CommandHandler is no longer a @MainActor function type — the 112 inline "
          f"`handler:` closures lose their isolation with it (F-435)")
    problems += 1

print(f"handlers={handlers} problems={problems}")
sys.exit(1 if problems else 0)
