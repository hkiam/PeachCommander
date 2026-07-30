# Security Policy

## Reporting a vulnerability

Please report privately, not in a public issue:

**[Report a vulnerability](https://github.com/hkiam/PeachCommander/security/advisories/new)**
— GitHub's private reporting is enabled, so the report stays visible only to the
maintainers until a fix is out.

Useful in a report: what an attacker can achieve, the steps to get there, your macOS
version and architecture, and whether any plugin was involved. A proof of concept
helps but is not required.

Expect a first response within a few days. Peach Commander is a spare-time beta
project, so please don't read silence as dismissal — ping the advisory thread.

## Supported versions

Only the **latest release** is supported. The project is pre-1.0 and there are no
maintenance branches: fixes go into the next release rather than being backported.

| Version | Supported |
| --- | --- |
| latest release ([v0.1.0](https://github.com/hkiam/PeachCommander/releases/latest)) | ✅ |
| anything older | ❌ |

There is no auto-update yet, so keeping current means downloading a newer build.

## What the threat model already assumes

Some properties are deliberate design decisions, documented in
[the security architecture](https://hkiam.github.io/PeachCommander/arch-security.html)
and the ADRs. They are not vulnerabilities in themselves — though a way to *abuse*
them beyond what is described here certainly is:

- **No App Sandbox.** A file manager needs the user's whole disk. Distribution is via
  Developer ID + notarization rather than the App Store (ADR-006).
- **Plugins run in-process and are not isolated.** A crash guard catches fatal
  signals and quarantines the offending plugin for the session (F-230), but a
  malicious plugin has the app's full privileges. Out-of-process isolation is
  deferred past 1.0. Only install plugins you trust.
- **Library validation is relaxed.** The hardened runtime entitlements enable
  `com.apple.security.cs.disable-library-validation`, because third-party plugins are
  not signed by this project's team.
- **The beta is unsigned and un-notarized** by choice, which is why macOS blocks the
  first launch. A build that Gatekeeper accepts without that step would be the
  surprising thing.

What the app does promise:

- Passwords for FTP/SFTP/WebDAV live in the **macOS Keychain**, never in plain-text
  config.
- **No telemetry**; crash reports stay local and are not uploaded.
- Peach Commander can invoke external tools (`7z`, `unar`, `tar`) found on `PATH`.
  Nothing is downloaded or executed from the network to do so.

## Scope

In scope: the app, the bundled plugins, the plugin SDK and host, the build and
release tooling in this repository.

Out of scope: vulnerabilities in third-party dependencies (report those upstream —
see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)), the external command-line
tools the app can call, and issues that require an already-compromised machine or a
plugin the user chose to install.
