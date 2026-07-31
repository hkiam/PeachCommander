// SPDX-License-Identifier: Apache-2.0
// ThemeGoldenTests.swift — the default appearance must not drift.
//
// Selectable themes were added on one hard condition: the current look stays the default.
// Palettes turn the panel colours from literals into data, and data is easy to edit by
// accident — a tweak meant for the Norton palette landing in `light` would change how the app
// looks for everyone, and nothing would fail.
//
// So these are golden tests in the strict sense: they pin the exact sRGB value of every colour
// in the two default palettes. They are *meant* to be annoying. A failure here is either a real
// regression or a deliberate redesign of the default look — in the latter case update the
// expectations in the same commit that changes Theme.swift, on purpose.
//
// Values are compared as "rrggbb@alpha" rather than via Theme's own `hexString`, which drops
// alpha: two of the defaults are translucent, and a lost alpha is exactly the kind of silent
// change this file exists to catch. They were generated from the code, not typed by hand.
//
// The target compiles Sources/PCApp/Theme.swift directly instead of hosting the app: Theme only
// imports AppKit, so there is no test host, no launch and no plugin loading.

import AppKit
import XCTest

final class ThemeGoldenTests: XCTestCase {
    /// "rrggbb@a.aaa" in sRGB.
    private func rgba(_ c: NSColor) -> String {
        let s = c.usingColorSpace(.sRGB) ?? c
        return String(format: "%02x%02x%02x@%.3f", Int((s.redComponent * 255).rounded()),
                      Int((s.greenComponent * 255).rounded()), Int((s.blueComponent * 255).rounded()),
                      s.alphaComponent)
    }

    /// Every field of `Theme.Colors`. Adding a colour without extending this map is caught by
    /// `testGoldenMapCoversEveryColor` below, so a new field cannot slip in untested.
    private func values(of c: Theme.Colors) -> [String: String] {
        [
            "windowBackground": rgba(c.windowBackground),
            "listBackground": rgba(c.listBackground),
            "listText": rgba(c.listText),
            "selectedText": rgba(c.selectedText),
            "cursorFrame": rgba(c.cursorFrame),
            "activePathBarBackground": rgba(c.activePathBarBackground),
            "activePathBarText": rgba(c.activePathBarText),
            "inactivePathBarBackground": rgba(c.inactivePathBarBackground),
            "inactivePathBarText": rgba(c.inactivePathBarText),
            "pathBarBackground": rgba(c.pathBarBackground),
            "pathBarText": rgba(c.pathBarText),
            "pathBarHoverBackground": rgba(c.pathBarHoverBackground),
            "pathBarSeparator": rgba(c.pathBarSeparator),
            "pathBarFreeSpaceText": rgba(c.pathBarFreeSpaceText),
            "columnSeparator": rgba(c.columnSeparator),
            "functionButtonBackground": rgba(c.functionButtonBackground),
            "functionButtonPressed": rgba(c.functionButtonPressed),
            "functionButtonText": rgba(c.functionButtonText),
            "statusBarBackground": rgba(c.statusBarBackground),
            "statusBarText": rgba(c.statusBarText),
            "zebraRow": rgba(c.zebraRow),
            "selectionFillActive": rgba(c.selectionFillActive),
            "selectionFillInactive": rgba(c.selectionFillInactive),
            "activeCursorFrame": rgba(c.activeCursorFrame),
            "headerSeparator": rgba(c.headerSeparator),
            "driveBarBackground": rgba(c.driveBarBackground),
            "driveBarHighlight": rgba(c.driveBarHighlight),
            "driveBarText": rgba(c.driveBarText),
            "driveBarHighlightText": rgba(c.driveBarHighlightText),
            // Optional: "none" when the palette leaves the cursor row's text alone.
            "cursorRowText": c.cursorRowText.map(rgba) ?? "none",
        ]
    }

    // MARK: - The defaults

    private let lightGolden = [
        "windowBackground": "ffffff@1.000",
        "listBackground": "ffffff@1.000",
        "listText": "000000@1.000",
        "selectedText": "ff0000@1.000",
        "cursorFrame": "000080@1.000",
        "activePathBarBackground": "cce0ff@1.000",
        "activePathBarText": "000000@1.000",
        "inactivePathBarBackground": "e6e6e6@1.000",
        "inactivePathBarText": "4d4d4d@1.000",
        "pathBarBackground": "f2f2f2@1.000",
        "pathBarText": "000000@1.000",
        "pathBarHoverBackground": "000080@0.200",
        "pathBarSeparator": "b2b2b2@1.000",
        "pathBarFreeSpaceText": "808080@1.000",
        "columnSeparator": "cccccc@1.000",
        "functionButtonBackground": "f2f2f2@1.000",
        "functionButtonPressed": "d9d9d9@1.000",
        "functionButtonText": "000000@1.000",
        "statusBarBackground": "f2f2f2@1.000",
        "statusBarText": "000000@1.000",
    ]

