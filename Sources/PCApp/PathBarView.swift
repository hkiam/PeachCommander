// SPDX-License-Identifier: Apache-2.0
// PathBarView.swift - Editable breadcrumb path bar for Peach Commander.
//
// Shows the current directory as clickable breadcrumb segments (each navigates
// to that ancestor). Clicking empty space — or double-clicking anywhere — turns
// the bar into a free-text edit field (Total Commander style): type any path,
// Enter navigates if it's a valid directory, otherwise (or on Esc / focus loss)
// the last valid path is kept. Volume name / free space are intentionally NOT
// shown here — that information lives in the status bar.

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

    @objc private func editButtonClicked() { beginEditing() }

    /// Trailing space reserved for the edit button so segments don't run under it.
    private var contentTrailingInset: CGFloat { 30 }

    func setActive(_ active: Bool) {
        backgroundColor = active ? Theme.current.activePathBarBackground : Theme.current.pathBarBackground
        needsDisplay = true
    }

    /// Update with the current path. `volume` is ignored (free space is shown in
    /// the status bar); the parameter stays for call-site compatibility.
    func update(with path: String, volume: Volume?) {
        currentPath = path
        segments = Self.makeSegments(path)
        if !isEditing { needsDisplay = true }
    }

    /// Breadcrumb segments for `path` — see `PathSegments.make`, which is where the logic lives so it
    /// can be tested without a view.
    static func makeSegments(_ path: String) -> [(name: String, path: String)] {
        PathSegments.make(path)
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

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                separatorColor.setStroke()
                context.stroke(NSMakeRect(xOffset, yOffset + 4, 1, height - 8))
                xOffset += 5
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
            let attrString = NSAttributedString(string: segment.name, attributes: attrs)
            let textSize = attrString.size()
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
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard !isEditing else { return }
        // Single-click a segment → navigate; double-click anywhere → edit. The
        // right-edge pencil button is the primary way into the edit mode.
        if event.clickCount >= 2 { beginEditing(); return }
        let loc = convert(event.locationInWindow, from: nil)
        if let hit = hitFrames.first(where: { NSPointInRect(loc, $0.rect) }) {
            onPathClick?(hit.path)
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

    /// Validate the typed path; navigate if it's a real directory, otherwise keep
    /// the last valid value (a beep signals the rejected input).
    private func commitEdit() {
        let text = editField?.stringValue ?? ""
        let expanded = (text as NSString).expandingTildeInPath
        var isDir: ObjCBool = false
        let valid = !expanded.isEmpty
            && FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir)
            && isDir.boolValue
        endEditing()
        if valid { onPathClick?(expanded) } else { NSSound.beep() }
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
}
