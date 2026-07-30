// WincmdImporterTests.swift - wincmd.ini hotlist + button bar import (F-276).

import XCTest
@testable import PCFoundation

final class WincmdImporterTests: XCTestCase {

    // MARK: - Hotlist ([DirMenu])

    func testHotlistFlattensCdEntriesAndSkipsSeparatorsAndSubmenus() {
        let ini = INIDocument(parsing: """
        [DirMenu]
        menu1=&Root
        cmd1=cd /
        menu2=Projects
        cmd2=
        menu3=&Web
        cmd3=cd /Users/me/web
        menu4=-
        cmd4=
        menu5=--
        cmd5=
        menu6=Run tool
        cmd6=cm_Something
        """)
        let entries = WincmdImporter.parseHotlist(ini)
        // Only the two `cd` entries survive; submenu header (empty cmd), separator,
        // submenu-close and the non-cd command are dropped.
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].title, "Root")          // mnemonic '&' stripped
        XCTAssertEqual(entries[0].path, "/")
        XCTAssertEqual(entries[1].title, "Web")
        XCTAssertEqual(entries[1].path, "/Users/me/web")
    }

    func testHotlistTitleFallsBackToLastPathComponent() {
        let ini = INIDocument(parsing: """
        [DirMenu]
        menu1=
        cmd1=cd /var/tmp/work
        """)
        let entries = WincmdImporter.parseHotlist(ini)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "work")
        XCTAssertEqual(entries[0].path, "/var/tmp/work")
    }

    func testDoubleAmpersandBecomesLiteral() {
        XCTAssertEqual(WincmdImporter.cleanCaption("Tools && Toys"), "Tools & Toys")
        XCTAssertEqual(WincmdImporter.cleanCaption("&File"), "File")
    }

    func testEmptyDirMenuYieldsNothing() {
        XCTAssertTrue(WincmdImporter.parseHotlist(INIDocument(parsing: "[Other]\nx=1")).isEmpty)
    }

    // MARK: - Button bar (inline + referenced)

    func testInlineButtonBarIsParsed() {
        let text = """
        [Buttonbar]
        Buttoncount=2
        button1=wcmicons.dll,5
        cmd1=cm_Copy
        menu1=Copy
        iconic1=1
        button2=wcmicons.dll,6
        cmd2=cm_RenMov
        menu2=Move
        iconic2=1
        """
        let (bar, ref) = WincmdImporter.resolveButtonBar(iniText: text, sourceDirectory: URL(fileURLWithPath: "/nonexistent"))
        XCTAssertNil(ref)
        XCTAssertEqual(bar?.buttons.count, 2)
        XCTAssertEqual(bar?.buttons.first?.cmd, "cm_Copy")
    }

    func testReferencedButtonBarIsLoadedFromAdjacentFile() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wincmd-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // TC references the .bar by a Windows path; we match on the filename only.
        try """
        [Buttonbar]
        Buttoncount=1
        button1=x.ico
        cmd1=cm_List
        menu1=View
        iconic1=1
        """.write(to: dir.appendingPathComponent("DEFAULT.BAR"), atomically: true, encoding: .utf8)

        let wincmd = """
        [Buttonbar]
        Buttonbar=%COMMANDER_PATH%\\DEFAULT.BAR
        """
        let (bar, ref) = WincmdImporter.resolveButtonBar(iniText: wincmd, sourceDirectory: dir)
        XCTAssertEqual(ref, "%COMMANDER_PATH%\\DEFAULT.BAR")
        XCTAssertEqual(bar?.buttons.count, 1)
        XCTAssertEqual(bar?.buttons.first?.cmd, "cm_List")
    }

    func testUnresolvedReferenceReturnsNilBarButKeepsReference() {
        let wincmd = """
        [Buttonbar]
        Buttonbar=C:\\TC\\missing.bar
        """
        let (bar, ref) = WincmdImporter.resolveButtonBar(iniText: wincmd, sourceDirectory: URL(fileURLWithPath: "/nonexistent"))
        XCTAssertNil(bar)
        XCTAssertEqual(ref, "C:\\TC\\missing.bar")
    }

    // MARK: - importAll

    func testImportAllDetectsColorsAndCombines() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wincmd-all-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let iniURL = dir.appendingPathComponent("wincmd.ini")
        let text = """
        [Colors]
        BackColor=-1
        [DirMenu]
        menu1=Home
        cmd1=cd /Users/me
        [Buttonbar]
        Buttoncount=1
        cmd1=cm_Copy
        menu1=Copy
        iconic1=1
        """
        try text.write(to: iniURL, atomically: true, encoding: .utf8)
        let result = WincmdImporter.importAll(iniText: text, sourceURL: iniURL)
        XCTAssertEqual(result.hotlistEntries.count, 1)
        XCTAssertEqual(result.buttonBar?.buttons.count, 1)
        XCTAssertTrue(result.colorsPresent)
    }
}
