// SPDX-License-Identifier: Apache-2.0
// SurfaceColourAudit.swift - Finding surfaces the colour scheme did not reach (F-015).
//
// The folder tree was white under Midnight because a repaint existed that nobody called. What made
// that survive to a user was not the missing call — it was that of 59 regression scenarios, none
// looked at a colour. Screenshots were compared for *layout*, and a white column in a dark window is
// a perfectly well-laid-out white column.
//
// Enumerating every widget's expected colour would be a second copy of the theme, wrong the first
// time a palette changed. So this asks the two questions the defect actually violated, which need no
// per-widget table:
//
//   1. Is there a bright surface in a dark window? That is the reported symptom exactly.
//   2. Is any text too close in colour to what is directly behind it? That is "pale text", and it
//      also catches the opposite mistake — dark text a palette left on a dark surface.
//
// It is a *detector*, not an oracle: it reports what it found and the numbers behind it, and each
// finding is then judged. Some bright surfaces are meant to be bright.

#if DEBUG
import AppKit

/// A view that paints its own background in `draw` rather than through a layer or a control's
/// background colour, and can say what it painted.
///
/// Needed because the audit reads what is *on* a view, and a fill drawn with `NSBezierPath` leaves
/// nothing to read. A conformer returns the same value its `draw` uses — the same value, not a
/// second copy of the rule, or the audit will one day judge contrast against a colour the user
/// never sees.
protocol SelfPaintedBackground: NSView {
    var auditBackgroundFill: NSColor? { get }
}

enum SurfaceColourAudit {

    /// A surface worth looking at, with the numbers that made it worth looking at.
    struct Finding {
        let window: String
        /// Where in the view tree, as a class chain — enough to find it again without a pointer.
        let path: String
        /// "BRIGHT" (a light surface in a dark window) or "LOWCONTRAST" (text against its own back).
        let kind: String
        let detail: String

        var line: String { "\(window) \(kind) \(path) \(detail)" }
    }

    // MARK: - Colour arithmetic

    /// Shared with the theme, deliberately: see `ColourContrast`.
    static func luminance(_ color: NSColor) -> Double? { ColourContrast.luminance(color) }
    static func contrast(_ a: NSColor, _ b: NSColor) -> Double? { ColourContrast.ratio(a, b) }
    static func composite(_ over: NSColor, on base: NSColor) -> NSColor {
        ColourContrast.composite(over, on: base)
    }

    /// Text is called unreadable below this. WCAG asks 4.5 for body text; 3.0 is the large-text bar
    /// and the one used here, so the report is about text that is genuinely hard to read rather than
    /// about every label that could be a shade darker.
    static let contrastFloor = 3.0
    /// A window is dark when its list background is below this. Midnight is 0.01, Dark 0.03,
    /// Norton 0.03, Light 1.0 — nothing sits near the line, so no palette is a judgement call.
    static let darkCeiling = 0.35
    /// A surface brighter than this inside a dark window is the reported symptom.
    static let brightFloor = 0.5

    // MARK: - Reading a view's actual background

    /// What a view paints behind its content, or nil when it paints nothing and whatever is behind
    /// it shows through.
    ///
    /// Deliberately not `NSColor.windowBackgroundColor`-style guessing: the question is what is on
    /// screen, and a view that draws no background contributes none.
    static func background(of view: NSView) -> NSColor? {
        if let scroll = view as? NSScrollView, scroll.drawsBackground {
            return scroll.backgroundColor
        }
        if let table = view as? NSTableView, table.backgroundColor.alphaComponent > 0.9 {
            return table.backgroundColor
        }
        if let field = view as? NSTextField, field.drawsBackground {
            return field.backgroundColor
        }
        if let box = view as? NSBox, box.boxType == .custom {
            return box.fillColor.alphaComponent > 0.9 ? box.fillColor : nil
        }
        if let cg = view.layer?.backgroundColor, cg.alpha > 0.9 {
            return NSColor(cgColor: cg)
        }
        return nil
    }

