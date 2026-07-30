// AttributesDialog.swift - Change POSIX permissions via checkboxes (TODOS #39).
//
// A 3×3 grid of read/write/execute checkboxes for owner/group/other (instead of a
// raw octal number), with a live "755 (rwxr-xr-x)" readout and a recursive option.
// Backed by the tested PosixPermissions model.

import AppKit
import PCFoundation

/// Read/list/remove POSIX extended attributes (xattr) on a path.
enum XattrStore {
    /// (name, byteSize) for every extended attribute on `path`, in system order.
    static func list(_ path: String) -> [(name: String, size: Int)] {
        let bufSize = listxattr(path, nil, 0, 0)
        guard bufSize > 0 else { return [] }
        var buffer = [CChar](repeating: 0, count: bufSize)
        let written = listxattr(path, &buffer, bufSize, 0)
        guard written > 0 else { return [] }
        var names: [String] = []
        var start = 0
        let bytes = buffer.prefix(written)
        for (i, c) in bytes.enumerated() where c == 0 {
            if i > start, let name = String(bytes: bytes[start..<i].map { UInt8(bitPattern: $0) }, encoding: .utf8) {
                names.append(name)
            }
            start = i + 1
        }
        return names.map { ($0, max(0, getxattr(path, $0, nil, 0, 0, 0))) }
    }

    /// Removes the named extended attribute; returns true on success.
    @discardableResult
    static func remove(_ name: String, from path: String) -> Bool {
        removexattr(path, name, 0) == 0
    }
}

final class AttributesDialog: NSWindowController {
    /// The set of changes chosen in the dialog. A nil field means "leave unchanged".
    struct Change {
        var mode: UInt16
        var recursive: Bool
        var bsdFlags: UInt32?
        var modified: Date?
        var ownerName: String?
        var groupName: String?
    }

    /// Called on Apply with the chosen changes.
    var onApply: ((Change) -> Void)?

    // BSD file flags we expose (settable by the owner without root).
    private static let UF_IMMUTABLE: UInt32 = 0x0000_0002   // "Locked" (uchg)
    private static let UF_HIDDEN: UInt32    = 0x0000_8000   // Finder-hidden

    private var perms: PosixPermissions
    private let path: String?
    private var boxes: [(who: PosixPermissions.Who, perm: PosixPermissions.Perm, button: NSButton)] = []
    private let octalLabel = NSTextField()   // editable octal entry (F-094)
    private let recursiveCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // F-094 additions: BSD flags, owner/group (chown), modification date.
    private let lockedCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hiddenCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let ownerField = NSTextField()
    private let groupField = NSTextField()
    private let changeDateCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let datePicker = NSDatePicker()
    private let xattrPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let xattrRemoveButton = NSButton(title: "", target: nil, action: nil)
    private var xattrs: [(name: String, size: Int)] = []

    // Seeded current values, so Apply only sends what actually changed.
    private var initialFlags: UInt32 = 0
    private var initialOwner = ""
    private var initialGroup = ""

