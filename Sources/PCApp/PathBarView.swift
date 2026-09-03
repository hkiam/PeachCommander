// SPDX-License-Identifier: Apache-2.0
// PathBarView.swift - Editable breadcrumb path bar for Peach Commander.
//
// Shows the current directory as clickable breadcrumb segments (each navigates
// to that ancestor). Clicking the area right of the last segment — the pencil
// button included — or double-clicking anywhere turns the bar into a free-text
// edit field (Total Commander style): type any path, Enter navigates if it's a
// valid directory, otherwise (or on Esc / focus loss) the last valid path is
// kept. Volume name / free space are intentionally NOT shown here — that
// information lives in the status bar.
//
// The paragraph above described the empty-space click for a long time before
// anything implemented it: only the double-click was real, so the pencil was
// the sole way in and it is 18 points wide (F-444).

import AppKit
import PCFoundation
import PCVFS

class PathBarView: NSView, NSTextFieldDelegate {
    private var _backgroundColor: NSColor?

    /// The full current directory path (the last valid value).
    private var currentPath: String = ""
    /// Breadcrumb segments: display name + the absolute path it navigates to.
    private var segments: [(name: String, path: String)] = []
    /// Hit rectangles computed during draw, reused for click/hover hit-testing.
    private var hitFrames: [(rect: NSRect, path: String)] = []
    /// Path of the segment currently hovered (for highlight).
    private var hoverPath: String?

    /// Inline edit field, present only while editing.
    private var editField: NSTextField?
    private var isEditing = false
    /// True once the edit field is genuinely focused; gates the cancel-on-blur
    /// handler so the initial focus transition doesn't tear the field down.
    private var editReady = false
    /// Text length after the last change, to distinguish typing from deleting
    /// (autocomplete only pops up while inserting).
    private var lastEditLength = 0
    /// Right-edge affordance that opens the free-text edit mode.
    private let editButton = NSButton()

    /// Callback with an absolute directory path to navigate to.
    var onPathClick: ((String) -> Void)?
    /// A typed network address (UNC, `smb://…`): mount it if needed, then navigate. The bar
    /// cannot answer that itself — it would have to mount — so it hands the text on.
    var onNetworkPath: ((String) -> Void)?
    /// A typed path that is not a directory. Rejection used to be a bare `NSSound.beep()`, which
    /// says something was refused but not which of the many reasons applied — and for a UNC path,
    /// where the bar's own resolution never had a chance, the beep was the only thing the user
    /// ever got.
    var onInvalidPath: ((String) -> Void)?
    /// Make this panel the active one. A click here used to leave the focus where it was, so the path
    /// editor could belong to the panel the user was not looking at (F-444).
    var onActivate: (() -> Void)?

    /// Right edge of the last segment as drawn — everything from here to the panel's edge opens the
    /// editor. `nil` until the first draw, when there is nothing on screen to have aimed at.
    private var contentEndX: CGFloat?

    private let position: PanelPosition

    init(position: PanelPosition) {
        self.position = position
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) {
        self.position = .left
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Theme.current.pathBarBackground
        editButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Edit path")
        editButton.isBordered = false
        editButton.imagePosition = .imageOnly
        editButton.target = self
        editButton.action = #selector(editButtonClicked)
        editButton.contentTintColor = Theme.current.pathBarText
        editButton.toolTip = String(localized: "Edit path…")
        addSubview(editButton)
    }

    override func layout() {
        super.layout()
        let s: CGFloat = 18
        editButton.frame = NSRect(x: bounds.width - s - 6, y: (bounds.height - s) / 2, width: s, height: s)
        editField?.frame = bounds.insetBy(dx: 3, dy: 3)
    }

    @objc private func editButtonClicked() {
        // A real NSButton subview: its clicks never reach `mouseDown`, so the activation is repeated
        // here rather than being lost.
        onActivate?()
        beginEditing()
    }

    /// Trailing space reserved for the edit button so segments don't run under it.
    private var contentTrailingInset: CGFloat { 30 }

    func setActive(_ active: Bool) {
        backgroundColor = active ? Theme.current.activePathBarBackground : Theme.current.pathBarBackground
        needsDisplay = true
    }

