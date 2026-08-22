---
title: Developer onboarding
slug: dev-getting-started
group: Develop
section: Developer guide
order: 20
related: [dev-overview, architecture-overview]
---

# Developer onboarding

This page takes you from a fresh clone to a running, tested build of Peach
Commander, and then through the packaging and release flow. It is precise about
what is automated and what is not — several release steps require Apple signing
credentials and are performed by hand today.

Peach Commander is a native macOS file manager written in Swift. The UI is
AppKit; the engine is a set of pure-Swift frameworks with no AppKit dependency.
See [Architecture overview](architecture-overview) for the module map and
[Developer guide overview](dev-overview) for the wider landscape.

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| macOS | 13.0+ (Ventura) | Deployment target; universal `arm64` + `x86_64` builds |
| Xcode | 16 | `xcodeVersion: "16.0"` in `project.yml`; Swift 5.10+ toolchain |
| Homebrew | any recent | Used to install `xcodegen` and `libssh2` |
| XcodeGen | 2.40.0+ | `minimumXcodegenVersion` in `project.yml`; installed by `bootstrap.sh` |
| libssh2 | Homebrew keg | Required to link `PCNet` (SFTP, F-214) |

`libssh2` is **not** installed by `bootstrap.sh` — install it yourself:

```sh
brew install libssh2
```

The build settings in `project.yml` hard-code the Apple-silicon keg path
(`/opt/homebrew/opt/libssh2/...`) into `LIBRARY_SEARCH_PATHS`, `OTHER_CFLAGS`,
and `OTHER_SWIFT_FLAGS`. On an Intel host the keg lives under
`/usr/local/...`; adjust those paths locally (this is an
**open question** — the project.yml paths are Apple-silicon-only today and there
is no auto-detection).

## Clone and generate the project

The `.xcodeproj` is **generated and gitignored** — `project.yml` is the single
source of truth (ADR-002: LLMs corrupt `.xcodeproj` plists and merges are
painful). Never edit the `.xcodeproj` by hand; edit `project.yml` and
regenerate.

```sh
git clone <repo-url> peachcommander
cd peachcommander
./Tools/bootstrap.sh      # checks Xcode, installs xcodegen if missing, runs `xcodegen generate`
```

`bootstrap.sh` verifies Xcode is present, installs `xcodegen` via Homebrew if it
is missing, and runs `xcodegen generate` to produce `PeachCommander.xcodeproj`.
Re-run `xcodegen generate` (or `bootstrap.sh`) any time you change `project.yml`
or add/remove source files.

```mermaid
flowchart LR
  A[project.yml] -->|xcodegen generate| B[PeachCommander.xcodeproj]
  B -->|xcodebuild| C[PeachCommander.app]
  A -.source of truth.- A
  B -.gitignored.- B
```

## What gets built

The workspace has **8 Swift modules** plus **12 C static-library targets**.
Dependencies always point *down* toward `PCFoundation`; AppKit appears only in
`PCApp`.

```mermaid
flowchart TD
  PCApp --> PCCommands
  PCApp --> PCOperations
  PCApp --> PCArchive
  PCApp --> PCNet
  PCApp --> PCPluginHost
  PCCommands --> PCVFS
  PCOperations --> PCVFS
  PCArchive --> PCVFS
  PCNet --> PCVFS
  PCPluginHost --> PCVFS
  PCVFS --> PCFoundation
  PCCommands --> PCFoundation
  PCApp --> PCVFS
  PCApp --> PCFoundation
```

- **PCFoundation** — shared utilities, logging (`os.Logger`, subsystem
  `com.peachcommander`), config primitives (`ConfigStore`, `ConfigPaths`),
  `LaunchOptions`. No dependencies of ours.
- **PCVFS** — virtual file-system protocol and local FS backend; directory
  listing and watching.
- **PCCommands** — command registry (`cm_*`), shortcut mapping, user commands.
- **PCOperations** — copy/move/delete engine with a queue, plan/execute/verify.
- **PCArchive** — archive VFS backends wrapping libarchive (ADR-005).
- **PCNet** — FTP/SFTP backends (SFTP via `CSSH2` → libssh2, ADR-011).
- **PCPluginHost** — plugin loading, C-ABI bridging, plugin registry.
- **PCApp** — the AppKit application (windows, panels, dialogs, Lister). The
  app target's product is `PCApp.app`, renamed to `PeachCommander.app` on build.

The C targets are the plugin ABIs (`CPCX`, `CPDX`, `CPFX`, `CPLX`, `CContrib`,
`CPluginGuard`), `CSSH2` (the libssh2 clang module), and five vendored
tree-sitter grammars used by the Lister's syntax highlighting.

## Local configuration

Peach Commander persists all app configuration as **INI files** (ADR-007), not
`UserDefaults`, under:

```
~/Library/Application Support/PeachCommander/
```

