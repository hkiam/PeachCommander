// SPDX-License-Identifier: Apache-2.0
// ThemePluginBridgeTests.swift — the theme.* keys plugins read (F-338).
//
// These keys are an ABI in everything but name: a plugin compiled today asks for them by string,
// and renaming or dropping one silently breaks a plugin the host cannot see. So the key *names* are
// pinned here as deliberately as the default palettes are, and the guarantees plugins are told to
// rely on — hex format, "absent means unset", semantic-to-raw consistency — are asserted rather
// than documented and hoped for.

import AppKit
import XCTest

final class ThemePluginBridgeTests: XCTestCase {
    private func values(_ colors: Theme.Colors = Theme.light,
                        isDark: Bool = false, id: String = "system") -> [String: String] {
        Theme.pluginContextValues(colors: colors, isDark: isDark, themeId: id)
    }

    // MARK: - The published key set

    /// Every semantic key a plugin may read. Adding to this list is fine; removing or renaming one
    /// breaks already-built plugins, so a failure here means an ABI decision, not a typo to fix.
    func testSemanticKeysArePresentAndPinned() {
        let v = values()
        let expected = [
            "theme.id", "theme.isDark",
            "theme.background", "theme.windowBackground", "theme.text", "theme.secondaryText",
            "theme.accent", "theme.separator", "theme.selectionBackground", "theme.selectionText",
            "theme.markedText", "theme.controlBackground", "theme.controlText",
        ]
        for key in expected {
            XCTAssertNotNil(v[key], "\(key) is missing — plugins built against it would lose their colour")
        }
    }

    /// The raw set: every colour of the palette, under the same names a user theme file uses. That
    /// shared vocabulary is the point — what you can write in a theme file, a plugin can read.
    func testEveryPaletteColorIsAvailableRawUnderItsThemeFileName() {
        let v = values(Theme.norton, isDark: true, id: "norton")
        for label in Mirror(reflecting: Theme.norton).children.compactMap(\.label) {
            // cursorRowText is optional; Norton sets it, so here every name must be present.
            XCTAssertNotNil(v["theme.color.\(label)"], "theme.color.\(label) missing")
        }
        XCTAssertEqual(v["theme.color.listBackground"], "#0000AA")
        XCTAssertEqual(v["theme.color.statusBarText"], "#000000")
    }

    /// An unset optional colour must be *absent*, not empty or black: a plugin has to be able to
    /// tell "this palette does not re-colour the cursor row" from "it colours it black".
    func testUnsetOptionalColorsAreOmittedEntirely() {
        XCTAssertNil(values(Theme.light)["theme.color.cursorRowText"],
                     "light does not set cursorRowText, so the key must not appear at all")
        XCTAssertEqual(values(Theme.norton, isDark: true, id: "norton")["theme.color.cursorRowText"], "#000000")
    }

    // MARK: - Format

    /// Plugins parse these with a 6-or-8 digit reader. Anything else — a name, rgb(), 3 digits —
    /// would silently fall back to the plugin's own default colour.
    func testEveryColorIsUppercaseHexWithAnOptionalAlphaByte() {
        for (key, value) in values(Theme.dark, isDark: true, id: "dark") where key.hasPrefix("theme.") {
            guard key != "theme.id", key != "theme.isDark" else { continue }
            XCTAssertTrue(value.hasPrefix("#"), "\(key) = \(value) must start with #")
            let digits = value.dropFirst()
            XCTAssertTrue(digits.count == 6 || digits.count == 8, "\(key) = \(value): 6 or 8 digits")
            XCTAssertTrue(digits.allSatisfy { $0.isHexDigit && !$0.isLowercase },
                          "\(key) = \(value) must be uppercase hex")
        }
    }

    /// Alpha is only emitted when it carries information. Always-8-digit output would work too, but
    /// the shorter form is what a human reads in a theme file, and the two must agree.
    func testAlphaByteAppearsOnlyForTranslucentColors() {
        let opaque = Theme.pluginHex(NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        let translucent = Theme.pluginHex(NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 0.5))
        XCTAssertEqual(opaque, "#0000FF")
        XCTAssertEqual(translucent, "#0000FF80")
    }

    /// Round-trip: what the bridge emits, a theme file (and the plugin helper) must be able to read
    /// back. If these two ever disagree, a colour copied out of a plugin into a theme file breaks.
    func testEmittedHexParsesBackToTheSameColor() {
        for c in [NSColor(srgbRed: 0.1, green: 0.2, blue: 0.3, alpha: 1),
                  NSColor(srgbRed: 0.9, green: 0.4, blue: 0.1, alpha: 0.22),
                  NSColor.black, NSColor.white] {
            guard let back = NSColor(hexString: Theme.pluginHex(c)) else {
                return XCTFail("\(Theme.pluginHex(c)) does not parse back")
            }
            let a = c.usingColorSpace(.sRGB)!, b = back.usingColorSpace(.sRGB)!
            XCTAssertEqual(a.redComponent, b.redComponent, accuracy: 0.004)
            XCTAssertEqual(a.greenComponent, b.greenComponent, accuracy: 0.004)
            XCTAssertEqual(a.blueComponent, b.blueComponent, accuracy: 0.004)
            XCTAssertEqual(a.alphaComponent, b.alphaComponent, accuracy: 0.004)
        }
    }

