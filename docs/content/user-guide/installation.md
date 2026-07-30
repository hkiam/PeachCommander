---
title: Installing Peach Commander
slug: installation
section: user-guide
order: 10
related: [introduction, privacy-and-security]
---

This page walks you through getting Peach Commander running on your Mac: checking that your system is supported, downloading the current build, getting past the first-launch security check while the app is still a preview, and granting the one system permission a file manager needs. It finishes with how to keep the app up to date.

Peach Commander is still **pre-1.0**. The steps below reflect that: the download is a preview build, and a couple of the polish items that make installation seamless on a shipping app (Developer-ID signing and automatic updates) are being finalized. Everything works today — you just do one or two things by hand that a 1.0 release will handle for you.

## System requirements

- **macOS 13 (Ventura) or later.** Earlier versions are not supported.
- **Any Mac from the last several years.** The app is a *universal* build, so it runs natively on both Apple Silicon (M-series) and Intel Macs — there is nothing to choose at download time.
- **About 15 MB of disk space** for the app itself, plus room for anything you copy or download with it.

To check your macOS version, choose the Apple menu ▸ **About This Mac**.

## Download the preview build

1. Go to the Peach Commander downloads page and download the latest disk image (a `.dmg` file).
2. When the download finishes, double-click the `.dmg` in your Downloads folder. A window opens showing the **Peach Commander** app next to a shortcut to your **Applications** folder.
3. Drag the **Peach Commander** icon onto the **Applications** shortcut. This installs the app.
4. Eject the disk image (click the eject arrow next to it in a Finder sidebar), and, if you like, move the downloaded `.dmg` to the Trash.

You now have Peach Commander in your Applications folder like any other app.

## First launch: right-click ▸ Open

While the preview builds are still being signed and notarized with Apple, macOS Gatekeeper does not yet recognize the app and will refuse to open it on a normal double-click, showing a message like *"Peach Commander cannot be opened because the developer cannot be verified."* This is expected for a preview build and does **not** mean anything is wrong with the download.

Open it the first time this way:

1. In your **Applications** folder, **right-click** (or Control-click) the **Peach Commander** icon.
2. Choose **Open** from the menu.
3. In the dialog that appears, click **Open** again to confirm.

You only need to do this once. After the first successful launch, macOS remembers your choice and you can open the app normally from then on — a double-click, Launchpad, or Spotlight all work.

> **Why the extra step?** Developer-ID signing and notarization — the process that lets macOS vouch for the app automatically — are being finalized for the 1.0 release. Once that's in place, this right-click step disappears and Peach Commander opens on a plain double-click like any other app.

## Grant Full Disk Access

A file manager is only useful if it can reach your files, and macOS keeps some locations private (other apps' data inside your Library folder, Mail and Messages storage, and similar) until you explicitly allow an app to see them. So that Peach Commander can browse everywhere Finder can, grant it **Full Disk Access**.

The app keeps working right away with reduced access — you'll browse and manage everything you can normally see. Only system-protected folders stay hidden until you turn this on.

1. In Peach Commander, choose **Commands ▸ Full Disk Access…**. (On first launch the app may also offer to take you straight there.)
2. macOS opens **System Settings ▸ Privacy & Security ▸ Full Disk Access**.
3. Turn on the switch next to **Peach Commander**. If it isn't listed yet, click the **+** button and add it from your Applications folder.
4. If prompted, quit and reopen Peach Commander so the new permission takes effect.

For more on why this permission matters and where your data lives, see [Privacy & security](privacy-and-security.md).

## Keeping Peach Commander up to date

**For now, updates are manual.** When a new preview build is available, download the new `.dmg` from the downloads page and repeat the install: drag the new **Peach Commander** onto your **Applications** folder and choose to replace the older copy. Your settings, saved connections, and Keychain-stored passwords are kept separately from the app, so they carry over to the new build.

**Automatic updates are planned.** A built-in "Check for Updates" feature (with your choice of how often to check) is on the roadmap for a future release but is **not enabled yet**. Until it ships, checking the downloads page from time to time is the way to stay current.

## Ready to go

That's it — Peach Commander is installed and can reach your files. New to a dual-panel file manager? Head to [Welcome to Peach Commander](introduction.md) for a two-minute tour of the two-panel layout and the first shortcuts worth learning.
