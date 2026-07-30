// PanelDateFormatter.swift - Configurable Date column formatting (F-031).
//
// The file panel's Date column uses a user-configurable Unicode date pattern
// (Options → Display). An empty pattern falls back to the locale's short
// date+time, matching the system format. Kept tiny and pure so it can be unit-
// tested with a fixed locale/timezone; the panel caches one formatter built here.

import Foundation

public enum PanelDateFormatter {
    /// The built-in default pattern (ISO-like, sortable) used when nothing is set.
    public static let defaultPattern = "yyyy-MM-dd HH:mm"

    /// A `DateFormatter` configured from `pattern`. A blank pattern uses the
    /// locale's short date + short time instead of a fixed pattern.
    public static func makeFormatter(pattern: String,
                                     locale: Locale = .current,
                                     timeZone: TimeZone = .current) -> DateFormatter {
        let df = DateFormatter()
        df.locale = locale
        df.timeZone = timeZone
        let p = pattern.trimmingCharacters(in: .whitespaces)
        if p.isEmpty {
            df.dateStyle = .short
            df.timeStyle = .short
        } else {
            df.dateFormat = p
        }
        return df
    }

    /// Convenience: format a single `date` with `pattern`.
    public static func string(_ date: Date, pattern: String,
                              locale: Locale = .current,
                              timeZone: TimeZone = .current) -> String {
        makeFormatter(pattern: pattern, locale: locale, timeZone: timeZone).string(from: date)
    }
}