    init(permissions: PosixPermissions, path: String? = nil) {
        self.perms = permissions
        self.path = path
        if let path { (initialFlags, initialOwner, initialGroup) = Self.currentMeta(path) }
        let hasXattrPath = path != nil
        let height: CGFloat = hasXattrPath ? 440 : 380
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: height),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = String(localized: "Change Attributes")
        super.init(window: window)
        buildUI()
        refreshOctal()
        reloadXattrs()
    }

    /// Read a path's current BSD flags, owner name and group name for seeding.
    private static func currentMeta(_ path: String) -> (flags: UInt32, owner: String, group: String) {
        var info = stat()
        let flags = lstat(path, &info) == 0 ? UInt32(info.st_flags) : 0
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let owner = (attrs?[.ownerAccountName] as? String) ?? ""
        let group = (attrs?[.groupOwnerAccountName] as? String) ?? ""
        return (flags, owner, group)
    }

    private static func currentModified(_ path: String?) -> Date? {
        guard let path else { return nil }
        return (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func runModalDialog() {
        guard let window else { return }
        window.center()
        NSApp.runModal(for: window)
        window.orderOut(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 12
        grid.rowSpacing = 6

        let header = [NSGridCell.emptyContentView,
                      label(String(localized: "Read")), label(String(localized: "Write")), label(String(localized: "Execute"))]
        grid.addRow(with: header)

        for who in PosixPermissions.Who.allCases {
            var row: [NSView] = [label(title(for: who))]
            for perm in PosixPermissions.Perm.allCases {
                let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggled(_:)))
                box.state = perms.has(who, perm) ? .on : .off
                boxes.append((who, perm, box))
                row.append(box)
            }
            grid.addRow(with: row)
        }
        content.addSubview(grid)

        octalLabel.font = Fonts.monospacedDigit13
        octalLabel.isEditable = true            // type an octal mode directly (e.g. 644)
        octalLabel.isBezeled = true
        octalLabel.target = self
        octalLabel.action = #selector(octalEdited)
        octalLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(octalLabel)

        recursiveCheck.title = String(localized: "Apply to enclosed items")
        recursiveCheck.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(recursiveCheck)

        // BSD flags (F-094): Locked (user-immutable) + Hidden.
        lockedCheck.title = String(localized: "Locked")
        lockedCheck.state = (initialFlags & Self.UF_IMMUTABLE) != 0 ? .on : .off
        hiddenCheck.title = String(localized: "Hidden")
        hiddenCheck.state = (initialFlags & Self.UF_HIDDEN) != 0 ? .on : .off
        let flagsStack = NSStackView(views: [lockedCheck, hiddenCheck])
        flagsStack.orientation = .horizontal
        flagsStack.spacing = 16
        flagsStack.translatesAutoresizingMaskIntoConstraints = false

        // Owner / group (F-094, chown — needs privileges for most changes).
        ownerField.stringValue = initialOwner
        ownerField.translatesAutoresizingMaskIntoConstraints = false
        ownerField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        groupField.stringValue = initialGroup
        groupField.translatesAutoresizingMaskIntoConstraints = false
        groupField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let ownerStack = NSStackView(views: [label(String(localized: "Owner:")), ownerField,
                                             label(String(localized: "Group:")), groupField])
        ownerStack.orientation = .horizontal
        ownerStack.spacing = 6
        ownerStack.translatesAutoresizingMaskIntoConstraints = false

        // Modification date (F-094): only applied when the checkbox is ticked.
        changeDateCheck.title = String(localized: "Modified:")
        changeDateCheck.state = .off
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
        datePicker.dateValue = Self.currentModified(path) ?? Date(timeIntervalSince1970: 0)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        let dateStack = NSStackView(views: [changeDateCheck, datePicker])
        dateStack.orientation = .horizontal
        dateStack.spacing = 8
        dateStack.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(flagsStack)
        content.addSubview(ownerStack)
        content.addSubview(dateStack)

        // Extended-attributes (xattr) inspector — only when editing a single path.
        let xattrLabel = label(String(localized: "Extended attributes:"))
        xattrLabel.font = Fonts.bold13
        xattrLabel.translatesAutoresizingMaskIntoConstraints = false
        xattrPopup.translatesAutoresizingMaskIntoConstraints = false
        xattrRemoveButton.title = String(localized: "Remove")
        xattrRemoveButton.bezelStyle = .rounded
        xattrRemoveButton.target = self
        xattrRemoveButton.action = #selector(removeXattrTapped)
        xattrRemoveButton.translatesAutoresizingMaskIntoConstraints = false
        if path != nil {
            content.addSubview(xattrLabel)
            content.addSubview(xattrPopup)
            content.addSubview(xattrRemoveButton)
        }

        let apply = NSButton(title: String(localized: "Apply"), target: self, action: #selector(applyTapped))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelTapped))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        // ACL editor (F-298): only meaningful for a concrete path.
        var buttonViews: [NSView] = [cancel, apply]
        if path != nil {
            let acl = NSButton(title: String(localized: "ACL…"), target: self, action: #selector(editACLTapped))
            acl.bezelStyle = .rounded
            buttonViews.insert(acl, at: 0)
        }
        let buttons = NSStackView(views: buttonViews)
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            octalLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 16),
            octalLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            recursiveCheck.topAnchor.constraint(equalTo: octalLabel.bottomAnchor, constant: 12),
            recursiveCheck.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            flagsStack.topAnchor.constraint(equalTo: recursiveCheck.bottomAnchor, constant: 12),
            flagsStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            ownerStack.topAnchor.constraint(equalTo: flagsStack.bottomAnchor, constant: 12),
            ownerStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            dateStack.topAnchor.constraint(equalTo: ownerStack.bottomAnchor, constant: 12),
            dateStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        if path != nil {
            NSLayoutConstraint.activate([
                xattrLabel.topAnchor.constraint(equalTo: dateStack.bottomAnchor, constant: 16),
                xattrLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                xattrPopup.topAnchor.constraint(equalTo: xattrLabel.bottomAnchor, constant: 6),
                xattrPopup.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                xattrPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
                xattrRemoveButton.centerYAnchor.constraint(equalTo: xattrPopup.centerYAnchor),
                xattrRemoveButton.leadingAnchor.constraint(equalTo: xattrPopup.trailingAnchor, constant: 10),
                xattrRemoveButton.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
                buttons.topAnchor.constraint(equalTo: xattrPopup.bottomAnchor, constant: 16),
            ])
        } else {
            buttons.topAnchor.constraint(equalTo: dateStack.bottomAnchor, constant: 16).isActive = true
        }
    }

    /// (Re)loads the extended-attribute list into the popup.
    private func reloadXattrs() {
        guard let path else { return }
        xattrs = XattrStore.list(path)
        xattrPopup.removeAllItems()
        if xattrs.isEmpty {
            xattrPopup.addItem(withTitle: String(localized: "(none)"))
            xattrPopup.isEnabled = false
            xattrRemoveButton.isEnabled = false
        } else {
            for x in xattrs {
                xattrPopup.addItem(withTitle: "\(x.name) — \(ByteSize(Int64(x.size)).formatted(style: .bytesWithSep))")
            }
            xattrPopup.isEnabled = true
            xattrRemoveButton.isEnabled = true
        }
    }

    @objc private func removeXattrTapped() {
        guard let path, !xattrs.isEmpty else { return }
        let index = xattrPopup.indexOfSelectedItem
        guard index >= 0, index < xattrs.count else { return }
        let name = xattrs[index].name
        if !XattrStore.remove(name, from: path) { NSSound.beep() }
        reloadXattrs()
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = Fonts.system13
        return field
    }

    private func title(for who: PosixPermissions.Who) -> String {
        switch who {
        case .owner: return String(localized: "Owner")
        case .group: return String(localized: "Group")
        case .other: return String(localized: "Others")
        }
    }

    @objc private func toggled(_ sender: NSButton) {
        for entry in boxes where entry.button === sender {
            perms.set(entry.who, entry.perm, sender.state == .on)
        }
        refreshOctal()
    }

    private func refreshOctal() {
        octalLabel.stringValue = "\(perms.octalString)   \(perms.symbolic)"
    }

    /// Parse a typed octal mode (the leading token, e.g. "644" in "644 rw-r--r--")
    /// and sync the checkbox grid; ignore invalid input.
    @objc private func octalEdited() {
        let token = octalLabel.stringValue.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        if !token.isEmpty, let v = UInt16(token, radix: 8) {
            perms = PosixPermissions(mode: v)
            for (who, perm, box) in boxes { box.state = perms.has(who, perm) ? .on : .off }
        }
        refreshOctal()
    }

    @objc private func applyTapped() {
        // BSD flags: send only when the user changed them from the seeded value.
        var newFlags = initialFlags
        newFlags = lockedCheck.state == .on ? (newFlags | Self.UF_IMMUTABLE) : (newFlags & ~Self.UF_IMMUTABLE)
        newFlags = hiddenCheck.state == .on ? (newFlags | Self.UF_HIDDEN) : (newFlags & ~Self.UF_HIDDEN)
        let bsdFlags: UInt32? = (newFlags != initialFlags) ? newFlags : nil

        // Owner / group: send only when changed and non-empty.
        let owner = ownerField.stringValue.trimmingCharacters(in: .whitespaces)
        let group = groupField.stringValue.trimmingCharacters(in: .whitespaces)
        let ownerName: String? = (!owner.isEmpty && owner != initialOwner) ? owner : nil
        let groupName: String? = (!group.isEmpty && group != initialGroup) ? group : nil

        let modified: Date? = changeDateCheck.state == .on ? datePicker.dateValue : nil

        onApply?(Change(mode: perms.mode, recursive: recursiveCheck.state == .on,
                        bsdFlags: bsdFlags, modified: modified,
                        ownerName: ownerName, groupName: groupName))
        NSApp.stopModal()
    }

    @objc private func cancelTapped() {
        NSApp.stopModal()
    }

    private var aclEditor: ACLEditorWindowController?
    @objc private func editACLTapped() {
        guard let path else { return }
        let editor = ACLEditorWindowController(path: path)
        aclEditor = editor                              // retain while the sheet is up
        guard let sheet = editor.window, let host = window else { editor.showWindow(nil); return }
        host.beginSheet(sheet) { [weak self] _ in self?.aclEditor = nil }
    }
}
