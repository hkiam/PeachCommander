// SPDX-License-Identifier: Apache-2.0
// PluginTitleLocalizer.swift - Localize plugin contribution titles through the
// plugin's OWN bundle.
//
// Contribution titles (menu items, context items) come from a plugin's Info.plist
// and are English. Each plugin ships translations in its bundle's
// <lang>.lproj/Localizable.strings (the same tables its in-code `L()` reads, see
// Plugins/SDK/LOCALIZATION.md), keyed by the English title. Resolving the title
// through the plugin bundle keeps every plugin owning its own translations —
// including future third-party plugins the app catalog can't know about.

import Foundation

enum PluginTitleLocalizer {
    /// The plugin-bundle title translation for the app's current language, or the
    /// English `title` if the plugin ships no matching key. `bundlePath` is the
    /// plugin's `.…plugin` wrapper (the registry's pluginId).
    static func localize(_ title: String, bundlePath: String) -> String {
        guard let bundle = Bundle(path: bundlePath) else { return title }
        return bundle.localizedString(forKey: title, value: title, table: nil)
    }
}
