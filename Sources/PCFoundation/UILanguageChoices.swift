// SPDX-License-Identifier: Apache-2.0
// UILanguageChoices.swift - The languages the Settings ▸ Language page offers (F-272).
//
// The page used to list English and Deutsch by hand while the app shipped nineteen translations, so
// anyone who wanted French on an English Mac had no way to get it. The list is now whatever the bundle
// is localized into — a translation added later appears without anyone remembering this page.

import Foundation

public enum UILanguageChoices {
    /// One entry per localization, named in its own language ("Français", "Deutsch") because that is
    /// the name someone looking for it recognises, whatever language the menu is in now. Sorted by that
    /// name; `Base` and duplicates are left out.
    public static func choices(localizations: [String]) -> [(code: String, label: String)] {
        var seen = Set<String>()
        let codes = localizations.filter { $0 != "Base" && seen.insert($0).inserted }
        return codes.map { code in
            let locale = Locale(identifier: code)
            let name = locale.localizedString(forIdentifier: code) ?? code
            return (code, name.prefix(1).uppercased(with: locale) + name.dropFirst())
        }
        .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }
}
