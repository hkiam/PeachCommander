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
}
