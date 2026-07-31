// SPDX-License-Identifier: Apache-2.0
// PluginThemeTests.swift — the plugin side of the theme bridge (F-338).
//
// Plugins/SDK/PluginTheme.swift is compiled *into* each plugin, so nothing in the host's build
// exercises it: a mistake there ships silently and only shows up as a plugin drawing the wrong
// colours. This target compiles it against a fake PcHostServices table, which tests the half of
// the bridge the host cannot otherwise reach — including the fallbacks, which are the promise that
// a plugin using the helper against an older host looks exactly as it does today.

import AppKit
import CContrib
import XCTest

/// Values the fake host answers. Global because a `@convention(c)` function cannot capture.
private nonisolated(unsafe) var fakeContext: [String: String] = [:]
/// Keys the fake host was asked for, so a test can assert the helper really queries the host.
private nonisolated(unsafe) var fakeQueriedKeys: [String] = []

private func fakeGetContext(_ host: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                            _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let key, let out else { return 0 }
    let k = String(cString: key)
    fakeQueriedKeys.append(k)
    guard let v = fakeContext[k] else { return 0 }
    _ = strlcpy(out, v, Int(maxlen))
    return 1
}

final class PluginThemeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        fakeContext = [:]
        fakeQueriedKeys = []
    }

    private func services() -> PcHostServices {
        var s = PcHostServices()
        s.getContext = fakeGetContext
        return s
    }

    /// Feed the helper exactly what the host emits for a palette — no hand-written fixtures, so the
    /// two halves of the bridge are tested against each other rather than against my assumptions.
    private func theme(for colors: Theme.Colors, isDark: Bool, id: String) -> PluginTheme {
        fakeContext = Theme.pluginContextValues(colors: colors, isDark: isDark, themeId: id)
        return PluginTheme(services())
    }

    // MARK: - Reading the host

    func testReadsTheHostPalette() {
        let t = theme(for: Theme.norton, isDark: true, id: "norton")
        XCTAssertTrue(t.hostSuppliesTheme)
        XCTAssertEqual(t.id, "norton")
        XCTAssertTrue(t.isDark)
        XCTAssertEqual(Theme.pluginHex(t.background), "#0000AA")
        XCTAssertEqual(Theme.pluginHex(t.text), "#00AAAA")
        XCTAssertEqual(Theme.pluginHex(t.accent), "#55FFFF")
        XCTAssertEqual(Theme.pluginHex(t.selectionText), "#000000")
        XCTAssertEqual(Theme.pluginHex(t.controlText), "#000000")
    }

    func testEveryPaletteRoundTripsThroughTheBridge() {
        for p in Theme.palettes {
            let t = theme(for: p.colors, isDark: p.isDark, id: p.id)
            XCTAssertEqual(t.id, p.id)
            XCTAssertEqual(t.isDark, p.isDark, "palette \(p.id): isDark lost in transit")
            XCTAssertEqual(Theme.pluginHex(t.background), Theme.pluginHex(p.colors.listBackground),
                           "palette \(p.id): background lost in transit")
            XCTAssertEqual(Theme.pluginHex(t.text), Theme.pluginHex(p.colors.listText),
                           "palette \(p.id): text lost in transit")
        }
    }

    /// Translucent colours must survive: `selectionFillActive` is 22% alpha in the default themes,
    /// and a plugin drawing it at full opacity would paint over its own content.
    func testTranslucentColorsKeepTheirAlpha() {
        let t = theme(for: Theme.light, isDark: false, id: "light")
        let sel = t.selectionBackground.usingColorSpace(.sRGB)!
        XCTAssertEqual(sel.alphaComponent, 0.22, accuracy: 0.01)
    }

    // MARK: - Fallbacks (the compatibility promise)

    /// A host that predates the theme keys answers nothing. Every colour must then be the system
    /// colour the plugins used before — that is what makes adopting the helper visually neutral.
    func testAnOlderHostYieldsExactlyTheSystemColors() {
        fakeContext = [:]
        let t = PluginTheme(services())
        XCTAssertFalse(t.hostSuppliesTheme, "no theme.id means the host does not support themes")
        XCTAssertEqual(t.id, "system")
        XCTAssertEqual(t.background, .textBackgroundColor)
        XCTAssertEqual(t.windowBackground, .windowBackgroundColor)
        XCTAssertEqual(t.text, .labelColor)
        XCTAssertEqual(t.secondaryText, .secondaryLabelColor)
        XCTAssertEqual(t.accent, .controlAccentColor)
        XCTAssertEqual(t.separator, .separatorColor)
        XCTAssertEqual(t.selectionBackground, .selectedContentBackgroundColor)
        XCTAssertEqual(t.controlBackground, .controlColor)
        XCTAssertEqual(t.controlText, .labelColor)
    }

    /// No services at all — the state a view is in before the host binds it. Must not crash and must
    /// give the same system colours.
    func testNoServicesIsSafe() {
        XCTAssertEqual(PluginTheme.systemFallback.text, .labelColor)
        XCTAssertEqual(PluginTheme(nil as UnsafePointer<PcHostServices>?).background, .textBackgroundColor)
        var empty = PcHostServices()      // a table with no getContext at all
        empty.getContext = nil
        XCTAssertEqual(PluginTheme(empty).text, .labelColor)
    }

    /// A host that answers *some* keys — a newer plugin against an older host, or a palette missing
    /// a colour — must mix cleanly rather than failing wholesale.
    func testPartialAnswersFallBackPerKey() {
        fakeContext = ["theme.id": "half", "theme.text": "#123456"]
        let t = PluginTheme(services())
        XCTAssertEqual(Theme.pluginHex(t.text), "#123456", "the answered key must be used")
        XCTAssertEqual(t.background, .textBackgroundColor, "the unanswered key must fall back")
    }

    /// Garbage in a value must not become a wrong colour. A plugin keeping its own default is the
    /// only safe response — a mis-parsed hex could be black text on black.
    func testMalformedValuesFallBackRatherThanMisparse() {
        for bad in ["", "blue", "#12", "#GGGGGG", "0x00FF00", "rgb(1,2,3)"] {
            fakeContext = ["theme.id": "x", "theme.text": bad]
            XCTAssertEqual(PluginTheme(services()).text, .labelColor,
                           "\(bad.debugDescription) must fall back, not parse into something")
        }
    }

    /// A truncating host (a small buffer, a long value) must not yield a half-parsed colour. The
    /// helper's buffer is 128 bytes and every value is at most 9, so this is headroom, not a limit —
    /// but a silently truncated "#0000AA" → "#0000A" must still fall back.
    func testTruncatedValueFallsBack() {
        fakeContext = ["theme.id": "x", "theme.text": "#0000A"]
        XCTAssertEqual(PluginTheme(services()).text, .labelColor)
    }

    // MARK: - Raw colours

    func testHostColorReadsRawPaletteNamesAndFallsBack() {
        let t = theme(for: Theme.norton, isDark: true, id: "norton")
        XCTAssertEqual(Theme.pluginHex(t.hostColor("statusBarBackground", fallback: .black)), "#00AAAA")
        XCTAssertEqual(t.hostColor("noSuchColour", fallback: .magenta), .magenta,
                       "an unknown name must give the caller's fallback")
    }

    /// `hostColor` after init proves the helper kept a usable services copy — the bug that a stored
    /// pointer left unset would otherwise hide behind the fallback and look like "no theme".
    func testHostColorWorksAfterInitNotOnlyDuringIt() {
        let t = theme(for: Theme.norton, isDark: true, id: "norton")
        fakeQueriedKeys = []
        _ = t.hostColor("listBackground", fallback: .black)
        XCTAssertTrue(fakeQueriedKeys.contains("theme.color.listBackground"),
                      "hostColor did not reach the host — the services copy was lost")
    }

    // MARK: - Legibility of what a plugin is handed

    /// A plugin drawing `text` on `background` must be able to see it. This is the pairing the
    /// helper hands out, so it is the helper's problem, not only the palette's.
    func testTextIsLegibleOnBackgroundForEveryPalette() {
        for p in Theme.palettes {
            let t = theme(for: p.colors, isDark: p.isDark, id: p.id)
            func lum(_ c: NSColor) -> CGFloat {
                let s = c.usingColorSpace(.sRGB) ?? c
                return 0.299 * s.redComponent + 0.587 * s.greenComponent + 0.114 * s.blueComponent
            }
            XCTAssertGreaterThan(abs(lum(t.text) - lum(t.background)), 0.2,
                                 "palette \"\(p.id)\": theme.text on theme.background is not readable")
        }
    }
}
