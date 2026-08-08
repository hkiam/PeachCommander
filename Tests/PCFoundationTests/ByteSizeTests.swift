// SPDX-License-Identifier: Apache-2.0
// ByteSizeTests.swift - The free-space and size-field formatter (F-030).
//
// Two things this got wrong, both visible every day:
//
//   * the unit ladder stopped at gigabytes, so a 4 TB volume's free space read "4096.0 GB" and a 16 TB
//     one "16384.0 GB";
//   * `String(format: "%.1f")` writes a decimal *point* whatever the language, while
//     `SelectionSummaryFormatter` right beside it in the same status bar is locale-aware — so a German
//     user saw "4096.0 GB" next to "2,0 M".
//
// The second could not simply be fixed: the Find Files dialog *writes* these strings into its size
// fields when a template is loaded and *reads them back* when the search starts, so a localized comma
// had to be parseable before it could be produced.

import XCTest
@testable import PCFoundation

final class ByteSizeTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let de = Locale(identifier: "de_DE")

    private func gib(_ count: Double) -> Int64 { Int64(count * 1024 * 1024 * 1024) }

    // MARK: - The ladder goes past gigabytes

    func testATerabyteVolumeIsNotFourDigitsOfGigabytes() {
        XCTAssertEqual(ByteSize(gib(1024)).formatted(style: .mb, locale: en), "1.0 TB")
        XCTAssertEqual(ByteSize(gib(4096)).formatted(style: .mb, locale: en), "4.0 TB")
        XCTAssertEqual(ByteSize(gib(16384)).formatted(style: .mb, locale: en), "16.0 TB")
    }

    func testTheUnitsBelowThatAreUnchanged() {
        XCTAssertEqual(ByteSize(512 * 1024 * 1024).formatted(style: .mb, locale: en), "512 MB")
        XCTAssertEqual(ByteSize(gib(5)).formatted(style: .mb, locale: en), "5.0 GB")
        XCTAssertEqual(ByteSize(gib(100)).formatted(style: .mb, locale: en), "100.0 GB")
        XCTAssertEqual(ByteSize(1536).formatted(style: .kb, locale: en), "1.5 KB")
        XCTAssertEqual(ByteSize(1234).formatted(style: .bytes), "1234 bytes")
    }

    // MARK: - The separator matches the rest of the status bar

    func testTheDecimalSeparatorFollowsTheLocale() {
        XCTAssertEqual(ByteSize(gib(4096)).formatted(style: .mb, locale: de), "4,0 TB")
        XCTAssertEqual(ByteSize(1536).formatted(style: .kb, locale: de), "1,5 KB")
        XCTAssertEqual(ByteSize(gib(5)).formatted(style: .mb, locale: de), "5,0 GB")
    }

    // MARK: - What is written into the size fields must read back

    func testWhatFormattedWritesParseCanRead() throws {
        for locale in [en, de, Locale(identifier: "fr_FR")] {
            for bytes: Int64 in [700, 10 * 1024, 1536 * 1024, 5 * 1024 * 1024 * 1024] {
                let shown = ByteSize(bytes).formatted(style: .kb, locale: locale)
                XCTAssertNotNil(ByteSize.parse(shown),
                                "\(locale.identifier): [\(shown)] came out of formatted and will not parse")
            }
        }
    }

    func testParseAcceptsBothDecimalSeparators() {
        XCTAssertEqual(ByteSize.parse("1.5M"), 1536 * 1024)
        XCTAssertEqual(ByteSize.parse("1,5M"), 1536 * 1024)
        XCTAssertEqual(ByteSize.parse("1,5 MB"), 1536 * 1024)
    }

    func testParseStillRefusesNonsense() {
        // The forgiveness above must not turn into "accepts anything": a filter that silently means
        // nothing is worse than one that reports a bad value.
        XCTAssertNil(ByteSize.parse(""))
        XCTAssertNil(ByteSize.parse("abc"))
        XCTAssertNil(ByteSize.parse("1.2.3M"))
        XCTAssertNil(ByteSize.parse("-5M"))
    }
}
