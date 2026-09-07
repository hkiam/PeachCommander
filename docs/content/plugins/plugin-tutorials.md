---
title: Plugin tutorials
slug: plugin-tutorials
group: Develop
section: SDK & plugins
order: 30
related: [sdk-overview, plugin-architecture-guide, plugin-publishing, api-overview]
---

Hands-on walkthroughs for building a Peach Commander plugin. They assume you have
read the [SDK overview](sdk-overview.md). All paths are relative to a checkout of
the repository; the SDK headers live in `Plugins/SDK/` and the bundled sample
plugins in `Plugins/` are working references.

## 1. Your first plugin — a command

The smallest useful plugin adds a **command** that appears in a menu and does
something with the selected file. This uses only the contributions ABI, so it works
regardless of plugin type; declare the type as `ptx` (a pure tool/action plugin).

**a. The manifest** (`Contents/Info.plist`):

```xml
<key>PCPluginType</key>        <string>ptx</string>
<key>PCPluginName</key>        <string>Word Count</string>
<key>PCPluginAPIVersion</key>  <integer>1</integer>
<key>PCContributions</key>
<dict>
  <key>commands</key>
  <array>
    <dict>
      <key>id</key><string>plugin.wordcount.count</string>
      <key>title</key><string>Count Words</string>
      <key>needsLocalPath</key><true/>
    </dict>
  </array>
  <key>contextMenus</key>
  <array>
    <dict>
      <key>command</key><string>plugin.wordcount.count</string>
      <key>surface</key><string>panel.item</string>
      <key>when</key><string>cursorPath</string>
    </dict>
  </array>
</dict>
```

**b. The behavior** (`wordcount.swift`):

```swift
import CPeachCommanderPlugin
import Foundation

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?,
                         _ services: UnsafePointer<PcHostServices>?) {
    guard let services = services?.pointee, let host = services.host else { return }
    var buf = [CChar](repeating: 0, count: 4096)
    guard services.localCursorPath?(host, &buf, 4096) == 1 else { return }
    let path = String(cString: buf)
    let words = (try? String(contentsOfFile: path, encoding: .utf8))?
        .split(whereSeparator: { $0.isWhitespace }).count ?? 0
    services.presentInfo?(host, "Word Count", "\(words) words in \(path)")
}
```

`needsLocalPath` + `localCursorPath` give you a real on-disk path even when the
cursor is inside an archive or on a remote file system (the host materializes it to
a temp file). `presentInfo` shows a native alert.

## 2. Add a menu item, toolbar button, or keybinding

You already added a context-menu item above. To also put the command in the menu
bar, in a container, or on a key, add more entries to `PCContributions`:

```xml
<key>menus</key>
<array>
  <dict>
    <key>command</key><string>plugin.wordcount.count</string>
    <key>menu</key><string>Commands</string>
    <key>group</key><string>9_plugins</string>
  </dict>
</array>
<key>keybindings</key>
<array>
  <dict>
    <key>command</key><string>plugin.wordcount.count</string>
    <key>key</key><string>cmd+shift+w</string>
  </dict>
</array>
```

Button-bar buttons run any command by id, so users can drop your command onto the
[button bar](toolbar.md) themselves — nothing extra is required from the plugin.

## 3. Add a panel or sidebar view

Declare a `views` contribution and implement `PcMakeView`, returning an `NSView*`.
The Treemap ("Disk Map") plugin is a full example: it declares a `sidebar` view and
reads its root folder from `getContext("sidebarViewRoot")`.

```swift
@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?,
                       _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    let view = MyView(frame: .zero)          // an NSView subclass
    return Unmanaged.passRetained(view).toOpaque()
}
```

The host calls `PcCloseView` when it tears the view down; balance your retain there.

## 4. Access selected files and run operations