managed by `ConfigStore` (an actor in PCFoundation with debounced, atomic
writes). Do **not** add `UserDefaults.standard` for app config — only
`ConfigStore` honors the config-root override and `UserDefaults` would pollute
the user's real app state.

For development and tests, redirect the whole config tree away from your real
profile with either:

```sh
# launch argument
PeachCommander.app/Contents/MacOS/PeachCommander -ConfigRoot /tmp/pc-dev-config

# or environment variable (F-277)
PEACHCMD_CONFIG_ROOT=/tmp/pc-dev-config ./Tools/build.sh
```

Engine code always receives paths via a `ConfigPaths` value — never hardcode a
path. Secrets (FTP/SFTP passwords) live in the macOS Keychain via `SecretStore`;
`ftp-sites.ini` stores only a `password=keychain` marker.

## Build

```sh
./Tools/build.sh          # Debug build of the PeachCommander scheme
```

`build.sh` regenerates the project if needed and runs:

```sh
xcodebuild -project PeachCommander.xcodeproj \
  -scheme PeachCommander -configuration Debug build
```

The output is `build/Debug/PeachCommander.app`. You can also open
`PeachCommander.xcodeproj` in Xcode and build/run the `PeachCommander` scheme
directly. Swift Package dependencies (Sparkle, SwiftTreeSitter, Neon, the
tree-sitter grammar packages) are resolved automatically by Xcode/xcodebuild on
first build.

## Run

Launch the built app, or run from Xcode with the `PeachCommander` scheme. Useful
launch arguments in DEBUG:

- `-ConfigRoot <path>` — isolate config (see above).
- `-AutomationScript <path>` — run a scripted automation (DEBUG only, see below).

## Tests

There are roughly **1300 tests across 9 targets**. The suite includes a VFS
conformance battery, an XCUITest smoke test, and performance benchmarks.

```sh
./Tools/test.sh           # runs the PeachCommander scheme's test action
```

Two things to know about the schemes:

- The **`PeachCommander`** scheme runs the seven engine/unit test targets
  (`PCFoundationTests`, `PCVFSTests`, `PCCommandsTests`, `PCOperationsTests`,
  `PCArchiveTests`, `PCPluginHostTests`, `PCNetTests`). This is what
  `Tools/test.sh` uses.
- The **`AllTests`** scheme adds `PCPerfTests` on top of those seven — use it
  when you want the performance benchmarks included:

  ```sh
  xcodebuild -project PeachCommander.xcodeproj -scheme AllTests \
    -configuration Debug test
  ```

- The **`UITests`** scheme runs `PCUITests` (the XCUITest smoke test) on its own.

### Live network tests (opt-in)

`PCNetTests/LiveServerTests` are gated behind an environment variable: they call
`XCTSkipUnless` and only run when `PC_NET_LIVE=1` **and** a reachable server is
configured (host/credentials via env). Without it they skip cleanly.

```sh
PC_NET_LIVE=1 xcodebuild -project PeachCommander.xcodeproj \
  -scheme PeachCommander -configuration Debug test
```

### Performance fixtures

`PCPerfTests` operates on large fixture trees that are **not committed** (binary
fixtures over 100 KB are never checked in). Generate them first:

```sh
./Tools/make-fixtures.sh          # tree-10k, tree-100k, unicode names, sparse file
./Tools/make-fixtures.sh clean    # remove and regenerate
```

Fixtures default to `/tmp/pc_fixtures`; override with `PC_FIXTURES_DIR`. The
script also documents the targets it exercises (e.g. tree-10k listing < 500 ms,
tree-100k < 1500 ms).

## Debugging the running app

Prefer the built-in **`-AutomationScript`** hook over GUI-clicking or
screenshot-driven automation. It is compiled into DEBUG builds only
(`Sources/PCApp/AutomationRunner.swift`) and, after the window loads, executes
one verb per line so tests and tools can drive the *real* app deterministically —
including the async network connect path.

```
# example automation script
left  /Users/me/Projects
right /tmp
active left
cmd   cm_CopySamePanel
connect sftp://user:pass@host/home/me
wait  1500
dump  /tmp/left-listing.txt
quit
```

Selected verbs: `left`/`right` (load a directory in a panel), `active`
(set the active panel), `focus`/`enter` (move the cursor / descend),
`cmd <cm_Name>` (run a registered command), `connect`/`disconnect` (network
mounts), `wait <ms>`, `dump <file>` (write the active panel's path + entry
names), and `quit`. Lines starting with `#` are comments. This is the intended
way to reproduce and inspect app behavior headlessly — see also the memory note
on app automation for testing.

## Packaging

The distributable is a DMG built by `Tools/make-dmg.sh` (Release by default):

```sh
./Tools/make-dmg.sh            # -> build/PeachCommander.dmg
```

`make-dmg.sh` orchestrates several steps:

