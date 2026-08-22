---
title: Automation (AppleScript & Shortcuts)
slug: automation
group: Using Peach Commander
section: Power tools
order: 98
related: [start-menu, settings]
---

Peach Commander is scriptable, so you can drive it from AppleScript and from the Shortcuts app. A handful of core verbs let a script navigate the panels, select files by a mask, copy or move the current selection, and run any Peach Commander command by its id — reusing exactly the same actions the menus use, so a scripted step behaves like a manual one. It's handy for repetitive chores: filing downloads, staging a build's output, or wiring a file step into a larger Shortcut.

## See the dictionary

1. Open **Script Editor** (in `/Applications/Utilities`).
2. Choose **Window ▸ Library**, then double-click **Peach Commander** (add it with **+** if it isn't listed).
3. The dictionary opens, listing the commands and properties below.

The first time a script controls Peach Commander, macOS asks you to allow it (**System Settings ▸ Privacy & Security ▸ Automation**). Approve it once and later scripts run without prompting.

## What you can read

| Property | Meaning |
| --- | --- |
| `active folder` | POSIX path of the active panel's folder. |
| `inactive folder` | POSIX path of the other panel's folder. |
| `selection paths` | The selected items in the active panel (or the item under the cursor). |

## The verbs

| Command | What it does |
| --- | --- |
| `go to "<path>" [in left\|right]` | Open a folder in a panel (default: the active panel). |
| `select "<mask>"` | Select items in the active panel by a wildcard mask, e.g. `*.pdf`. |
| `copy items to "<folder>"` | Copy the active panel's selection to a folder. |
| `move items to "<folder>"` | Move the active panel's selection to a folder. |
| `run command "<id>"` | Run any command by its id, e.g. `cm_PackFiles`. |

Copy and move use the same background transfer queue as F5/F6, so progress and any overwrite prompts appear exactly as they do for a manual operation.

## Example

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Using it from Shortcuts

In the **Shortcuts** app, add the **Run AppleScript** action and paste a script like the one above. That lets you fold a Peach Commander step into a larger Shortcut — for example, triggered by a folder change or a hotkey.

## Notes

- The command id you pass to `run command` is the same `cm_*` id shown in the command browser (see [The Start menu & custom commands](start-menu.md)).
- Scripting always acts on the **active** panel; use `go to … in left` / `in right` first if you need a specific side.
- Peach Commander is a single-window app, so scripts target that window's two panels.
