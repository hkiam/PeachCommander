// KeymapTests.swift - Tests for the keyboard-remapping engine (F-254).

import XCTest
@testable import PCFoundation

final class KeymapTests: XCTestCase {

    // MARK: - KeyChord parsing

    func testParsePlainFunctionKey() {
        let chord = KeyChord(parsing: "F5")
        XCTAssertEqual(chord, KeyChord(key: "F5"))
        XCTAssertEqual(chord?.spec, "F5")
        XCTAssertEqual(chord?.ctrl, false)
        XCTAssertEqual(chord?.alt, false)
        XCTAssertEqual(chord?.shift, false)
        XCTAssertEqual(chord?.cmd, false)
    }

    func testParseCtrlShiftFunctionKey() {
        let chord = KeyChord(parsing: "C+S+F5")
        XCTAssertEqual(chord, KeyChord(ctrl: true, shift: true, key: "F5"))
        XCTAssertEqual(chord?.spec, "C+S+F5")
        XCTAssertEqual(chord?.ctrl, true)
        XCTAssertEqual(chord?.shift, true)
        XCTAssertEqual(chord?.alt, false)
        XCTAssertEqual(chord?.cmd, false)
    }

    func testParseAltFunctionKey() {
        let chord = KeyChord(parsing: "A+F7")
        XCTAssertEqual(chord, KeyChord(alt: true, key: "F7"))
        XCTAssertEqual(chord?.spec, "A+F7")
    }

    func testParseCtrlAltLetter() {
        let chord = KeyChord(parsing: "C+A+L")
        XCTAssertEqual(chord, KeyChord(ctrl: true, alt: true, key: "L"))
        XCTAssertEqual(chord?.spec, "C+A+L")
    }

    func testParseNumpadPlus() {
        let chord = KeyChord(parsing: "Num+")
        XCTAssertEqual(chord, KeyChord(key: "NUM+"))
        XCTAssertEqual(chord?.key, "NUM+")
        XCTAssertEqual(chord?.spec, "NUM+")
    }

    func testParseCtrlNumpadPlus() {
        let chord = KeyChord(parsing: "C+Num+")
        XCTAssertEqual(chord, KeyChord(ctrl: true, key: "NUM+"))
        XCTAssertEqual(chord?.key, "NUM+")
        XCTAssertEqual(chord?.spec, "C+NUM+")
    }

    func testParseOtherNumpadKeys() {
        XCTAssertEqual(KeyChord(parsing: "Num-")?.key, "NUM-")
        XCTAssertEqual(KeyChord(parsing: "Num*")?.key, "NUM*")
        XCTAssertEqual(KeyChord(parsing: "Num/")?.key, "NUM/")
    }

    func testParseNamedKeyEnter() {
        let chord = KeyChord(parsing: "Enter")
        XCTAssertEqual(chord, KeyChord(key: "ENTER"))
        XCTAssertEqual(chord?.spec, "ENTER")
    }

    func testParseCtrlLeft() {
        let chord = KeyChord(parsing: "C+Left")
        XCTAssertEqual(chord, KeyChord(ctrl: true, key: "LEFT"))
        XCTAssertEqual(chord?.spec, "C+LEFT")
    }

    // MARK: - Case-insensitivity & modifier ordering

    func testCaseInsensitiveParse() {
        XCTAssertEqual(KeyChord(parsing: "c+s+f5"), KeyChord(parsing: "C+S+F5"))
        XCTAssertEqual(KeyChord(parsing: "c+s+f5")?.spec, "C+S+F5")
    }

    func testModifierOrderCanonicalized() {
        // Modifiers supplied out of order still canonicalize to C, A, S, W.
        XCTAssertEqual(KeyChord(parsing: "S+C+A+W+F1")?.spec, "C+A+S+W+F1")
    }

    // MARK: - Aliases

    func testModifierAliases() {
        XCTAssertEqual(KeyChord(parsing: "CTRL+A"), KeyChord(ctrl: true, key: "A"))
        XCTAssertEqual(KeyChord(parsing: "ALT+F7"), KeyChord(alt: true, key: "F7"))
        XCTAssertEqual(KeyChord(parsing: "OPT+F7"), KeyChord(alt: true, key: "F7"))
        XCTAssertEqual(KeyChord(parsing: "SHIFT+F5"), KeyChord(shift: true, key: "F5"))
        XCTAssertEqual(KeyChord(parsing: "CMD+C"), KeyChord(cmd: true, key: "C"))
        XCTAssertEqual(KeyChord(parsing: "WIN+C"), KeyChord(cmd: true, key: "C"))
    }

    func testKeyAliases() {
        XCTAssertEqual(KeyChord(parsing: "DEL")?.key, "DELETE")
        XCTAssertEqual(KeyChord(parsing: "ESCAPE")?.key, "ESC")
        XCTAssertEqual(KeyChord(key: "del").key, "DELETE")
        XCTAssertEqual(KeyChord(key: "escape").key, "ESC")
    }