    private let darkGolden = [
        "windowBackground": "262626@1.000",
        "listBackground": "333333@1.000",
        "listText": "e6e6e6@1.000",
        "selectedText": "ff0000@1.000",
        "cursorFrame": "4d4dff@1.000",
        "activePathBarBackground": "3d4d73@1.000",
        "activePathBarText": "f2f2f2@1.000",
        "inactivePathBarBackground": "404040@1.000",
        "inactivePathBarText": "808080@1.000",
        "pathBarBackground": "404040@1.000",
        "pathBarText": "e6e6e6@1.000",
        "pathBarHoverBackground": "333399@0.300",
        "pathBarSeparator": "4d4d4d@1.000",
        "pathBarFreeSpaceText": "999999@1.000",
        "columnSeparator": "4d4d4d@1.000",
        "functionButtonBackground": "404040@1.000",
        "functionButtonPressed": "595959@1.000",
        "functionButtonText": "e6e6e6@1.000",
        "statusBarBackground": "404040@1.000",
        "statusBarText": "e6e6e6@1.000",
    ]

    func testLightPaletteIsUnchanged() {
        assertColors(values(of: Theme.light), lightGolden, label: "Theme.light")
    }

    func testDarkPaletteIsUnchanged() {
        assertColors(values(of: Theme.dark), darkGolden, label: "Theme.dark")
    }

    /// The nine colours lifted out of the drawing code are *semantic* (`controlAccentColor`,
    /// `separatorColor`, …), so their sRGB value depends on the user's accent colour and cannot
    /// be pinned. What must hold is that they still default to exactly those system colours —
    /// that identity is what makes the default look the same as before themes existed.
    func testExtractedColorsStillDefaultToTheSystemOnes() {
        for (name, c) in [("light", Theme.light), ("dark", Theme.dark)] {
            XCTAssertEqual(c.zebraRow, NSColor.gray.withAlphaComponent(0.08), "\(name).zebraRow")
            XCTAssertEqual(c.selectionFillActive, NSColor.controlAccentColor.withAlphaComponent(0.22),
                           "\(name).selectionFillActive")
            XCTAssertEqual(c.selectionFillInactive, NSColor.gray.withAlphaComponent(0.10),
                           "\(name).selectionFillInactive")
            XCTAssertEqual(c.activeCursorFrame, NSColor.controlAccentColor, "\(name).activeCursorFrame")
            XCTAssertEqual(c.headerSeparator, NSColor.separatorColor, "\(name).headerSeparator")
            XCTAssertEqual(c.driveBarBackground, NSColor.controlColor, "\(name).driveBarBackground")
            XCTAssertEqual(c.driveBarHighlight, NSColor.controlAccentColor, "\(name).driveBarHighlight")
            XCTAssertEqual(c.driveBarText, NSColor.labelColor, "\(name).driveBarText")
            XCTAssertEqual(c.driveBarHighlightText, NSColor.white, "\(name).driveBarHighlightText")
            XCTAssertNil(c.cursorRowText,
                         "\(name).cursorRowText must stay nil — a value here changes how every "
                         + "cursor row is drawn in the default theme")
        }
    }

    /// Guards the guard: a colour added to `Theme.Colors` but not to `values(of:)` would leave a
    /// hole in every assertion in this file without anything going red.
    func testGoldenMapCoversEveryColor() {
        let mapped = Set(values(of: Theme.light).keys)
        // Reflection sees the stored properties; anything it finds must be in the map.
        let declared = Set(Mirror(reflecting: Theme.light).children.compactMap(\.label))
        XCTAssertTrue(declared.subtracting(mapped).isEmpty,
                      "Theme.Colors gained colours that no golden test covers: "
                      + declared.subtracting(mapped).sorted().joined(separator: ", ")
                      + " — add them to values(of:), and to a palette's own list if they must not "
                      + "fall back to a system colour.")
    }

    // MARK: - Resolution

