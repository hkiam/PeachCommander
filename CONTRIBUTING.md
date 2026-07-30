# Contributing to Peach Commander

Bug reports, feature requests and pull requests are all welcome — the app is in
beta and this is exactly the stage where feedback changes it.

## Reporting bugs

Open an [issue](https://github.com/hkiam/PeachCommander/issues/new/choose). The bug
form asks for your **macOS version** and whether you are on **Apple Silicon or
Intel**, because a good share of problems are specific to one or the other. Steps to
reproduce beat a description of the symptom.

Something that looks like a security problem? Please don't open a public issue —
see [SECURITY.md](SECURITY.md).

## Building from source

You need **Xcode 26 or newer**. The sources use Swift 6.3 syntax and macOS 26 SDK
APIs, so Xcode 16 cannot build the project even though the app *runs* on macOS 13+.

```bash
git clone https://github.com/hkiam/PeachCommander.git
cd PeachCommander
./Tools/bootstrap.sh     # checks Xcode, installs xcodegen + libssh2, generates the project
./Tools/build.sh         # Debug build
./Tools/test.sh          # the full suite
```

`bootstrap.sh` installs `libssh2` via Homebrew. That is not optional: `CSSH2`
resolves `<libssh2.h>` from the keg and no header is vendored.

**Never edit `PeachCommander.xcodeproj`.** It is generated from `project.yml` by
XcodeGen, is not tracked in git, and `build.sh`/`test.sh` regenerate it on every run.
Build settings, targets and the app version all live in `project.yml`.

### Plugins

```bash
Tools/build-all-plugins.sh                  # into ~/Library/Application Support/PeachCommander/plugins
PC_PLUGIN_ARCHS=arm64 Tools/build-all-plugins.sh   # one slice only — much faster while iterating
```

Release builds compile every plugin universal (arm64 + x86_64) via
`Tools/lib/pc-universal.sh`. Keep that in mind if you add a build script: use
`pc_swiftc` / `pc_clang`, not `swiftc` / `clang` directly.

### Performance tests

`PCPerfTests` needs fixtures that are generated, not committed:

```bash
Tools/make-fixtures.sh
```

Without them those tests skip rather than fail.

## Changing documentation

The docs are single-sourced: the same Markdown feeds the in-app Apple Help Book and
the website. CI enforces four gates, so run them before pushing:

```bash
python3 docs/scripts/gen-api-reference.py   # regenerate derived reference pages
python3 docs/scripts/gen-overviews.py       # regenerate FEATURES.md + glossary
python3 docs/scripts/check-docs.py          # links, images, terminology, coverage
python3 docs/scripts/check-translations.py  # UI + Help translation coverage
python3 docs/scripts/build-site.py          # builds all 19 languages, strict
```

The generated files under `docs/content/reference/` and `FEATURES.md` **must be
committed** — CI fails if regenerating them produces a diff.

Two things that trip people up:

- **Terminology is enforced.** `docs/metadata/terminology.yml` lists words that must
  not appear in user-facing prose: write *panel*, never *pane* (so "dual-panel", not
  "dual-pane"), and *favorite*, never *bookmark*.
- **English is the source of truth.** Translated Help lives in `docs/help-<lang>/`;
  adding an English help topic without translations makes the coverage gate fail.

Read [`DOCUMENTATION.md`](DOCUMENTATION.md) before larger docs changes.

## Code style and layout

See [`CONVENTIONS.md`](CONVENTIONS.md) — module layout, AppKit-over-SwiftUI rule,
naming, testing expectations. New engine code comes with unit tests in the same
commit.

Add the licence identifier to new source files, matching the rest of the tree:

```swift
// SPDX-License-Identifier: Apache-2.0
```

> `WORKFLOW.md` is an operating protocol for AI-assisted sessions, not a guide for
> human contributors. You do not need to follow it to send a pull request.

## Pull requests

- Branch off `main` and keep the change focused on one thing.
- `./Tools/test.sh` green, plus the docs gates if you touched `docs/`.
- Explain *why* in the commit message, not just what — the existing history is
  written that way.
- Say what you verified and what you did not. "Not tested on Intel" is useful
  information, not a weakness.

## Releases

Maintainers only; the process, the signing story and the version rules are in
[`RELEASE.md`](RELEASE.md). Note that the app version lives in `project.yml` and
`Tools/check-version.sh` refuses a tag that disagrees with it.

## Licence

Contributions are accepted under the [Apache License 2.0](LICENSE), the same licence
as the project. By opening a pull request you agree your contribution is licensed
under it.
