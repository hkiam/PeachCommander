// SPDX-License-Identifier: Apache-2.0
// RawKeyboardTests.swift - Who gets a key press: the focused view, or the file manager (F-381).
//
// `performKeyEquivalent` is broadcast to every view in the window, which is how a Total Commander
// keyboard works at all — F5 copies wherever the cursor is. It is also how the panel used to swallow
// ⌘C while the user typed in the command line. The fix at the time asked `firstResponder is NSText`,
// which repaired the command line and nothing else: anything focusable that is not an `NSText` walked
// straight back into it.
//
// The case that cannot be exercised any other way yet is the plugin one. A plugin's view arrives as an
// `NSView*` across a C ABI and cannot adopt a Swift protocol, so it declares `rawKeyboard` in its
// manifest and the host resolves the focused responder *up its view hierarchy* to see whether it lands
// inside one. A terminal's focused view will be several levels inside the root the host was handed, so
// asking the focused view alone would always answer no — and there is no terminal yet to notice.
//
// `RawKeyboard.swift` is compiled into this bundle rather than imported: PCApp is an application, not
// a library, so there is nothing to `@testable import`. It is the arrangement PCThemeTests already
// uses for Theme.swift, and it works here because the file depends on AppKit and nothing else.

import XCTest
import AppKit

@MainActor
final class RawKeyboardTests: XCTestCase {

    /// A key press that is not a menu equivalent — the kind the app's own keymap would claim.
    private func key(_ chars: String, _ flags: NSEvent.ModifierFlags = .command) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                         windowNumber: 0, context: nil, characters: chars,
                         charactersIgnoringModifiers: chars, isARepeat: false, keyCode: 8)!
    }

    // MARK: - Nobody focused, or nothing special

    func testAPlainViewGetsNothing() {
        // The default has to stay "the app's keyboard wins", or a Total Commander keyboard stops
        // working the moment anything at all is focused.
        let view = NSView()
        XCTAssertFalse(RawKeyboard.wantsRaw(key("c"), firstResponder: view, rawViews: []))
    }

    func testNoFirstResponderGetsNothing() {
        XCTAssertFalse(RawKeyboard.wantsRaw(key("c"), firstResponder: nil, rawViews: []))
    }

    // MARK: - Text (the case the old special case covered)

    func testATextObjectBeingEditedGetsEverything() {
        // Previously only ⌘C/V/X/A/Z were handed over. A text view wants its keys, all of them.
        let text = NSTextView()
        XCTAssertTrue(RawKeyboard.wantsRaw(key("c"), firstResponder: text, rawViews: []))
        XCTAssertTrue(RawKeyboard.wantsRaw(key("b", .control), firstResponder: text, rawViews: []))
    }

    // MARK: - Plugin views (declared in the manifest, resolved by hierarchy)

    func testAViewInsideADeclaredPluginViewGetsTheKey() {
        // The shape a terminal will have: the host holds the root NSView the plugin returned, and the
        // thing that actually takes focus is the plugin's own class somewhere inside it.
        let pluginRoot = NSView()
        let inner = NSView()
        let focused = NSView()
        pluginRoot.addSubview(inner)
        inner.addSubview(focused)

        XCTAssertTrue(RawKeyboard.wantsRaw(key("c"), firstResponder: focused,
                                           rawViews: [pluginRoot]))
    }

    func testAViewOutsideItDoesNot() {
        // The walk goes up, not sideways: a sibling of the plugin's view is not inside it.
        let pluginRoot = NSView()
        let elsewhere = NSView()
        let window = NSView()
        window.addSubview(pluginRoot)
        window.addSubview(elsewhere)

        XCTAssertFalse(RawKeyboard.wantsRaw(key("c"), firstResponder: elsewhere,
                                            rawViews: [pluginRoot]))
    }

    func testAPluginViewThatDidNotDeclareItGetsNothing() {
        // rawKeyboard is opt-in. A plugin showing a list wants F5 to mean "copy files" like everywhere
        // else in the window, and taking the keyboard away from the file manager by default would be
        // the worse mistake of the two.
        let pluginRoot = NSView()
        let focused = NSView()
        pluginRoot.addSubview(focused)
        XCTAssertFalse(RawKeyboard.wantsRaw(key("c"), firstResponder: focused, rawViews: []))
    }

    // MARK: - Built-ins, which can answer per event

    private final class PickyView: NSView, RawKeyboardConsumer {
        func wantsRawKeyEvent(_ event: NSEvent) -> Bool {
            event.charactersIgnoringModifiers == "c"
        }
    }

    func testABuiltInIsAskedAboutTheSpecificKey() {
        // Per event rather than a flag: a view may want the arrows and not ⌘F, and being asked about
        // the press is the difference between "this view is special" and "this key is".
        let picky = PickyView()
        XCTAssertTrue(RawKeyboard.wantsRaw(key("c"), firstResponder: picky, rawViews: []))
        XCTAssertFalse(RawKeyboard.wantsRaw(key("v"), firstResponder: picky, rawViews: []))
    }

    func testABuiltInIsFoundThroughTheHierarchyToo() {
        let picky = PickyView()
        let focused = NSView()
        picky.addSubview(focused)
        XCTAssertTrue(RawKeyboard.wantsRaw(key("c"), firstResponder: focused, rawViews: []))
    }
}
