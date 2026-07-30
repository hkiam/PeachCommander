# Localizing a PeachCommander plugin

Every plugin localizes itself independently, using its own bundle. The mechanism is
shared and identical for all plugins, so a new plugin gets it "for free" by following
four steps. English is the source language (the English literal is the key); German is
shipped today. Adding Slovak, Russian, … later is one `.lproj` file per plugin.

## The four steps

1. **Compile the shared helper into the plugin.** Add `Plugins/SDK/PluginLoc.swift` to
   the plugin's `swiftc` sources in `Tools/build-<name>-plugin.sh`:

   ```sh
   swiftc -emit-library -O ... \
     "$ROOT/Plugins/<Name>/<name>.swift" \
     "$ROOT/Plugins/SDK/PluginLoc.swift"
   ```

   `PluginLoc.swift` defines `L("English text")`. It resolves the plugin's OWN bundle
   via a class compiled into that plugin (`Bundle(for: PluginBundleAnchor.self)`), which
   works even though the plugin is `dlopen`'d in-process. So `NSLocalizedString` (which
   would look in the host app's bundle) must NOT be used in a plugin — use `L(...)`.

2. **Wrap user-facing strings** in `L(...)`, keeping the English text as the key:

   ```swift
   window.title = String(format: L("Uninstall %@"), appName)   // format args preserved
   NSButton(title: L("Move to Trash"), ...)
   ```

3. **Ship translations** as `Plugins/<Name>/Resources/<lang>.lproj/Localizable.strings`.
   Ship BOTH `en.lproj` (source: key = key) AND every translation. With only one
   `.lproj`, NSBundle always picks that single localization regardless of the user's
   language, so `en.lproj` is required for English to actually resolve.

   ```
   Plugins/<Name>/Resources/en.lproj/Localizable.strings   # "Cancel" = "Cancel";
   Plugins/<Name>/Resources/de.lproj/Localizable.strings   # "Cancel" = "Abbrechen";
   ```

4. **Copy the resources into the bundle** at the end of the build script:

   ```sh
   if [ -d "$ROOT/Plugins/<Name>/Resources" ]; then
     cp -R "$ROOT/Plugins/<Name>/Resources/." "$BUNDLE/Contents/Resources/"
   fi
   ```

At runtime `L("Cancel")` returns the string for the app's current language from the
plugin's own bundle, falling back to the English key if a translation is missing.

## Adding a language

Add `Plugins/<Name>/Resources/<lang>.lproj/Localizable.strings` for each plugin, mirroring
the keys in `en.lproj`. No code or build-script changes are needed — the `cp -R` already
ships every `*.lproj`. Keep format specifiers (`%@`, `%lld`, `%1$@`) identical to the
source string.

## Verifying headlessly (no display, no language switch)

`-AppleLanguages '(de)'` is not honored by a bare Swift executable, so verify the
resolution logic directly against a specific language instead of the process language:

```swift
let b = Bundle(path: "<built>/<Name>.ptxplugin")!
let picked = Bundle.preferredLocalizations(from: b.localizations, forPreferences: ["de"]).first!
let url = b.url(forResource: "Localizable", withExtension: "strings",
                subdirectory: nil, localization: picked)!
print(NSDictionary(contentsOf: url)!["Cancel"])   // → Abbrechen
```

Reference implementation: the **Uninstaller** plugin (`Plugins/Uninstaller/`,
`Tools/build-uninstaller-plugin.sh`).