    // MARK: - Invalid specs

    func testInvalidSpecs() {
        XCTAssertNil(KeyChord(parsing: ""))
        XCTAssertNil(KeyChord(parsing: "C+"))       // no key token
        XCTAssertNil(KeyChord(parsing: "C+ZZ"))     // invalid key token
        XCTAssertNil(KeyChord(parsing: "X+F5"))     // unknown modifier
        XCTAssertNil(KeyChord(parsing: "F13"))      // out of F-key range
        XCTAssertNil(KeyChord(parsing: "   "))      // whitespace only
    }

    // MARK: - Round trip & hashing

    func testSpecRoundTrip() {
        for spec in ["F5", "C+S+F5", "A+F7", "C+A+L", "C+NUM+", "ENTER", "C+LEFT", "C+A+S+W+F1"] {
            let chord = KeyChord(parsing: spec)
            XCTAssertNotNil(chord, "expected \(spec) to parse")
            XCTAssertEqual(chord?.spec, spec, "round trip mismatch for \(spec)")
        }
    }

    func testHashableEqualityOfEquivalentChords() {
        let a = KeyChord(parsing: "c+s+f5")!
        let b = KeyChord(ctrl: true, shift: true, key: "F5")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        let set: Set<KeyChord> = [a, b]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - KeymapScheme

    func testSchemeParseAndLookup() {
        let ini = """
        [Shortcuts]
        F5=cm_Copy
        A+F7=cm_SearchFor
        C+M=cm_MultiRenameFiles
        """
        let scheme = KeymapScheme(parsing: ini)
        XCTAssertEqual(scheme.bindings.count, 3)
        XCTAssertEqual(scheme.bindings[KeyChord(key: "F5")], "cm_Copy")
        XCTAssertEqual(scheme.bindings[KeyChord(alt: true, key: "F7")], "cm_SearchFor")
        XCTAssertEqual(scheme.bindings[KeyChord(ctrl: true, key: "M")], "cm_MultiRenameFiles")
    }

    func testSchemeParseSkipsInvalidAndComments() {
        let ini = """
        ; a comment
        [Shortcuts]
        F5=cm_Copy
        ZZ=cm_Bogus
        C+=cm_Nothing
        # another comment
        A+F7=cm_SearchFor
        """
        let scheme = KeymapScheme(parsing: ini)
        XCTAssertEqual(scheme.bindings.count, 2)
        XCTAssertEqual(scheme.bindings[KeyChord(key: "F5")], "cm_Copy")
        XCTAssertEqual(scheme.bindings[KeyChord(alt: true, key: "F7")], "cm_SearchFor")
    }

    func testSchemeParseIgnoresLinesOutsideSection() {
        let ini = """
        [Other]
        F5=cm_ShouldBeIgnored
        [Shortcuts]
        F6=cm_RenMov
        """
        let scheme = KeymapScheme(parsing: ini)
        XCTAssertEqual(scheme.bindings.count, 1)
        XCTAssertEqual(scheme.bindings[KeyChord(key: "F6")], "cm_RenMov")
        XCTAssertNil(scheme.bindings[KeyChord(key: "F5")])
    }

    func testSchemeBlankCommandRemoves() {
        let ini = """
        [Shortcuts]
        F5=cm_Copy
        F5=
        """
        let scheme = KeymapScheme(parsing: ini)
        XCTAssertNil(scheme.bindings[KeyChord(key: "F5")])
        XCTAssertTrue(scheme.bindings.isEmpty)
    }

    func testSchemeSerializeRoundTrip() {
        let ini = """
        [Shortcuts]
        A+F7=cm_SearchFor
        C+M=cm_MultiRenameFiles
        F5=cm_Copy
        """
        let scheme = KeymapScheme(parsing: ini)
        let serialized = scheme.serialized()
        // Sorted by spec: "A+F7" < "C+M" < "F5".
        XCTAssertEqual(serialized, """
        [Shortcuts]
        A+F7=cm_SearchFor
        C+M=cm_MultiRenameFiles
        F5=cm_Copy
        """)
        // Re-parsing the serialized form yields an equal scheme.
        XCTAssertEqual(KeymapScheme(parsing: serialized), scheme)
    }

    // MARK: - Keymap precedence

    func testPrecedenceUserBeatsSchemeBeatsBuiltin() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Builtin"])
        let scheme = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Scheme"])
        let user = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_User"])

        let onlyBuiltin = Keymap(builtin: builtin)
        XCTAssertEqual(onlyBuiltin.command(for: KeyChord(key: "F5")), "cm_Builtin")

        let withScheme = Keymap(builtin: builtin, scheme: scheme)
        XCTAssertEqual(withScheme.command(for: KeyChord(key: "F5")), "cm_Scheme")

        let withUser = Keymap(builtin: builtin, scheme: scheme, user: user)
        XCTAssertEqual(withUser.command(for: KeyChord(key: "F5")), "cm_User")
    }

