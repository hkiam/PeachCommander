# Releasing Peach Commander

How a build gets from a tag to a downloadable disk image, what is automated today,
and what still has to be done by hand. Referenced from
`.github/workflows/release.yml` and `Tools/make-dmg.sh`.

> **Status:** the packaging path is automated end to end; **signing and
> notarization are not yet wired up**. Until they are, every DMG is unsigned and
> Gatekeeper will refuse it on a normal double-click (right-click → **Open**
> works). See [Signing & notarization](#signing--notarization).

## The pipeline

`.github/workflows/release.yml` runs on `macos-26` with Xcode `^26.0` and is
triggered by:

- **pushing a version tag** — `v*`, e.g. `v0.9.0`; this is the real release path, or
- **`workflow_dispatch`** — a dry run. It builds, tests and packages the DMG and
  uploads it as a workflow artifact, but the "Create GitHub Release" step is gated
  on `startsWith(github.ref, 'refs/tags/')`, so **no release is created**. Use this
  to validate pipeline changes without publishing anything.

Steps:

1. `brew install xcodegen libssh2` — libssh2 is required, not optional: `CSSH2`
   resolves `<libssh2.h>` from the keg (no header is vendored) and
   `Tools/bundle-libssh2.sh` copies the dylibs out of it.
2. `Tools/bootstrap.sh` — generates `PeachCommander.xcodeproj` from `project.yml`
   (the project is not tracked in git) and enforces Xcode 26+.
3. `Tools/build.sh` and `Tools/test.sh` — a release is never cut from a red tree.
4. `Tools/make-dmg.sh` — see below.
5. Upload `build/PeachCommander.dmg` as the `PeachCommander-dmg` artifact.
6. On a tag only: create a **draft** GitHub Release with generated notes and the
   DMG attached.

## What make-dmg.sh produces

`Tools/make-dmg.sh [configuration]` (default `Release`) writes
`build/PeachCommander.dmg`, a compressed UDZO image containing the app plus an
`/Applications` symlink. On the way it:

- regenerates `Resources/ThirdPartyNotices.json` + `Licenses/` from
  `Package.resolved` via `Tools/generate-third-party-notices.py`, so the shipped
  app always carries current attributions;
- builds with `CODE_SIGNING_ALLOWED=NO` into `build/dmg-derived`;
- bundles **every shipping plugin** into `Contents/PlugIns` via
  `Tools/build-all-plugins.sh` (sample plugins are excluded), pointing the AI
  plugin at this build's `PCAutomation.framework` rather than Debug DerivedData;
- embeds `libssh2` + `openssl@3` into `Contents/Frameworks` with `@rpath` install
  names via `Tools/bundle-libssh2.sh`, so SFTP works without Homebrew on the
  target machine (F-214), and ad-hoc re-signs what it rewrote.

### How the universal build hangs together

The DMG is a genuine universal binary — `arm64` **and** `x86_64` in every Mach-O it
carries. Three things have to line up for that, and each one silently degraded the
result on its own before:

1. **No `ARCHS` override.** `project.yml` already sets `ARCHS = arm64 x86_64` on the
   app target; `make-dmg.sh` used to override it with `$(uname -m)`, which reduced
   the shipped image to the build machine's slice.
2. **Universal libssh2 + openssl.** `Tools/make-universal-deps.sh` stages 2-slice
   dylibs under `build/universal-deps` and the build points at them through
   `PC_SSH2_PREFIX`. A Homebrew keg only ever holds the host architecture, so
   linking the `x86_64` slice against it fails outright — and bundling it would put
   a single-architecture dylib inside a universal app, breaking SFTP on Intel.
   The bottles come straight from Homebrew's registry (checksum verified) because
   `brew fetch --bottle-tag` refuses a foreign architecture on an arm64 install.
3. **Universal plugins.** Every `Tools/build-*-plugin*.sh` goes through
   `Tools/lib/pc-universal.sh`. They used to compile for `$(uname -m)`, which meant
   the app launched on Intel while *no plugin could load* — Git, Archive, WebDAV,
   Disk Map and the rest just silently absent. `clang` takes several `-arch` flags
   directly; `swiftc` accepts only one `-target`, so each slice is compiled
   separately and merged with `lipo`.

Verify a packaged build rather than trusting it:

```bash
APP=build/dmg-derived/Build/Products/Release/PeachCommander.app
find "$APP" -type f -exec sh -c 'a=$(lipo -archs "$1" 2>/dev/null) || exit 0
  [ -n "$a" ] && case "$a" in *arm64*x86_64*|*x86_64*arm64*) ;; *) echo "SINGLE: $1 -> $a";; esac' _ {} \;
```

Silence means every slice is present. `PC_PLUGIN_ARCHS=arm64` builds plugins for one
architecture when iterating locally.

## Cutting a release

```bash
# 1. Make sure main is green (CI, Docs, Pages) and the tree is clean.
git switch main && git pull

# 2. Dry-run the packaging pipeline without publishing anything.
gh workflow run release.yml --ref main
gh run watch

# 3. Tag and push. This is what actually creates the release.
git tag -a v0.9.0 -m "Peach Commander v0.9.0"
git push origin v0.9.0

# 4. Review the DRAFT release, then publish it.
gh release view v0.9.0
gh release edit v0.9.0 --draft=false
```

Step 4 is deliberately manual: the workflow creates the release as
`draft: true`, so nothing becomes public until a human looks at the notes and the
attached DMG.

**Publishing matters for the website.** The download buttons on
<https://hkiam.github.io/PeachCommander/> read the GitHub releases API
(`docs/assets/website/download.js`). Draft releases are invisible to the anonymous
API, so the buttons keep showing "No build published yet" until step 4 is done.
Once a release is published the buttons pick it up on the next page load — no
redeploy of the site is needed.

## Signing & notarization

Not implemented yet. The workflow has a placeholder step that warns when no
signing secrets are present and otherwise does nothing. Wiring it up needs:

| Secret | Contents |
| --- | --- |
| `DEVELOPER_ID_APP` | base64 of the *Developer ID Application* `.p12` certificate |
| `DEVELOPER_ID_PASSWORD` | password for that `.p12` |
| `NOTARY_KEYCHAIN_PROFILE` | `notarytool` keychain profile name |

The steps a signed release has to perform, in order:

1. Import the `.p12` into a temporary keychain.
2. `codesign --force --options runtime --timestamp --deep --sign "Developer ID Application: …"`
   over the app — note the plugins in `Contents/PlugIns` and the dylibs in
   `Contents/Frameworks` are signed as part of this pass, replacing the ad-hoc
   signatures `bundle-libssh2.sh` applied.
3. `xcrun notarytool submit build/PeachCommander.dmg --keychain-profile "…" --wait`
4. `xcrun stapler staple build/PeachCommander.dmg`
5. `spctl -a -t open --context context:primary-signature -v build/PeachCommander.dmg`
   to verify Gatekeeper accepts the result.

Until that exists, `docs/content/user-guide/installation.md` documents the
right-click → **Open** workaround for users, and auto-update via Sparkle stays
disabled (`Sparkle/` is gitignored; the feed is not published).

## Version numbers

The version the app reports lives in `project.yml` — `CFBundleShortVersionString`
and `CFBundleVersion` under the app target's `info.properties` (currently `0.1.0`
and `1`). `Tools/bootstrap.sh` generates `Sources/PCApp/Info.plist` from it, so
`project.yml` is the single place to edit.

Bump it **before** tagging. Nothing derives the tag from that value or checks that
they agree, so `v0.9.0` will happily ship an app that calls itself `0.1.0`.
