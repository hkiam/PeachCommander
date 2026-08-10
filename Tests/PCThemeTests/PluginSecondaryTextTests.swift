// SPDX-License-Identifier: Apache-2.0
// PluginSecondaryTextTests.swift - The quiet label colour handed to plugins is readable (F-015).
//
// It used to be taken from `pathBarFreeSpaceText`, a colour each palette defines against its *path
// bar*. Norton's is black, which is right on that palette's cyan path bar and unreadable on its blue
// panels — where the plugins draw. The terminal's status line shipped black on blue because of it.
//
// A palette is data, so this is the cheap place to catch the next one: a golden test over every
// shipped palette, no window and no screenshot needed.

import XCTest
import AppKit

final class PluginSecondaryTextTests: XCTestCase {

    /// WCAG's large-text threshold. The derivation aims at 4.0, so a palette landing exactly on the
    /// line is a bug in the derivation rather than a rounding accident.
    private let floor = 3.0

    func testEveryPaletteGivesPluginsAReadableSecondaryLabel() throws {
        for palette in Theme.palettes {
            let values = Theme.pluginContextValues(colors: palette.colors,
                                                   isDark: palette.isDark, themeId: palette.id)
            let secondary = try XCTUnwrap(NSColor(pcHexString: try XCTUnwrap(values["theme.secondaryText"])),
                                          palette.id)
            let background = try XCTUnwrap(NSColor(pcHexString: try XCTUnwrap(values["theme.background"])),
                                           palette.id)
            let ratio = try XCTUnwrap(ColourContrast.ratio(secondary, background), palette.id)
            XCTAssertGreaterThanOrEqual(ratio, floor,
                                        "\(palette.id): secondary label at \(String(format: "%.1f", ratio)):1")
        }
    }

    func testItStaysQuieterThanThePlainTextWhereThePaletteHasRoom() {
        // The point of a secondary colour is to recede. Light has an enormous contrast budget, so if
        // the derivation ever stopped dimming at all this would still pass the readability test
        // above while being visually wrong.
        let light = Theme.palettes.first { $0.id == "light" }!
        let quiet = ColourContrast.quietened(light.colors.listText, on: light.colors.listBackground)
        let plain = ColourContrast.ratio(light.colors.listText, light.colors.listBackground)!
        let dimmed = ColourContrast.ratio(quiet, light.colors.listBackground)!
        XCTAssertLessThan(dimmed, plain)
    }

    func testAPaletteWithNoRoomKeepsItsPlainTextRatherThanBecomingUnreadable() {
        // Cyan on blue has almost no budget. Dimming by a fixed amount lands at 2.4:1 there, which is
        // the defect this replaced; the rule is "as quiet as the floor allows, and no quieter".
        let onlyRoomForItself = ColourContrast.quietened(NSColor(srgbRed: 0, green: 0.667, blue: 0.667, alpha: 1),
                                                         on: NSColor(srgbRed: 0, green: 0, blue: 0.667, alpha: 1))
        let ratio = ColourContrast.ratio(onlyRoomForItself,
                                         NSColor(srgbRed: 0, green: 0, blue: 0.667, alpha: 1))!
        XCTAssertGreaterThanOrEqual(ratio, floor)
    }
}
