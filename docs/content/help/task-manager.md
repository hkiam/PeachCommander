---
title: Task Manager
slug: task-manager
section: Plugins
order: 125
related: [plugins, viewing-files, deleting-files]
---

The Task Manager plugin turns the running processes on your Mac into a folder you can browse. It appears as a **TaskManager** drive in the drive bar; open it and every process is a row you can sort, inspect like a file, or end — using the same keys you already use for files. It's a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**.

## Open it

1. Click the **📊 TaskManager** entry in the drive bar (it sits right after your boot drive).
2. The panel fills with one row per running process. Each row's name is the process name followed by its PID, for example `Finder (462)`.

![The Task Manager listing running processes with PID, CPU, memory, and command columns](screenshots/task-manager.png)
*(Figure: running processes shown as a file list you can sort and act on.)*

## What each column means

Alongside the usual Size (memory) and Date (start time) columns, Task Manager adds process columns:

| Column | Meaning |
| --- | --- |
| **PID** | Process id |
| **CPU %** | Recent processor use (needs a second refresh to appear) |
| **Threads** | Thread count |
| **State** | R running · S sleeping · T stopped · Z zombie · I idle |
| **User** | Owner |
| **PPID** | Parent process id |
| **Command** | Full command line |

Sort by any column (for example CPU % or Size/memory) just as you would in a normal folder.

## Inspect or end a process

- **View (F3)** shows a *Process Information* report: name, PID, parent, user, state, threads, memory, CPU, start time, executable path, and the full command line.
- **Delete (F8)** ends the process. The first delete sends a graceful **quit** (SIGTERM); deleting a process that's still running a second time escalates to a **force quit** (SIGKILL). The plugin never targets PID 1.

## Notes

- Basic details (PID, parent, user, state) are readable for every process, like `ps`. Memory, threads, and CPU can only be read for **your own** processes; other processes show those columns blank (they need elevated privileges, a later addition).
- CPU % is a change between two samples, so it's blank until the panel refreshes a second time (the panel refreshes roughly every two seconds).
- The list is read-only apart from ending a process — you can't copy files into it.