    /// Update with the current path. `volume` is ignored (free space is shown in
    /// the status bar); the parameter stays for call-site compatibility.
    ///
    /// `rootLabel` names the leading segment when the listing is a mounted drive rather than a
    /// directory — "TaskManager" instead of a "/" that belongs to no disk the user can point at.
    func update(with path: String, volume: Volume?, rootLabel: String? = nil) {
        currentPath = path
        segments = Self.makeSegments(path, rootLabel: rootLabel)
        if !isEditing { needsDisplay = true }
    }

    /// The breadcrumb as drawn — for the automation report; the segments are painted, not controls.
    ///
    /// Joined with " > ", not "/": the segment names include the root, and a slash between them
    /// reads as a path — which is exactly the thing the report has to be able to contradict.
    var crumbForAutomation: String { segments.map(\.name).joined(separator: " > ") }

    /// Breadcrumb segments for `path` — see `PathSegments.make`, which is where the logic lives so it
    /// can be tested without a view.
    static func makeSegments(_ path: String, rootLabel: String? = nil) -> [(name: String, path: String)] {
        PathSegments.make(path, rootLabel: rootLabel)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        backgroundColor?.setFill()
        context.fill(dirtyRect)
        // The edit field covers the bar while editing; skip breadcrumb drawing.
        guard !isEditing else { return }

        let font = Fonts.system13
        let textColor = Theme.current.pathBarText
        let hoverColor = Theme.current.pathBarHoverBackground
        let separatorColor = Theme.current.pathBarSeparator

        var xOffset: CGFloat = 6
        let yOffset: CGFloat = 4
        let height = bounds.height - 8
        hitFrames.removeAll(keepingCapacity: true)
        // `contentTrailingInset` had been written for exactly this and then ignored, so a long path
        // drew its deepest folders underneath the pencil and left no free space at all (F-444).
        let contentLimit = max(6, bounds.width - contentTrailingInset)

        for (index, segment) in segments.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
            let attrString = NSAttributedString(string: segment.name, attributes: attrs)
            let textSize = attrString.size()
            // A segment that does not fit *whole* is not drawn at all. Stopping when the pen has
            // already crossed the limit is not enough — the segment that crossed it overhangs, and its
            // hit rect then reaches into the trailing area and answers the clicks meant for the editor.
            // That is exactly what the first run of this showed: a click in the free space navigated.
            let advance = (index > 0 ? 5 : 0) + textSize.width + 4
            if xOffset + advance > contentLimit { break }
            if index > 0 {
                separatorColor.setStroke()
                context.stroke(NSMakeRect(xOffset, yOffset + 4, 1, height - 8))
                xOffset += 5
            }
            let rect = NSMakeRect(xOffset - 2, yOffset, textSize.width + 4, height)

            if hoverPath == segment.path {
                hoverColor.setFill()
                let r = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
                r.fill()
            }
            attrString.draw(at: NSMakePoint(xOffset, yOffset + 2))
            hitFrames.append((rect, segment.path))
            xOffset += textSize.width + 4
        }
        // Every segment drawn fits inside the limit, so this really is the right edge of the content
        // and everything beyond it is free space.
        contentEndX = xOffset
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard !isEditing else { return }
        // Activate first, then edit: `activate…Panel` makes the file list the first responder, while
        // `beginEditing` focuses its field on the next runloop tick — so the field wins, in that order
        // and only in that order.
        onActivate?()
        let loc = convert(event.locationInWindow, from: nil)
        let frames = hitFrames.map { PathBarSegmentFrame(rect: $0.rect, path: $0.path) }
        switch pathBarHit(at: loc, segments: frames, contentEndX: contentEndX,
                          clickCount: event.clickCount) {
        case .navigate(let path): onPathClick?(path)
        case .edit:               beginEditing()
        case .none:               break
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        guard !isEditing else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let p = hitFrames.first(where: { NSPointInRect(loc, $0.rect) })?.path
        if p != hoverPath { hoverPath = p; needsDisplay = true }
    }
    override func mouseExited(with event: NSEvent) {
        if hoverPath != nil { hoverPath = nil; needsDisplay = true }
    }

