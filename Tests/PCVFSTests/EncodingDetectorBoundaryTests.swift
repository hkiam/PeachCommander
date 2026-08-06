// SPDX-License-Identifier: Apache-2.0
// EncodingDetectorBoundaryTests.swift - The 64 KB sample and the byte-order mark (F-376).
//
// Two defects found by sweeping 300 real text files over 64 KB from this machine against what the *whole*
// file decodes as:
//
//   1. The sample is a fixed 64 KB cut, so its last bytes are often half of a multi-byte character.
//      Validating those as well made the check fail and declared a perfectly good UTF-8 file to be
//      CP1252 — the editor showed mojibake and saved it back that way. 4 of the 300 files, all German
//      transcripts: the more non-ASCII a text is, the likelier the cut lands mid-character.
//   2. A UTF-16 byte-order mark was detected and then left in the data, so the decoded text began with an
//      invisible U+FEFF.
//
// The negative cases matter as much as the positive ones here: trading a false CP1252 for a false UTF-8
// would be the worse bug, because a Latin-1 file would then decode to replacement characters instead of
// to something the user can at least recognise and correct with the encoding menu.

import XCTest
@testable import PCVFS

final class EncodingDetectorBoundaryTests: XCTestCase {

    /// A UTF-8 sample whose 64 KB boundary falls inside a multi-byte character.
    private func sampleCutMidCharacter(pad: Int) -> [UInt8] {
        Array((String(repeating: "a", count: pad) + "äöü Grüße").utf8)
    }

    // MARK: - The cut

    func testAUTF8FileCutMidCharacterIsStillUTF8() {
        for pad in [65_535, 65_534, 65_533, 65_532] {
            let bytes = sampleCutMidCharacter(pad: pad)
            XCTAssertEqual(EncodingDetector.detect(bytes), .utf8,
                           "pad \(pad): a UTF-8 file must not be reported as CP1252 because of where the "
                           + "64 KB sample happens to end")
        }
    }

    func testAThreeByteCharacterAtTheBoundaryIsHandled() {
        // CJK is three bytes per character, so the cut lands mid-character far more often than for Latin
        // text — this is the case that made the defect noticeable at all.
        for pad in [65_534, 65_535, 65_536] {
            let bytes = Array((String(repeating: "a", count: pad) + "日本語のテキスト").utf8)
            XCTAssertEqual(EncodingDetector.detect(bytes), .utf8, "pad \(pad)")
        }
    }

    func testTheTrimmerDropsOnlyAnIncompleteTail() {
        // "ä" is C3 A4. Cut after C3 → drop it; keep the whole thing when both bytes are there.
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0xC3]), [0x61])
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0xC3, 0xA4]), [0x61, 0xC3, 0xA4])
        // Three-byte character, cut after one and after two bytes.
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0xE6]), [0x61])
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0xE6, 0x97]), [0x61])
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0xE6, 0x97, 0xA5]),
                       [0x61, 0xE6, 0x97, 0xA5])
    }

    func testTheTrimmerLeavesGenuinelyInvalidBytesAlone() {
        // Continuation bytes with no lead are not a cut character; removing them would call an invalid
        // file valid, which is how a heuristic starts lying.
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0x61, 0x80, 0x80]), [0x61, 0x80, 0x80])
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([0xFF, 0xFF]), [0xFF, 0xFF])
        XCTAssertEqual(EncodingDetector.trimmedToCharacterBoundary([]), [])
    }

    // MARK: - Still CP1252 when it should be

    func testLatin1IsStillDetected() {
        // "Grüße" in CP1252: ü = FC, ß = DF, neither valid as UTF-8.
        XCTAssertEqual(EncodingDetector.detect([0x47, 0x72, 0xFC, 0xDF, 0x65]), .windowsCP1252)
    }

    func testALoneHighByteAtTheSampleEndIsNotTreatedAsACutCharacter() {
        // FC is a lead byte for a five-byte sequence, which UTF-8 does not have — so it is simply invalid,
        // not a character cut short, and the file is CP1252.
        let bytes = [UInt8](repeating: 0x61, count: 65_535) + [0xFC]
        XCTAssertEqual(EncodingDetector.detect(bytes), .windowsCP1252)
    }

    func testBrokenUTF8IsNotCalledUTF8() {
        XCTAssertEqual(EncodingDetector.detect([0x61, 0x80, 0x80, 0x62]), .windowsCP1252)
    }

    // MARK: - The byte-order mark

    func testDecodingDropsAUTF16BOM() {
        var data = Data([0xFF, 0xFE])
        data.append("Hallo".data(using: .utf16LittleEndian)!)
        let decoded = EncodingDetector.decode(data)
        XCTAssertEqual(decoded.encoding, .utf16LittleEndian)
        XCTAssertEqual(decoded.text, "Hallo")
        XCTAssertNotEqual(decoded.text.unicodeScalars.first?.value, 0xFEFF)
    }

    func testDecodingDropsABigEndianBOM() {
        var data = Data([0xFE, 0xFF])
        data.append("Hallo".data(using: .utf16BigEndian)!)
        XCTAssertEqual(EncodingDetector.decode(data).text, "Hallo")
    }

    func testDecodingDropsAUTF8BOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("Hallo".utf8))
        XCTAssertEqual(EncodingDetector.decode(data).text, "Hallo")
    }

    func testDecodingLeavesTextWithoutABOMAlone() {
        XCTAssertEqual(EncodingDetector.decode(Data("Hallo".utf8)).text, "Hallo")
    }

    func testWithoutBOMForCallersThatDecodeThemselves() {
        XCTAssertEqual(EncodingDetector.withoutBOM([0xEF, 0xBB, 0xBF, 0x61]), [0x61])
        XCTAssertEqual(EncodingDetector.withoutBOM([0xFF, 0xFE, 0x61, 0x00]), [0x61, 0x00])
        XCTAssertEqual(EncodingDetector.withoutBOM([0x61, 0x62]), [0x61, 0x62])
    }

    func testATruncatedUTF16FileStillShowsTheTextThatIsThere() {
        // A garbled or partial view beats an empty window: the user can still read what survived and
        // switch the encoding by hand. Measured rather than assumed — Foundation drops the odd trailing
        // byte and decodes the rest.
        var data = Data([0xFF, 0xFE])
        data.append("Hallo".data(using: .utf16LittleEndian)!)
        data.append(0x41)                            // one stray byte: an odd body length
        XCTAssertEqual(EncodingDetector.decode(data).text, "Hallo")
    }
}