- Cursor file: `services.cursorPath` (display path) or `localCursorPath` (on disk).
- Selection: `services.selectionCount` + `services.selectionPath(host, i, …)`.
- Act on files through the host op engine so it participates in undo/progress:
  `services.moveToTrash`, `services.deletePermanently`, then
  `services.reloadActivePanel`. Navigate with `openPath` / `openPathInPanel`.

For a **file-system** plugin (PFX) or a **packer** (PCX), you implement the
file-op ABI instead — see the [API reference](api-overview.md) and the SampleFS /
SamplePacker plugins.

## 5. Settings, events, and logging

- **Settings** — resolve your config directory from `-ConfigRoot` /
  `PEACHCMD_CONFIG_ROOT` (see the [architecture guide](plugin-architecture-guide.md))
  and store JSON there. Never use `UserDefaults`.
- **Events** — the host pushes context changes to an embedded view via
  `PcNotifyView(view, key, value)`; read live context with `getContext`.
- **Logging** — use `os.Logger` / `NSLog`; keep a plugin quiet by default. The
  bundled Log Viewer plugin is a good pattern for a tool window with its own menus.

## 6. Localize

Add `Resources/en.lproj/Localizable.strings` and translations, and look strings up
through your **own** bundle:

```swift
// PluginLoc.swift (copy from Plugins/SDK/)
let title = L("Count Words")   // English literal is the key; falls back if untranslated
```

Do **not** call `NSLocalizedString` — it resolves in the host bundle, not yours.

## 7. Package the plugin

Build a `.<type>plugin` bundle whose `Contents/MacOS/<name>` matches the bundle name — the host
derives that name from the bundle's, so the two must agree — and make it **universal**, because a
single-architecture plugin cannot be loaded at all on the other kind of Mac.

```
Tools/make-pcplug.sh MyPlugin.pcxplugin dist/
→ dist/MyPlugin-1.0.0.pcplug
```

`make-pcplug.sh` and `pc-universal.sh` are in the
[SDK repository](https://github.com/hkiam/PeachCommanderPluginSDK); in this repository the
`Tools/build-*-plugin.sh` scripts and `Tools/lib/pc-universal.sh` do the same thing for the bundled
plugins, and any of them works as a template.

A `.pcplug` is a zip with its own extension, holding the bundle and a `pluginst.inf`. Users install
it by double-clicking it, pressing Enter on it in a panel, dropping it on the plugin window, or
through Configuration ▸ Plugins ▸ Install… — see [publishing a plugin](plugin-publishing.md).

## 8. Test the plugin

- **Headless** — the host's test suite loads plugins through `PCPluginHost`;
  the SampleFS / SampleLister / SamplePacker plugins expose test hooks and are
  driven by `PCPluginHostTests`. Model your own tests on those.
- **In the app** — drop the bundle in the plugins folder, enable it in
  Configuration ▸ Plugins, and drive the app with the DEBUG `-AutomationScript`
  hook (or the VM screenshot harness) for repeatable checks.
- Because plugins are crash-guarded, a bug shows up as a quarantined plugin rather
  than an app crash — check the logs to see why it was quarantined.

## 9. Publish

Check it first — `pcplug-validate` runs the host's own admission checks, so a missing export or a
half-universal binary is caught by you rather than by a user:

```
swift run pcplug-validate MyPlugin.pcxplugin --open some-test-file
```

Then attach the `.pcplug` to a release page, or distribute it however you like; there is no
registry and nothing to register with. Give your plugin a reverse-DNS `PCPluginIdentifier` and a
semver `PCPluginVersion` before the first release — the identifier is what the user's settings are
stored under, and changing it later loses them.

[Publishing a plugin](plugin-publishing.md) covers the package format, the four install routes, the
quarantine and signing situation, and what the version numbers mean.

## Porting a Total Commander plugin

WCX/WFX/WLX/WDX plugins map directly onto PCX/PFX/PLX/PDX. `Plugins/SDK/PORTING.md`
is a full walkthrough: the type and entry-point maps, replacing Win32 types and
time formats, and a worked example. In most cases you keep your logic and swap the
header and a handful of signatures.