    func testFallThroughToLowerLayers() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F6"): "cm_RenMov"])
        let scheme = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        let map = Keymap(builtin: builtin, scheme: scheme)
        // F6 only in builtin, F5 only in scheme.
        XCTAssertEqual(map.command(for: KeyChord(key: "F6")), "cm_RenMov")
        XCTAssertEqual(map.command(for: KeyChord(key: "F5")), "cm_Copy")
        XCTAssertNil(map.command(for: KeyChord(key: "F7")))
    }

    func testUserSuppressionReturnsNil() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        let user = KeymapScheme(bindings: [KeyChord(key: "F5"): ""])
        let map = Keymap(builtin: builtin, user: user)
        XCTAssertNil(map.command(for: KeyChord(key: "F5")))
    }

    // MARK: - setUserBinding

    func testSetUserBindingAddReplaceRemove() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        var map = Keymap(builtin: builtin)

        // Add override.
        map.setUserBinding(KeyChord(key: "F5"), to: "cm_MyCopy")
        XCTAssertEqual(map.command(for: KeyChord(key: "F5")), "cm_MyCopy")

        // Replace override.
        map.setUserBinding(KeyChord(key: "F5"), to: "cm_OtherCopy")
        XCTAssertEqual(map.command(for: KeyChord(key: "F5")), "cm_OtherCopy")

        // Remove override (nil) -> falls back to builtin.
        map.setUserBinding(KeyChord(key: "F5"), to: nil)
        XCTAssertEqual(map.command(for: KeyChord(key: "F5")), "cm_Copy")
        XCTAssertTrue(map.userScheme.bindings.isEmpty)
    }

    func testSetUserBindingSuppression() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        var map = Keymap(builtin: builtin)
        map.setUserBinding(KeyChord(key: "F5"), to: "")
        XCTAssertNil(map.command(for: KeyChord(key: "F5")))
        // The suppression entry is retained in the user layer.
        XCTAssertEqual(map.userScheme.bindings[KeyChord(key: "F5")], "")
    }

    // MARK: - chord(for:)

    func testChordForCommandPrecedence() {
        // Builtin binds cm_Copy to F5; user rebinds it to C+C. User wins.
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        let user = KeymapScheme(bindings: [KeyChord(ctrl: true, key: "C"): "cm_Copy"])
        let map = Keymap(builtin: builtin, user: user)
        XCTAssertEqual(map.chord(for: "cm_Copy"), KeyChord(ctrl: true, key: "C"))
    }

    func testChordForCommandSmallestSpecTieBreak() {
        // Two builtin chords for the same command: pick the smallest spec.
        let builtin = KeymapScheme(bindings: [
            KeyChord(key: "F5"): "cm_Copy",
            KeyChord(ctrl: true, key: "C"): "cm_Copy",
        ])
        let map = Keymap(builtin: builtin)
        // "C+C" < "F5" lexicographically.
        XCTAssertEqual(map.chord(for: "cm_Copy"), KeyChord(ctrl: true, key: "C"))
    }

    func testChordForCommandNotFound() {
        let builtin = KeymapScheme(bindings: [KeyChord(key: "F5"): "cm_Copy"])
        let map = Keymap(builtin: builtin)
        XCTAssertNil(map.chord(for: "cm_DoesNotExist"))
    }

    // MARK: - effective

    func testEffectiveMergeAndSuppressionRemoval() {
        let builtin = KeymapScheme(bindings: [
            KeyChord(key: "F5"): "cm_Copy",
            KeyChord(key: "F6"): "cm_RenMov",
            KeyChord(key: "F7"): "cm_MkDir",
        ])
        let scheme = KeymapScheme(bindings: [
            KeyChord(key: "F6"): "cm_SchemeRenMov", // overrides builtin
        ])
        let user = KeymapScheme(bindings: [
            KeyChord(key: "F5"): "cm_UserCopy",     // overrides builtin
            KeyChord(key: "F7"): "",                // suppresses builtin
            KeyChord(key: "F8"): "cm_Delete",       // brand new
        ])
        let map = Keymap(builtin: builtin, scheme: scheme, user: user)
        let eff = map.effective

        XCTAssertEqual(eff[KeyChord(key: "F5")], "cm_UserCopy")
        XCTAssertEqual(eff[KeyChord(key: "F6")], "cm_SchemeRenMov")
        XCTAssertNil(eff[KeyChord(key: "F7")]) // suppressed
        XCTAssertEqual(eff[KeyChord(key: "F8")], "cm_Delete")
        XCTAssertEqual(eff.count, 3)
    }
}
