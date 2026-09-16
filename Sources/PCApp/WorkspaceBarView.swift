// SPDX-License-Identifier: Apache-2.0
// WorkspaceBarView.swift - The row of workspace chips across the top of the window (F-499).
//
// A sibling of `TabBarView` rather than a generalisation of it, and the sibling is the cheaper of the
// two. That view is per panel, carries lock glyphs, closes a tab on a middle click, offers a "+" that
// means something else, and exposes a `titlesForAutomation` string three VM scenarios assert on.
// This one needs colour fills, a different context menu, shrink-to-fit, and must **never** close
// anything on a middle click — a workspace is deleted, which is destructive, not closed. Merging the
// two for two callers would rewrite geometry that existing scenarios are baselined against, to save
// perhaps eighty lines. The house already has three hand-drawn chip strips that share the pattern and
// no code; this is the fourth.
//
// **Where it sits.** Topmost row of the content view, full width, above the button bar. Not between
// the button bar and the panels, for three reasons in ascending order of force:
//
//   1. The button bar can be a left-hand *column* (F-011), in which case it is pinned to the top of
//      the container and the split view starts at the top too. A strip below it would begin halfway
//      down the window in that mode, or need a second set of constraints for it.
//   2. Switching a workspace changes everything below this line and nothing above it. The frame
//      around the window says that; a strip wedged into the middle does not.
//   3. Two adjacent file-drop strips meaning different things is a defect waiting to be filed. The
//      button bar already takes file drops on its free space (F-342). Directly beneath it would sit a
//      second horizontal strip at nearly the same height — one of which runs a program with your
//      files and the other of which collects them. A full-width top row with its own background and a
//      separator is the cheapest way to say "different thing".
//
// **It is 24 pt, where the tab bar is 26.** Deliberate: two chip strips of the same height stacked
// three rows apart read as one control that has wrapped.

import AppKit
import PCFoundation

@MainActor
final class WorkspaceBarView: NSView {

    static let barHeight: CGFloat = 24
    private static let maxChipWidth: CGFloat = 170
    /// Below this a name is more ellipsis than name; the bar collapses to swatches instead.
    private static let minChipWidth: CGFloat = 56
    private static let swatchWidth: CGFloat = 24
    private static let capWidth: CGFloat = 4
    private static let chipPadding: CGFloat = 9
    private static let chipGap: CGFloat = 3
    private static let chipInset: CGFloat = 2
    private static let plusWidth: CGFloat = 22

    struct Chip {
        let id: String
        let name: String
        let tint: Int
        let current: Bool
        /// How many files are in this workspace's basket. Shown on **every** chip, including the ones
        /// that are not current — which is what makes dropping onto a workspace you are not in
        /// visibly effective rather than an act of faith (F-499).
        let stashCount: Int
    }

    var onSelect: ((Int) -> Void)?
    var onNewWorkspace: (() -> Void)?
    var onReorder: ((_ from: Int, _ to: Int) -> Void)?
    /// Right-click. `nil` index means the click was on free space rather than on a chip.
    var onContextMenu: ((Int?, NSEvent) -> Void)?
    /// The ✕ was clicked. The caller asks before anything happens — a workspace is deleted, not
    /// closed, and its stash and journal go with it.
    ///
    /// The **id**, where `onSelect` above passes an index, and the difference is deliberate: an index
    /// is only as good as the strip being in step with the list it was built from, and switching to
    /// the wrong workspace is a click to undo while deleting the wrong one is not. The chip knows its
    /// own id; there is no reason for the destructive path to look one up by position.
    var onCloseWorkspace: ((String) -> Void)?

    /// What a drop onto a chip should do.
    enum DropIntent { case stash, copyIntoActiveFolder, moveIntoActiveFolder }

    /// Files were dropped on the chip at `index`.
    var onDropFiles: ((_ index: Int, _ paths: [String], _ intent: DropIntent) -> Void)?

    private var chips: [Chip] = []
    private var chipFrames: [NSRect] = []
    /// The ✕ a mouse-down armed, if any.
    private var closeIndex: Int?
    private var plusFrame: NSRect = .zero
    private var dragIndex: Int?
    private var dragOrigin: NSPoint = .zero
    private var didDrag = false
    /// The chip a file drag is currently over, drawn with an outline.
    private var dropTarget: Int? { didSet { if oldValue != dropTarget { needsDisplay = true } } }

