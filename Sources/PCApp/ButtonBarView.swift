// ButtonBarView.swift - Toolbar button strip (I13 T04, F-253)
//
// Renders a TC .bar as a horizontal strip of icon/text buttons. Clicking a button
// invokes its command through the owner (cm_/em_/program/dir). Right-click offers
// "Edit Button Bar…" (opens the .bar file). Icon loading covers SF Symbols
// ("sf:<name>") and file/app paths; everything else falls back to a text label.
// A trailing »-chevron reveals buttons that don't fit (F-253); drag-and-drop,
// subbars, and the Customize dialog are deferred.

import AppKit
import PCFoundation

final class ButtonBarView: NSView {
    /// Invoked when a button is clicked, with the button's model.
    var onRunButton: ((BarButton) -> Void)?
    /// Invoked for "Edit Button Bar…" (right-click).
    var onEditBar: (() -> Void)?
    /// Invoked when files are dropped onto a button (F-067): the model + paths.
    var onDropOnButton: ((BarButton, [String]) -> Void)?

    private let stack = NSStackView()
    private var bar = ButtonBar()
    /// Vertical (left-column) vs horizontal (top-strip) layout — F-011.
    private(set) var isVertical = false
    private var stackConstraintsH: [NSLayoutConstraint] = []
    private var stackConstraintsV: [NSLayoutConstraint] = []
    // Overflow (F-253): buttons that don't fit go behind a trailing »-chevron menu.
    private let overflowChevron = NSButton(title: "»", target: nil, action: nil)
    private var buttonViews: [(view: NSView, model: BarButton?)] = []
    private var overflowButtons: [BarButton] = []
    private var relayingOverflow = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        stackConstraintsH = [
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ]
        stackConstraintsV = [
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(stackConstraintsH)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Preferred thickness (0 when empty so it collapses): the strip's height when
    /// horizontal, or the column's width when vertical.
    var preferredHeight: CGFloat { bar.buttons.isEmpty ? 0 : 30 }
    var preferredThickness: CGFloat { preferredHeight }

    /// Switch between the top-strip (horizontal) and left-column (vertical) layout.
    func setVertical(_ vertical: Bool) {
        guard vertical != isVertical else { return }
        isVertical = vertical
        stack.orientation = vertical ? .vertical : .horizontal
        stack.alignment = vertical ? .centerX : .centerY
        NSLayoutConstraint.deactivate(vertical ? stackConstraintsH : stackConstraintsV)
        NSLayoutConstraint.activate(vertical ? stackConstraintsV : stackConstraintsH)
        rebuild()
    }

    // Subbar navigation (F-253): stack of parent bars entered via .bar buttons.
    private var barStack: [ButtonBar] = []

    func setBar(_ bar: ButtonBar) {
        self.bar = bar
        barStack = []          // switching the top-level bar resets any subbar nesting
        applyTheme()
        rebuild()
    }

    /// Descend into a subbar (a `.bar` button was clicked), keeping the current bar
    /// on a back-stack so a leading ◀ button returns to it (F-253).
    func enterSubbar(_ sub: ButtonBar) {
        barStack.append(bar)
        bar = sub
        rebuild()
    }

    @objc private func popSubbar() {
        guard let parent = barStack.popLast() else { return }
        bar = parent
        rebuild()
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.functionButtonBackground.cgColor
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttonViews = []
        // Leading ◀ back button while inside a subbar (F-253).
        if !barStack.isEmpty {
            let back = NSButton(title: "◀", target: self, action: #selector(popSubbar))
            back.bezelStyle = .texturedRounded
            back.toolTip = String(localized: "Back")
            stack.addArrangedSubview(back)
            buttonViews.append((back, nil))
        }
        for (index, button) in bar.buttons.enumerated() {
            let view: NSView
            if button.isSeparator {
                let sep = NSBox()
                sep.boxType = .separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                // A vertical bar needs a horizontal divider, and vice versa.
                sep.heightAnchor.constraint(equalToConstant: isVertical ? 1 : 20).isActive = true
                sep.widthAnchor.constraint(equalToConstant: isVertical ? 20 : 1).isActive = true
                view = sep
            } else {
                view = makeButton(button, tag: index)
            }
            stack.addArrangedSubview(view)
            buttonViews.append((view, button.isSeparator ? nil : button))
        }
        // Trailing overflow chevron (F-253), shown only when buttons don't fit.
        overflowChevron.bezelStyle = .texturedRounded
        overflowChevron.target = self
        overflowChevron.action = #selector(showOverflowMenu(_:))
        overflowChevron.toolTip = String(localized: "More buttons")
        overflowChevron.isHidden = true
        stack.addArrangedSubview(overflowChevron)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        // Only the horizontal strip overflows; the vertical column scrolls naturally.
        guard !isVertical, !relayingOverflow, !buttonViews.isEmpty else { return }
        relayingOverflow = true; defer { relayingOverflow = false }

        let available = bounds.width - stack.edgeInsets.left - stack.edgeInsets.right
        let widths = buttonViews.map { $0.view.fittingSize.width + stack.spacing }
        let total = widths.reduce(0, +)

        if total <= available {                       // everything fits → no chevron
            buttonViews.forEach { $0.view.isHidden = false }
            overflowButtons = []
            overflowChevron.isHidden = true
            return
        }
        let budget = available - overflowChevron.fittingSize.width - stack.spacing
        var used: CGFloat = 0
        overflowButtons = []
        for (i, entry) in buttonViews.enumerated() {
            if overflowButtons.isEmpty && used + widths[i] <= budget {
                used += widths[i]
                entry.view.isHidden = false
            } else {
                entry.view.isHidden = true
                if let model = entry.model { overflowButtons.append(model) }
            }
        }
        overflowChevron.isHidden = overflowButtons.isEmpty
    }

    @objc private func showOverflowMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for model in overflowButtons {
            let item = NSMenuItem(title: Self.label(for: model), action: #selector(runOverflow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = model
            if let icon = Self.loadIcon(model.icon) { icon.size = NSSize(width: 16, height: 16); item.image = icon }
            menu.addItem(item)
        }
        let origin = NSPoint(x: 0, y: sender.bounds.height)
        menu.popUp(positioning: nil, at: origin, in: sender)
    }

    @objc private func runOverflow(_ sender: NSMenuItem) {
        if let model = sender.representedObject as? BarButton { onRunButton?(model) }
    }

    private func makeButton(_ model: BarButton, tag: Int) -> NSButton {
        let button = DroppableButton(title: "", target: self, action: #selector(buttonClicked(_:)))
        button.tag = tag
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.toolTip = model.menu.isEmpty ? model.cmd : model.menu
        // Accept file drops onto this button (F-067) — separators excluded.
        if !model.isSeparator {
            button.onDropFiles = { [weak self] files in self?.onDropOnButton?(model, files) }
        }

        if let image = Self.loadIcon(model.icon) {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.imagePosition = .noImage
            button.title = Self.label(for: model)
        }
        return button
    }

    @objc private func buttonClicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < bar.buttons.count else { return }
        onRunButton?(bar.buttons[sender.tag])
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Edit Button Bar…"),
                     action: #selector(editBar), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func editBar() { onEditBar?() }

    // MARK: - Icons / labels

    private static func loadIcon(_ spec: String) -> NSImage? {
        guard !spec.isEmpty else { return nil }
        if spec.hasPrefix("sf:") {
            return NSImage(systemSymbolName: String(spec.dropFirst(3)), accessibilityDescription: nil)
        }
        if FileManager.default.fileExists(atPath: spec) {
            return NSWorkspace.shared.icon(forFile: spec)
        }
        return nil
    }

    /// A short human label when there is no icon: the tooltip, else a cleaned command.
    private static func label(for model: BarButton) -> String {
        if !model.menu.isEmpty { return model.menu }
        if model.cmd.hasPrefix("cm_") { return String(model.cmd.dropFirst(3)) }
        if model.cmd.hasPrefix("em_") { return String(model.cmd.dropFirst(3)) }
        return (model.cmd as NSString).lastPathComponent
    }
}

/// An NSButton that accepts dropped files and reports their paths (F-067).
final class DroppableButton: NSButton {
    var onDropFiles: (([String]) -> Void)?

    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }

    convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDropFiles != nil && Self.files(from: sender).count > 0 ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let files = Self.files(from: sender)
        guard let onDropFiles, !files.isEmpty else { return false }
        onDropFiles(files)
        return true
    }

    private static func files(from sender: NSDraggingInfo) -> [String] {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return [] }
        return urls.map(\.path)
    }
}
