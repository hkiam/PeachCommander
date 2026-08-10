// SPDX-License-Identifier: Apache-2.0
// PositionalKeyTests.swift - A shortcut bound to a key's *position* rather than its character (F-381).
//
// Every other token the keymap accepts is layout-independent because the character is: an "A" is an
// "A" on every keyboard. The key left of the "1" is not — it prints ` on a US layout, ^ on a German
// one, @ on a French one — so the dock's shortcut could not be expressed as a character without
// meaning a different physical key on every machine. On a German layout it is worse than ambiguous:
// the backtick lives on Shift plus the dead-key acute, so ⌃` would be a three-finger gesture through
// a dead key.
//
// So "BACKQUOTE" is a token that names a position, and the dispatcher resolves it from the hardware
// key code (`KeymapMenu.keyToken`, checked before the character lookup). What this file guards is the
// half that lives in PCFoundation: that the token parses, survives a round trip through the INI form
// a scheme is written in, and is not quietly accepted as some other key.

import XCTest
@testable import PCFoundation

final class PositionalKeyTests: XCTestCase {

    func testTheTokenParsesWithModifiers() {
        let chord = KeyChord(parsing: "C+BACKQUOTE")
        XCTAssertNotNil(chord)
        XCTAssertEqual(chord?.key, "BACKQUOTE")
        XCTAssertTrue(chord?.ctrl == true)
        XCTAssertFalse(chord?.shift == true)
        XCTAssertFalse(chord?.cmd == true)
    }

    func testItRoundTripsThroughTheSpecForm() throws {
        // A scheme is stored as text, so a token that parses but does not serialize back would lose
        // the binding the first time the user's keymap is written out.
        let chord = try XCTUnwrap(KeyChord(parsing: "C+BACKQUOTE"))
        XCTAssertEqual(chord.spec, "C+BACKQUOTE")
        XCTAssertEqual(KeyChord(parsing: chord.spec), chord)
    }

    func testTheCharacterItselfIsStillNotAKeyToken() {
        // The point of the token is that the character is not usable. If "`" ever became acceptable,
        // a binding written that way would silently be layout-dependent again.
        XCTAssertNil(KeyChord(parsing: "C+`"))
        XCTAssertNil(KeyChord(parsing: "C+^"))
    }

    func testTheTerminalKeyIsBoundInBothShippedSchemes() throws {
        // The binding is product, not decoration: the terminal is unreachable from the keyboard
        // without it, and the two schemes are edited independently often enough that one drifting is
        // likely.
        for name in ["keymap-macos", "keymap-tc-classic"] {
            let url = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Sources/PCApp/Resources/\(name).ini")
            let scheme = KeymapScheme(parsing: try String(contentsOf: url, encoding: .utf8))
            let chord = try XCTUnwrap(KeyChord(parsing: "C+BACKQUOTE"))
            XCTAssertEqual(scheme.bindings[chord], "cm_TerminalFocus", name)
        }
    }
}