    // MARK: - Meaning

    func testIdAndIsDarkReportTheHostState() {
        XCTAssertEqual(values(Theme.light, isDark: false, id: "system")["theme.id"], "system")
        XCTAssertEqual(values(Theme.light, isDark: false, id: "system")["theme.isDark"], "0")
        XCTAssertEqual(values(Theme.norton, isDark: true, id: "norton")["theme.isDark"], "1")
    }

    /// The semantic keys must be the same colours as their raw counterparts, or a plugin mixing the
    /// two vocabularies draws two slightly different greys and looks broken.
    func testSemanticKeysAgreeWithTheirRawSources() {
        let v = values(Theme.norton, isDark: true, id: "norton")
        XCTAssertEqual(v["theme.background"], v["theme.color.listBackground"])
        XCTAssertEqual(v["theme.windowBackground"], v["theme.color.windowBackground"])
        XCTAssertEqual(v["theme.text"], v["theme.color.listText"])
        XCTAssertEqual(v["theme.accent"], v["theme.color.activeCursorFrame"])
        XCTAssertEqual(v["theme.separator"], v["theme.color.columnSeparator"])
        XCTAssertEqual(v["theme.selectionBackground"], v["theme.color.selectionFillActive"])
        XCTAssertEqual(v["theme.markedText"], v["theme.color.selectedText"])
        XCTAssertEqual(v["theme.controlBackground"], v["theme.color.driveBarBackground"])
        XCTAssertEqual(v["theme.controlText"], v["theme.color.driveBarText"])
        // `theme.secondaryText` is deliberately *not* in this list. It used to equal
        // `pathBarFreeSpaceText` and this test held that in place — which is how the terminal's
        // status line came to be black on Norton's blue panels: that colour is defined against the
        // path bar, a surface plugins do not draw on. It is now derived from the list colours, so
        // there is no raw counterpart to agree with; `PluginSecondaryTextTests` checks the property
        // that actually matters, which is that it can be read.
        XCTAssertNotEqual(v["theme.secondaryText"], v["theme.color.pathBarFreeSpaceText"],
                          "Norton's path-bar black is the one colour this must not be")
    }

    /// `selectionText` is what a plugin draws *on* `selectionBackground`. A palette that inverts its
    /// cursor row supplies the colour; otherwise it is the normal text colour, because that is what
    /// the host's own panel draws there — a plugin following the host must match.
    func testSelectionTextFollowsThePaletteInversion() {
        XCTAssertEqual(values(Theme.light)["theme.selectionText"], values(Theme.light)["theme.text"],
                       "no inversion: the panel keeps its text colour on the cursor row")
        let nc = values(Theme.norton, isDark: true, id: "norton")
        XCTAssertEqual(nc["theme.selectionText"], "#000000", "Norton inverts: black on the cyan bar")
        XCTAssertNotEqual(nc["theme.selectionText"], nc["theme.text"])
    }

    /// The pairing that actually decides legibility for a plugin: whatever it is told to draw on the
    /// selection must be distinguishable from the selection itself. Checked for every palette.
    func testSelectionTextIsLegibleOnSelectionBackgroundInEveryPalette() {
        for p in Theme.palettes {
            let v = Theme.pluginContextValues(colors: p.colors, isDark: p.isDark, themeId: p.id)
            XCTAssertNotEqual(v["theme.selectionText"], v["theme.selectionBackground"],
                              "palette \"\(p.id)\": a plugin drawing selectionText on "
                              + "selectionBackground would render invisible text")
        }
    }

    /// A plugin reads these by string and keeps its own colour when a key is missing. Nothing in the
    /// bridge may therefore hand back an empty value, which would parse as "present but unusable".
    func testNoKeyIsEverEmpty() {
        for palette in Theme.palettes {
            let v = Theme.pluginContextValues(colors: palette.colors, isDark: palette.isDark,
                                              themeId: palette.id)
            for (key, value) in v {
                XCTAssertFalse(value.isEmpty, "\(key) is empty in palette \(palette.id)")
            }
        }
    }

    // MARK: - Eight-digit theme-file input

    /// The counterpart of the emitted alpha: a theme file must be able to *write* it, or the two
    /// translucent panel colours could not be expressed at all.
    func testThemeFilesAcceptEightDigitColors() {
        let result = ThemeFile.parse("[Colors]\nZebraRow = #0000AA59\nListText = #FFFFFF", id: "x")
        XCTAssertTrue(result.warnings.isEmpty, "warnings: \(result.warnings)")
        guard let p = result.palette else { return XCTFail("not parsed") }
        let z = p.colors.zebraRow.usingColorSpace(.sRGB)!
        XCTAssertEqual(z.alphaComponent, 0.349, accuracy: 0.01, "alpha byte must survive")
        XCTAssertEqual(Theme.pluginHex(p.colors.zebraRow), "#0000AA59")
    }

    func testMalformedLengthsAreStillRejected() {
        for bad in ["#FFF", "#FFFFF", "#FFFFFFF", "#FFFFFFFFF", "", "#", "nonsense"] {
            XCTAssertNil(NSColor(hexString: bad), "\(bad.debugDescription) must not parse")
        }
    }
}
