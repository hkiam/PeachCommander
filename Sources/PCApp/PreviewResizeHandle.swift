// SPDX-License-Identifier: Apache-2.0
// PreviewResizeHandle.swift - Drag the side panel wider or narrower (F-344).
//
// The panel's width used to be a constant. This is the thin strip along its left edge that turns
// that constant into something the user owns: press and drag, and the panel follows the mouse.
//
// A plain view rather than an NSSplitView divider, because the panel is not in the split view —
// the two file panels are, and putting the preview in there as well would make every existing
// constraint on the split view mean something different.

import AppKit
import PCFoundation

final class PreviewResizeHandle: NSView {
    static let width: CGFloat = 6

    /// Reports the width the panel should have while dragging, already clamped.
    var onResize: ((CGFloat) -> Void)?
    /// Called once when the drag ends, so the owner can persist the final width rather than
    /// writing the config on every mouse-moved event.
    var onResizeFinished: ((CGFloat) -> Void)?
    /// The panel's current width, set by the owner; the drag starts from this.
    var panelWidth: CGFloat = 0

    /// Bounds for the result. The minimum keeps the details column readable; the maximum is
    /// applied against the window so the panel can never swallow the file panels entirely.
    static let minWidth: CGFloat = 180
    private var dragStartX: CGFloat = 0
    private var dragStartWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = String(localized: "Drag to resize the preview panel")
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// A resize cursor over the whole strip, so the affordance is visible before the first drag.
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartX = convert(event.locationInWindow, from: nil).x
        dragStartWidth = panelWidth
    }

    override func mouseDragged(with event: NSEvent) {
        // The panel lies to the *right* of this strip, so dragging left (negative dx) widens it.
        let dx = convert(event.locationInWindow, from: nil).x - dragStartX
        onResize?(clamp(dragStartWidth - dx))
    }

    override func mouseUp(with event: NSEvent) {
        onResizeFinished?(clamp(panelWidth))
    }

    /// Keep the panel between a readable minimum and roughly two thirds of the window, so a
    /// careless drag cannot leave the file panels as slivers.
    private func clamp(_ width: CGFloat) -> CGFloat {
        let maximum = max(Self.minWidth, (window?.frame.width ?? 1200) * 0.66)
        return min(max(width, Self.minWidth), maximum)
    }

    // MARK: - Accessibility (I19 T06)

    /// A splitter, with the panel's width as its value.
    ///
    /// Six points of plain view with a `mouseDown`: to VoiceOver it was nothing at all, so the panel's
    /// width was mouse-only. As a splitter it can be found, read and adjusted — the increment and
    /// decrement actions move it by the same step the keyboard would, and they clamp exactly as a drag
    /// does, so there is one rule for how wide the panel may get.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .splitter }
    override func accessibilityLabel() -> String? { String(localized: "Preview panel width") }
    override func accessibilityValue() -> Any? { Int(panelWidth) }

    /// One press of an arrow, in points. Big enough to be worth doing, small enough to aim with.
    private static let accessibilityStep: CGFloat = 20

    override func accessibilityPerformIncrement() -> Bool {
        apply(clamp(panelWidth + Self.accessibilityStep))
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        apply(clamp(panelWidth - Self.accessibilityStep))
        return true
    }

    /// Report a new width and persist it, as the end of a drag does.
    private func apply(_ width: CGFloat) {
        onResize?(width)
        onResizeFinished?(width)
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.columnSeparator.cgColor
    }
}
