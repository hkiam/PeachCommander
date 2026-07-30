// SPDX-License-Identifier: Apache-2.0
// TabBarView.swift - Per-panel tab bar view for Peach Commander (SPEC iteration I06 T01).
//
// Displays the set of open tabs for a single panel as a horizontal row of
// "chips", plus a trailing "+" button to open a new tab. Like the path bar,
// the whole bar is custom-drawn in `draw(_:)` (no layer-backed NSButton
// subviews, which failed to render inside the split view) and hit tests
// clicks against the chip rects it laid out while drawing. A left click
// selects a tab, the "+" chip opens a new tab, and a middle click on a tab
// closes it (Total Commander behaviour).

import AppKit
import PCFoundation

/// Horizontal tab bar shown above a panel's file list, one chip per open tab.
@MainActor
public final class TabBarView: NSView {
    /// The fixed height of the bar.
    private static let barHeight: CGFloat = 26

    /// Maximum width of a chip before its title truncates.
    private static let maxChipWidth: CGFloat = 180

    /// Horizontal padding inside a chip, on each side of the title.
    private static let chipPadding: CGFloat = 10

    /// Gap between adjacent chips.
    private static let chipGap: CGFloat = 3

    /// Width of the trailing "+" (new tab) chip.
    private static let newTabWidth: CGFloat = 24

    /// Vertical inset of a chip from the top/bottom of the bar.
    private static let chipInset: CGFloat = 2

    /// Called when a tab chip is clicked, with the tab's index.
    public var onSelect: ((Int) -> Void)?

    /// Called when a tab's close control is used (middle-click on a chip),
    /// with the tab's index.
    public var onClose: ((Int) -> Void)?

    /// Called when the trailing "+" chip is clicked.
    public var onNewTab: (() -> Void)?

    /// Called live while a tab chip is dragged past a neighbour, with the tab's
    /// current index and the index it should move to (F-008).
    public var onReorder: ((_ from: Int, _ to: Int) -> Void)?

    /// One tab's display state.
    private struct Tab {
        let title: String
        let active: Bool
        let locked: Bool
    }

    /// Current tabs, left to right.
    private var tabs: [Tab] = []

