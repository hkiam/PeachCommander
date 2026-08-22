---
title: Privacy & security
slug: privacy-and-security
group: Using Peach Commander
section: macOS & privacy
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander is built to stay out of your way and keep your data on your Mac. Passwords are handed to the macOS Keychain, crash information never leaves your computer without your say-so, and the app collects no usage analytics. This topic explains where your sensitive information lives and how to grant the one system permission a file manager needs to do its job.

## Where passwords are stored

Any password or key passphrase you save — for an FTP or SFTP connection, or to open a password-protected archive — is written to the macOS **Keychain**, the same secure store the system uses for your Wi-Fi and website logins. Passwords are never written to Peach Commander's own settings or connection files in plain text.

1. When you save a connection or archive password, choose the option to remember it.
2. The password is stored in your login Keychain, protected by your account.
3. To review or remove a saved password later, open the **Keychain Access** app (in Applications ▸ Utilities) and search for the connection name.

## Grant Full Disk Access

macOS keeps some locations private — Mail, Messages, and other apps' data inside your Library folder — until you explicitly allow access. Because a file manager is meant to reach every file, Peach Commander asks for **Full Disk Access**. The app keeps working with reduced access until you grant it; you simply won't see those protected folders.

1. Choose **Commands ▸ Full Disk Access…**, or click **Open System Settings** when the app offers to guide you on launch.
2. In **System Settings ▸ Privacy & Security ▸ Full Disk Access**, turn on the switch next to Peach Commander.
3. Relaunch the app if prompted.

## Crash reports stay local

If the app quits unexpectedly, macOS writes a crash report to your own diagnostics folder. On the next launch Peach Commander notices it and offers to help you file a bug report — but only with your consent.

- You can **Show in Finder** to see the report, or **Copy Report to Clipboard** to paste it into a bug report yourself.
- Nothing is ever transmitted automatically, and there is no third-party crash-reporting service involved.

## Notes

- **No telemetry.** Peach Commander does not track your activity or send usage analytics anywhere.
- **Reduced access is safe.** If you skip Full Disk Access, the app still browses and manages the files you can normally see; only system-protected locations are hidden.
- **You control saved passwords.** Because credentials live in the Keychain, you manage and revoke them with standard macOS tools rather than inside the app.
