---
title: Automation (AppleScript & Shortcuts)
slug: automation
group: Using Peach Commander
section: Power tools
order: 98
related: [start-menu, settings, macros]
---

Automation here works in both directions.

**Out:** Peach Commander is scriptable, so you can drive it from AppleScript and from the Shortcuts app. A handful of core verbs let a script navigate the panels, select files by a mask, copy or move the current selection, and run any Peach Commander command by its id — reusing exactly the same actions the menus use, so a scripted step behaves like a manual one. That is the rest of this page.

**In:** Peach Commander can also *run* a script of yours — AppleScript or JavaScript — and put it on a menu, a button or a key. That needs the **Scripting** plugin, which ships switched off; see [Running your own scripts](#running-your-own-scripts) below.

For repeating a *sequence* of file actions rather than one, see [Macros](macros.md).

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

## Running your own scripts

The other direction: a script of yours, run by Peach Commander.

This is a plugin, and it ships **switched off**, because running a program of your choosing can do everything the rest of the app can and several things none of it covers. Two switches, both off until you set them:

1. **Configuration ▸ Plugins…** — enable **Scripting**.
2. **Settings ▸ AI** — turn on **Let scripts run**. It is on that page because it is the same kind of permission as the assistant's shell, and both live together.

Then put a script in `scripts/` inside your configuration folder — **Commands ▸ Open Scripts Folder** takes you there and leaves an example behind the first time. A `.applescript`, `.scpt` or `.jxa` file in that folder *is* a script; there is nothing to register.

### What a script is given

The panel state arrives in the environment, so the ordinary case needs no Apple events and no permission prompt:

| Variable | Means |
| --- | --- |
| `PC_ACTIVE_DIR` | The active panel's folder |
| `PC_TARGET_DIR` | The other panel's folder |
| `PC_CURSOR_NAME` | The file under the cursor |
| `PC_SELECTION_COUNT` | How many items are selected |
| `PC_SELECTION_FILE` | A text file with one selected path per line (absent when nothing is selected) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Anything beyond that goes through the application itself, using the verbs above — so the two halves compose.

### Putting a script on a button or a key

Each script becomes a command named `plugin.script.run.<name>`, where `<name>` is the file's name without its extension (spaces and dots become hyphens). That id works anywhere a `cm_*` id does: in the button bar, in `usercmd.ini`, in a `.mnu` file, and in **Configuration ▸ Edit Shortcuts…**.

### How a script is run, and the timeout

By default a script runs as a separate process, which means it can be given a time limit and stopped if it overruns — thirty seconds unless you say otherwise. A script can opt into running *inside* the application instead, which lets it return a structured value and keeps it compiled between runs, but then there is no time limit: a script that loops holds the application. Put the choice in `scripts.json` beside your scripts:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Only what differs from the defaults needs an entry; a file with no entry gets its own name as its title, runs as a subprocess, and stops after thirty seconds.

### For the assistant

With the plugin on and the setting enabled, the assistant gains `run_applescript`, `run_jxa` and `check_script`. Each one shows you the exact script and waits for your approval before anything runs, and none of them is ever offered to an external agent over MCP.

## Notes

- The command id you pass to `run command` is the same `cm_*` id shown in the command browser (see [The Start menu & custom commands](start-menu.md)).
- Scripting always acts on the **active** panel; use `go to … in left` / `in right` first if you need a specific side.
- Peach Commander is a single-window app, so scripts target that window's two panels.
