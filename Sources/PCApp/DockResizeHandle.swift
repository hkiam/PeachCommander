// SPDX-License-Identifier: Apache-2.0
// DockResizeHandle.swift - Drag the bottom dock taller or shorter (F-381).
//
// `PreviewResizeHandle` rotated through ninety degrees, and for the same reason: the dock is not in
// the split view, so an `NSSplitView` divider would mean putting it there and changing what every
// existing constraint on that split view means. A thin strip with a `mouseDown` is the smaller change.
//
// The one thing that is not a rotation is which way the drag runs. AppKit's window coordinates grow
// *upward* and the dock sits *below* this strip, so dragging up (a rising y) makes the dock taller —
// the opposite sign from the preview handle, where the panel lies to the right of the strip and
// dragging left widens it.

import AppKit
import PCFoundation

final class DockResizeHandle: NSView {
    static let height: CGFloat = 6

    /// Reports the height the dock should have while dragging, already clamped.
    var onResize: ((CGFloat) -> Void)?
    /// Called once when the drag ends, so the owner can persist the final height rather than
    /// writing the config on every mouse-moved event.
    var onResizeFinished: ((CGFloat) -> Void)?
    /// The dock's current height, set by the owner; the drag starts from this.
    var dockHeight: CGFloat = 0

    private var dragStartY: CGFloat = 0
    private var dragStartHeight: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        toolTip = String(localized: "Drag to resize the dock")
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = event.locationInWindow.y
        dragStartHeight = dockHeight
    }

    override func mouseDragged(with event: NSEvent) {
        // Window coordinates grow upward and the dock is below this strip, so a rising y grows it.
        let dy = event.locationInWindow.y - dragStartY
        onResize?(clamp(dragStartHeight + dy))
    }

    override func mouseUp(with event: NSEvent) {
        onResizeFinished?(clamp(dockHeight))
    }

    /// Keep the dock between a usable minimum and roughly two thirds of the window, so a careless
    /// drag cannot leave the file panels as a sliver.
    private func clamp(_ height: CGFloat) -> CGFloat {
        let maximum = max(BottomDockView.minHeight, (window?.frame.height ?? 800) * 0.66)
        return min(max(height, BottomDockView.minHeight), maximum)
    }

    // MARK: - Accessibility

    /// A splitter, with the dock's height as its value — the preview handle's argument applies here
    /// unchanged: six points of plain view with a `mouseDown` is nothing at all to VoiceOver, which
    /// would make the dock's height mouse-only.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .splitter }
    override func accessibilityLabel() -> String? { String(localized: "Dock height") }
    override func accessibilityValue() -> Any? { Int(dockHeight) }

    /// One press of an arrow, in points. Big enough to be worth doing, small enough to aim with.
    private static let accessibilityStep: CGFloat = 20

    override func accessibilityPerformIncrement() -> Bool {
        apply(clamp(dockHeight + Self.accessibilityStep))
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        apply(clamp(dockHeight - Self.accessibilityStep))
        return true
    }

    private func apply(_ height: CGFloat) {
        onResize?(height)
        onResizeFinished?(height)
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.columnSeparator.cgColor
    }
}
