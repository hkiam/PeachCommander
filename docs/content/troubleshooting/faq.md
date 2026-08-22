---
title: Frequently asked questions
slug: faq
group: Reference & help
section: troubleshooting
order: 30
related: [troubleshooting, known-limitations, privacy-and-security]
---

Short, honest answers to the questions people ask most often about Peach Commander. If your question is really a "something is broken" question, start with [Troubleshooting](troubleshooting.md); for features that have deliberate limits in this preview, see [Known limitations](known-limitations.md).

## Is Peach Commander free? Is it open source?

Peach Commander is currently a pre-1.0 preview. It is not yet a finished 1.0 release, and licensing and pricing are still being settled ahead of that. Treat the current builds as an evaluation preview rather than a final product.

## Does it replace Finder?

It doesn't have to. Peach Commander is a dual-panel file manager: two folder listings side by side so you can copy (F5) and move (F6) between them and switch panels with Tab. Many people use it alongside Finder for heavier file work — bulk copying, renaming, comparing, searching, and archive handling — while keeping Finder for everyday browsing. Both see the same files on disk, so you can use whichever fits the task.

## Why does it ask for Full Disk Access?

macOS keeps some locations private — Mail, Messages, and other apps' data inside your Library folder — until you explicitly allow access. Because a file manager is meant to reach every file, Peach Commander asks for Full Disk Access. It keeps working with reduced access; you simply won't see those protected folders until you grant it. See [Privacy & security](privacy-and-security.md) for the exact steps.

## Are my passwords safe?

Yes. Any password or passphrase you save — for a server connection or a password-protected archive — is handed to the macOS Keychain, the same secure store the system uses for your Wi-Fi and website logins. Passwords are never written to Peach Commander's own settings or connection files in plain text. You review or remove them anytime in the Keychain Access app. More detail in [Privacy & security](privacy-and-security.md).

## Does it phone home or collect analytics?

No. There is no telemetry: the app does not track your activity or send usage analytics anywhere. If it ever quits unexpectedly, the crash report stays in your own diagnostics folder, and nothing is transmitted unless you choose to send it yourself.

## Can I use my Total Commander plugins?

Not the plugin files themselves. Total Commander plugins are Windows binaries and will not run on macOS. Peach Commander has its own native plugin system — five plugin types plus an SDK — and several plugins are built in already (see [Plugins](plugins.md)). Note that it can import many of your Total Commander preferences from a `wincmd.ini` file, so your settings can come across even though the plugin binaries cannot.

## Does it handle RAR files?

It reads them: you can open an existing RAR archive and browse it like a folder, and copy files out. Creating RAR archives is different. RAR is a proprietary format, so packing to RAR requires the separate RAR command-line tool installed on your Mac; without it, RAR is unavailable in the Pack dialog. If you only need to create archives, ZIP and 7z work out of the box and both support AES-256 encryption and split volumes. See [Working with archives](archives.md).

## Why won't a very large ZIP open?

Very large ZIP files use an extension called ZIP64 — typically when an archive holds more than about 65,000 items or exceeds 4 GB. The built-in reader does not support ZIP64, so such archives may fail to open or list incompletely. Standard ZIP, TAR, and gzip-compressed TAR open directly as folders. For a ZIP64 archive, extract it with another tool first, then work with the files. This is a documented limit — see [Known limitations](known-limitations.md).

## Why didn't my folder refresh automatically?

A panel notices outside changes on a short delay rather than instantly — it re-checks the current folder roughly every couple of seconds, so a file added or removed by another app can take a moment to appear. Network and mounted volumes don't always report changes at all. If you don't want to wait, click the panel and press F2 (or Ctrl+R) to re-read it immediately.

## Is there automatic updating yet?

Not in this preview. Automatic updates are planned but not enabled in the current build, so check back for new versions manually for now. Because signing and notarization are still being finalized, a preview build may be flagged by Gatekeeper the first time you open it — right-click (or Control-click) the app and choose Open, then confirm, to run it.

## Is it native on Apple Silicon?

Yes. Peach Commander is a universal app that runs natively on both Apple Silicon and Intel Macs. It requires macOS 13 or later.

## Can I script or automate it?

There is no public scripting or automation interface in this preview. For power users, the intended way to extend Peach Commander is through its plugin SDK rather than external scripts. For fast repetitive file work without scripting, look at the built-in bulk tools instead: [multi-rename](multi-rename.md), synchronize and compare, and [deep search](searching.md).
