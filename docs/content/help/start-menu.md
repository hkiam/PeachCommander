---
title: The Start menu & custom commands
slug: start-menu
group: Customise
section: Customizing
order: 111
related: [toolbar, keyboard-shortcuts]
---

The **Start** menu is your own personal menu, sitting in the menu bar alongside File, Edit, and the rest. It holds commands you define yourself, so the actions you reach for most often are always one click away. In the tradition of classic dual-panel file managers, each entry can run a built-in command, launch an external program or app, or jump straight to a folder. Peach Commander ships with the Start menu empty and ready for you to fill.

## How to add your own commands

1. Choose **Start > Change Start Menu…**. Peach Commander opens your user-commands file (creating it with a commented example the first time).
2. Add one section per command. Each section starts with a name in square brackets, then a few simple keys:
   - **cmd** — what to run: a program path, an app, a built-in `cm_` command, or another of your own commands.
   - **param** — parameters passed to a program. Placeholders are filled in when the command runs: `%P` (source folder), `%N` (current file), `%T` (other panel's folder), `%M` (other panel's file), `%S` (selected files).
   - **path** — the folder to start in (defaults to the current folder).
   - **menu** — the title shown in the Start menu.
   - **key** — an optional shortcut, e.g. `C+S+B`.
3. Save the file. The Start menu updates on its own the next time Peach Commander becomes active, so your new entries appear right away.

## Tips

- To open the current folder in Terminal, set **cmd** to `open`, **param** to `-a Terminal %P`, and **menu** to `Open Terminal Here`.
- Point **cmd** at a `cm_` command to give a built-in action its own Start-menu entry and shortcut.
- Order in the file is the order in the menu, so put your most-used commands at the top.

## Notes

- You can also replace the entire menu bar with your own. Choose **Configuration > Edit Menu File…** to open a menu file seeded from the current, fully localized built-in menu; edit it freely and your changes apply the next time the app is activated. Delete the file to restore the standard menu bar.
