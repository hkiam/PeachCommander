// SPDX-License-Identifier: Apache-2.0
// MenuFileTests.swift - Total Commander .mnu menu parsing/serialize (F-257).

import XCTest
@testable import PCFoundation

final class MenuFileTests: XCTestCase {

    private let sample = """
    ; a comment
    POPUP "&Files"
      MENUITEM "&View\\tF3", cm_List
      MENUITEM "&Copy\\tF5", 40000
      MENUITEM SEPARATOR
      POPUP "&More"
        MENUITEM "&Pack…", cm_PackFiles
      END_POPUP
    END_POPUP
    POPUP "&Mark"
      MENUITEM "Select &All", cm_SelectAll
    END_POPUP
    """

    func testParsesNestedPopupsAndItems() {
        let menu = MenuFile(parsing: sample)
        XCTAssertEqual(menu.roots.count, 2)

        guard case .popup(let cap0, let files) = menu.roots[0] else { return XCTFail("root0 not popup") }
        XCTAssertEqual(cap0, "&Files")
        XCTAssertEqual(files.count, 4)   // View, Copy, separator, More

        guard case .command(let c0, let cmd0) = files[0] else { return XCTFail("not command") }
        XCTAssertEqual(c0, "&View\\tF3")   // raw caption preserved (literal \t from source)
        XCTAssertEqual(cmd0, "cm_List")

        guard case .command(_, let cmd1) = files[1] else { return XCTFail("not command") }
        XCTAssertEqual(cmd1, "40000")     // numeric TC id preserved

        guard case .separator = files[2] else { return XCTFail("not separator") }

        guard case .popup(let capMore, let more) = files[3] else { return XCTFail("not popup") }
        XCTAssertEqual(capMore, "&More")
        XCTAssertEqual(more.count, 1)
    }

    func testDisplayCaptionStripsMnemonicAndAccelerator() {
        XCTAssertEqual(MenuFile.displayCaption("&View\tF3"), "View")    // real tab
        XCTAssertEqual(MenuFile.displayCaption("&View\\tF3"), "View")   // literal \t
        XCTAssertEqual(MenuFile.displayCaption("Select &All"), "Select All")
        XCTAssertEqual(MenuFile.displayCaption("Files && Folders"), "Files & Folders")
    }

    func testUnbalancedPopupIsClosedGracefully() {
        let menu = MenuFile(parsing: """
        POPUP "&Open"
          MENUITEM "One", cm_One
        """)
        XCTAssertEqual(menu.roots.count, 1)
        guard case .popup(_, let kids) = menu.roots[0] else { return XCTFail() }
        XCTAssertEqual(kids.count, 1)
    }

    func testRoundTripThroughSerialize() {
        let menu = MenuFile(parsing: sample)
        let reparsed = MenuFile(parsing: menu.serialize())
        XCTAssertEqual(menu, reparsed)
    }

    func testUnknownLinesAndBlankLinesIgnored() {
        let menu = MenuFile(parsing: """

        GARBAGE here
        POPUP "&X"
          MENUITEM "Y", cm_Y
        END_POPUP
        """)
        XCTAssertEqual(menu.roots.count, 1)
    }

    func testMenuItemWithoutCommandIsSkipped() {
        // A caption with an empty command token should not create an item.
        let menu = MenuFile(parsing: """
        POPUP "&P"
          MENUITEM "Empty",
          MENUITEM "Good", cm_Good
        END_POPUP
        """)
        guard case .popup(_, let kids) = menu.roots[0] else { return XCTFail() }
        XCTAssertEqual(kids.count, 1)
        guard case .command(_, let c) = kids[0] else { return XCTFail() }
        XCTAssertEqual(c, "cm_Good")
    }

    // MARK: - Diagnostics

    /// Lenient is not the same as silent: whatever the parser skips has to be reportable,
    /// or the user is left with a menu entry that is simply not there.
    func testEverySkippedLineIsReported() {
        let (menu, diagnostics) = MenuFile.parse("""
        POPUP "&Good"
          MENUITEM "Fine", cm_Fine
        END_POPUP
        GARBAGE here
        MENUITEM "Homeless", cm_Nowhere
        END_POPUP
        POPUP "&Never closed"
          MENUITEM "Nameless",
        """)
        XCTAssertEqual(diagnostics.map(\.kind),
                       [.unknownLine, .itemOutsideMenu, .strayEndPopup, .unclosedPopup, .itemWithoutCommand])
        XCTAssertEqual(diagnostics.map(\.line), [4, 5, 6, 7, 8])
        XCTAssertEqual(diagnostics[0].text, "GARBAGE here")
        XCTAssertEqual(diagnostics[3].text, "&Never closed")   // the popup's caption, not the line
        // The tree is still what the lenient parser always produced.
        XCTAssertEqual(menu.roots.count, 3)   // &Good, the homeless item, &Never closed
    }

    func testCleanFileHasNoDiagnostics() {
        XCTAssertEqual(MenuFile.parse(sample).diagnostics, [])
    }

    func testCommentsAndBlankLinesAreNotDiagnostics() {
        let (_, diagnostics) = MenuFile.parse("""

        ; comment
        # comment
        // comment
        POPUP "&X"
          MENUITEM SEPARATOR
        END_POPUP
        """)
        XCTAssertEqual(diagnostics, [])
    }

    // MARK: - Captions containing a quote

    /// A caption with a `"` in it used to be cut at that quote and its command lost with
    /// it — reachable from the generated starter file, whose captions come from the live
    /// menu (a plugin may contribute any title).
    func testDoubledQuoteInCaptionIsOneLiteralQuote() {
        let menu = MenuFile(parsing: """
        POPUP "&P"
          MENUITEM "Say ""hello"" now", cm_Say
        END_POPUP
        """)
        guard case .popup(_, let kids) = menu.roots[0], case .command(let caption, let cmd) = kids[0]
        else { return XCTFail("expected one command item") }
        XCTAssertEqual(caption, "Say \"hello\" now")
        XCTAssertEqual(cmd, "cm_Say")
    }

    func testQuoteInCaptionRoundTrips() {
        let original = MenuFile(roots: [.popup(caption: "&\"P\"", children: [
            .command(caption: "A \"B\" C", command: "cm_X")
        ])])
        XCTAssertEqual(MenuFile(parsing: original.serialize()), original)
    }

    func testUnterminatedQuoteIsSkippedNotCrashed() {
        let (menu, diagnostics) = MenuFile.parse("""
        POPUP "&P"
          MENUITEM "no closing quote, cm_X
          MENUITEM "Good", cm_Good
        END_POPUP
        """)
        guard case .popup(_, let kids) = menu.roots[0] else { return XCTFail() }
        XCTAssertEqual(kids.count, 1)
        XCTAssertEqual(diagnostics.map(\.kind), [.itemWithoutCommand])
    }

    // MARK: - Files as Total Commander writes them

    /// CRLF line endings and a numeric command id, i.e. the shape of a real TC menu file
    /// (its encoding is WindowsTextFile's job).
    func testCRLFFileWithNumericIdsParses() {
        let menu = MenuFile(parsing: "POPUP \"&Dateien\"\r\n  MENUITEM \"&Kopieren\", 540\r\nEND_POPUP\r\n")
        guard case .popup(let caption, let kids) = menu.roots[0],
              case .command(_, let cmd) = kids[0] else { return XCTFail() }
        XCTAssertEqual(caption, "&Dateien")
        XCTAssertEqual(cmd, "540")
    }
}
