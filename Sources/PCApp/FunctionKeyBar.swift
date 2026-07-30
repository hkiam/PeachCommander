// FunctionKeyBar.swift - Total Commander-style function-key bar (F-004).
//
// A row of clickable buttons at the very bottom of the window (F3 View … F8
// Delete). Clicking a button runs the same command as pressing the F-key, so the
// bar doubles as an always-visible reminder of the function keys. Holding Alt or
// Shift relabels the buttons (and changes what a click does), mirroring the F-key
// behavior in the panel: Alt+F5 Pack, Alt+F7 Find, Shift+F4 New, Shift+F8 Delete!.

import AppKit

final class FunctionKeyBar: NSView {
    /// Invoked with the cm_ command name when a button is clicked.
    var onRun: ((String) -> Void)?

    /// A function-key button: a non-translatable key prefix ("F3", "⇧F8") plus a
    /// localized verb. `title` composes them; the verb is localized through
    /// `localizedVerb` (literal `String(localized:)` calls so the strings get
    /// extracted into the catalog).
    private struct FKey {
        let key: String; let verb: String; let command: String
        var title: String { "\(key) \(FunctionKeyBar.localizedVerb(verb))" }
    }

    /// Base row (no modifiers).
    private static let base: [FKey] = [
        FKey(key: "F3", verb: "View", command: "cm_List"),
        FKey(key: "F4", verb: "Edit", command: "cm_Edit"),
        FKey(key: "F5", verb: "Copy", command: "cm_Copy"),
        FKey(key: "F6", verb: "Move", command: "cm_RenMov"),
        FKey(key: "F7", verb: "NewFolder", command: "cm_MkDir"),
        FKey(key: "F8", verb: "Delete", command: "cm_Delete"),
    ]
    /// Overrides when Shift is held (index-matched; nil = keep base).
    private static let shift: [FKey?] = [
        nil,
        FKey(key: "⇧F4", verb: "New", command: "cm_EditNewFile"),
        nil,
        FKey(key: "⇧F6", verb: "Rename", command: "cm_RenameOnly"),
        nil,
        FKey(key: "⇧F8", verb: "Delete!", command: "cm_DeleteReal"),
    ]
    /// Overrides when Alt/Option is held.
    private static let alt: [FKey?] = [
        nil, nil,
        FKey(key: "⌥F5", verb: "Pack", command: "cm_PackFiles"),
        nil,
        FKey(key: "⌥F7", verb: "Find", command: "cm_SearchFor"),
        nil,
    ]

    /// Localize a function-bar verb. Literal `String(localized:)` calls so the
    /// build-time extractor picks them up.
    private static func localizedVerb(_ verb: String) -> String {
        switch verb {
        case "View": return String(localized: "View")
        case "Edit": return String(localized: "Edit")
        case "Copy": return String(localized: "Copy")
        case "Move": return String(localized: "Move")
        case "NewFolder": return String(localized: "NewFolder")
        case "Delete": return String(localized: "Delete")
        case "New": return String(localized: "New")
        case "Rename": return String(localized: "Rename")
        case "Delete!": return String(localized: "Delete!")
        case "Pack": return String(localized: "Pack")
        case "Find": return String(localized: "Find")
        default: return verb
        }
    }

    static let barHeight: CGFloat = 24

    private let stack = NSStackView()
    private var buttons: [NSButton] = []
    private var commands: [String] = []
    private var flagsMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        build()
        applyTheme()
        apply(modifiers: [])
        // Track modifier keys so the labels update live while a key is held.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.apply(modifiers: event.modifierFlags)
            return event
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) } }

    private func build() {
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for i in Self.base.indices {
            let button = NSButton(title: "", target: self, action: #selector(clicked(_:)))
            button.tag = i
            button.bezelStyle = .regularSquare
            button.isBordered = true
            button.font = NSFont.systemFont(ofSize: 11)
            button.setButtonType(.momentaryPushIn)
            buttons.append(button)
            commands.append(Self.base[i].command)
            stack.addArrangedSubview(button)
        }
    }

    /// Update titles + click actions for the currently-held modifiers.
    private func apply(modifiers: NSEvent.ModifierFlags) {
        let overrides: [FKey?]
        if modifiers.contains(.option) { overrides = Self.alt }
        else if modifiers.contains(.shift) { overrides = Self.shift }
        else { overrides = Array(repeating: nil, count: Self.base.count) }
        for i in Self.base.indices {
            let entry = overrides[i] ?? Self.base[i]
            buttons[i].title = entry.title
            commands[i] = entry.command
        }
    }

    func applyTheme() {
        layer?.backgroundColor = Theme.current.functionButtonBackground.cgColor
    }

    @objc private func clicked(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < commands.count else { return }
        onRun?(commands[sender.tag])
    }
}
