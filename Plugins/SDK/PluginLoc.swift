// SPDX-License-Identifier: Apache-2.0
// PluginLoc.swift - Shared localization helper for PeachCommander plugins.
//
// Add this file to a plugin's swiftc sources (see Tools/build-*-plugin.sh) and wrap
// user-facing strings in `L("English source text")`. Ship translations as
// Plugins/<Name>/Resources/<lang>.lproj/Localizable.strings; the build script copies
// them into the plugin bundle's Contents/Resources. `L` looks them up in the plugin's
// OWN bundle (resolved via a class compiled into the plugin), so each plugin is
// localized independently and new plugins get the same mechanism for free.
//
// The English source string is the key; a missing translation falls back to it.

import Foundation

/// Anchor whose bundle is the plugin bundle: `Bundle(for:)` on a class compiled into
/// the plugin resolves to that plugin's `.­plugin` wrapper even when it is dlopen'd.
final class PluginBundleAnchor {}

/// A localized string from the plugin's own bundle (Localizable.strings), or `key`.
func L(_ key: String, _ comment: String = "") -> String {
    Bundle(for: PluginBundleAnchor.self).localizedString(forKey: key, value: key, table: nil)
}
