// SPDX-License-Identifier: Apache-2.0
// MnuMenuTests.swift - What a user .mnu turns into, and which of it can be clicked (F-257).
//
// Two defects these are about, both of which made a menu entry that looks live do
// nothing at all:
//
//   * a command token this app has no command for (a numeric Total Commander id out of
//     the several hundred TC has and this registry does not) was passed through as the
//     item's represented command, where the enable pass ignored it for not starting with
//     `cm_` — an enabled entry that swallowed the click;
//   * an `em_` item naming a user command that `usercmd.ini` does not define stayed
//     enabled for the same reason.
//
// The dispatch half (em_ names must go to the user-command runner, not the cm_ registry)
// lives in MainWindowController and is verified in the running app — a unit test here
// would test a mock of the thing that was broken.

import XCTest
import AppKit
import PCFoundation

@MainActor
final class MnuMenuTests: XCTestCase {

    /// Everything the builder needs from a controller.
    private final class Target: NSObject {
        @objc func run(_ sender: NSMenuItem) {}
    }

    private let target = Target()
    private var action: Selector { #selector(Target.run(_:)) }

    private func build(_ text: String,
                       resolve: @escaping (String) -> String? = { $0 }) -> MnuMenuBuilder.Result {
        MnuMenuBuilder.build(roots: MenuFile(parsing: text).roots, target: target,
                            action: action, resolve: resolve)
    }

    func testCaptionsAreStrippedAndStructurePreserved() {
        let result = build("""
        POPUP "&Files"
          MENUITEM "&View\\tF3", cm_List
          MENUITEM SEPARATOR
          POPUP "&More"
            MENUITEM "&Pack…", cm_PackFiles
          END_POPUP
        END_POPUP
        """)
        XCTAssertEqual(result.menus.count, 1)
        let files = result.menus[0]
        XCTAssertEqual(files.title, "Files")                  // & and \t gone
        XCTAssertEqual(files.items.count, 3)
        XCTAssertEqual(files.items[0].title, "View")
        XCTAssertEqual(files.items[0].representedObject as? String, "cm_List")
        XCTAssertTrue(files.items[1].isSeparatorItem)
        XCTAssertEqual(files.items[2].submenu?.items.first?.representedObject as? String, "cm_PackFiles")
        XCTAssertEqual(result.unresolved, [])
    }

    func testResolvedNumericIdBecomesItsCommandName() {
        let result = build("""
        POPUP "&P"
          MENUITEM "Reread", 540
        END_POPUP
        """, resolve: { $0 == "540" ? "cm_RereadSource" : nil })
        XCTAssertEqual(result.menus[0].items[0].representedObject as? String, "cm_RereadSource")
        XCTAssertTrue(result.menus[0].items[0].isEnabled)
    }

    func testUnknownCommandIsDisabledInertAndReported() {
        let result = build("""
        POPUP "&P"
          MENUITEM "Some TC command", 2400
          MENUITEM "Typo", cm_Nonexistent
          MENUITEM "Works", cm_List
        END_POPUP
        """, resolve: { $0 == "cm_List" ? $0 : nil })
        let items = result.menus[0].items
        XCTAssertEqual(items[0].title, "Some TC command")     // the user's own caption is kept
        XCTAssertFalse(items[0].isEnabled)
        XCTAssertNil(items[0].action)                         // nothing to invoke
        XCTAssertNil(items[0].representedObject)
        XCTAssertFalse(items[1].isEnabled)
        XCTAssertTrue(items[2].isEnabled)
        XCTAssertEqual(result.unresolved, ["2400", "cm_Nonexistent"])
    }

    func testTopLevelItemsWithoutAPopupAreDropped() {
        // The menu bar has no place for them; the parser reports them (itemOutsideMenu).
        let result = build("""
        MENUITEM "Homeless", cm_List
        POPUP "&P"
          MENUITEM "Home", cm_List
        END_POPUP
        """)
        XCTAssertEqual(result.menus.count, 1)
        XCTAssertEqual(result.menus[0].title, "P")
    }

    // MARK: - The enable pass

    private func applyKeymap(to menu: NSMenu, registered: Set<String>, userCommands: Set<String>) {
        KeymapMenu.apply(Keymap(builtin: KeymapScheme()), to: menu,
                         registered: registered, userCommands: userCommands)
    }

    func testEmItemIsEnabledOnlyWhenTheUserCommandExists() {
        let result = build("""
        POPUP "&Start"
          MENUITEM "Open terminal here", em_OpenTerminalHere
          MENUITEM "Gone", em_Vanished
        END_POPUP
        """)
        applyKeymap(to: result.menus[0], registered: ["cm_List"], userCommands: ["em_OpenTerminalHere"])
        XCTAssertTrue(result.menus[0].items[0].isEnabled)
        XCTAssertFalse(result.menus[0].items[1].isEnabled)
    }

    func testUnimplementedCmCommandStaysDisabled() {
        let result = build("""
        POPUP "&P"
          MENUITEM "Pending", cm_ActivateMenu
          MENUITEM "Ready", cm_List
        END_POPUP
        """)
        applyKeymap(to: result.menus[0], registered: ["cm_List"], userCommands: [])
        XCTAssertFalse(result.menus[0].items[0].isEnabled)
        XCTAssertTrue(result.menus[0].items[1].isEnabled)
    }

    /// A plugin-contributed item carries its own command id, in neither namespace: the
    /// enable pass must leave it alone rather than grey out every plugin menu entry.
    func testPluginContributionItemIsLeftAlone() {
        let menu = NSMenu(title: "Plugins")
        let item = NSMenuItem(title: "Notes", action: action, keyEquivalent: "")
        item.representedObject = "notes.open"
        menu.addItem(item)
        applyKeymap(to: menu, registered: [], userCommands: [])
        XCTAssertTrue(item.isEnabled)
    }

    /// The unresolved item has no represented command at all, so the enable pass skips it
    /// — it must not be re-enabled on the way past.
    func testEnablePassDoesNotReviveAnUnresolvedItem() {
        let result = build("""
        POPUP "&P"
          MENUITEM "Some TC command", 2400
        END_POPUP
        """, resolve: { _ in nil })
        applyKeymap(to: result.menus[0], registered: [], userCommands: [])
        XCTAssertFalse(result.menus[0].items[0].isEnabled)
    }
}
