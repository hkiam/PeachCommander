// SPDX-License-Identifier: Apache-2.0
// ImageZoom.swift - The arithmetic behind "zoom in / out / 100% / fit", shared by the quick preview
// in the info sidebar and the viewer's image representation (F-389).
//
// Pure on purpose. Every question a zoom control has to answer — what fits, where the next stop is,
// what the level should say — is a calculation, and calculations belong somewhere they can be checked
// without a window on screen. The two call sites then only own the AppKit half: which scroll view.

import CoreGraphics
import Foundation

public enum ImageZoom {

    /// The stops "zoom in" and "zoom out" walk between.
    ///
    /// A ladder rather than a fixed factor, so repeated clicks land on numbers a person recognises —
    /// 50%, 100%, 200% — instead of 128% and 164%. The two ends are also the hard limits: below 5% a
    /// photograph is a dot, and above 1600% one pixel fills a fifth of the panel.
    public static let stops: [CGFloat] = [0.05, 0.1, 0.25, 0.33, 0.5, 0.66, 0.75,
                                          1, 1.5, 2, 3, 4, 6, 8, 12, 16]

    public static var minScale: CGFloat { stops.first! }
    public static var maxScale: CGFloat { stops.last! }

    /// Keep a scale inside the supported range.
    public static func clamped(_ scale: CGFloat) -> CGFloat {
        guard scale.isFinite, scale > 0 else { return 1 }
        return min(maxScale, max(minScale, scale))
    }

    /// The scale at which all of `image` is visible inside `viewport`.
    ///
    /// Unclamped by the ladder in one direction on purpose: a 12 000 px scan in a 300 pt sidebar needs
    /// 0.025, and refusing to go below a stop would cut it off rather than show it. Still clamped to the
    /// supported range, since a scale of zero is not a picture.
    public static func fitScale(image: CGSize, in viewport: CGSize) -> CGFloat {
        guard image.width > 0, image.height > 0,
              viewport.width > 0, viewport.height > 0 else { return 1 }
        return clamped(min(viewport.width / image.width, viewport.height / image.height))
    }

    /// The scale to open an image at: fitted when it is too big for the viewport, and 100% when it
    /// already fits.
    ///
    /// The second half is the part that is easy to get wrong and looks broken when it is: a 16×16 icon
    /// blown up to fill the panel is a mess of soft squares, and it is what "scale proportionally up or
    /// down" does by itself. Preview and Finder both leave a small image alone, so this does too.
    public static func initialScale(image: CGSize, in viewport: CGSize) -> CGFloat {
        min(1, fitScale(image: image, in: viewport))
    }

    /// The next stop above (or below) `scale`.
    ///
    /// Strictly above/below, with a whisker of tolerance: sitting *on* a stop must move to the next one
    /// rather than to itself, while a fit scale of 0.4999999 must not count as already being 0.5 and
    /// jump two stops. At the ends it returns the limit, so a held key stops instead of wrapping.
    public static func next(after scale: CGFloat, zoomingIn: Bool) -> CGFloat {
        let current = clamped(scale)
        let epsilon: CGFloat = 0.0001
        if zoomingIn {
            return stops.first { $0 > current + epsilon } ?? maxScale
        }
        return stops.last { $0 < current - epsilon } ?? minScale
    }

    /// The zoom level as a percentage, for a label next to the controls.
    ///
    /// Rounded to whole percent above 1:1 and to one decimal below 10%, because "0%" is what plain
    /// rounding says about a scan shown at 4 tenths of a percent — a number that reads as broken.
    public static func percentText(_ scale: CGFloat) -> String {
        let percent = Double(scale) * 100
        if percent < 10, percent.rounded() != percent {
            return String(format: "%.1f%%", percent)
        }
        return String(format: "%.0f%%", percent)
    }
}
