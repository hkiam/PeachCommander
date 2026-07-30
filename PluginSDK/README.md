# Peach Commander Plugin SDK (SwiftPM)

A distributable SwiftPM package that vends the Peach Commander plugin **C ABI**
so external authors can build plugins without copying headers by hand.

## Plugin types

| Header        | Type | Purpose                                   |
|---------------|------|-------------------------------------------|
| `pcx.h`       | PCX  | Packer plugins (browse / extract / pack)  |
| `pdx.h`       | PDX  | Content / detector plugins                |
| `pfx.h`       | PFX  | Virtual file-system plugins               |
| `plx.h`       | PLX  | Lister (viewer) plugins                   |
| `contrib.h`   | —    | Shared command / view contribution ABI    |
| `pc_common.h` | —    | Shared types used by all of the above     |

## Usage (Swift-authored plugin)

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/…/PeachCommanderPluginSDK.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyPlugin", dependencies: [
        .product(name: "CPeachCommanderPlugin", package: "PeachCommanderPluginSDK"),
    ]),
]
```

```swift
import CPeachCommanderPlugin

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }
```

C-authored plugins can instead add the package's `include` directory to their
compiler's search path (`-I …/CPeachCommanderPlugin/include`).

Each plugin ships as a `*.pfxplugin` / `*.pcxplugin` / … bundle with a
`Contents/Info.plist` manifest (`PCPluginType`, `PCPluginName`,
`PCPluginAPIVersion`) and `Contents/MacOS/<name>` binary. See
`Plugins/SDK/PORTING.md` for the full walkthrough and `Plugins/Sample*` for
worked examples.

## Header provenance

The headers here mirror the canonical in-repo copies under `Plugins/SDK/`.
Run `Tools/sync-plugin-sdk.sh` from the repo root to refresh them after an ABI
change so the distributable package never drifts.
