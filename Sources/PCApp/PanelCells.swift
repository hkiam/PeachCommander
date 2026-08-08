// SPDX-License-Identifier: Apache-2.0
// PanelCells.swift - Reusable cell and row views for the panel list
//
// DirectoryCellView renders the Name column (icon + text) and drives the async
// IconLoader with a per-configure generation token so a recycled cell ignores a
// stale icon resolution (cancel-on-scroll). PlainCellView renders text columns.
// CursorRowView draws the TC cursor frame around the focused row.

import AppKit
import PCVFS
import PCFoundation

/// Name-column cell: 16pt icon + label. Marked rows render in the theme's
/// selected-text color; the icon resolves asynchronously.
final class DirectoryCellView: NSTableCellView, NSTextFieldDelegate {
    static let reuseID = NSUserInterfaceItemIdentifier("PCNameCell")

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")   // trailing note/content badge
    private var iconGeneration = 0

    // In-cell rename (F-081) state.
    private var editCommit: ((String) -> Void)?
    private var editOriginal = ""
    private var editCancelled = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        identifier = DirectoryCellView.reuseID
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        label.font = Fonts.panelText
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.isBezeled = false; badgeLabel.isEditable = false; badgeLabel.drawsBackground = false
        badgeLabel.font = Fonts.panelText
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(iconView)
        addSubview(label)
        addSubview(badgeLabel)
        textField = label

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: badgeLabel.leadingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    /// Configure the cell. `request` nil means no icon (icon mode off or `..`
    /// handled separately). Invalidates any in-flight icon resolution.
    func configure(name: String, request: IconRequest?, isSelected: Bool, badge: String? = nil, color: NSColor? = nil) {
        iconGeneration &+= 1
        label.stringValue = name
        isMarked = isSelected
        baseTextColor = isSelected ? Theme.current.selectedText : (color ?? Theme.current.listText)
        label.textColor = baseTextColor
        badgeLabel.stringValue = badge ?? ""
        badgeLabel.textColor = .systemYellow   // sticky-note hue

        guard let request else {
            iconView.image = nil
            return
        }
        iconView.image = IconLoader.shared.cachedOrPlaceholder(for: request)
        if !IconLoader.shared.hasCachedIcon(for: request) {
            let gen = iconGeneration
            IconLoader.shared.resolve(request) { [weak self] image in
                guard let self, self.iconGeneration == gen else { return }
                self.iconView.image = image
            }
        }
    }

    /// See `CursorRowAwareCell`. Kept beside the rename support because both touch `label`'s
    /// colour: `beginInlineEdit` deliberately switches to the system text colours, and
    /// `applyCursorRowText` must not fight it — it is only ever called for non-editing rows,
    /// since the cursor row cannot move while its own cell is being edited.
    private var baseTextColor: NSColor = Theme.current.listText
    private var isMarked = false

    func applyCursorRowText(_ onCursorRow: Bool) {
        guard !isMarked, let cursorColor = Theme.current.cursorRowText else {
            label.textColor = baseTextColor
            return
        }
        label.textColor = onCursorRow ? cursorColor : baseTextColor
    }

    // MARK: - In-cell rename (F-081)

    /// Turn the label into an editable field seeded with `rawName` (never the
    /// bracketed/symlink-decorated display), select its first `basenameLen`
    /// characters, and focus it. `onCommit` fires with the final text on Enter or
    /// focus loss; Escape cancels (onCommit is not called).
    func beginInlineEdit(rawName: String, selectingBasenameOfLength basenameLen: Int,
                         onCommit: @escaping (String) -> Void) {
        editCommit = onCommit
        editOriginal = rawName
        editCancelled = false
        label.stringValue = rawName
        label.textColor = .labelColor
        label.isEditable = true
        label.isSelectable = true
        label.isBordered = true
        label.bezelStyle = .squareBezel
        label.drawsBackground = true
        label.backgroundColor = .textBackgroundColor
        label.lineBreakMode = .byClipping
        label.delegate = self
        window?.makeFirstResponder(label)
        if let editor = label.currentEditor() {
            let len = (label.stringValue as NSString).length
            let sel = (basenameLen > 0 && basenameLen <= len) ? basenameLen : len
            editor.selectedRange = NSRange(location: 0, length: sel)
        }
    }

