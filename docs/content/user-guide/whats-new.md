---
title: What's new
slug: whats-new
group: Get started
section: user-guide
order: 80
related: [version-notes, known-limitations, installation]
---

<!-- Generated from CHANGELOG.md by docs/scripts/gen-whats-new.py. Do not edit by hand. -->

# What's new

Peach Commander is at **0.9.3**, released 25 September 2026. Every release is written up in full in the [changelog](https://github.com/hkiam/PeachCommander/blob/main/CHANGELOG.md) — this page is the shorter read: what each one was about, newest first, and what it added.

<div class="pc-release pc-release--latest" markdown="1">

## 0.9.3 <span class="pc-release__date">25 September 2026</span>

<p class="pc-release__chips"><span class="pc-chip pc-chip--now">Latest release</span><span class="pc-chip">1 new</span><span class="pc-chip">6 fixed</span></p>

Markdown and HTML as PDFs, from the renderer that already draws them — and the five ways an SFTP
site could be left unable to log in at all.

**What it added**

- Markdown and HTML documents export as PDFs.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.9.3">0.9.3 in full — the other 6 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.9.2 <span class="pc-release__date">19 September 2026</span>

<p class="pc-release__chips"><span class="pc-chip">3 changed</span><span class="pc-chip">9 fixed</span></p>

Named workspaces, a keyboard that works the same in every view — and the packaging defect behind
"it keeps asking for folder permissions".

A workspace is a named work context now rather than a saved layout: both panels, every tab, the
marks, the filter, the tree and the window's whole arrangement switch together, and switching back
restores what you left. The panel's keyboard vocabulary, which only ever worked in the details view,
now works in Brief, Icons and Gallery as well, and those views draw what is marked. The quick search
and the quick filter lost the last of the places where the list and the count disagreed.

And the app bundle is sealed at last. It never was: `codesign --verify` answered *"code object is
not signed at all"*, because the plugin build wrote its incremental stamps into
`Contents/PlugIns/.build-stamps` and `codesign` refuses a bundle carrying a directory it does not
recognise — with or without a certificate. macOS 26 kept honouring permissions granted to an unsealed
bundle; macOS 27 will not grant new ones, which is why a fresh install asked for Desktop, Documents
and Downloads over and over and forgot every answer. Measured on 27.0: 27 prompts before, three
after — one per folder, remembered, and nothing at all on the next launch. This is an ad-hoc seal,
not a Developer ID: the first launch still goes through System Settings.

**Highlights**

- Workspaces are named work contexts now, not saved layouts.
- The arrow keys step between the quick search's matches.
- A filtered list cycles, and keeps its cursor while you narrow it.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.9.2">0.9.2 in full — the other 9 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.9.1 <span class="pc-release__date">15 September 2026</span>

<p class="pc-release__chips"><span class="pc-chip">18 new</span><span class="pc-chip">6 changed</span><span class="pc-chip">46 fixed</span></p>

Docker as a drive, directory synchronisation worked through end to end, and a round of things
reported by the people using it.

A running container's filesystem browses like any other volume — its own drive, its volumes and
compose projects as folders, its log as a *file* so F3, the viewer's search and its encoding picker
all apply to it, and start/stop/restart in the same context menu as everything else. Synchronisation
gained the half that was missing: it says what it is doing while it does it and can be called off, it
remembers what a pair looked like last time so a deletion on one side is carried to the other rather
than undone, it writes down what each run did and can put it back, and the preset now restores the
*view* of a comparison as well as its rules. Underneath both, the copy engine stopped losing things
at the edges — a symlink is copied as a symlink, an interrupted overwrite leaves the existing file
untouched, and verify-after-copy reads half as much as it did.

The rest came from use: the terminal tab's ✕ sits inside the tab and asks before closing, "Search in"
stopped clipping its own letters, Escape closes the synchronise window, and the search dialog's third
field remembers the folders you searched.

**Highlights**

- A container's log is a file now.
- The Docker provider has a settings page.
- A container or a volume has a context menu now.
- Docker containers and volumes are a drive.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.9.1">0.9.1 in full — the other 66 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.9.0 <span class="pc-release__date">7 September 2026</span>

<p class="pc-release__chips"><span class="pc-chip">9 new</span><span class="pc-chip">6 changed</span><span class="pc-chip">17 fixed</span></p>

Plugins stopped being something only this repository can write.

A plugin now arrives as a file you double-click. That sounds small and was not: a third party could
not depend on the SDK at all, because its package manifest sits in a subdirectory and SwiftPM looks
for one at a repository root — so the dependency line this project's own documentation had shown
from the start had never resolved for anybody. The API version was checked for *equality*, in two
places, so the first time that number moved every existing plugin would have stopped loading in the
same instant. A plugin's identity was its display name, so renaming one lost the user's setting and
two sharing a title shared one switch. `PCPluginMinHostVersion` had been read and compared against
nothing since the day it was added. And installing meant picking a `.zip` from a file chooser, after
which somebody else's code was running in this process with your whole disk in reach, having told
you neither its name nor what it was about to take over.

All of that is answered, and two companion repositories now exist to prove it rather than describe
it: the [SDK](https://github.com/hkiam/PeachCommanderPluginSDK) as a package you can actually depend
on — with `pcplug-validate`, which runs this app's own admission checks against a built plugin
before a user is the one who finds out — and a
[worked example](https://github.com/hkiam/PeachCommanderPluginISO) that reads ISO 9660, Joliet, Rock
Ridge, UDF and El Torito disc images. That example is not a demo: `.iso` was already browsable here
through `bsdtar`, one subprocess per file, every file showing the *container's* timestamp rather
than its own, and UDF unreadable altogether. Nothing on this side changed to let a plugin take that over.

The rest of the release is the editor and the viewer catching up with each other — per-line notes,
Save As, Print, Next/Previous Mark, the strings in a binary in four encodings at once — and
seventeen fixes, several of which were things quietly losing data or hanging the window: a file the
editor could not read opened as an empty one and saving wrote that over it, an unreadable ACL was
replaced by an empty one, and a slow DNS lookup froze the window for half a minute whenever a
terminal reported where it was.

**Highlights**

- Plugins are installable from a package, and you are told what is in it first.
- Plugins have a stable identity and a version.
- `ReadEntryData` and `PC_CAP_RANDOM_ACCESS`, both optional.
- Per-line notes in the editor.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.9.0">0.9.0 in full — the other 28 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.8.2 <span class="pc-release__date">2 September 2026</span>

<p class="pc-release__chips"><span class="pc-chip">3 new</span><span class="pc-chip">3 changed</span><span class="pc-chip">3 fixed</span></p>

A file inside an archive can be previewed and opened — and, because working out why it could not led
straight into it, the app stopped reading things nobody asked it to read.

The first half is what was reported: in a ZIP the quick preview showed nothing and a double-click on a
spreadsheet did nothing at all. The second half is what that turned up on the way. Three parts of the
window read a file simply because the cursor landed on it, and none of them had ever asked what that
costs — only whether the path existed. That is the wrong question on a network share (which looks
exactly like an ordinary folder), on a file the cloud has not downloaded yet (which sits on your own
disk with none of its contents), and inside an archive. Switching a panel on a network share to gallery
view read *every* file in the folder over the wire, one thumbnail at a time. It asks first now, and
answers in seconds rather than megabytes: after a few reads it knows how fast that connection actually
is.

Underneath both, reading a file out of an archive no longer needs it to fit in memory. A 400 MB file
opened from a ZIP cost 588 MB before and costs 151 MB now.

**Highlights**

- A file inside an archive can be previewed and opened.
- A budget for everything the cursor reads by itself.
- The measurement behind that now actually runs on a mounted share.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.8.2">0.8.2 in full — the other 6 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.8.1 <span class="pc-release__date">29 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">4 changed</span><span class="pc-chip">12 fixed</span></p>

Macros, worked through against the three things the first person to use them ran into — same day as 0.8.0, which is when a feature is most worth fixing.

The recorder read what had already happened and left you to work out which of the last thirty things
was the job — the one question you can answer and the list cannot. It now has two ends you press
yourself. It also told people who had just made three folders that nothing had happened, because what
you do by hand is read back out of a history that can be switched off; the new recording does not
depend on it. And each macro is its own file now, because a macro is a thing people hand to each other
and getting one out of a JSON array meant editing by hand — which is also why one typo no longer costs
you every macro you have.

**Highlights**

- Macros can be recorded with a beginning and an end.
- A recording survives a restart.
- A new file (Shift+F4) can be recorded.
- The macro window can run a macro.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.8.1">0.8.1 in full — the other 20 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.8.0 <span class="pc-release__date">29 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">13 new</span><span class="pc-chip">1 changed</span><span class="pc-chip">15 fixed</span></p>

The assistant is split in two. What ran on your Mac was a chat that could not read a file: measured
against Apple Intelligence, the thirty-two tools it offered the model cost 3442 of the model's 4096
tokens, leaving 473 for your question, the file and the answer together — so it answered in the wrong
language, mistook folders for files, and died on the second message telling you to start a new chat,
which changed nothing. That was the default every new reader landed on.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.8.0">0.8.0 in full — all 29 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.7.3 <span class="pc-release__date">25 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">21 new</span><span class="pc-chip">10 changed</span><span class="pc-chip">33 fixed</span></p>

Markdown and HTML leave the core: both formats are now drawn by a plugin that renders
diagrams and mathematics on your Mac, on every surface that shows a file — the viewer, the preview
panel, Quick View and the gallery. Searching inside archives reaches every archive the app can open,
says what it could not read, and no longer leaves extracted copies behind. Amazon S3 joins the drives,
the assistant summarises whole files and looks through your disk for one, and the documentation
website stops reporting its readers to anyone.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.7.3">0.7.3 in full — all 64 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.7.2 <span class="pc-release__date">19 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">9 new</span><span class="pc-chip">6 fixed</span></p>

The Git plugin, from a first pass into something worth reaching for — and the host change that
made the last of it possible.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.7.2">0.7.2 in full — all 15 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.7.1 <span class="pc-release__date">18 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">3 new</span><span class="pc-chip">8 fixed</span></p>

A round of reported defects, four of which were losing something rather than merely looking wrong.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.7.1">0.7.1 in full — all 11 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.7.0 <span class="pc-release__date">16 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">1 fixed</span></p>

**Highlights**

- Filesystem images open like archives.
- Firmware with no partition table is taken apart.
- The space outside the partitions is listed too.
- Commands ▸ Scan Image Layout.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.7.0">0.7.0 in full — the other 1 note &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.6.4 <span class="pc-release__date">15 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">2 new</span><span class="pc-chip">4 fixed</span></p>

**Highlights**

- Arithmetic in "Go to".
- A global history, on Ctrl+Cmd+H.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.6.4">0.6.4 in full — the other 4 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.6.3 <span class="pc-release__date">14 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">5 fixed</span></p>

**Highlights**

- Find empty folders.
- The quick search in the file list is visible now.
- Order and speed per transfer.
- Regular expressions in the viewer and the editor.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.6.3">0.6.3 in full — the other 6 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.6.2 <span class="pc-release__date">13 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">10 new</span><span class="pc-chip">6 fixed</span></p>

**Highlights**

- Open a process and see the files it has open.
- The columns Activity Monitor has and this didn't.
- Who signed each program.
- Other users' processes show numbers too.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.6.2">0.6.2 in full — the other 12 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.6.1 <span class="pc-release__date">12 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">1 changed</span><span class="pc-chip">5 fixed</span></p>

Three user reports, and each of them turned out to be about something the application was
deciding on the user's behalf. It left `.bak` files in folders you curate, with nothing
anywhere to turn that off. It knew the terminal as "the thing in the bottom strip", so
moving it to the side panel left its own menu commands opening an empty strip instead. And
its quick previews could show you a picture but never let you look closer at it.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.6.1">0.6.1 in full — all 10 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.6.0 <span class="pc-release__date">11 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">5 fixed</span></p>

A repair release. Everything below came out of one user report — a folder tree that stayed
white under the Midnight palette — because chasing it exposed that of 59 regression
scenarios, not one had ever looked at a colour. The audit built to answer that found a
crash on ordinary use, and the same sweep of the test harness found seven keyboard checks
that had been measuring nothing at all.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.6.0">0.6.0 in full — all 9 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.5.0 <span class="pc-release__date">10 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">20 new</span><span class="pc-chip">13 fixed</span><span class="pc-chip">4 security</span></p>

**Highlights**

- Terminal tabs can be closed.
- How much scrollback the terminal keeps is yours to set.
- The terminal's status line only shows what there is to show.
- The terminal has its own menu.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.5.0">0.5.0 in full — the other 33 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.4.0 <span class="pc-release__date">8 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">3 new</span><span class="pc-chip">20 fixed</span><span class="pc-chip">3 security</span></p>

Mostly a repair release. A systematic sweep went through the feature inventory looking for rows that
claimed to be done but had nothing verifying them: 73 rows examined, **33 defects found and fixed**.
Several of them could damage data or, in three cases, be used against you. If you are running 0.3.0,
this is the release to take.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.4.0">0.4.0 in full — all 28 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.3.0 <span class="pc-release__date">5 August 2026</span>

<p class="pc-release__chips"><span class="pc-chip">11 new</span><span class="pc-chip">3 changed</span><span class="pc-chip">6 fixed</span></p>

**Highlights**

- Structure view for JSON, YAML and XML in the editor.
- Structural navigation and selection.
- Copy Structural Path.
- Validate Document.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.3.0">0.3.0 in full — the other 16 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.2.0 <span class="pc-release__date">30 July 2026</span>

<p class="pc-release__chips"><span class="pc-chip">4 new</span><span class="pc-chip">2 fixed</span></p>

**Highlights**

- Decompiler plugins for Java/Android and .NET, inside the Commander rather than beside it.
- A VM regression harness (`Tools/vm/regress.py`) that drives the real app over VNC.
- Accessibility: labels for every list, tree and hand-drawn control, plus a per-window keyboard gate.
- 19 languages for the UI and the complete in-app Help Book.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.2.0">0.2.0 in full — the other 2 notes &rarr;</a></p>

</div>

<div class="pc-release" markdown="1">

## 0.1.0 <span class="pc-release__date">14 July 2026</span>

First public beta: dual-panel browsing, the file operation engine, archives, the viewer and editor, FTP,
plugins, and the settings.

<p class="pc-release__more"><a href="https://github.com/hkiam/PeachCommander/releases/tag/v0.1.0">0.1.0 in full — the release on GitHub &rarr;</a></p>

</div>

## The whole story

Every release ever made is listed on the [releases page](https://github.com/hkiam/PeachCommander/releases), and the complete history — including the notes that are too detailed for this page — is in [CHANGELOG.md](https://github.com/hkiam/PeachCommander/blob/main/CHANGELOG.md).

Peach Commander is still before 1.0, so behaviour it got wrong may still change between releases. [Version notes](version-notes.md) says what the current preview can and cannot do, and [Known limitations](known-limitations.md) has the honest list.