    /// The whole promise of "the default stays": an unset, empty or unknown theme id must resolve
    /// to the untouched light/dark pair, never to a palette. A removed theme or a typo in the
    /// config file can then never leave the app in a state the user cannot read.
    func testUnknownAndSystemThemesResolveToTheDefaults() {
        for id in ["system", "", "norten", "Norton Commander", "nc", "SYSTEM"] {
            XCTAssertEqual(rgba(Theme.resolve(themeId: id, isDark: false).colors.listBackground),
                           lightGolden["listBackground"],
                           "theme id \(id.debugDescription) must fall back to Theme.light")
            XCTAssertEqual(rgba(Theme.resolve(themeId: id, isDark: true).colors.listBackground),
                           darkGolden["listBackground"],
                           "theme id \(id.debugDescription) must fall back to Theme.dark")
        }
    }

    func testResolveIgnoresAppearanceForNamedPalettes() {
        // A palette carries its own colours; the appearance flag must not reach into them.
        for isDark in [true, false] {
            XCTAssertEqual(rgba(Theme.resolve(themeId: "norton", isDark: isDark).colors.listBackground),
                           "0000aa@1.000")
        }
    }

    func testPaletteIdsAreUniqueAndDoNotShadowSystem() {
        let ids = Theme.palettes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count,
                       "duplicate palette id — Theme.palette(id:) would pick one arbitrarily")
        XCTAssertFalse(ids.contains("system"), "\"system\" is reserved for the no-palette default")
        for p in Theme.palettes { XCTAssertFalse(p.name.isEmpty, "palette \(p.id) has no display name") }
    }

    /// The `light`/`dark` palettes are the same data as the defaults, just pinnable explicitly.
    /// If they ever diverge, picking "Light" would not give you the light theme.
    func testNamedLightAndDarkPalettesMatchTheDefaults() {
        assertColors(values(of: Theme.palette(id: "light")!.colors), lightGolden, label: "palette light")
        assertColors(values(of: Theme.palette(id: "dark")!.colors), darkGolden, label: "palette dark")
        XCTAssertFalse(Theme.palette(id: "light")!.isDark)
        XCTAssertTrue(Theme.palette(id: "dark")!.isDark)
    }

    // MARK: - Norton Commander

    /// The point of the gimmick is that it reads as the real thing, which means the authentic CGA
    /// palette and nothing else. Pinned so a later "let's soften that blue" is a deliberate edit.
    func testNortonUsesTheAuthenticCGAPalette() {
        guard let nc = Theme.palette(id: "norton") else { return XCTFail("norton palette missing") }
        XCTAssertTrue(nc.isDark,
                      "NC must be dark-based, or system sheets and scrollers come up light against CGA blue")
        XCTAssertEqual(rgba(nc.colors.listBackground), "0000aa@1.000")
        XCTAssertEqual(rgba(nc.colors.windowBackground), "0000aa@1.000")
        XCTAssertEqual(rgba(nc.colors.listText), "00aaaa@1.000")
        XCTAssertEqual(rgba(nc.colors.selectedText), "ffff55@1.000")
        XCTAssertEqual(rgba(nc.colors.activeCursorFrame), "55ffff@1.000")
        XCTAssertEqual(rgba(nc.colors.statusBarBackground), "00aaaa@1.000")
        XCTAssertEqual(rgba(nc.colors.statusBarText), "000000@1.000")
    }

    /// No colour in a palette may be left at a semantic system default, or the user's accent
    /// bleeds through — an accent-blue cursor row on CGA blue is invisible. This is also the bug
    /// that `applying()` failing to carry the new fields would have produced.
    func testNortonOverridesEveryPanelDrawingColor() {
        guard let nc = Theme.palette(id: "norton") else { return XCTFail("norton palette missing") }
        XCTAssertNotEqual(nc.colors.activeCursorFrame, NSColor.controlAccentColor)
        XCTAssertNotEqual(nc.colors.selectionFillActive, NSColor.controlAccentColor.withAlphaComponent(0.22))
        XCTAssertNotEqual(nc.colors.driveBarHighlight, NSColor.controlAccentColor)
        XCTAssertNotEqual(nc.colors.driveBarText, NSColor.labelColor)
        XCTAssertNotEqual(nc.colors.headerSeparator, NSColor.separatorColor)
        XCTAssertNotEqual(nc.colors.driveBarBackground, NSColor.controlColor)
    }

    /// Cheap legibility check on the gimmick: text must not be drawn in its own background
    /// colour anywhere. Catches a copy-paste inside the palette, which is easy to miss when
    /// half the fields are the same cyan.
    func testNortonTextIsNeverItsOwnBackground() {
        guard let nc = Theme.palette(id: "norton") else { return XCTFail("norton palette missing") }
        let pairs: [(String, NSColor, NSColor)] = [
            ("list", nc.colors.listText, nc.colors.listBackground),
            ("statusBar", nc.colors.statusBarText, nc.colors.statusBarBackground),
            ("activePathBar", nc.colors.activePathBarText, nc.colors.activePathBarBackground),
            ("inactivePathBar", nc.colors.inactivePathBarText, nc.colors.inactivePathBarBackground),
            ("functionButton", nc.colors.functionButtonText, nc.colors.functionButtonBackground),
            ("driveBar", nc.colors.driveBarText, nc.colors.driveBarBackground),
            ("driveBarHighlight", nc.colors.driveBarHighlightText, nc.colors.driveBarHighlight),
        ]
        for (name, fg, bg) in pairs {
            XCTAssertNotEqual(rgba(fg), rgba(bg), "\(name): text and background are the same colour")
        }
    }

    /// The invariant that the shipped Norton palette violated: the cursor row is drawn as a
    /// filled bar while the cells keep their normal text colour, so a palette whose
    /// `selectionFillActive` is close to its `listText` renders an unreadable row unless it also
    /// sets `cursorRowText`. Checked for every palette, not just Norton, so the next one cannot
    /// repeat it.
    func testEveryPaletteKeepsTheCursorRowReadable() {
        for p in Theme.palettes {
            if p.colors.cursorRowText != nil { continue }   // it re-colours the text, fine
            let contrast = luminanceGap(p.colors.listText, over: p.colors.selectionFillActive,
                                        on: p.colors.listBackground)
            XCTAssertGreaterThan(contrast, 0.12,
                """
                palette "\(p.id)": the cursor bar (\(rgba(p.colors.selectionFillActive))) is too                 close to the row text (\(rgba(p.colors.listText))) — set cursorRowText, or pick a                 fill that leaves the text readable.
                """)
        }
    }

    /// Perceived-brightness gap between text and the bar it sits on. `selectionFillActive` may be
    /// translucent, so it is composited over the panel background first — comparing against the
    /// raw fill would call a 22%-alpha accent tint "different" when on screen it barely shifts.
    private func luminanceGap(_ text: NSColor, over fill: NSColor, on background: NSColor) -> CGFloat {
        func lum(_ c: NSColor) -> CGFloat {
            let s = c.usingColorSpace(.sRGB) ?? c
            return 0.299 * s.redComponent + 0.587 * s.greenComponent + 0.114 * s.blueComponent
        }
        let f = fill.usingColorSpace(.sRGB) ?? fill
        let a = f.alphaComponent
        let composited = lum(f) * a + lum(background) * (1 - a)
        return abs(lum(text) - composited)
    }

    // MARK: - Custom colours on top

    /// The four existing user overrides must keep winning over a palette — that is what the
    /// Settings note promises — and, the bug fixed alongside this work, setting one must not
    /// reset the palette's *other* colours to the macOS defaults.
    func testCustomColorsOverridePaletteWithoutResettingTheRest() {
        guard let nc = Theme.palette(id: "norton") else { return XCTFail("norton palette missing") }
        var custom = Theme.ColorOverride()
        custom.listText = NSColor(hexString: "#FF00FF")
        let applied = nc.colors.applying(custom)

        XCTAssertEqual(rgba(applied.listText), "ff00ff@1.000", "custom text colour must win")
        XCTAssertEqual(rgba(applied.listBackground), "0000aa@1.000", "palette background must survive")
        XCTAssertEqual(rgba(applied.activeCursorFrame), "55ffff@1.000",
                       "palette cursor colour must survive — this reverted to the macOS accent before")
        XCTAssertEqual(rgba(applied.driveBarBackground), rgba(nc.colors.driveBarBackground))
        XCTAssertEqual(rgba(applied.statusBarText), "000000@1.000")
    }

    func testEmptyOverrideChangesNothing() {
        assertColors(values(of: Theme.light.applying(Theme.ColorOverride())),
                     values(of: Theme.light), label: "Theme.light.applying(empty)")
    }

    // MARK: - Helper

    /// Compares only the keys present in `expected`, and reports every mismatch at once so a
    /// palette-wide accident is one readable failure instead of a bisect.
    private func assertColors(_ actual: [String: String], _ expected: [String: String],
                              label: String, file: StaticString = #filePath, line: UInt = #line) {
        var wrong: [String] = []
        for (key, want) in expected.sorted(by: { $0.key < $1.key }) {
            guard let got = actual[key] else { wrong.append("\(key): missing from values(of:)"); continue }
            if got != want { wrong.append("\(key): \(got) ≠ \(want)") }
        }
        XCTAssertTrue(wrong.isEmpty,
                      "\(label) changed. If that was intentional, update these expectations:\n  "
                      + wrong.joined(separator: "\n  "), file: file, line: line)
    }
}
