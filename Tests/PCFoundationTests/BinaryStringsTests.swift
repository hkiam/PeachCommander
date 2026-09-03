// SPDX-License-Identifier: Apache-2.0
// BinaryStringsTests.swift - The strings scanner behind the hex viewer's/editor's
// strings panel (F-489).
//
// The interesting cases are not "does it find Hello" but the ones the reconciliation
// exists for: the same bytes readable in three encodings, a UTF-16 string at an odd
// offset, and an encoding that was switched off actually staying off.

import XCTest
@testable import PCFoundation

final class BinaryStringsTests: XCTestCase {

    private func utf16(_ s: String, littleEndian: Bool) -> [UInt8] {
        var out: [UInt8] = []
        for unit in Array(s.utf16) {
            out.append(contentsOf: littleEndian ? [UInt8(unit & 0xFF), UInt8(unit >> 8)]
                                                : [UInt8(unit >> 8), UInt8(unit & 0xFF)])
        }
        return out
    }

    // MARK: - ASCII

    func testFindsAsciiRunBetweenBinaryNoise() {
        let bytes: [UInt8] = [0x00, 0x01, 0x8F] + Array("Hello".utf8) + [0x00, 0x02]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.text, "Hello")
        XCTAssertEqual(hits.first?.offset, 3)
        XCTAssertEqual(hits.first?.byteLength, 5)
        XCTAssertEqual(hits.first?.encoding, .ascii)
    }

    func testRunsShorterThanTheMinimumAreNotReported() {
        let bytes: [UInt8] = [0x00] + Array("abc".utf8) + [0x00]
        XCTAssertTrue(BinaryStrings.scan(bytes).isEmpty)
        let shorter = BinaryStrings.scan(bytes, options: StringScanOptions(minimumLength: 3))
        XCTAssertEqual(shorter.map(\.text), ["abc"])
    }

    func testControlCharactersEndARunButTabDoesNot() {
        let bytes: [UInt8] = Array("key\tvalue".utf8) + [0x0A] + Array("next".utf8)
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.map(\.text), ["key\tvalue", "next"])
    }

    func testBaseOffsetIsAddedToEveryHit() {
        let bytes: [UInt8] = [0x00] + Array("Hello".utf8)
        let hits = BinaryStrings.scan(bytes, baseOffset: 0x1000)
        XCTAssertEqual(hits.first?.offset, 0x1001)
    }

    // MARK: - UTF-8 and Latin-1

    func testMultiByteUtf8RunIsReportedAsUtf8WithItsByteLength() {
        let text = "Grüße"                       // 5 characters, 7 bytes
        let bytes: [UInt8] = [0x00] + Array(text.utf8) + [0x00]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.text, text)
        XCTAssertEqual(hits.first?.encoding, .utf8)
        XCTAssertEqual(hits.first?.byteLength, 7)
    }

    func testHighBytesThatAreNotValidUtf8AreReadAsLatin1() {
        // "Grüße" in ISO-8859-1: ü = 0xFC, ß = 0xDF. No valid UTF-8 sequence anywhere.
        let bytes: [UInt8] = [0x00, 0x47, 0x72, 0xFC, 0xDF, 0x65, 0x00]
        let hits = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.ascii, .latin1]))
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.encoding, .latin1)
        XCTAssertEqual(hits.first?.text, "Grüße")
        XCTAssertEqual(hits.first?.byteLength, 5)
    }

    func testC1ControlBytesEndARunRatherThanBecomingLatin1Text() {
        let bytes: [UInt8] = Array("abcd".utf8) + [0x85] + Array("efgh".utf8)
        XCTAssertEqual(BinaryStrings.scan(bytes).map(\.text), ["abcd", "efgh"])
    }

    func testOverlongUtf8IsNotAcceptedAsText() {
        // C0 AF is an overlong encoding of '/'. A decoder that accepts it turns byte
        // patterns that are not text into text.
        let bytes: [UInt8] = Array("abcd".utf8) + [0xC0, 0xAF] + Array("efgh".utf8)
        let hits = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.ascii, .utf8]))
        XCTAssertEqual(hits.map(\.text), ["abcd", "efgh"])
    }

    // MARK: - UTF-16, both endiannesses and both alignments

    func testUtf16LittleEndianRunIsFound() {
        let bytes: [UInt8] = [0x00, 0x00] + utf16("Windows", littleEndian: true) + [0x00, 0x00]
        let hit = BinaryStrings.scan(bytes).first { $0.text == "Windows" }
        XCTAssertEqual(hit?.encoding, .utf16le)
        XCTAssertEqual(hit?.byteLength, 14)
        XCTAssertEqual(hit?.offset, 2)
    }

    func testUtf16BigEndianRunIsFound() {
        let bytes: [UInt8] = [0xFF, 0xFF] + utf16("Windows", littleEndian: false) + [0xFF, 0xFF]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.first { $0.text == "Windows" }?.encoding, .utf16be)
    }

    func testUtf16AtAnOddOffsetIsStillFound() {
        // One filler byte, so the string does not begin on an even offset.
        let bytes: [UInt8] = [0x01] + utf16("Registry", littleEndian: true) + [0x00, 0x00]
        let hits = BinaryStrings.scan(bytes)
        let hit = hits.first { $0.text == "Registry" }
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.offset, 1)
        XCTAssertEqual(hit?.encoding, .utf16le)
    }

    func testSeveralEncodingsInOneBufferAreAllReported() {
        var bytes: [UInt8] = Array("plain-ascii".utf8)
        bytes += [0x00, 0x00]
        bytes += utf16("wide-le", littleEndian: true)
        bytes += [0x00, 0x00]
        bytes += utf16("wide-be", littleEndian: false)
        bytes += [0x00, 0x00]
        bytes += Array("mit Größe".utf8)
        let hits = BinaryStrings.scan(bytes)
        let byText = Dictionary(uniqueKeysWithValues: hits.map { ($0.text, $0.encoding) })
        XCTAssertEqual(byText["plain-ascii"], .ascii)
        XCTAssertEqual(byText["wide-le"], .utf16le)
        XCTAssertEqual(byText["wide-be"], .utf16be)
        XCTAssertEqual(byText["mit Größe"], .utf8)
    }

    // MARK: - Reconciliation

    func testAsciiTextIsNotAlsoReportedAsItsUtf16Misreading() {
        // "Hello, world" read two bytes at a time is a run of perfectly printable
        // ideographs. Reporting those alongside the real string is the noise this
        // feature exists to avoid.
        let bytes: [UInt8] = [0x00, 0x00] + Array("Hello, world".utf8) + [0x00, 0x00]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.encoding, .ascii)
        XCTAssertEqual(hits.first?.text, "Hello, world")
    }

    func testTheCorrectlyAlignedUtf16ReadingWinsOverTheShiftedOne() {
        let bytes: [UInt8] = utf16("Configuration", littleEndian: true) + [0x00, 0x00]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.text, "Configuration")
        XCTAssertEqual(hits.first?.offset, 0)
    }

    func testNulPaddedWideTextIsReadAsLittleEndianWhenBothReadingsAreIdentical() {
        // A big-endian run surrounded by NUL padding is byte-for-byte the same text read
        // little-endian one byte later, and nothing distinguishes them. Pinned so the
        // resolution stays a decision: little-endian, because that is what wide strings in
        // real files are. Only the label and one byte at each end of the range differ.
        let bytes: [UInt8] = [0x00, 0x00] + utf16("Registry", littleEndian: false) + [0x00, 0x00]
        let hits = BinaryStrings.scan(bytes)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.text, "Registry")
        XCTAssertEqual(hits.first?.byteLength, 16)
    }

    func testTwoStringsFarApartAreBothKept() {
        var bytes: [UInt8] = Array("first-string".utf8)
        bytes += [UInt8](repeating: 0x00, count: 64)
        bytes += Array("second-string".utf8)
        XCTAssertEqual(BinaryStrings.scan(bytes).map(\.text), ["first-string", "second-string"])
    }

    func testPlausibilityPrefersAsciiOverIdeographs() {
        XCTAssertGreaterThan(BinaryStrings.plausibility("Hello, world"),
                             BinaryStrings.plausibility("䡥汬漬⁷潲汤"))
    }

    // MARK: - Printable is not the same as meaningful

    func testLatin1IsNotScannedUnlessAskedFor() {
        // Three quarters of all byte values are printable Latin-1, which is why the reading
        // is not in the default set: it passes compiled code in bulk.
        XCTAssertFalse(StringEncodingKind.defaults.contains(.latin1))
        let bytes: [UInt8] = [0x00, 0x47, 0x72, 0xFC, 0xDF, 0x65, 0x00]
        XCTAssertTrue(BinaryStrings.scan(bytes).isEmpty)
    }

    func testAWideRunOfIdeographsIsNotReportedAsText() {
        // A run of x86 that reads, two bytes at a time, as perfectly printable ideographs.
        // Printable, and not a string.
        let bytes: [UInt8] = [0x48, 0x89, 0xE5, 0x41, 0x57, 0x41, 0x56, 0x41, 0x55, 0x41,
                              0x54, 0x53, 0x48, 0x83, 0xEC, 0x38]
        let strict = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.utf16le, .utf16be]))
        XCTAssertTrue(strict.isEmpty)
        let everything = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.utf16le, .utf16be],
                                                                              plausibleOnly: false))
        XCTAssertFalse(everything.isEmpty, "switching the filter off must show what it hides")
    }

    func testLatin1SoupIsRejectedButAccentedTextIsKept() {
        XCTAssertTrue(BinaryStrings.qualifies(Array("Grüße".unicodeScalars), as: .latin1))
        XCTAssertTrue(BinaryStrings.qualifies(Array("Ärzte".unicodeScalars), as: .latin1))
        // Too few ASCII characters to be accented text.
        XCTAssertFalse(BinaryStrings.qualifies(Array("å]éeë".unicodeScalars), as: .latin1))
        // Latin-1 symbols rather than letters: common in random bytes, rare in prose.
        XCTAssertFalse(BinaryStrings.qualifies(Array("7}¡¸".unicodeScalars), as: .latin1))
        // No two adjacent ASCII letters — not a word.
        XCTAssertFalse(BinaryStrings.qualifies(Array("1À]é51".unicodeScalars), as: .latin1))
    }

    func testAsciiAndUtf8AreKeptWithoutFurtherJudgement() {
        XCTAssertTrue(BinaryStrings.qualifies(Array("%s: %d".unicodeScalars), as: .ascii))
        XCTAssertTrue(BinaryStrings.qualifies(Array("日本語です".unicodeScalars), as: .utf8))
    }

    func testWideAsciiIsKeptAndWideIdeographsAreNot() {
        XCTAssertTrue(BinaryStrings.qualifies(Array("SOFTWARE\\Microsoft".unicodeScalars), as: .utf16le))
        XCTAssertFalse(BinaryStrings.qualifies(Array("䡥汬漬⁷潲汤".unicodeScalars), as: .utf16le))
    }

    // MARK: - Encoding selection

    func testAnEncodingThatWasSwitchedOffIsNotReported() {
        let bytes: [UInt8] = Array("plain".utf8) + [0x00, 0x00] + utf16("wide-text", littleEndian: true)
        let asciiOnly = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.ascii]))
        XCTAssertEqual(asciiOnly.map(\.text), ["plain"])
        let wideOnly = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.utf16le]))
        XCTAssertEqual(wideOnly.map(\.text), ["wide-text"])
    }

    func testUtf8OffMeansAHighByteEndsTheRunRatherThanChangingItsKind() {
        let bytes: [UInt8] = Array("abcd".utf8) + Array("ü".utf8) + Array("efgh".utf8)
        let hits = BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.ascii]))
        XCTAssertEqual(hits.map(\.text), ["abcd", "efgh"])
    }

    // MARK: - Bounds

    func testALongRunIsCutIntoFindingsOfTheMaximumLength() {
        let bytes = [UInt8](repeating: 0x41, count: 25)      // 25 × 'A'
        let hits = BinaryStrings.scan(bytes, options: StringScanOptions(minimumLength: 4, maximumLength: 10,
                                                                        encodings: [.ascii]))
        XCTAssertEqual(hits.map(\.text.count), [10, 10, 5])
        XCTAssertEqual(hits.map(\.offset), [0, 10, 20])
    }

    func testEmptyInputYieldsNothing() {
        XCTAssertTrue(BinaryStrings.scan([]).isEmpty)
    }

    func testALoneSurrogateDoesNotProduceAHit() {
        // Read little-endian these are four D800s — high surrogates with no low surrogate
        // after them, so not text. (Read big-endian the same bytes are four U+00D8 'Ø',
        // which is why only the little-endian reading is asserted here.)
        let bytes: [UInt8] = [0x00, 0xD8, 0x00, 0xD8, 0x00, 0xD8, 0x00, 0xD8]
        XCTAssertTrue(BinaryStrings.scan(bytes, options: StringScanOptions(encodings: [.utf16le])).isEmpty)
    }

    func testFindingsComeBackInFileOrder() {
        var bytes: [UInt8] = []
        for i in 0..<20 {
            bytes += Array("string-\(i)".utf8)
            bytes += [0x00, 0x00, 0x00]
        }
        let offsets = BinaryStrings.scan(bytes).map(\.offset)
        XCTAssertEqual(offsets, offsets.sorted())
    }
}
