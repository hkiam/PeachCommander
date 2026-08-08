// SPDX-License-Identifier: Apache-2.0
// PCFoundationTests - Unit tests for PCFoundation module

import XCTest
@testable import PCFoundation

final class PCFoundationTests: XCTestCase {
    func testByteSizeFormatting_bytes() {
        let bs = ByteSize(1234)
        XCTAssertEqual(bs.formatted(style: .bytes), "1234 bytes")
    }

    // F-026: natural (numeric) vs plain alphabetic comparison.
    func testNaturalCompare_numericOrdering() {
        XCTAssertEqual(naturalCompare("file2", "file10"), .orderedAscending)          // 2 < 10
        XCTAssertEqual(naturalCompare("file10", "file2", natural: false), .orderedAscending)  // "1" < "2"
    }

    func testNaturalCompare_sortsAListNaturally() {
        let names = ["file10", "file2", "file1"]
        let natural = names.sorted { naturalCompare($0, $1) == .orderedAscending }
        XCTAssertEqual(natural, ["file1", "file2", "file10"])
        let plain = names.sorted { naturalCompare($0, $1, natural: false) == .orderedAscending }
        XCTAssertEqual(plain, ["file1", "file10", "file2"])
    }

    // An explicit locale, because the separator follows it now: these two asserted "1.5 KB" while
    // calling the machine's own locale, so they passed in CI (English) and failed on a German Mac. They
    // were testing the test runner's language, not the formatter.
    func testByteSizeFormatting_kb() {
        let bs = ByteSize(1536)  // 1.5 KB
        XCTAssertEqual(bs.formatted(style: .kb, locale: Locale(identifier: "en_US")), "1.5 KB")
    }

    func testByteSizeFormatting_mb() {
        let bs = ByteSize(1_572_864)  // 1.5 MB
        XCTAssertEqual(bs.formatted(style: .mb, locale: Locale(identifier: "en_US")), "1.5 MB")
    }

    func testWildcardMask_basic() {
        let mask = WildcardMask("*.txt")
        XCTAssertTrue(mask.matches("readme.txt"))
        XCTAssertFalse(mask.matches("readme.md"))
    }

    func testWildcardMask_multiplePatterns() {
        let mask = WildcardMask("*.c;*.h")
        XCTAssertTrue(mask.matches("main.c"))
        XCTAssertTrue(mask.matches("header.h"))
        XCTAssertFalse(mask.matches("readme.txt"))
    }

    func testWildcardMask_exclude() {
        let mask = WildcardMask("*.txt|*.bak")
        XCTAssertTrue(mask.matches("readme.txt"))
        XCTAssertFalse(mask.matches("readme.bak"))
    }

    func testPathUtils_parent() {
        XCTAssertEqual(PathUtils.parent("/Users/me/Documents"), "/Users/me")
    }

    func testPathUtils_filename() {
        XCTAssertEqual(PathUtils.filename("/Users/me/Documents/file.txt"), "file.txt")
    }

    func testPathUtils_extension() {
        XCTAssertEqual(PathUtils.fileExtension(from: "file.txt"), "txt")
        XCTAssertEqual(PathUtils.fileExtension(from: "file"), "")
    }

    func testPathUtils_normalizedIsNFCNotDiacriticFolding() {
        // "cafe" + combining acute (NFD) must normalize to precomposed "café" (NFC),
        // and must NOT strip the accent (the old bug turned it into "cafe").
        let nfd = "cafe\u{0301}"
        let nfc = "caf\u{00E9}"
        XCTAssertEqual(PathUtils.normalized(nfd), nfc)
        XCTAssertEqual(PathUtils.normalized(nfc), nfc)
        XCTAssertTrue(PathUtils.normalized(nfd).contains("é"))
        XCTAssertTrue(PathUtils.nameEquivalent(nfd, nfc))
        XCTAssertEqual(PathUtils.decomposed(nfc), nfd)
    }

    func testPathUtils_isHidden() {
        XCTAssertTrue(PathUtils.isHidden(".hidden"))
        XCTAssertFalse(PathUtils.isHidden("visible"))
    }

    func testNaturalCompare() {
        let result = naturalCompare("file2.txt", "file10.txt")
        XCTAssertEqual(result, .orderedAscending)
    }
}