    /// The chips as drawn, active one marked with "*" — the strip paints itself, so nothing else can
    /// read it back for a report.
    var chipsForAutomation: String {
        chips.map { chip in
            (chip.current ? "*" : "") + chip.name + "#\(chip.tint)"
                + (chip.stashCount > 0 ? "(\(chip.stashCount))" : "")
        }.joined(separator: "|")
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    func setChips(_ chips: [Chip]) {
        self.chips = chips
        needsDisplay = true
    }

    func applyTheme() { needsDisplay = true }

    // MARK: - Colours

    private var barBackground: NSColor { Theme.current.tabBarBackground }

    // MARK: - Layout

    /// How wide each chip may be, given how many there are and how much room there is.
    ///
    /// Shrink, never a "»" overflow chevron like the button bar's: a workspace you cannot see is a
    /// workspace you cannot switch to, and this strip exists precisely so that every context is one
    /// click away. Past the point where a name is unreadable the chips become plain colour swatches —
    /// nine of those fit in any window this app can be opened in, and the colour is the identity.
    private func chipWidth(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let available = bounds.width - Self.plusWidth - Self.chipGap * CGFloat(count + 2)
        let natural = Self.maxChipWidth
        let fair = available / CGFloat(count)
        if fair >= natural { return natural }
        if fair >= Self.minChipWidth { return floor(fair) }
        return Self.swatchWidth
    }

    /// Does the chip at `index` draw a ✕?
    ///
    /// The single answer for all three readers — the drawing, the hit test and the accessibility
    /// children — because three copies of this rule would drift and the drift would show up as a
    /// glyph you can see and cannot click.
    private func showsClose(_ index: Int) -> Bool {
        // The last workspace cannot be deleted, so it is not offered. Same rule as the "+": a control
        // that cannot work is not drawn.
        chips.count > 1 && chips.indices.contains(index)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let background = barBackground
        background.setFill()
        NSBezierPath(rect: bounds).fill()

        // A hairline under the bar, so it reads as part of the window frame rather than as a row of
        // controls floating above the button bar.
        Theme.current.pathBarSeparator.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)).fill()

        let chipTop = Self.chipInset + 0.5
        let chipHeight = bounds.height - Self.chipInset * 2 - 0.5
        let width = chipWidth(for: chips.count)
        let swatchesOnly = width <= Self.swatchWidth
        let font = Fonts.system13

        chipFrames = []
        var x = Self.chipGap

        for (index, chip) in chips.enumerated() {
            let rect = NSRect(x: x, y: chipTop, width: width, height: chipHeight)
            chipFrames.append(rect)

            let fill = WorkspaceTint.fill(chip.tint, active: chip.current, on: background)
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            fill.setFill()
            path.fill()
            if dropTarget == index {
                // The chip a drop would land on. Two points, not one: a one-point outline on a 24 pt
                // strip reads as an artefact rather than as an answer to "where is this going".
                WorkspaceTint.hue(chip.tint).setStroke()
                path.lineWidth = 2
                path.stroke()
            } else if chip.current {
                Theme.current.pathBarSeparator.setStroke()
                path.lineWidth = 1.0
                path.stroke()
            }

            // The colour cap, at full strength whatever the chip's state: it is what identifies the
            // workspace when the name has had to go.
            let cap = NSRect(x: rect.minX + 1, y: rect.minY + 1,
                             width: Self.capWidth, height: rect.height - 2)
            WorkspaceTint.hue(chip.tint).setFill()
            NSBezierPath(roundedRect: cap, xRadius: 1.5, yRadius: 1.5).fill()

            guard !swatchesOnly else { x += width + Self.chipGap; continue }

            // The ✕'s room is taken out of the name's rectangle rather than drawn over it — the
            // terminal's tab strip learned that one the other way round, where the glyph sat on the
            // last letter of a long folder name.
            let close = WorkspaceChipHit.closeRect(in: rect, showsClose: showsClose(index))
            let reserved = close.map { rect.maxX - $0.minX } ?? 0
            let textRect = NSRect(x: rect.minX + Self.capWidth + Self.chipPadding - 3,
                                  y: rect.minY + (chipHeight - font.pointSize - 4) / 2,
                                  width: rect.width - Self.capWidth - Self.chipPadding * 2 + 4 - reserved,
                                  height: font.pointSize + 4)
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let attributed = NSAttributedString(string: chip.name, attributes: [
                .font: chip.current ? Fonts.bold13 : font,
                .foregroundColor: WorkspaceTint.textColor(on: fill, theme: Theme.current),
                .paragraphStyle: style,
            ])
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: textRect).setClip()
            attributed.draw(in: textRect)
            NSGraphicsContext.restoreGraphicsState()