    /// The colour actually behind `view` — including fills a view paints itself.
    ///
    /// The self-painted ones are usually translucent (a cursor tint over the panel background), so
    /// they are collected on the way up and composited onto the first opaque surface found. Reading
    /// only opaque backgrounds reported the panel colour for every cursor row, and then every
    /// contrast figure for those rows was against a colour no pixel actually has.
    static func effectiveBackground(behind view: NSView) -> NSColor? {
        var overlays: [NSColor] = []            // nearest first
        var node: NSView? = view
        while let current = node {
            if let drawn = (current as? SelfPaintedBackground)?.auditBackgroundFill {
                if drawn.alphaComponent > 0.999 {
                    return overlays.reversed().reduce(drawn) { composite($1, on: $0) }
                }
                overlays.append(drawn)
            }
            if let colour = background(of: current) {
                // Farthest first, so each overlay lands on what is already beneath it.
                return overlays.reversed().reduce(colour) { composite($1, on: $0) }
            }
            node = current.superview
        }
        return nil
    }

    // MARK: - The walk

    /// Views whose insides are not the theme's business.
    ///
    /// An image view is a picture and may be any colour; a button draws itself from the system's
    /// control appearance and keeps its title in an internal text field, which is how an earlier
    /// dump managed to count every button title twice. A visual-effect view has a material rather
    /// than a colour, so it reports nothing and its children are read against what is behind it.
    static func isOpaqueToTheAudit(_ view: NSView) -> Bool {
        view is NSImageView || view is NSButton || view is NSSlider || view is NSProgressIndicator
    }

    static func audit(window: NSWindow, label: String) -> [Finding] {
        guard let root = window.contentView else { return [] }
        var findings: [Finding] = []
        let dark = (luminance(Theme.current.listBackground) ?? 1) < darkCeiling

        func hex(_ c: NSColor) -> String {
            guard let rgb = c.usingColorSpace(.sRGB) else { return "?" }
            return String(format: "#%02X%02X%02X", Int(rgb.redComponent * 255),
                          Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
        }

        func walk(_ view: NSView, path: String) {
            // A hidden view is not on screen, and neither is a zero-sized or fully transparent one.
            // Reporting them would bury the findings that matter under scaffolding the user never
            // sees — and `alphaValue` is not a detail: AppKit keeps opaque-white helper views around
            // at zero alpha, which is a white surface that is not on screen.
            guard !view.isHidden, view.alphaValue > 0.05,
                  view.bounds.width > 1, view.bounds.height > 1 else { return }
            let here = path.isEmpty ? String(describing: type(of: view))
                                    : path + "/" + String(describing: type(of: view))

            if dark, let bg = background(of: view), let lum = luminance(bg), lum > brightFloor {
                // The frame in window coordinates, because "a white surface exists" and "a white
                // surface is somewhere the user looks" are different claims, and the second one is
                // the one worth acting on.
                let inWindow = view.convert(view.bounds, to: nil)
                findings.append(Finding(window: label, path: here, kind: "BRIGHT",
                                        detail: "bg=\(hex(bg)) luminance=\(String(format: "%.2f", lum)) "
                                              + "alpha=\(String(format: "%.2f", view.alphaValue)) "
                                              + "frame=\(Int(inWindow.origin.x)),\(Int(inWindow.origin.y)) "
                                              + "\(Int(inWindow.width))x\(Int(inWindow.height))"))
            }
            if let field = view as? NSTextField, !field.stringValue.isEmpty,
               let text = field.textColor, let behind = effectiveBackground(behind: field),
               let ratio = contrast(text, behind), ratio < contrastFloor {
                findings.append(Finding(window: label, path: here, kind: "LOWCONTRAST",
                                        detail: "text=\(hex(text)) on=\(hex(behind)) "
                                              + "ratio=\(String(format: "%.1f", ratio))"))
            }

            guard !isOpaqueToTheAudit(view) else { return }
            for child in view.subviews { walk(child, path: here) }
        }

        // Resolve dynamic colours — `labelColor` and friends — the way this window will draw them.
        // Without this they resolve against whatever appearance happens to be current, which for a
        // window following the OS is not necessarily the window's own.
        window.effectiveAppearance.performAsCurrentDrawingAppearance {
            walk(root, path: "")
        }
        return findings
    }
}
#endif