    /// Layout produced by the last `draw(_:)`: the frame of each tab chip
    /// (index matches `tabs`) and the frame of the trailing "+" chip, used to
    /// hit test mouse clicks.
    private var chipFrames: [NSRect] = []
    private var newTabFrame: NSRect = .zero

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.barHeight)
    }

    /// Kept for API compatibility; the bar redraws itself from `Theme.current`.
    public func applyTheme() {
        needsDisplay = true
    }

    /// Rebuild the bar for a new set of tabs.
    ///
    /// - Parameters:
    ///   - titles: Display titles, one per tab.
    ///   - activeIndex: Index of the tab to highlight as active.
    ///   - locked: Lock state per tab; same count as `titles`.
    public func setTabs(titles: [String], activeIndex: Int, locked: [Bool]) {
        tabs = titles.enumerated().map { index, title in
            Tab(title: title,
                active: index == activeIndex,
                locked: index < locked.count ? locked[index] : false)
        }
        needsDisplay = true
    }

    // MARK: - Colors

    private var isDarkMode: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private var barBackground: NSColor {
        isDarkMode ? NSColor(white: 0.16, alpha: 1.0) : NSColor(white: 0.82, alpha: 1.0)
    }

    private var activeChipColor: NSColor {
        isDarkMode ? NSColor(white: 0.34, alpha: 1.0) : NSColor.white
    }

    private var inactiveChipColor: NSColor {
        isDarkMode ? NSColor(white: 0.22, alpha: 1.0) : NSColor(white: 0.90, alpha: 1.0)
    }

    private var chipTextColor: NSColor {
        isDarkMode ? NSColor(white: 0.92, alpha: 1.0) : NSColor(white: 0.10, alpha: 1.0)
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Bar background (pure AppKit, no CGContext dependency).
        barBackground.setFill()
        NSBezierPath(rect: bounds).fill()

        let border = Theme.current.pathBarSeparator
        let font = Fonts.system13
        let chipTop = Self.chipInset
        let chipHeight = bounds.height - Self.chipInset * 2

        chipFrames = []
        var x: CGFloat = Self.chipGap

        for tab in tabs {
            let text = tab.locked ? "🔒 \(tab.title)" : tab.title
            // Measure with the same font used to draw (bold for the active tab) so the
            // active chip is wide enough and its title does not truncate to an ellipsis.
            let chipFont = tab.active ? Fonts.bold13 : font
            let textWidth = ceil((text as NSString).size(withAttributes: [.font: chipFont]).width)
            let chipWidth = min(Self.maxChipWidth, textWidth + Self.chipPadding * 2)
            let chipRect = NSRect(x: x, y: chipTop, width: chipWidth, height: chipHeight)
            chipFrames.append(chipRect)

            let path = NSBezierPath(roundedRect: chipRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            (tab.active ? activeChipColor : inactiveChipColor).setFill()
            path.fill()
            border.setStroke()
            path.lineWidth = tab.active ? 1.0 : 0.5
            path.stroke()

            // Title, clipped to the chip's inner text area.
            let textRect = NSRect(x: chipRect.minX + Self.chipPadding,
                                  y: chipRect.minY + (chipHeight - font.pointSize - 4) / 2,
                                  width: chipRect.width - Self.chipPadding * 2,
                                  height: font.pointSize + 4)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: textRect).setClip()
            let attrText = NSMutableAttributedString(string: text, attributes: [
                .font: tab.active ? Fonts.bold13 : font,
                .foregroundColor: chipTextColor
            ])
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            attrText.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attrText.length))
            attrText.draw(in: textRect)
            NSGraphicsContext.restoreGraphicsState()

            x += chipWidth + Self.chipGap
        }

        // Trailing "+" new-tab chip.
        let plusRect = NSRect(x: x, y: chipTop, width: Self.newTabWidth, height: chipHeight)
        newTabFrame = plusRect
        let plusPath = NSBezierPath(roundedRect: plusRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
        inactiveChipColor.setFill()
        plusPath.fill()
        border.setStroke()
        plusPath.lineWidth = 0.5
        plusPath.stroke()
        let plusAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: chipTextColor
        ]
        let plus = "+" as NSString
        let plusSize = plus.size(withAttributes: plusAttrs)
        plus.draw(at: NSPoint(x: plusRect.midX - plusSize.width / 2,
                              y: plusRect.midY - plusSize.height / 2),
                  withAttributes: plusAttrs)

        // Separator line along the bottom edge (adjacent to the path bar below).
        border.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: 1)).fill()
    }

    // MARK: - Mouse handling

    // Drag-reorder state (F-008).
    private var dragTabIndex: Int?
    private var dragOriginX: CGFloat = 0
    private var isDraggingTab = false

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, frame) in chipFrames.enumerated() where frame.contains(point) {
            dragTabIndex = index
            dragOriginX = point.x
            isDraggingTab = false
            onSelect?(index)
            return
        }
        dragTabIndex = nil
        if newTabFrame.contains(point) {
            onNewTab?()
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let from = dragTabIndex else { return }
        let point = convert(event.locationInWindow, from: nil)
        if !isDraggingTab {
            guard abs(point.x - dragOriginX) > 4 else { return }   // small threshold to start
            isDraggingTab = true
        }
        // Live reorder: when the cursor moves over a different chip, move there.
        guard let to = chipIndex(atX: point.x), to != from else { return }
        onReorder?(from, to)
        dragTabIndex = to   // the dragged chip now lives at `to`
    }

    public override func mouseUp(with event: NSEvent) {
        dragTabIndex = nil
        isDraggingTab = false
    }

    /// The tab chip index under horizontal position `x`, clamped to the ends.
    private func chipIndex(atX x: CGFloat) -> Int? {
        guard !chipFrames.isEmpty else { return nil }
        for (i, frame) in chipFrames.enumerated() where x >= frame.minX && x <= frame.maxX { return i }
        if let first = chipFrames.first, x < first.minX { return 0 }
        return chipFrames.count - 1
    }

    public override func otherMouseDown(with event: NSEvent) {
        guard event.buttonNumber == 2 else {
            super.otherMouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        for (index, frame) in chipFrames.enumerated() where frame.contains(point) {
            onClose?(index)
            return
        }
    }

    /// Right-click on a tab → context menu (Duplicate / Close / …).
    public var onContextMenu: ((Int) -> Void)?
    public override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, frame) in chipFrames.enumerated() where frame.contains(point) {
            onContextMenu?(index)
            return
        }
        super.rightMouseDown(with: event)
    }
}