    private func endInlineEdit() {
        label.delegate = nil
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        let value = label.stringValue
        let commit = editCommit
        let cancelled = editCancelled
        editCommit = nil
        endInlineEdit()
        if !cancelled { commit?(value) }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            editCancelled = true
            label.stringValue = editOriginal
            window?.makeFirstResponder(nil)   // ends editing → controlTextDidEndEditing (skips commit)
            return true
        }
        return false
    }
}

/// Plain text column cell (Ext / Size / Date / Attr).
extension DirectoryCellView: CursorRowAwareCell {}

/// A panel cell whose label colour depends on whether its row is the cursor row.
///
/// The cursor row is drawn as a filled bar by `CursorRowView` while the cells keep their normal
/// text colour, so a palette whose bar colour is close to its text colour renders an unreadable
/// row. `Theme.current.cursorRowText` fixes that per palette, and this protocol is how the row
/// view reaches the cells to apply it.
///
/// Inert unless a palette sets `cursorRowText`: with nil — every built-in light/dark theme — the
/// row view does not even iterate its cells, so the default drawing path is untouched.
protocol CursorRowAwareCell: AnyObject {
    func applyCursorRowText(_ onCursorRow: Bool)
}

final class PlainCellView: NSTableCellView {
    static let reuseID = NSUserInterfaceItemIdentifier("PCPlainCell")

    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        identifier = PlainCellView.reuseID
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(text: String, isSelected: Bool, monospaced: Bool = false,
                   alignment: NSTextAlignment = .left, color: NSColor? = nil) {
        label.stringValue = text
        isMarked = isSelected
        baseTextColor = isSelected ? Theme.current.selectedText : (color ?? Theme.current.listText)
        label.textColor = baseTextColor
        label.font = monospaced ? Fonts.panelMono : Fonts.panelText
        label.alignment = alignment
    }

    /// The colour `configure` chose, so the cursor-row colour can be applied and removed without
    /// re-running configure (the cursor moves far more often than cells are reconfigured).
    private var baseTextColor: NSColor = Theme.current.listText
    /// Marked files keep `selectedText` even on the cursor bar — that is how NC shows them too,
    /// and losing the marking would be worse than a slightly odd colour pairing.
    private var isMarked = false

    func applyCursorRowText(_ onCursorRow: Bool) {
        guard !isMarked, let cursorColor = Theme.current.cursorRowText else {
            label.textColor = baseTextColor
            return
        }
        label.textColor = onCursorRow ? cursorColor : baseTextColor
    }
}

extension PlainCellView: CursorRowAwareCell {}

/// Row view that draws the TC cursor frame around the focused row.
final class CursorRowView: NSTableRowView {
    var isCursor: Bool = false {
        didSet { if oldValue != isCursor { needsDisplay = true; needsLayout = true } }
    }
    /// Whether this row's panel is the active one — the cursor row is tinted more
    /// strongly on the active side so you can tell which panel is focused.
    var isActivePanel: Bool = false {
        didSet { if oldValue != isActivePanel, isCursor { needsDisplay = true; needsLayout = true } }
    }
    /// Alternating-row background (F-032): shade odd rows when enabled.
    var zebra: Bool = false { didSet { if oldValue != zebra { needsDisplay = true } } }
    var isOddRow: Bool = false { didSet { if oldValue != isOddRow { needsDisplay = true } } }

