// SPDX-License-Identifier: Apache-2.0
// WindowsTextFileTests.swift - Config files written on Windows must still read (F-257).
//
// The defect: a `.mnu`/`.bar`/`usercmd.ini`/`wincmd.ini` carried over from Total
// Commander is ANSI or UTF-16, `try? String(contentsOf:encoding:.utf8)` returns nil
// for it, and every caller reads that nil as "the user has no such file". A German
// menu file therefore loaded as no menu at all — silently.

import XCTest
@testable import PCFoundation

final class WindowsTextFileTests: XCTestCase {

    func testPlainUTF8IsUnchanged() {
        XCTAssertEqual(WindowsTextFile.decode(Data("POPUP \"&Dateien\"\n".utf8)), "POPUP \"&Dateien\"\n")
    }

    func testUTF8BOMIsStripped() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("MENUITEM \"Größe\", cm_Size".utf8))
        XCTAssertEqual(WindowsTextFile.decode(data), "MENUITEM \"Größe\", cm_Size")
    }

    func testUTF16LittleEndianWithBOM() {
        var data = Data([0xFF, 0xFE])
        data.append("POPUP \"&Änsicht\"".data(using: .utf16LittleEndian)!)
        XCTAssertEqual(WindowsTextFile.decode(data), "POPUP \"&Änsicht\"")
    }

    func testUTF16BigEndianWithBOM() {
        var data = Data([0xFE, 0xFF])
        data.append("POPUP \"&Änsicht\"".data(using: .utf16BigEndian)!)
        XCTAssertEqual(WindowsTextFile.decode(data), "POPUP \"&Änsicht\"")
    }

    /// The case that actually happens: TC's German menu file, in the Windows code page.
    func testANSICodePageFallback() {
        let text = "POPUP \"&Änsicht mit Größe – ü\""
        let data = text.data(using: .windowsCP1252)!
        XCTAssertNil(String(data: data, encoding: .utf8), "precondition: these bytes are not valid UTF-8")
        XCTAssertEqual(WindowsTextFile.decode(data), text)
    }

    /// 0x81 has no Windows-1252 mapping; Latin-1 is the last resort so decoding a file
    /// that exists never fails (callers branch on nil meaning "no file").
    func testUndefinedCP1252ByteStillDecodes() {
        let data = Data([0x41, 0x81, 0x42])
        let decoded = WindowsTextFile.decode(data)
        XCTAssertTrue(decoded.hasPrefix("A"))
        XCTAssertTrue(decoded.hasSuffix("B"))
    }

    func testEmptyDataDecodesToEmptyString() {
        XCTAssertEqual(WindowsTextFile.decode(Data()), "")
    }

    func testReadReturnsNilOnlyWhenThereIsNoFile() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-wtf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertNil(WindowsTextFile.read(dir.appendingPathComponent("absent.mnu")))

        let url = dir.appendingPathComponent("present.mnu")
        try "MENUITEM \"Ä\", cm_X".data(using: .windowsCP1252)!.write(to: url)
        XCTAssertEqual(WindowsTextFile.read(url), "MENUITEM \"Ä\", cm_X")
    }
}