    // MARK: - Editing (Total Commander style free-text path entry)

    private func beginEditing() {
        guard editField == nil else { return }
        isEditing = true
        editReady = false
        hoverPath = nil
        editButton.isHidden = true
        let field = NSTextField(frame: bounds.insetBy(dx: 3, dy: 3))
        field.stringValue = currentPath
        field.font = Fonts.system13
        field.isEditable = true
        field.isBezeled = true
        field.bezelStyle = .squareBezel
        field.focusRingType = .none
        field.lineBreakMode = .byTruncatingHead
        field.delegate = self
        field.autoresizingMask = [.width, .height]
        addSubview(field)
        editField = field
        lastEditLength = currentPath.count
        needsDisplay = true
        // Focus on the next runloop tick, after the field is laid out. Doing it
        // synchronously here makes AppKit fire a spurious controlTextDidEndEditing
        // that would tear the field right back down. `editReady` gates the cancel
        // handler until the field is genuinely focused.
        DispatchQueue.main.async { [weak self] in
            guard let self, let f = self.editField else { return }
            self.window?.makeFirstResponder(f)
            f.selectText(nil)
            self.editReady = true
        }
    }

    private func endEditing() {
        isEditing = false
        editReady = false
        editField?.removeFromSuperview()
        editField = nil
        editButton.isHidden = false
        needsDisplay = true
    }

