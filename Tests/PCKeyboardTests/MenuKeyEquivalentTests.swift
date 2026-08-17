// SPDX-License-Identifier: Apache-2.0
// MenuKeyEquivalentTests.swift - May the menu bar claim a bare keystroke? (F-404)
//
// The defect these are about: the keymap binds `DELETE=cm_Delete`, `KeymapMenu.apply` copies that onto
// File ▸ Delete, and a modifier-less accelerator is matched app-wide *before* any window sees the
// keystroke. Pressing Del while typing in the Find dialog therefore asked to move the file under the
// panel's cursor to the Trash — measured, with the confirmation reading "1 Objekt(e) in den Papierkorb
// legen?" while the key window was "Dateien suchen".
//
// Only the rule is tested here. Whether AppKit consults the menu bar at all, and whether the guard is
// wired into the bar that is installed, are facts about the running app and are checked there (the
// `keysend` automation verb and the `menu-key-guard` regression scenario) — a unit test that mocked
// either would prove the mock.

import XCTest
import AppKit

@MainActor
final class MenuKeyEquivalentTests: XCTestCase {

    /// A bare key press, given as the character AppKit puts in the event.
    private func bare(_ chars: String, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: 0, context: nil, characters: chars,
                         charactersIgnoringModifiers: chars, isARepeat: false, keyCode: 0)!
    }

    private var del: NSEvent { bare(String(UnicodeScalar(0xF728)!)) }   // NSDeleteFunctionKey
    private var f5: NSEvent { bare(String(UnicodeScalar(0xF708)!)) }    // F5

    // MARK: - The reported defect

    func testDelIsRefusedWhileATextFieldInAnotherWindowIsBeingEdited() {
        // The Find dialog: a text object is focused and the key window is not the file manager. Either
        // one alone is enough to refuse; this is the case a user reported, so it is asserted as it stood.
        XCTAssertFalse(RawKeyboard.menuMayClaim(del, keyWindowIsFileManager: false,
                                               firstResponder: NSTextView(), rawViews: []))
    }

    func testDelIsRefusedFromAnyWindowThatIsNotTheFileManager() {
        // Focus does not have to be in a text field for the keystroke to be aimed elsewhere: a dialog
        // with a button or a table focused is still not the panel the file would be deleted from.
        XCTAssertFalse(RawKeyboard.menuMayClaim(del, keyWindowIsFileManager: false,
                                               firstResponder: NSTableView(), rawViews: []))
    }

    func testDelIsRefusedWhileTypingInTheFileManagerItself() {
        // The command line and the quick filter live *in* the main window, so the window check does not
        // cover them — the same "is this being typed" rule has to.
        XCTAssertFalse(RawKeyboard.menuMayClaim(del, keyWindowIsFileManager: true,
                                               firstResponder: NSTextView(), rawViews: []))
    }

    // MARK: - What must keep working

    func testDelStillDeletesWhenThePanelHasTheKeyboard() {
        // The whole point of the key. A plain view is what a focused file panel looks like to this rule.
        XCTAssertTrue(RawKeyboard.menuMayClaim(del, keyWindowIsFileManager: true,
                                              firstResponder: NSView(), rawViews: []))
    }

    func testFunctionKeysStillReachThePanelsWhileTypingInTheFileManager() {
        // Deliberate exception: F1–F12 are not typing keys, and a file manager whose F5 stops copying
        // because the cursor sits in the command line has lost the property that makes it one.
        XCTAssertTrue(RawKeyboard.menuMayClaim(f5, keyWindowIsFileManager: true,
                                              firstResponder: NSTextView(), rawViews: []))
    }

    func testFunctionKeysAreStillRefusedFromAnotherWindow() {
        // The exception is about typing, not about F-keys being harmless: F5 is Copy and F7 is New
        // Folder, and a dialog's keystroke must not run either on the panels behind it.
        XCTAssertFalse(RawKeyboard.menuMayClaim(f5, keyWindowIsFileManager: false,
                                               firstResponder: NSTextView(), rawViews: []))
    }

    func testShiftAloneIsStillABareKey() {
        // ⇧F8 is "Delete Permanently" — the one binding in the default keymap where getting this wrong
        // deletes without a Trash to recover from.
        let shiftF8 = bare(String(UnicodeScalar(0xF70B)!), .shift)
        XCTAssertFalse(RawKeyboard.menuMayClaim(shiftF8, keyWindowIsFileManager: false,
                                                firstResponder: NSTextView(), rawViews: []))
    }

    // MARK: - Chords the menu owns wherever they are pressed

    func testCommandChordsAreTheMenusEverywhere() {
        // Unchanged macOS behaviour, and the reason this rule is about bare keys only: ⌘W closes a
        // Terminal.app tab too, and a text field does not get to keep it.
        let cmdW = bare("w", .command)
        XCTAssertTrue(RawKeyboard.menuMayClaim(cmdW, keyWindowIsFileManager: false,
                                              firstResponder: NSTextView(), rawViews: []))
    }

    func testControlAndOptionChordsAreAlsoTheMenus() {
        XCTAssertTrue(RawKeyboard.menuMayClaim(bare("b", .control), keyWindowIsFileManager: false,
                                              firstResponder: NSTextView(), rawViews: []))
        XCTAssertTrue(RawKeyboard.menuMayClaim(bare("f", .option), keyWindowIsFileManager: false,
                                              firstResponder: NSTextView(), rawViews: []))
    }

    // MARK: - Plugin views

    func testABareKeyInsideAPluginViewThatDeclaredRawKeyboardIsRefused() {
        // A terminal in the file manager's window: Del there belongs to whatever is running inside it.
        let pluginRoot = NSView()
        let focused = NSView()
        pluginRoot.addSubview(focused)
        XCTAssertFalse(RawKeyboard.menuMayClaim(del, keyWindowIsFileManager: true,
                                               firstResponder: focused, rawViews: [pluginRoot]))
    }
}
