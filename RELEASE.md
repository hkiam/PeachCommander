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

This is enforced, not documented-and-hoped-for. `Tools/verify-shipping.sh` runs inside
make-dmg.sh before the image is staged and fails the release if any Mach-O in the bundle
carries a single slice — the previous version of this section was a one-liner to run by
hand, which is precisely why nobody ran it while twelve plugins shipped host-only.

The same script also checks that every plugin in `Plugins/` (bar `Sample*` and `SDK`) is
actually built by `build-all-plugins.sh`, because the CSV lister sat there for weeks
without being shipped. That half needs no build and runs in CI too.

```bash
Tools/verify-shipping.sh                 # shipping-set completeness only
Tools/verify-shipping.sh path/to/App.app # plus every Mach-O is arm64 + x86_64
```

`PC_PLUGIN_ARCHS=arm64` builds plugins for one architecture when iterating locally.

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

**The README's download link needs no maintenance — and must stay the way it is.** It points at
`/releases/latest`, which GitHub redirects to the newest release page, and a shields.io badge beside it
names the version (`include_prereleases`, or it reports nothing here). The obvious "improvement" —
`/releases/latest/download/PeachCommander.dmg`, a direct link to the asset — **404s for this
repository**, measured: that route and the `releases/latest` API both skip pre-releases, and every
release so far is one. It would start working the day a release is published without the pre-release
flag, and break again at the next beta.

**Publishing matters for the website.** The download buttons on
<https://hkiam.github.io/PeachCommander/> read the GitHub releases API
(`docs/assets/website/download.js`). Draft releases are invisible to the anonymous
API, so the buttons keep showing "No build published yet" until step 4 is done.
Once a release is published the buttons pick it up on the next page load — no
redeploy of the site is needed.

## Signing & notarization

The pipeline is wired up but **inactive until you add the secrets** — with none
present it prints a warning and produces the same unsigned DMG as before. Nothing
else needs changing; add the secrets and the next release is signed and notarized.

> **Not yet exercised against a real certificate.** The scripts, the keychain
> import and the unsigned fall-through are tested; the Developer ID signature and
> the notary submission have never run, because that needs credentials. Expect to
> iterate once on the first signed release.

### Secrets

Signing — both required, or the build stays unsigned:

| Secret | Contents |
| --- | --- |
| `DEVELOPER_ID_APP` | base64 of the *Developer ID Application* `.p12` (`base64 -i cert.p12 \| pbcopy`) |
| `DEVELOPER_ID_PASSWORD` | password for that `.p12` |

Notarization — an App Store Connect API key (preferred for CI):

| Secret | Contents |
| --- | --- |
| `NOTARY_KEY` | the whole `.p8` private key, including its BEGIN/END lines |
| `NOTARY_KEY_ID` | the key's Key ID |
| `NOTARY_ISSUER_ID` | the issuer UUID |

…or an Apple ID instead, if you prefer: `NOTARY_APPLE_ID`, `NOTARY_PASSWORD` (an
**app-specific** password, not the account password) and `NOTARY_TEAM_ID`.

A `notarytool` *keychain profile* is deliberately not supported. A profile lives in
a local keychain and cannot be handed to a fresh runner — the workflow used to
document a `NOTARY_KEYCHAIN_PROFILE` secret, which could never have worked in CI.

### How it runs

1. **Import Developer ID certificate** (`release.yml`) — creates a throwaway
   keychain, imports the `.p12`, and resolves the identity hash. This runs *before*
   packaging on purpose: the app is signed on its way into the image, so a
   certificate arriving later would leave the shipped app unsigned.
2. **`Tools/codesign-app.sh`**, called by `make-dmg.sh` once the plugins and dylibs
   are in place. Signs inside-out — the 3 embedded dylibs, the 8 frameworks, then
   each plugin in `Contents/PlugIns`, then the bundle itself with
   `--options runtime --timestamp` and `Resources/PeachCommander.entitlements`
   (no App Sandbox, library validation relaxed for third-party plugins; ADR-006).
   `--deep` is *not* used: Apple documents it as unsuitable for distribution
   signing, and it would push the app's entitlements onto nested code.
3. **`make-dmg.sh`** signs the finished disk image too, so Gatekeeper can judge the
   download itself and notarytool has something to staple to.
4. **`Tools/notarize.sh`** submits with `--wait`, staples the ticket, then verifies
   with `stapler validate` and `spctl --assess`. A rejection fails the job rather
   than shipping an image Gatekeeper will refuse.

Both scripts no-op when their credentials are missing, so they are safe to keep in
the pipeline and safe to run locally.

Until a signed release exists, `docs/content/user-guide/installation.md` documents
the right-click → **Open** workaround for users, and auto-update via Sparkle stays
disabled (`Sparkle/` is gitignored; the feed is not published).

## Version numbers

The version the app reports lives in `project.yml` — `CFBundleShortVersionString`
and `CFBundleVersion` under the app target's `info.properties` (currently `0.1.0`
and `1`). `Tools/bootstrap.sh` generates `Sources/PCApp/Info.plist` from it, so
`project.yml` is the single place to edit.

Bump it **before** tagging. `Tools/check-version.sh` enforces the match and runs as
the first step of the release workflow, so a mismatched tag fails in seconds
instead of after the build:

```bash
Tools/check-version.sh          # what version is this?
Tools/check-version.sh v0.2.0   # would this tag be accepted?
```

Nothing *derives* the tag from `project.yml` — bumping is still a deliberate edit —
but a `v0.2.0` tag can no longer ship an app that calls itself `0.1.0`.
