---
title: Macros
slug: macros
group: Using Peach Commander
section: Power tools
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

A macro is a named sequence of file actions — create a folder, move the selection into it, tag what is left — that you can run again with one click. It is not a scripting language: there are no conditions and no loops, and that is deliberate. A macro is a list you can read, and read is what you have to be able to do before you approve it.

Everything a macro does goes through the same machinery the assistant uses, so a macro cannot do anything you have not permitted, each of its steps appears in the action log, and a step that can be taken back still can be.

## The quickest way in: from what you just did

You do not have to write a macro from scratch.

1. Do the thing once — through the assistant, or by running an existing macro.
2. Choose **Configuration ▸ Macro from Recent Actions…**.
3. Tick the steps the macro should repeat, give it a name, and leave **Also add a button for it** on.

**Save Macro**, and the button is in the bar. That is the whole loop.

> **What is not recorded.** The list is built from actions that went through the assistant or another macro. Copying, moving or renaming in the panels *by hand* — F5, F6, F7 — is not recorded, so it cannot be turned into a macro this way. Use the editor below for those.

## Editing macros by hand

**Configuration ▸ Edit Macros…** opens `macros.json` in your configuration folder, seeding it with a commented example the first time. A macro is a list of steps, and each step names a tool and its arguments:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Saving reloads the macros immediately. To see which tools exist and what they take, ask the assistant for `list_macros`, or read the example the file was seeded with.

### Placeholders

The bare letters are the same ones the button bar and the Start menu use, so there is nothing new to learn if you have made a button:

| Placeholder | Means |
| --- | --- |
| `%P` | The active panel's folder |
| `%T` | The other panel's folder |
| `%N` | The file under the cursor |
| `%S` | The selected files — a **list**, which is what `copy`, `move` and `move_to_trash` take |
| `%{date:yyyy-MM}` | The date the macro started, in that format |
| `%{1}` | The result of step 1, where the step produced a path or a list of paths |

The braces are for the extras because the letters are already taken: `%M` means "the name under the cursor in the other panel" everywhere else in the program, so a month could not be spelled that way.

`%S` is the one place a macro differs from a button: on a button the selection becomes a list of words for a command line, here it becomes the list of full paths the file tools take.

A step whose `%S` or `%{1}` comes out **empty stops the macro** rather than running with nothing to act on. A `move` with no files is not a smaller move — it is a request that no longer says anything, and reporting success for it would be a lie.

## Running a macro

Each macro becomes a command called `mc_<id>`, so it appears by itself in:

- **Configuration ▸ Command Browser…**
- **Configuration ▸ Edit Shortcuts…** — put it on a key
- The button-bar editor's command picker
- Your `.mnu` menu file and `usercmd.ini`, if you use those
- The assistant, which can run it by name

Before a macro that changes anything runs, it shows you its steps as a list and waits. You can strike out a step you do not want; what is left is what runs. A macro that only reads runs without asking.

If a step fails, the macro **stops there** rather than carrying on — step two of a macro usually assumes step one happened, and moving files into a folder that was not created is not a partial success. The report names the step and says what went wrong, and the steps that did run are in the action log.

## What a macro is allowed to do

A macro is held to the most demanding thing in it. A macro whose steps only read is treated as a read; one that ends in a permanent delete is gated like a permanent delete — before any of it runs, not four steps in.

Granting nothing extra is the default. If a macro contains a step your permissions do not allow — a shell command, a script — the whole macro is refused and told you why, and nothing happens.

## Undo

Each step is logged on its own, so **undo** after a macro takes back its *last* step, not the whole macro. There is no macro-wide undo, because several tools have no inverse at all and a button offering one would be lying about those.

## Where things are saved

- Your macros are in `macros.json` in the configuration folder — a plain file you can diff and keep with your dotfiles.
- Buttons a macro added are ordinary button-bar entries in `default.bar`, so removing one is the same as removing any button.

## Next steps

- [Automation (AppleScript & Shortcuts)](automation.md) — driving Peach Commander from a script, and running your own scripts as macro steps.
- [The button bar](toolbar.md) — where the button a macro added ends up.
- [Keyboard & shortcuts](keyboard-shortcuts.md) — putting a macro on a key.
