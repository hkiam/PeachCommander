// SPDX-License-Identifier: Apache-2.0
// WorkspaceTint.swift - The nine colours a workspace chip can wear (F-499).
//
// A workspace stores an **index**, never a hex value, and this is the file that turns one into a
// colour. Three things fall out of that decision, and the third is the one that decided it:
//
//   * A chip stays readable in every shipped palette, including the Norton Commander one, because the
//     fill is composited onto *this* theme's bar rather than painted over it.
//   * The contrast audit (`surface-colours`) passes by construction rather than by luck, because the
//     label colour is chosen by measuring rather than by being written down.
//   * A `.pcworkspace` sent to somebody else looks right on their machine. A stored hex would arrive
//     tuned for the sender's theme and be illegible on the recipient's.
//
// The hues are deliberately ordinary — the point of a chip colour is to be told apart at a glance and
// remembered, not to be pretty. They are also the *only* thing distinguishing workspaces once the bar
// has to shrink its chips down to swatches, which is why there are nine rather than five.

import AppKit
import PCFoundation

@MainActor
enum WorkspaceTint {

    /// Kept in step with `WorkspaceMigration.tintCount`, which deals them out during migration.
    static var count: Int { WorkspaceMigration.tintCount }

    /// Base hues, in the order a new workspace is dealt them.
    private static let hues: [NSColor] = [
        NSColor(srgbRed: 0.85, green: 0.28, blue: 0.24, alpha: 1),   // red
        NSColor(srgbRed: 0.90, green: 0.55, blue: 0.15, alpha: 1),   // orange
        NSColor(srgbRed: 0.85, green: 0.74, blue: 0.16, alpha: 1),   // yellow
        NSColor(srgbRed: 0.35, green: 0.68, blue: 0.33, alpha: 1),   // green
        NSColor(srgbRed: 0.24, green: 0.68, blue: 0.66, alpha: 1),   // teal
        NSColor(srgbRed: 0.24, green: 0.52, blue: 0.85, alpha: 1),   // blue
        NSColor(srgbRed: 0.36, green: 0.36, blue: 0.78, alpha: 1),   // indigo
        NSColor(srgbRed: 0.61, green: 0.35, blue: 0.75, alpha: 1),   // purple
        NSColor(srgbRed: 0.50, green: 0.52, blue: 0.56, alpha: 1),   // grey
    ]

    /// Names, for the colour submenu and for what a screen reader announces.
    static let names: [String] = [
        String(localized: "Red"), String(localized: "Orange"), String(localized: "Yellow"),
        String(localized: "Green"), String(localized: "Teal"), String(localized: "Blue"),
        String(localized: "Indigo"), String(localized: "Purple"), String(localized: "Grey"),
    ]

    static func name(_ index: Int) -> String { names[wrap(index)] }

    /// The full-strength hue, used for the cap on the leading edge of every chip.
    ///
    /// The cap keeps full strength even on an inactive chip, because it is the identity: when the bar
    /// runs out of room and the names go, the cap is all that is left.
    static func hue(_ index: Int) -> NSColor { hues[wrap(index)] }

    /// The chip's fill, sitting *in* the current palette rather than on top of it.
    static func fill(_ index: Int, active: Bool, on background: NSColor) -> NSColor {
        let base = hue(index)
        // An inactive chip is a hint, not a statement: most of the bar is inactive chips, and nine
        // saturated blocks would turn a navigation aid into a warning light.
        return ColourContrast.composite(base.withAlphaComponent(active ? 0.92 : 0.20), on: background)
    }

    /// Whichever of the theme's two label colours can actually be read on that fill.
    ///
    /// Measured rather than assumed. A fixed "white on active, black on inactive" is right for about
    /// six of the nine hues and wrong for yellow in every palette — and being wrong here means a chip
    /// whose name cannot be read, which is the one job it has.
    static func textColor(on fill: NSColor, theme: Theme.Colors) -> NSColor {
        let candidates = [theme.tabBarActiveChipText, theme.tabBarChipText,
                          NSColor.white, NSColor.black]
        var best = candidates[0]
        var bestRatio = 0.0
        for candidate in candidates {
            let ratio = ColourContrast.ratio(candidate, fill) ?? 0
            if ratio >= 4.5 { return candidate }         // good enough; prefer the theme's own
            if ratio > bestRatio { bestRatio = ratio; best = candidate }
        }
        return best
    }

    private static func wrap(_ index: Int) -> Int {
        ((index % count) + count) % count
    }
}
