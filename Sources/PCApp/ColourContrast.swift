// SPDX-License-Identifier: Apache-2.0
// ColourContrast.swift - Readability arithmetic, shared by the theme and the surface audit (F-015).
//
// Both the product and its measurement need to answer "can this be read on that". Two copies would
// disagree eventually, and the disagreement would show up as a check that passes while the screen is
// wrong — which is the exact shape of the defect this whole area exists to catch.

import AppKit

enum ColourContrast {

    /// Relative luminance, WCAG's definition. Nil when the colour has no single sRGB value —
    /// pattern fills, mainly.
    static func luminance(_ color: NSColor) -> Double? {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        func channel(_ v: CGFloat) -> Double {
            let d = Double(v)
            return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.redComponent)
             + 0.7152 * channel(c.greenComponent)
             + 0.0722 * channel(c.blueComponent)
    }

    /// WCAG contrast ratio: 1 for two identical colours, 21 for black on white.
    static func ratio(_ a: NSColor, _ b: NSColor) -> Double? {
        guard let la = luminance(a), let lb = luminance(b) else { return nil }
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// `over` laid on `base`, honouring the top colour's alpha — what filling a rect actually does.
    static func composite(_ over: NSColor, on base: NSColor) -> NSColor {
        guard let top = over.usingColorSpace(.sRGB), let bottom = base.usingColorSpace(.sRGB) else {
            return over
        }
        let a = top.alphaComponent
        func mix(_ t: CGFloat, _ b: CGFloat) -> CGFloat { t * a + b * (1 - a) }
        return NSColor(srgbRed: mix(top.redComponent, bottom.redComponent),
                       green: mix(top.greenComponent, bottom.greenComponent),
                       blue: mix(top.blueComponent, bottom.blueComponent),
                       alpha: 1)
    }

    /// A quieter version of `text` on `background` — dimmed towards the background, but never so far
    /// that it stops being readable.
    ///
    /// Secondary labels want to recede. How far they *can* recede depends on the palette: Light has
    /// black on white and an enormous budget, Norton has cyan on blue and almost none. A fixed
    /// dimming factor therefore either wastes the budget or spends one the palette does not have —
    /// 35% towards the background reads nicely everywhere except Norton, where it lands at a ratio
    /// of 2.4 and is exactly the unreadable text this is meant to prevent.
    ///
    /// So: dim as far as the floor allows, and no further. A palette with no room gets its plain
    /// text colour back, which is the right answer — a secondary label that cannot be quiet is
    /// better loud than invisible.
    static func quietened(_ text: NSColor, on background: NSColor, floor: Double = 4.0) -> NSColor {
        for amount in stride(from: 0.35, through: 0.05, by: -0.05) {
            let candidate = composite(text.withAlphaComponent(CGFloat(1 - amount)), on: background)
            if let r = ratio(candidate, background), r >= floor { return candidate }
        }
        return text
    }
}
