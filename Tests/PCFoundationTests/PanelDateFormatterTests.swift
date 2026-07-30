// SPDX-License-Identifier: Apache-2.0
// PanelDateFormatterTests.swift - Configurable Date column formatting (F-031).

import XCTest
@testable import PCFoundation

final class PanelDateFormatterTests: XCTestCase {
    // A fixed instant: 2024-01-31 14:05:00 UTC.
    private let date = Date(timeIntervalSince1970: 1_706_709_900)
    private let gmt = TimeZone(identifier: "GMT")!
    private let posix = Locale(identifier: "en_US_POSIX")

    func test_defaultPattern_isSortableIsoLike() {
        let s = PanelDateFormatter.string(date, pattern: PanelDateFormatter.defaultPattern,
                                          locale: posix, timeZone: gmt)
        XCTAssertEqual(s, "2024-01-31 14:05")
    }

    func test_customPattern_isApplied() {
        let s = PanelDateFormatter.string(date, pattern: "dd.MM.yyyy HH:mm",
                                          locale: posix, timeZone: gmt)
        XCTAssertEqual(s, "31.01.2024 14:05")
    }

    func test_blankPattern_fallsBackToLocaleShortStyle() {
        let s = PanelDateFormatter.string(date, pattern: "   ", locale: posix, timeZone: gmt)
        // en_US_POSIX short date/time (e.g. "1/31/24, 2:05 PM"): assert it's a
        // non-empty, non-ISO string mentioning the day (exact glyphs are locale-defined).
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("31"))
        XCTAssertNotEqual(s, "2024-01-31 14:05")
    }

    func test_makeFormatter_isReusableAcrossDates() {
        let df = PanelDateFormatter.makeFormatter(pattern: "yyyy", locale: posix, timeZone: gmt)
        XCTAssertEqual(df.string(from: date), "2024")
        let later = Date(timeIntervalSince1970: 1_760_000_000) // 2025
        XCTAssertEqual(df.string(from: later), "2025")
    }
}
