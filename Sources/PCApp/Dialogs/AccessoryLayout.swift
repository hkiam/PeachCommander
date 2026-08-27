// SPDX-License-Identifier: Apache-2.0
// AccessoryLayout.swift — giving an NSAlert accessory view a size it will actually get (F-478).
//
// **NSAlert sizes an accessory view by its `frame`, not by its constraints.** Measured, from a
// screenshot: a scroll view of checkboxes with width and height *constraints* and no frame came out
// as a 230-point-wide alert with the list missing entirely and the name field printed on top of the
// informative text. Nothing was logged and no constraint conflicted — the layout was satisfiable and
// simply wrong, which is the class of defect a conflict count cannot catch (CONVENTIONS.md).
//
// So: turn autoresizing back on for the view the alert receives, and hand it a frame. Anything inside
// it stays constraint-driven; only the outermost view needs the frame.

import AppKit

enum AccessoryLayout {

    /// `view` wrapped as an NSAlert accessory of exactly this size.
    static func sized(_ view: NSView, width: CGFloat, height: CGFloat) -> NSView {
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = NSRect(x: 0, y: 0, width: width, height: height)
        return view
    }

    /// A clip view whose origin is the top-left, so a document view starts where the reader looks.
    ///
    /// AppKit's clip view is not flipped, so a stack of rows placed in one sits at the *bottom* of the
    /// scrollable area and the view opens scrolled past it. Measured from a screenshot: the scroller
    /// appeared, proving the content had height, and the list itself was nowhere on screen.
    private final class TopLeftClipView: NSClipView {
        override var isFlipped: Bool { true }
    }

    /// `views` stacked in a scroll view of exactly `width`, at most `maxHeight` tall.
    ///
    /// The stack gets a *frame*, not just constraints: as a scroll view's document view its size is what
    /// decides whether there is anything to scroll, and a constraint-only stack reports zero until
    /// something forces a layout pass.
    static func scrollingList(_ views: [NSView], width: CGFloat, rowHeight: CGFloat = 22,
                              maxHeight: CGFloat) -> NSScrollView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = true
        stack.layoutSubtreeIfNeeded()
        let contentHeight = max(stack.fittingSize.height, CGFloat(views.count) * rowHeight)
        stack.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)

        let scroll = NSScrollView()
        scroll.contentView = TopLeftClipView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .bezelBorder
        scroll.documentView = stack
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalToConstant: width),
            scroll.heightAnchor.constraint(equalToConstant: min(contentHeight + 8, maxHeight)),
        ])
        return scroll
    }

    /// A vertical stack as an accessory, sized to what it actually needs.
    ///
    /// `fittingSize` is read after a forced layout pass: before one, a stack view built in code reports
    /// zero, which is how a control ends up clipped to its title's first few words.
    static func stack(_ views: [NSView], width: CGFloat, spacing: CGFloat = 10) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
        stack.layoutSubtreeIfNeeded()
        return sized(stack, width: width, height: max(stack.fittingSize.height, 40))
    }
}
