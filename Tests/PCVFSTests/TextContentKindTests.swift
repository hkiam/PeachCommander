// SPDX-License-Identifier: Apache-2.0
// TextContentKindTests.swift - Binary content must not reach an NSTextView (Viewer).
//
// Reported: open a ~1 MB PNG, switch to hex (instant), switch to text — and the app stops responding.
// Sampled in the act, the whole time was inside CoreText's glyph lookup and cmap-table parsing,
// reached from a full-document layout: decoded, that file is 931,257 characters drawn from over 3,000
// different Unicode scalars, and CoreText hunts the font cascade for every one the monospaced font
// lacks. 2.0 s in a bare text view; not finished after twenty-six minutes in the running app.
//
// The fix routes such content to the virtual view instead, so both halves of the decision are pinned
// here — including the case each half alone would miss.

import XCTest
@testable import PCVFS

final class TextContentKindTests: XCTestCase {

    private func bytes(_ s: String, _ encoding: String.Encoding = .utf8) -> [UInt8] {
        [UInt8](s.data(using: encoding)!)
    }

    // MARK: - Ordinary text keeps the rich text view

    func testPlainTextIsFineInATextView() {
        let result = TextContentKind.decode(bytes("hello\nworld\n"), encoding: .utf8)
        XCTAssertFalse(result.needsVirtualView)
        XCTAssertEqual(result.text, "hello\nworld\n")
    }

    func testGermanTextInCP1252StaysInATextView() {
        // Not valid UTF-8, and that is fine: it is valid in the encoding it was detected as. This is
        // the case the decode check must *not* catch — measured on a 444 KB file, which stayed in the
        // NSTextView and switched in 153 ms.
        let raw = [UInt8]("Grüße aus München — Straße".data(using: .windowsCP1252)!)
        let result = TextContentKind.decode(raw, encoding: .windowsCP1252)
        XCTAssertFalse(result.needsVirtualView)
        XCTAssertTrue(result.text.contains("Grüße"))
    }

    func testAnEmptyFileIsText() {
        XCTAssertFalse(TextContentKind.decode([], encoding: .utf8).needsVirtualView)
    }

    // MARK: - …and binary content does not

    func testControlBytesAreCaughtByTheSample() {
        // What the byte heuristic is for: plenty of NULs in the first 4 KB.
        var raw = [UInt8](repeating: 0, count: 500)
        raw += bytes(String(repeating: "text ", count: 100))
        XCTAssertTrue(TextContentKind.decode(raw, encoding: .utf8).needsVirtualView)
    }

    func testUniformlyDistributedBinaryIsCaughtByTheDecoding() {
        // The case the byte heuristic misses: every byte value equally often is only 3.5 % control
        // bytes, under the 5 % threshold — so it passes for text on that question alone. It is not
        // valid UTF-8, and that is what catches it. Measured: a 900 KB file of exactly this shape.
        let raw = (0..<20_000).map { UInt8(($0 &* 7919 &+ 13) % 256) }
        let controlFraction = Double(raw.prefix(4096).filter { $0 == 0 || $0 < 9 }.count) / 4096
        XCTAssertLessThan(controlFraction, BinaryHeuristic.threshold,
                          "this sample is supposed to slip past the byte heuristic")
        XCTAssertFalse(BinaryHeuristic.isProbablyBinary(Array(raw.prefix(4096))))
        XCTAssertTrue(TextContentKind.decode(raw, encoding: .utf8).needsVirtualView,
                      "binary content would have been handed to an NSTextView")
    }

    func testInvalidUTF8IsNotTreatedAsText() {
        // A lone continuation byte: no valid UTF-8 contains one.
        let raw: [UInt8] = Array("ok ".utf8) + [0x80, 0x81] + Array(" more".utf8)
        XCTAssertTrue(TextContentKind.decode(raw, encoding: .utf8).needsVirtualView)
    }

    func testTheTextIsStillUsableWhenTheDecodeWasLossy() {
        // Routing it elsewhere must not mean losing it: what can be read is still read, because
        // looking at the strings inside a binary is the reason to open one as text at all.
        let raw: [UInt8] = [0xFF, 0xFE] + Array("PNG readable part".utf8) + [0x00, 0x01]
        let result = TextContentKind.decode(raw, encoding: .utf8)
        XCTAssertTrue(result.needsVirtualView)
        XCTAssertTrue(result.text.contains("readable part"))
    }
}