1. **`generate-third-party-notices.py`** — refreshes `Resources/ThirdPartyNotices.json`
   and `Licenses/` from `Package.resolved`.
2. **`xcodebuild ... build`** with `CODE_SIGNING_ALLOWED=NO`.
3. **`build-all-plugins.sh`** — builds every shipping plugin bundle into the
   app's `Contents/PlugIns` (sample/demo plugins are excluded). Each shipping
   plugin has its own `Tools/build-<name>-plugin.sh`.
4. **`bundle-libssh2.sh`** — copies `libssh2` + its `openssl@3` deps into
   `Contents/Frameworks`, rewrites their install names to `@rpath`, and ad-hoc
   re-signs them so SFTP works on machines without Homebrew (F-214).
5. Stages the app next to an `/Applications` symlink and produces a compressed
   (UDZO) `build/PeachCommander.dmg`.

To (re)build all plugins into your local plugins directory instead:

```sh
./Tools/build-all-plugins.sh    # defaults to ~/Library/Application Support/PeachCommander/plugins
```

## Signing, notarization, and release — honest status

The full release procedure is documented in `RELEASE.md`, but the security- and
distribution-sensitive steps are **not automated** and cannot run in CI or by an
unattended agent — they need an Apple Developer ID certificate and an
app-specific password / notarytool key.

The distribution model is **Developer ID + hardened runtime + notarized DMG**,
**not** the Mac App Store (ADR-006). A file manager needs full-disk access, so
the **App Sandbox is intentionally off**. The entitlements
(`Resources/PeachCommander.entitlements`) include
`disable-library-validation` (to `dlopen` unsigned plugin dylibs) and
`allow-dyld-environment-variables`.

Current honest state:

- The app is built **unsigned** today (`CODE_SIGNING_ALLOWED=NO`,
  `CODE_SIGNING_REQUIRED=NO` in `project.yml`). The DMG from `make-dmg.sh` runs
  locally but is blocked by Gatekeeper on other machines until signed and
  notarized.
- **Signing** and **notarization** are documented manual steps in `RELEASE.md`
  (marked `[creds]`), performed by a maintainer — not wired into any script or CI.
- **Sparkle 2** is declared as an SPM dependency in `project.yml` but is **not
  yet linked into the app**; the appcast/auto-update flow is planned, not
  implemented.

### Release checklist (from `RELEASE.md`)

```mermaid
flowchart TD
  V[Bump version + build number in PCApp Info.plist] --> T[Tag release commit]
  T --> D[make-dmg.sh: build + bundle plugins + libssh2]
  D --> S["Sign app: Developer ID + hardened runtime (creds)"]
  S --> N["Notarize + staple DMG (creds)"]
  N --> A["Sign appcast entry, publish DMG (planned, Sparkle)"]
```

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `Sources/PCApp/Info.plist`; tag the release commit (`git tag vX.Y.Z`).
2. `./Tools/make-dmg.sh`.
3. **[creds]** `codesign --force --deep --options runtime --sign "Developer ID
   Application: …" --entitlements Resources/PeachCommander.entitlements <app>`
   (bundled plugins and helper frameworks are signed by the `--deep` pass).
4. **[creds]** `xcrun notarytool submit … --wait` then `xcrun stapler staple`,
   verified with `spctl`.
5. (When Sparkle is integrated) sign the DMG with `sign_update` and append an
   `<item>` to `appcast.xml`.

## Continuous integration

CI runs on **macos-14**. It generates the project with XcodeGen and runs the
test action; the credential-gated signing/notarization steps are out of scope
for CI by design. Live network tests stay skipped unless `PC_NET_LIVE=1` is set.

## Conventions to internalize before your first PR

- Edit `project.yml`, never the generated `.xcodeproj` (ADR-002).
- AppKit only in `PCApp`; engine modules never import AppKit or PCApp
  (SwiftUI is allowed only for trivial auxiliary dialogs — ADR-001).
- Swift Concurrency (`async`/`await`, actors); no new GCD (ADR-008). The main
  thread renders; all I/O and enumeration run off-main.
- No `print()` in committed code — use `os.Logger` with category = module name.
- No `UserDefaults` for app config — use `ConfigStore`.
- User-visible strings go through `String(localized:)` (EN base, DE localized).
- Every UI command goes through the `PCCommands` registry — no ad-hoc selectors
  from menu items to controllers.

See `CONVENTIONS.md` for the full list and `DECISIONS.md` for the ADRs behind
these rules.

## Open questions

- `project.yml` hard-codes Apple-silicon Homebrew paths for libssh2; Intel hosts
  need manual adjustment and there is no auto-detection.
- Sparkle auto-update is declared but not integrated; the appcast flow is
  unimplemented.
- Signing/notarization are manual (`RELEASE.md` `[creds]` steps) and not yet
  scripted or CI-gated.
