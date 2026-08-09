// SPDX-License-Identifier: Apache-2.0
// SplitDividerHit.swift - Was that click on the divider? (F-001)
//
// Total Commander recentres the two panels when the splitter is double-clicked. The row said so and
// nothing did it: the window used an NSSplitView directly, with no subclass and no click handling
// anywhere near it, and the one function that centres the divider was reached only when the panel
// arrangement changed or when a launch found no saved width.
//
// AppKit offers no "is this point on the divider" question, so it is answered here, from the two
// panes' frames — and here rather than in the view, because it is arithmetic about rectangles and
// gets the interesting cases wrong quietly: a click one point past the edge, a divider on the other
// axis, a pane dragged fully closed.

import Foundation

public enum SplitDividerHit {

    /// Is `point` (in the split view's own coordinates) on the divider between `first` and `second`?
    ///
    /// The gap between the two panes *is* the divider, so it is measured rather than assumed to be
    /// `dividerThickness` wide: a split view with a collapsed pane, or one mid-animation, has the two
    /// frames wherever it has them. `slop` widens the target, because a divider is a few points wide
    /// and hitting it exactly with a double-click is not something to ask of anybody.
    public static func isOnDivider(_ point: CGPoint, first: CGRect, second: CGRect,
                                   isVertical: Bool, slop: CGFloat = 2) -> Bool {
        if isVertical {
            // "Vertical" in AppKit means the divider is vertical: the panes sit side by side.
            let low = min(first.maxX, second.maxX)
            let high = max(first.minX, second.minX)
            guard high >= low else { return false }
            return point.x >= low - slop && point.x <= high + slop
        } else {
            let low = min(first.maxY, second.maxY)
            let high = max(first.minY, second.minY)
            guard high >= low else { return false }
            return point.y >= low - slop && point.y <= high + slop
        }
    }

    /// Where the divider goes to put the two panes at equal size.
    ///
    /// `span` is the split view's length along the divided axis. The thickness is taken off first, so
    /// the two panes come out equal rather than the *left* one getting half of everything and the right
    /// one what is left after the divider.
    public static func centeredPosition(span: CGFloat, dividerThickness: CGFloat) -> CGFloat {
        max(0, (span - dividerThickness) / 2)
    }
}
