// SPDX-License-Identifier: Apache-2.0
// WindowScreenFit.swift - What to do with a window when the screens change.
//
// macOS does not resize windows for you when a display changes mode or goes away. Measured on a
// real machine: an external display went from 2560×1320 to 2560×1080 while the app was running, the
// main window stayed 1320 points tall, and its bottom 270 points — the status bar, the function-key
// row and the command line — sat below the edge of the screen with no way to reach them.
//
// The decision is here, as a function over three rectangles, because the interesting half cannot be
// tested any other way: "the monitor is plugged back in" needs a second screen configuration, and a
// test machine has one screen. Driving it through the app can only ever exercise the shrinking half
// (`screenclamp` in the automation runner does exactly that, end to end); this covers both.

import CoreGraphics

public enum WindowScreenFit {

    public enum Action: Equatable {
        /// The window fits. Touch nothing — the notification also fires for a Dock resize or a
        /// menu-bar change, and a window that is fine must not be nudged on either.
        case leaveAlone
        /// Shrink and move it into the visible frame, and remember what it was.
        case clamp(CGRect)
        /// There is room again: put back what the user had before the screen shrank.
        case restore(CGRect)
    }

    /// - Parameters:
    ///   - frame: where the window is now.
    ///   - remembered: the frame it had before an earlier clamp, if any.
    ///   - visible: the screen's visible frame (menu bar and Dock already excluded).
    public static func decide(frame: CGRect, remembered: CGRect?, visible: CGRect) -> Action {
        guard visible.width > 0, visible.height > 0 else { return .leaveAlone }
        // Room for what the user chose? That comes first: it is the case that gives the layout back
        // after a monitor is reattached, and it must win even though the current frame also fits.
        if let remembered, visible.contains(remembered) { return .restore(remembered) }
        if visible.contains(frame) { return .leaveAlone }
        return .clamp(clamped(frame, into: visible))
    }

    /// `frame` shrunk to fit `visible` and moved inside it, keeping its top-left corner as close to
    /// where it was as the screen allows.
    public static func clamped(_ frame: CGRect, into visible: CGRect) -> CGRect {
        var f = frame
        f.size.width = min(f.width, visible.width)
        f.size.height = min(f.height, visible.height)
        f.origin.x = min(max(f.minX, visible.minX), visible.maxX - f.width)
        f.origin.y = min(max(f.minY, visible.minY), visible.maxY - f.height)
        return f
    }
}
