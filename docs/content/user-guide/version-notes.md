---
title: Version notes
slug: version-notes
group: Get started
section: user-guide
order: 90
related: [whats-new, known-limitations, installation]
---

# Version notes

Peach Commander is a **pre-1.0 preview**. This page is the short answer to "should I install
this, and what should I know first?" — what state the preview is in, the two things that are
not finished, and the limits worth knowing before you rely on it. For what each individual
release changed — and which version you are looking at — see
[What's new](whats-new.md), which is written from the changelog itself.

Peach Commander is a **universal app** — it runs natively on both Apple Silicon and Intel
Macs — and requires **macOS 13 (Ventura) or later**.

## What state it is in

It is a file manager people use for a day's work, not a demonstration. Two panels with tabs
and the function keys; copy and move with a background transfer manager; archives you step
into like folders; search across names and contents, including inside archives; multi-rename,
compare and synchronize; FTP, SFTP, WebDAV, Amazon S3 and a running Docker engine, each
browsing like a folder on your Mac; a viewer and an editor; and a set of plugins that arrive
in the box rather than on a shop page. The interface and the complete in-app help are
translated into nineteen languages.

**What the app does is deliberately not listed again here.** It was, for eight releases, and
the list was wrong for most of them — a page nobody had a reason to reread is the worst place
to keep a feature list. The tour is on the [homepage](index.md), the full record is
[What's new](whats-new.md), and the individual topics are what the rest of this
documentation is.

Peach Commander collects **no telemetry** and transmits nothing about your usage
automatically. See [Privacy and security](privacy-and-security.md).

## The two things that are not finished

- **Automatic updates.** The groundwork for background auto-update is declared but not
  integrated, so this preview will not update itself. New builds are on the project's
  [releases page](https://github.com/hkiam/PeachCommander/releases), and
  [What's new](whats-new.md) says what each one changed — download and install them by hand
  for now.
- **Signing and notarization.** The release pipeline signs the app and submits it to Apple
  already; those steps skip themselves when no credentials are configured, and the project
  has no Apple Developer ID, so **every build so far is unsigned**. macOS therefore blocks
  the first launch. On **macOS 15 and later**, open it once, dismiss the warning, then allow
  it under System Settings ▸ Privacy & Security ▸ **Open Anyway** — Apple removed the
  right-click shortcut for unsigned software in macOS 15. On **macOS 13–14**, right-click
  (or Control-click) the app and choose **Open**, then confirm. The
  [installation guide](installation.md) walks through both.

## Limits worth knowing

A preview has honest limits. These are the ones that change what you can expect, in brief:

- **A split archive needs all of its parts.** A set split across `.z01`, `.z02`, … or
  `name.zip.001`, … opens as a folder when every part is in the same directory; one missing
  part is refused rather than opened half-read. Split TAR sets are not covered.
- **Over SFTP you can change permissions and timestamps, but not an owner.** The protocol
  carries owner and group as numbers with no way to resolve a name, so the change is refused
  rather than guessed at. Over plain FTP only permissions can be set, and only where the
  server offers `SITE CHMOD`.
- **Remote locations are not watched.** A folder on this Mac — and an archive you are looking
  inside — updates by itself as soon as something else changes it. FTP and SFTP offer no way
  to be told, so re-read those with **F2** or **Ctrl+R**.
- **Very long paths work, except for the Trash.** macOS refuses any path longer than 1024
  bytes, and nothing can trash a file it cannot name. Delete reports an error there;
  Shift+Delete (delete permanently) works.
- **The build is unsigned** (see above).

For the full list, the workarounds and the reasoning, read
[Known limitations](known-limitations.md), which is the page these are drawn from.

## A note on version numbers

As a pre-1.0 preview, features and shortcuts may still change between builds, and nothing
here should be read as a promise of a specific future version. The version you are running is
in the **Help** menu; what each release before it changed is on [What's new](whats-new.md).

This page deliberately carries no version number and no feature list of its own. It had both,
and it described 0.1.0 for eight releases after 0.1.0 had stopped being the current one —
including three limits that were not limits: ZIP64 archives it said might not open, SFTP
attributes it said could not be changed, and a two-second refresh delay that had never
existed. The same three sentences were in the README, where a gate now checks the claims that
can be checked. Prose still cannot be gated, so the answer here is to state fewer facts and
point at the pages that own them.
