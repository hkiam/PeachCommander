// SPDX-License-Identifier: Apache-2.0
// PanelSplitView.swift - The dual-pane split view, which recentres on a double-click (F-001).
//
// AppKit's NSSplitView has no notion of a double-click on the divider, and the window used one
// directly — so "double-click = 50%", which the feature row promised, did not exist. The arithmetic
// (was that point on the divider, and where does the divider go for two equal panes) lives in
// PCFoundation.SplitDividerHit, where it can be checked without a window.

import AppKit
import PCFoundation

final class PanelSplitView: NSSplitView {
    /// Called when the divider is double-clicked.
    var onDividerDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, subviews.count >= 2,
           SplitDividerHit.isOnDivider(convert(event.locationInWindow, from: nil),
                                       first: subviews[0].frame, second: subviews[1].frame,
                                       isVertical: isVertical) {
            onDividerDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }
}