            if chip.stashCount > 0 {
                drawStashBadge(chip, in: rect, fill: fill, reserving: reserved)
            }
            if let close { drawClose(in: close, chip: chip, fill: fill) }

            x += width + Self.chipGap
        }

        // The "+" chip, only while the strip is showing at all (so never at one workspace) and never
        // past the limit — a control that cannot work should not be drawn.
        if chips.count < MainWindowController.maxWorkspaces {
            plusFrame = NSRect(x: x, y: chipTop, width: Self.plusWidth, height: chipHeight)
            let path = NSBezierPath(roundedRect: plusFrame.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            Theme.current.tabBarInactiveChip.setFill()
            path.fill()
            let plus = NSAttributedString(string: "+", attributes: [
                .font: font, .foregroundColor: Theme.current.tabBarChipText,
            ])
            let size = plus.size()
            plus.draw(at: NSPoint(x: plusFrame.midX - size.width / 2,
                                  y: plusFrame.midY - size.height / 2))
        } else {
            plusFrame = .zero
        }
    }

    /// The count, at the trailing end of the chip.
    ///
    /// Drawn over the title's clip rather than reserved out of it: the name is what identifies the
    /// workspace, so when the bar is tight the number should be what gets crowded, not the word.
    private func drawStashBadge(_ chip: Chip, in rect: NSRect, fill: NSColor,
                                reserving: CGFloat) {
        let text = NSAttributedString(string: "\(chip.stashCount)", attributes: [
            .font: Fonts.bold11,
            .foregroundColor: WorkspaceTint.textColor(on: fill, theme: Theme.current),
        ])
        let size = text.size()
        let pill = NSRect(x: rect.maxX - size.width - 10 - reserving, y: rect.midY - 7,
                          width: size.width + 8, height: 14)
        guard pill.minX > rect.minX + Self.capWidth + 6 else { return }
        WorkspaceTint.hue(chip.tint).withAlphaComponent(chip.current ? 0.45 : 0.30).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 7, yRadius: 7).fill()
        text.draw(at: NSPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2))
    }

    /// The ✕, drawn rather than added as a button — this whole strip is drawn, and one real control
    /// among the pixels would be the odd thing out.
    ///
    /// Two details are the terminal tab strip's, paid for there: `xmark` at its natural weight is
    /// taller than the name beside it and reads as the chip's main control, so it is drawn small; and
    /// a glyph tinted with the theme's secondary text is dark-on-blue in the *current* chip — the one
    /// most likely to be clicked — so it takes the same colour the name does, which is already
    /// contrast-checked against the fill.
    private func drawClose(in rect: NSRect, chip: Chip, fill: NSColor) {
        let colour = WorkspaceTint.textColor(on: fill, theme: Theme.current)
        let glyph = NSAttributedString(string: "✕", attributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: colour.withAlphaComponent(chip.current ? 0.95 : 0.55),
        ])
        let size = glyph.size()
        glyph.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        didDrag = false
        closeIndex = nil
        switch WorkspaceChipHit.region(at: point, chips: chipFrames,
                                       showsClose: { [weak self] in self?.showsClose($0) ?? false },
                                       plus: plusFrame) {
        case .new:
            onNewWorkspace?()
        case .close(let index):
            // Armed on the way down and fired on the way up, the way a button behaves — and
            // deliberately *without* arming the reorder drag, or pressing the ✕ and moving a few
            // pixels would shuffle the strip instead.
            closeIndex = index
        case .chip(let index):
            dragIndex = index
            dragOrigin = point
        case .none:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard closeIndex == nil, let from = dragIndex else { return }
        let point = convert(event.locationInWindow, from: nil)
        // The same 4 pt threshold the tab bar uses, so a click with a shaky hand is still a click.
        guard abs(point.x - dragOrigin.x) > 4 else { return }
        for (index, frame) in chipFrames.enumerated() where frame.contains(point) && index != from {
            didDrag = true
            onReorder?(from, index)
            dragIndex = index
            return
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragIndex = nil; closeIndex = nil }
        let point = convert(event.locationInWindow, from: nil)

        if let index = closeIndex {
            // Only when the release lands on the same ✕ it was pressed on: sliding off a control is
            // how a Mac user takes a click back, and this one deletes.
            guard chipFrames.indices.contains(index),
                  let close = WorkspaceChipHit.closeRect(in: chipFrames[index],
                                                         showsClose: showsClose(index)),
                  close.contains(point) else { return }
            guard chips.indices.contains(index) else { return }
            onCloseWorkspace?(chips[index].id)
            return
        }

        guard let index = dragIndex, !didDrag else { return }
        guard chipFrames.indices.contains(index), chipFrames[index].contains(point) else { return }
        onSelect?(index)
    }

    /// Middle click does **nothing**, on purpose.
    ///
    /// The tab bar closes a tab here, and the muscle memory carries across — which is exactly the
    /// problem: the equivalent gesture on a workspace would delete it, along with everything it
    /// remembers, on a click nobody confirmed.
    override func otherMouseDown(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for (index, frame) in chipFrames.enumerated() where frame.contains(point) {
            onContextMenu?(index, event)
            return
        }
        onContextMenu?(nil, event)
    }

    // MARK: - Dropping files on a chip

    // **The unmodified drop goes to the stash, and that is a safety decision rather than a taste.**
    // This strip is one pixel below the top edge of the window, it is on the way to the Finder, and
    // the gesture ends in a mouse-up nobody can take back. So the plain drop may not move or delete
    // anything: it collects. ⌥ and ⌘ already mean copy and move on the panel's own drop, so the
    // modified drops speak a language the app already speaks rather than inventing a third one.

    private func intent(for sender: NSDraggingInfo) -> DropIntent {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) { return .moveIntoActiveFolder }
        if flags.contains(.option) { return .copyIntoActiveFolder }
        return .stash
    }

    private func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        switch intent(for: sender) {
        case .stash: return .generic
        case .copyIntoActiveFolder: return .copy
        case .moveIntoActiveFolder: return .move
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { dragUpdate(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { dragUpdate(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropTarget = nil }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { dropTarget = nil }

    /// Re-read on every update so the badge on the drag image follows the modifier key under the
    /// user's thumb rather than whatever was held when the drag began.
    private func dragUpdate(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard onDropFiles != nil, !FileDragPasteboard.paths(from: sender).isEmpty else {
            dropTarget = nil
            return []
        }
        let point = convert(sender.draggingLocation, from: nil)
        dropTarget = chipFrames.firstIndex { $0.contains(point) }
        // Free space is refused: unlike the button bar there is nothing sensible to create there, and
        // an accepted drop that does nothing is worse than one that was never offered.
        guard dropTarget != nil else { return [] }
        return operation(for: sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { dropTarget = nil }
        let paths = FileDragPasteboard.paths(from: sender)
        let point = convert(sender.draggingLocation, from: nil)
        guard let index = chipFrames.firstIndex(where: { $0.contains(point) }),
              !paths.isEmpty, let onDropFiles else { return false }
        onDropFiles(index, paths, intent(for: sender))
        return true
    }

    // MARK: - Accessibility

    // A hand-drawn strip is one opaque rectangle to VoiceOver — not "an unlabelled button", but
    // nothing at all. A VM run has already caught exactly this omission once.

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .tabGroup }
    override func accessibilityLabel() -> String? { String(localized: "Workspaces") }

    override func accessibilityChildren() -> [Any]? {
        var out: [Any] = zip(chips.indices, chipFrames).map { index, frame in
            // `.radioButton` inside a `.tabGroup` is what makes VoiceOver say "2 of 4, selected",
            // which is the right sentence for a mode.
            AccessibleHotspot(label: chips[index].name, role: .radioButton,
                              selected: chips[index].current,
                              frameInView: frame, parent: self) { [weak self] in
                self?.onSelect?(index)
            }
        }
        for index in chips.indices {
            guard chipFrames.indices.contains(index),
                  let close = WorkspaceChipHit.closeRect(in: chipFrames[index],
                                                         showsClose: showsClose(index)) else { continue }
            // Its own label, and one that says what it does rather than what it looks like: a hotspot
            // without one is announced as a second unnamed button sitting on the first (F-385).
            out.append(AccessibleHotspot(
                label: String(format: String(localized: "Delete workspace “%@”"), chips[index].name),
                role: .button, selected: false, frameInView: close, parent: self) {
                    [weak self] in
                    guard let self, self.chips.indices.contains(index) else { return }
                    self.onCloseWorkspace?(self.chips[index].id)
                })
        }
        if plusFrame != .zero {
            out.append(AccessibleHotspot(label: String(localized: "New Workspace"), role: .button,
                                         selected: false, frameInView: plusFrame, parent: self) {
                [weak self] in self?.onNewWorkspace?()
            })
        }
        return out
    }
}