    /// Apply the palette's cursor-row text colour to this row's cells.
    ///
    /// `layout()` rather than the `isCursor` setter: AppKit adds the cell views to the row view
    /// *after* `rowViewForRow` returns, so at that point there is nothing to colour. layout runs
    /// once the cells are in place and again whenever the cursor moves onto or off this row.
    ///
    /// The guard is what keeps the default untouched — with no `cursorRowText` the cells are never
    /// even visited, so light/dark draw exactly as they did before this existed.
    override func layout() {
        super.layout()
        guard Theme.current.cursorRowText != nil else { return }
        let onBar = isCursor && isActivePanel   // only the active panel's bar is filled strongly
        for case let cell as CursorRowAwareCell in subviews { cell.applyCursorRowText(onBar) }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Faint alternating shade on non-cursor odd rows (drawn under the content).
        if zebra, isOddRow, !isCursor {
            Theme.current.zebraRow.setFill()
            bounds.fill()
        }
        guard isCursor else { return }
        // Subtle background fill: accent tint on the active panel, faint grey on the
        // inactive one, so the cursor row stays readable but marks the active side.
        let fill = isActivePanel ? Theme.current.selectionFillActive
                                 : Theme.current.selectionFillInactive
        fill.setFill()
        bounds.fill()
        // Thin frame around the cursor row.
        let frame = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(rect: frame)
        path.lineWidth = 1
        (isActivePanel ? Theme.current.activeCursorFrame : Theme.current.cursorFrame).setStroke()
        path.stroke()
    }

    // TC list uses text-color marking, not row highlighting.
    override func drawSelection(in dirtyRect: NSRect) {}
}


/// Cell that renders Finder tag colors as small dots (Finder-style).
final class TagCellView: NSTableCellView {
    static let reuseID = NSUserInterfaceItemIdentifier("PCTagCell")

    private var colors: [NSColor] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = TagCellView.reuseID
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        identifier = TagCellView.reuseID
    }

    func configure(colors: [NSColor]) {
        self.colors = colors
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !colors.isEmpty else { return }
        let diameter: CGFloat = 9
        let spacing: CGFloat = 4
        let maxDots = 5
        let y = (bounds.height - diameter) / 2
        var x: CGFloat = 3
        for color in colors.prefix(maxDots) {
            let rect = NSRect(x: x, y: y, width: diameter, height: diameter)
            let dot = NSBezierPath(ovalIn: rect)
            color.setFill()
            dot.fill()
            // Thin outline so light dots stay visible on the row background.
            Theme.current.headerSeparator.setStroke()
            dot.lineWidth = 0.5
            dot.stroke()
            x += diameter + spacing
        }
    }
}

/// Helpers to derive icon requests and directory-ness from a VFSEntry.
/// By-file-type row colors (F-032). Parsed from a compact config string:
/// `masks=RRGGBB,masks=RRGGBB` where `masks` is a TC WildcardMask (e.g.
/// `*.zip;*.rar`) and the color is a hex triple. Rules are tried in order; the
/// first matching mask wins. An empty string disables coloring.
struct TypeColorRules {
    private let rules: [(mask: WildcardMask, color: NSColor)]

    init(_ config: String = "") {
        var r: [(WildcardMask, NSColor)] = []
        for rule in config.split(separator: ",") {
            guard let eq = rule.firstIndex(of: "=") else { continue }
            let masks = rule[rule.startIndex..<eq].trimmingCharacters(in: .whitespaces)
            let hex = rule[rule.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if !masks.isEmpty, let c = Self.parseHex(hex) {
                r.append((WildcardMask(masks), c))
            }
        }
        rules = r
    }

    var isEmpty: Bool { rules.isEmpty }
    func color(for name: String) -> NSColor? { rules.first { $0.mask.matches(name) }?.color }

    private static func parseHex(_ hex: String) -> NSColor? {
        var s = hex; if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

enum PanelEntryHelpers {
    static func isDirectoryLike(_ kind: VFSEntry.Kind) -> Bool {
        switch kind {
        case .directory, .symlinkDir, .package:
            return true
        case .file, .symlinkFile, .appBundle:
            return false
        }
    }

    static func isSymlink(_ kind: VFSEntry.Kind) -> Bool {
        kind == .symlinkDir || kind == .symlinkFile
    }

    static func iconRequest(for entry: VFSEntry, fullPath: String) -> IconRequest {
        IconRequest(
            fullPath: fullPath,
            ext: entry.ext,
            isDirectory: isDirectoryLike(entry.kind),
            isApplication: entry.kind == .appBundle,
            isSymlink: isSymlink(entry.kind)
        )
    }
}
