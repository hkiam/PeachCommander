// SPDX-License-Identifier: Apache-2.0
// SelectionSummaryFormatter - Total-Commander-style status-bar summary
// A pure, locale-aware formatter for the panel status bar's selection
// summary (file counts and byte sizes).

import Foundation

/// Formats Total-Commander-style status-bar summaries describing a
/// directory panel's current selection, e.g. "3 of 41 files, 2.1 M of 340 M".
///
/// Every method is pure (no shared mutable state) and locale-aware: decimal
/// separators and digit grouping follow the supplied `Locale`, and the
/// connecting words route through `String(localized:)` so they can be
/// translated.
public enum SelectionSummaryFormatter {

    /// Byte value below which `dynamicSize` renders a plain integer.
    private static let kiloThreshold: Int64 = 1000

    /// Byte value below which `dynamicSize` renders in "K" units.
    private static let megaThreshold: Int64 = 1000 * 1024

    /// Byte value below which `dynamicSize` renders in "M" units.
    private static let gigaThreshold: Int64 = 1000 * 1024 * 1024

    /// Builds a Total-Commander-style status summary, e.g.
    /// "3 of 41 files, 2.1 M of 340 M" (the decimal separator is
    /// locale-aware: "2,1 M" in German locales).
    ///
    /// When `selectedCount` is `0`, the summary still reads
    /// "0 of N files, 0 of <total>" rather than omitting the selection part.
    ///
    /// - Parameters:
    ///   - selectedCount: Number of currently selected entries.
    ///   - totalCount: Total number of entries in the panel.
    ///   - selectedBytes: Combined size in bytes of the selected entries.
    ///   - totalBytes: Combined size in bytes of all entries in the panel.
    ///   - locale: Locale used for number formatting and word choice.
    ///     Defaults to `.current`.
    /// - Returns: A single-line summary string suitable for a status bar.
    public static func summary(selectedCount: Int,
                                totalCount: Int,
                                selectedBytes: Int64,
                                totalBytes: Int64,
                                locale: Locale = .current) -> String {
        let selectedSize = dynamicSize(selectedBytes, locale: locale)
        let totalSize = dynamicSize(totalBytes, locale: locale)
        let of = ofWord(locale: locale)
        let files = filesWord(locale: locale)
        return "\(selectedCount) \(of) \(totalCount) \(files), \(selectedSize) \(of) \(totalSize)"
    }

    /// A status summary that breaks the counts into files and folders, making the
    /// marked amount explicit, e.g. "2/40 files, 1/5 folders · 3.4 M / 120 M".
    /// Byte sizes reflect files only (folders have no intrinsic size here).
    public static func detailed(selectedFiles: Int, totalFiles: Int,
                                selectedDirs: Int, totalDirs: Int,
                                selectedBytes: Int64, totalBytes: Int64,
                                locale: Locale = .current) -> String {
        let files = filesWord(locale: locale)
        let folders = foldersWord(locale: locale)
        let selSize = dynamicSize(selectedBytes, locale: locale)
        let totSize = dynamicSize(totalBytes, locale: locale)
        return "\(selectedFiles)/\(totalFiles) \(files), \(selectedDirs)/\(totalDirs) \(folders) · \(selSize) / \(totSize)"
    }

    /// Formats `bytes` the way Total Commander's "dynamic" size column does:
    /// a plain integer with thousands grouping below 1000, otherwise K / M /
    /// G with one fractional digit. Both the decimal separator and the
    /// grouping separator follow `locale`.
    ///
    /// Examples (en_US locale): `"999"`, `"2.1 K"`, `"340 M"`, `"1.2 G"`.
    ///
    /// - Parameters:
    ///   - bytes: The byte count to format.
    ///   - locale: Locale used for number formatting and the unit letter.
    ///     Defaults to `.current`.
    /// - Returns: The formatted size string, including its unit letter when
    ///   one applies.
    public static func dynamicSize(_ bytes: Int64, locale: Locale = .current) -> String {
        let magnitude = abs(bytes)

        if magnitude < kiloThreshold {
            let formatter = groupedIntegerFormatter(locale: locale)
            return formatter.string(from: NSNumber(value: bytes)) ?? String(bytes)
        }

        let unit: String
        let divisor: Double
        if magnitude < megaThreshold {
            unit = kiloUnit(locale: locale)
            divisor = 1024
        } else if magnitude < gigaThreshold {
            unit = megaUnit(locale: locale)
            divisor = 1024 * 1024
        } else {
            unit = gigaUnit(locale: locale)
            divisor = 1024 * 1024 * 1024
        }

        let value = Double(bytes) / divisor
        let formatter = groupedDecimalFormatter(locale: locale)
        let formattedValue = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
        return "\(formattedValue) \(unit)"
    }

    // MARK: - Number formatters

    /// A `NumberFormatter` for whole byte counts with locale-aware grouping.
    private static func groupedIntegerFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }

    /// A `NumberFormatter` for K/M/G values with one fractional digit and
    /// locale-aware grouping and decimal separators.
    private static func groupedDecimalFormatter(locale: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }

    // MARK: - Localized words

    /// The connector word between two counts, as in "3 of 41".
    private static func ofWord(locale: Locale) -> String {
        String(localized: "of", locale: locale, comment: "Connector word between two counts in the status bar summary, as in '3 of 41'")
    }

    /// The plural noun for entries in the status bar summary.
    private static func filesWord(locale: Locale) -> String {
        String(localized: "files", locale: locale, comment: "Plural noun for files/folders in the status bar summary, as in '3 of 41 files'")
    }

    /// The plural noun for folders/directories in the detailed status summary.
    private static func foldersWord(locale: Locale) -> String {
        String(localized: "folders", locale: locale, comment: "Plural noun for folders in the detailed status bar summary, as in '1/5 folders'")
    }

    /// Unit letter for kilobyte-scale sizes in `dynamicSize`.
    private static func kiloUnit(locale: Locale) -> String {
        String(localized: "K", locale: locale, comment: "Abbreviation for kilobytes in the dynamic size format")
    }

    /// Unit letter for megabyte-scale sizes in `dynamicSize`.
    private static func megaUnit(locale: Locale) -> String {
        String(localized: "M", locale: locale, comment: "Abbreviation for megabytes in the dynamic size format")
    }

    /// Unit letter for gigabyte-scale sizes in `dynamicSize`.
    private static func gigaUnit(locale: Locale) -> String {
        String(localized: "G", locale: locale, comment: "Abbreviation for gigabytes in the dynamic size format")
    }
}
