---
title: SDK overview
slug: sdk-overview
section: SDK & plugins
order: 10
related: [plugin-architecture-guide, api-overview, plugin-tutorials]
---

Peach Commander is extensible through **native plugin bundles** loaded in-process.
The SDK gives you the stable C ABI headers those plugins are built against, plus a
distributable Swift package so you can write a plugin in Swift or C without a copy
of the app source.

## What you can build

Five plugin types cover the main extension points (each modeled on a Total
Commander plugin class so existing TC plugins can be source-ported):

| Type | Bundle | Extends | TC analog |
|------|--------|---------|-----------|
| **PCX** | `.pcxplugin` | Archive formats — browse, extract, pack | WCX |
| **PDX** | `.pdxplugin` | Content fields — custom columns, search criteria, rename placeholders | WDX |
| **PFX** | `.pfxplugin` | File systems — remote/virtual volumes mounted like a drive | WFX |
| **PLX** | `.plxplugin` | Listers — render a file into a custom view for the viewer / Quick View | WLX |
| **PTX** | `.ptxplugin` | Tools/actions — a native extension type with no TC analog | — |

Orthogonally, a plugin of *any* type may also carry **contributions** — declared
commands, menu/context-menu items, keybindings, and embedded views (sidebar,
preview, bottom bar, titlebar) — via the [contributions ABI](api-contrib.md).

## Stability & versioning

- The ABI is **C11, UTF-8, self-contained**, and versioned by a single integer,
  `PC_API_VERSION` (currently **1**). A plugin exports `PcGetApiVersion`; the host
  refuses to load a plugin whose version it does not support.
- New fields are only ever **appended** to service tables, so older plugins keep
  working. Treat the headers in `Plugins/SDK/` as the contract.
- Status: the ABI is usable today but **pre-1.0** — expect additive change before
  1.0. Pin the header version you built against and check `PcGetApiVersion`.

## Prerequisites

- macOS 13 or later, Xcode 16.
- A plugin is an ordinary macOS bundle; no entitlement or notarization is required
  to load one locally (the host runs with library validation disabled so it can
  load unsigned plugin dylibs — see the [security model](arch-security.md)).

## Integrating the SDK

The canonical headers live in `Plugins/SDK/`:

| Header | ABI |
|--------|-----|
| `pc_common.h` | shared types, return codes, capability flags, callbacks |
| `pcx.h` | packer (PCX) |
| `pdx.h` | content fields (PDX) |
| `pfx.h` | file system (PFX) |
| `plx.h` | lister (PLX) |
| `contrib.h` | contributions (commands/views) + unified host services |

Two ways to consume them:

- **Swift** — depend on the distributable package `PluginSDK/` and
  `import CPeachCommanderPlugin`, then export your entry points with `@_cdecl`:

  ```swift
  import CPeachCommanderPlugin

  @_cdecl("PcGetApiVersion")
  public func PcGetApiVersion() -> Int32 { 1 }
  ```

  ```swift
  // Package.swift
  dependencies: [ .package(path: "…/PeachCommander/PluginSDK") ],
  targets: [ .target(name: "MyPlugin", dependencies: [
      .product(name: "CPeachCommanderPlugin", package: "PluginSDK") ]) ]
  ```

- **C/Objective-C** — add `Plugins/SDK` to your header search path and
  `#include "pcx.h"` (or the header for your type).

The package re-exports all six headers through one module; it is kept in sync with
the in-app copies by `Tools/sync-plugin-sdk.sh` after any ABI change.

## Package structure

```
PluginSDK/
├── Package.swift                       # one C-library product: CPeachCommanderPlugin
└── Sources/CPeachCommanderPlugin/
    ├── include/                        # the six ABI headers + module.modulemap
    └── shim.c                          # empty TU so SwiftPM builds a C library
```

## Core concepts

- **In-process, synchronous C calls.** The host casts your exported symbols to
  `@convention(c)` and calls them directly. Long or blocking work is serialized on
  a per-instance queue unless you advertise `PC_CAP_MULTITHREAD`.
- **Host services token.** Callback tables carry an opaque `host` pointer that you
  pass back to each host callback (cursor path, selection, Keychain, navigation…).
- **Manifest first.** Placement (which menus/columns/extensions your plugin claims)
  is declared in `Info.plist`, so the host can show it **without loading your
  binary** — see the [plugin architecture guide](plugin-architecture-guide.md).
- **Crash-guarded.** Plugin calls run under a fatal-signal guard; a plugin that
  crashes is quarantined for the session rather than taking down the app.

## Where to go next

- [Plugin architecture guide](plugin-architecture-guide.md) — manifest, lifecycle,
  contributions, host services, `when` expressions, detect strings.
- [Plugin tutorials](plugin-tutorials.md) — build, package, test, and publish a plugin.
- [API reference](api-overview.md) — every ABI symbol, generated from the headers.
- `Plugins/SDK/PORTING.md` — port a Total Commander WCX/WFX/WLX/WDX plugin.
