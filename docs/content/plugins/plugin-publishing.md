---
title: Publishing a plugin
slug: plugin-publishing
group: Develop
section: SDK & plugins
order: 40
related: [plugin-tutorials, sdk-overview, plugin-architecture-guide, arch-security]
---

How a plugin gets from your machine to somebody else's. There is no registry and nothing to
register with: a plugin is a file, and this page is about which file, how it is installed, and what
the version numbers on it mean.

## The SDK, and the example

Two repositories, neither of which needs a copy of the application's source:

- **[PeachCommanderPluginSDK](https://github.com/hkiam/PeachCommanderPluginSDK)** — the six C ABI
  headers as a SwiftPM package, the Swift helpers (`L()` for localisation, `PluginTheme` for the
  host's colours), `pcplug-validate`, and the two build scripts.
- **[PeachCommanderPluginISO](https://github.com/hkiam/PeachCommanderPluginISO)** — a complete
  third-party plugin: ISO 9660 / Joliet / Rock Ridge / UDF disc images, with its own build, tests,
  CI and release. Copy it rather than starting from a blank directory.

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/hkiam/PeachCommanderPluginSDK.git", from: "1.0.0"),
],
```

The canonical headers still live in this repository under `Plugins/SDK/`; the SDK package is
published from them on each release, and `Tools/check-sdk-headers.sh` fails the build if any copy
drifts.

## The package: `.pcplug`

A plugin package is a **zip archive with its own extension**, holding the bundle and a
`pluginst.inf` descriptor:

```
ISO9660-1.0.0.pcplug          (zip)
├── pluginst.inf              [plugininstall] type=pcx  file=ISO9660.pcxplugin  description=…
└── ISO9660.pcxplugin/
    └── Contents/
        ├── Info.plist        the manifest
        ├── MacOS/ISO9660     the dylib — base name must match the bundle name
        └── Resources/        optional: <lang>.lproj, assets
```

Build one with the SDK's script:

```
Tools/make-pcplug.sh MyPlugin.pcxplugin dist/
→ dist/MyPlugin-1.0.0.pcplug
```

The version in the file name comes from the manifest, so the file on a release page cannot disagree
with the plugin inside it.

Because it is a zip, the same file also installs through Configuration ▸ Plugins on versions that
predate the extension. The extension buys the double-click, not the capability.

## How users install it

Four routes, one confirmation:

| | |
|---|---|
| Double-click in the Finder | the app declares `.pcplug` as a document type |
| Enter on it in a panel | this is a file manager; the file is usually already in front of them |
| Drag onto Configuration ▸ Plugins… | |
| Configuration ▸ Plugins… ▸ **Install…** | also takes a `.zip` or an unpacked bundle |

Before anything is loaded, the dialog names the plugin, its version, its identifier, its type, and
**the file extensions it will take over** — a packer plugin that claims `.iso` becomes the app's
reader for those files, which is a consequence a user cannot otherwise see. If a plugin with the
same identifier is already installed, both versions are shown, so an update reads as an update and
a downgrade is called out as one.

Installation is not automatic and is not meant to be: a plugin runs in-process with the same access
to the user's files that the app has.

**Quarantine.** A downloaded package carries `com.apple.quarantine`, and a quarantined dylib is
refused by Gatekeeper on a signed, notarized build. The app clears the flag on the installed
bundle — but only after the user has confirmed, which is the moment their decision replaces
Gatekeeper's. This is why the dialog says the package came from the internet.

**Signing.** You do not need a Developer ID certificate and you do not need to notarize. The app
ships with `com.apple.security.cs.disable-library-validation` precisely so unsigned third-party
plugins load. Signing yours is welcome and changes nothing about whether it works. See the
[security model](arch-security.md) for what that costs.

## Checking your work

```
swift run pcplug-validate MyPlugin.pcxplugin
swift run pcplug-validate MyPlugin.pcxplugin --open some-test-file
```

`pcplug-validate` runs the host's admission checks in the host's own order — the manifest, the API
version window, the executable's name and **both architecture slices**, `dlopen`, every required
export for the declared type, and the `PcGetApiVersion` handshake. For a packer plugin, `--open`
opens a real file, lists it, and reads a slice back through `ReadEntryData`.

The architecture check is the one that catches the mistake nobody sees coming: the app is a
universal binary, and a plugin built for one architecture cannot be loaded *at all* on the other.
Nothing about it looks wrong until somebody on the other kind of Mac reports that your plugin does
not exist.

## Versioning

Two numbers, answering different questions.

### `PCPluginAPIVersion` — the ABI

What you built against; the value of `PC_API_VERSION` in the headers. It changes **only when
something that already worked stops working**. Adding an optional export, a capability bit, or a
field at the end of a service table does not bump it: plugins built before the addition keep
running untouched, and a plugin that wants the new thing tests for it — an absent symbol, an unset
bit — rather than demanding a version.

The host accepts a **window**, `PC_API_MIN_SUPPORTED` through `PC_API_VERSION`, and reports the two
ends differently, because they need different actions:

- below the window — the plugin is too old, and its author has to rebuild it;
- above the window — the *user's app* is too old, and updating it is the fix. The message says so.

### `PCPluginVersion` — yours

Semver, bumped on every release. The host reads it at install time to distinguish an update from a
reinstall from a downgrade, and shows the user which is happening. If it is absent,
`CFBundleShortVersionString` is used; if that is absent too, the plugin reports itself as `0.0.0`
and every install looks like an upgrade from nothing.

### `PCPluginIdentifier` — not a version, but the thing versions attach to

Reverse-DNS, and **strongly recommended**. It is the stable key the host stores the user's on/off
setting and file associations under. Without it the display name is used, which means renaming your
plugin silently loses the user's settings, and two plugins that happen to share a title displace
each other. It may not contain `;` `,` `=` `[` `]` or whitespace — those are `plugins.ini` syntax.

### `PCPluginMinHostVersion`

A `"1.2.3"` string is the minimum *app* version, checked against the running app; a bare integer is
the older meaning, a minimum plugin-API level. Set it to the oldest version you have actually
tried, not the newest one you have. A plugin that merely *uses* a newer feature — through an
optional export an older host does not look for — should keep the lower minimum and degrade
instead of excluding people for nothing.

## A release, end to end

The example plugin's `release.yml` is the shape:

1. a tag `vX.Y.Z` is pushed;
2. CI checks the tag against `PCPluginVersion` in the manifest — one version, not two;
3. tests run;
4. `build.sh dist --package` produces the universal bundle and the `.pcplug`;
5. `pcplug-validate` runs against the package, not just the bundle;
6. the package is attached to a GitHub release.

Nothing about that is specific to this project's infrastructure. Distribute the file however you
like — a release page, a web server, an email. Users install it the same way regardless.