    /// Validate the typed path; navigate if it's a real directory, hand a network address to the
    /// window, otherwise keep the last valid value and say why.
    private func commitEdit() {
        let text = editField?.stringValue ?? ""
        // A network address before anything local is tried: `expandingTildeInPath` leaves
        // `\\srv\share` untouched, so it was checked as a *file name* in the current folder,
        // found missing, and beeped. Whether it needs mounting is not this view's question.
        if NetworkShare.isNetworkLocation(text) {
            endEditing()
            onNetworkPath?(text.trimmingCharacters(in: .whitespaces))
            return
        }
        let expanded = (text as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        let valid = !expanded.isEmpty
            && FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir)
            && isDir.boolValue
        endEditing()
        if valid {
            onPathClick?(expanded)
        } else {
            NSSound.beep()
            if !expanded.isEmpty { onInvalidPath?(expanded) }
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commitEdit(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            endEditing(); return true   // Esc → keep last valid
        default:
            return false
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        // Ignore the spurious end that fires before the field is truly focused.
        guard editReady else { return }
        // Focus lost without Enter/Esc → cancel (keep last valid).
        if isEditing { endEditing() }
    }

    // MARK: - Autocomplete (directory-name completion while typing)

    func controlTextDidChange(_ obj: Notification) {
        guard let field = editField, let editor = field.currentEditor() else { return }
        let inserting = field.stringValue.count > lastEditLength
        lastEditLength = field.stringValue.count
        // Only offer completions while typing forward (not on delete), so the
        // popup doesn't fight backspacing.
        if inserting { editor.complete(nil) }
    }

    /// Complete the path segment being typed to matching subdirectory names.
    func control(_ control: NSControl, textView: NSTextView, completions words: [String],
                 forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        let ns = textView.string as NSString
        guard charRange.location <= ns.length, NSMaxRange(charRange) <= ns.length else { return [] }
        let prefix = ns.substring(with: charRange).lowercased()
        let parentPart = (ns.substring(to: charRange.location) as NSString).expandingTildeInPath
        let parent = parentPart.isEmpty ? "/" : parentPart
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue,
              let entries = try? fm.contentsOfDirectory(atPath: parent) else { return [] }
        let matches = entries.filter { name in
            guard name.lowercased().hasPrefix(prefix) else { return false }
            var d: ObjCBool = false
            let full = (parent as NSString).appendingPathComponent(name)
            return fm.fileExists(atPath: full, isDirectory: &d) && d.boolValue
        }.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        index.pointee = -1   // don't auto-select the first match
        return matches
    }

    // MARK: - Properties

    var backgroundColor: NSColor? {
        get { _backgroundColor }
        set { _backgroundColor = newValue; needsDisplay = true }
    }

    #if DEBUG
    /// Diagnostic: the state a click left behind (F-444).
    ///
    /// The bar draws its own segments and handles its own clicks, so nothing about it is readable
    /// through a control: without this, "the empty space opens the editor" could only be checked by
    /// looking at a picture and guessing where the picture's edges were.
    var stateForAutomation: String {
        let end = contentEndX.map { String(format: "%.0f", $0) } ?? "<undrawn>"
        return "editing=\(isEditing ? 1 : 0)\n"
            + "text=\(editField?.stringValue ?? "<none>")\n"
            + "crumb=\(crumbForAutomation)\n"
            + "contentEnd=\(end)\n"
            + "width=\(String(format: "%.0f", bounds.width))\n"
    }

    /// Where a named region is, in view coordinates. One resolver, so the click and the hit test can
    /// never end up asking about two different points — which would make the hit test's reassurance
    /// worthless exactly when it mattered.
    ///
    /// Regions: `first`, `last` (a breadcrumb segment), `gap` (between two of them), `trailing` (the
    /// free space), `pencil` (the button) and `x:<n>` (an exact coordinate).
    private func regionCentreForAutomation(_ region: String) -> CGFloat? {
        switch region {
        case "pencil":   return editButton.frame.midX
        case "first":    return hitFrames.first?.rect.midX
        case "last":     return hitFrames.last?.rect.midX
        case "gap":
            // Between two segments: just past the first one's right edge, where the separator is.
            guard hitFrames.count >= 2 else { return nil }
            let gap = hitFrames[1].rect.minX - hitFrames[0].rect.maxX
            guard gap > 1 else { return nil }
            return hitFrames[0].rect.maxX + gap / 2
        case "trailing":
            guard let end = contentEndX, end < bounds.width - 2 else { return nil }
            return (end + bounds.width) / 2
        default:
            guard region.hasPrefix("x:"), let v = Double(region.dropFirst(2)) else { return nil }
            return CGFloat(v)
        }
    }

    /// Diagnostic: click one of the bar's regions, as a real mouse would (F-444).
    ///
    /// A synthesised `NSEvent` through `mouseDown`, not a call to the decision function — the point is
    /// that the coordinates the view draws with and the ones it hit-tests against agree, which a direct
    /// call to `pathBarHit` would assume rather than check.
    ///
    /// Returns the x it aimed at, or nil when the region does not exist right now.
    func clickRegionForAutomation(_ region: String, clickCount: Int = 1) -> CGFloat? {
        guard let x = regionCentreForAutomation(region) else { return nil }
        // The pencil is an `NSButton` subview, so its clicks never reach `mouseDown` — pressing the
        // button is what a real click there does.
        if region == "pencil" { editButton.performClick(nil); return x }
        let point = NSPoint(x: x, y: bounds.midY)
        guard let event = NSEvent.mouseEvent(with: .leftMouseDown,
                                            location: convert(point, to: nil),
                                            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                            windowNumber: window?.windowNumber ?? 0, context: nil,
                                            eventNumber: 0, clickCount: clickCount, pressure: 1)
        else { return nil }
        mouseDown(with: event)
        return x
    }

    /// Diagnostic: which view a real click at `region` would actually land on (F-444).
    ///
    /// `clickRegionForAutomation` calls `mouseDown` directly, so it cannot see a *sibling* view lying on
    /// top: the panel keeps three indicator labels — the quick filter, type-ahead and a message —
    /// constrained over this bar, and they sit in exactly the region being made clickable. This asks the
    /// window the question instead, and the answer must be the path bar itself or its pencil.
    ///
    /// Ask it BEFORE clicking: once the click has opened the editor, the field covers the bar and the
    /// answer is about the field rather than about what a real mouse would have reached.
    func hitTestForAutomation(_ region: String) -> String {
        guard let x = regionCentreForAutomation(region) else { return "<no such region>" }
        let inWindow = convert(NSPoint(x: x, y: bounds.midY), to: nil)
        guard let root = window?.contentView else { return "<no window>" }
        let hit = root.hitTest(root.convert(inWindow, from: nil))
        return hit.map { String(describing: type(of: $0)) } ?? "<none>"
    }
    #endif
}
