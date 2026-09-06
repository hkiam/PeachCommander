// SPDX-License-Identifier: Apache-2.0
// ACLEditorWindowController.swift - GUI editor for macOS ACLs (F-298).
//
// Reads the current access-control list of a path via `/bin/ls -led`, edits it as a
// list of rows (kind · name · allow/deny · permissions), and writes it back by
// clearing all ACLs (`chmod -N`) and re-adding each row (`chmod +a`). The parsing and
// rule-string round-trip live in the tested PCFoundation `ACLEntry` model.

import AppKit
import PCFoundation

/// Runs `ls`/`chmod` to read and write a path's ACL.
enum ACLStore {
    /// Seconds `ls` or `chmod` may take before they are stopped.
    ///
    /// The deadline is the point of this file's rewrite. Both commands are instant on a disk and on a
    /// stalled network mount they do not return at all — and both are called straight from the ACL
    /// window, on the main thread, about a path the user picked in a panel. Without it, opening the
    /// editor on a share that has gone away is a beachball with no way out. `TextPipe` bounds the
    /// editor's filter commands for the same reason and with the same shape, which is the shape used
    /// here.
    private static let timeout = 20

    /// Read the current ACL entries of `path`, or **nil** when they could not be read.
    ///
    /// Nil rather than an empty array, and that distinction is the whole point: `[]` is a valid
    /// answer meaning "this file has no ACL", and Apply writes exactly that — `chmod -N` clears the
    /// list and then there is nothing to add back. So a read that failed must not arrive as the same
    /// value as a file without an ACL, or a stalled mount would silently wipe the very list nobody
    /// could see. It used to be `run(…) ?? ""`, which conflated the two.
    static func read(_ path: String) -> [ACLEntry]? {
        guard let result = BoundedProcess.run("/bin/ls", ["-led", path], timeout: timeout) else { return nil }
        return ACLEntry.parse(lsOutput: result.out)
    }

    /// Replace the ACL of `path` with `entries`. Returns nil on success or an error message.
    static func write(_ entries: [ACLEntry], to path: String) -> String? {
        guard BoundedProcess.run("/bin/chmod", ["-N", path], timeout: timeout) != nil else {   // clear existing ACL
            return String(localized: "Timed out after \(timeout) seconds.")
        }
        for e in entries {
            // chmod inserts each rule; canonical ordering may reorder allow/deny — acceptable.
            guard let result = BoundedProcess.run("/bin/chmod", ["+a", e.ruleString, path], timeout: timeout) else {
                return "\(e.ruleString): " + String(localized: "Timed out after \(timeout) seconds.")
            }
            let message = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty { return "\(e.ruleString): \(message)" }
        }
        return nil
    }

}

final class ACLEditorWindowController: NSWindowController {
    private let path: String
    private let rowsStack = FlippedStackView()   // documentView: must be top-origin
    private var rows: [(kind: NSPopUpButton, name: NSTextField, action: NSPopUpButton, perms: NSTextField)] = []
    private let statusLabel = NSTextField(labelWithString: "")
    /// The file's ACL never arrived, so the rows on screen are not a picture of it (see `init`).
    private var couldNotRead = false

    init(path: String) {
        self.path = path
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "Edit ACL")
        super.init(window: window)
        buildUI()
        if let entries = ACLStore.read(path) {
            for e in entries { addRow(e) }
        } else {
            // Say so, and remember it: an empty list here does not mean "no ACL", it means nobody
            // could read one, and Apply must not write that over what is on the file.
            couldNotRead = true
            statusLabel.stringValue = String(localized: "The current ACL could not be read.")
        }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let heading = NSTextField(labelWithString:
            String(localized: "Access-control entries for:") + " " + (path as NSString).lastPathComponent)
        heading.font = .boldSystemFont(ofSize: 12)
        heading.lineBreakMode = .byTruncatingMiddle
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(heading)

        let cols = NSStackView(views: [
            colLabel(String(localized: "Kind"), 90),
            colLabel(String(localized: "Name"), 130),
            colLabel(String(localized: "Access"), 80),
            colLabel(String(localized: "Permissions (comma-separated)"), 180),
        ])
        cols.spacing = 8
        cols.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(cols)

        rowsStack.orientation = .vertical
        rowsStack.alignment = .leading
        rowsStack.spacing = 6
        rowsStack.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = rowsStack
        content.addSubview(scroll)

        let add = NSButton(title: String(localized: "Add Entry"), target: self, action: #selector(addTapped))
        add.bezelStyle = .rounded
        add.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(add)

        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .systemRed
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(statusLabel)

        let apply = NSButton(title: String(localized: "Apply"), target: self, action: #selector(applyTapped))
        apply.bezelStyle = .rounded; apply.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelTapped))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, apply]); buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            cols.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 10),
            cols.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
            scroll.topAnchor.constraint(equalTo: cols.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: add.topAnchor, constant: -10),
            rowsStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            add.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            add.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            statusLabel.leadingAnchor.constraint(equalTo: add.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: add.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])
    }

    private func colLabel(_ text: String, _ width: CGFloat) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = NSFont.systemFont(ofSize: 11)
        f.textColor = .secondaryLabelColor
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        return f
    }

    private func addRow(_ entry: ACLEntry?) {
        let kind = NSPopUpButton()
        kind.addItems(withTitles: ACLEntry.Kind.allCases.map { $0.rawValue })
        kind.selectItem(withTitle: (entry?.kind ?? .user).rawValue)
        kind.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let name = NSTextField(string: entry?.name ?? "")
        // The person using the app, not the person who wrote it: this shipped showing the author's
        // account name, which is both a privacy slip and useless as a hint. `NSUserName` is the
        // short name an ACL actually wants, and it is right on every machine.
        name.placeholderString = NSUserName()
        name.widthAnchor.constraint(equalToConstant: 130).isActive = true

        let action = NSPopUpButton()
        action.addItems(withTitles: ACLEntry.Action.allCases.map { $0.rawValue })
        action.selectItem(withTitle: (entry?.action ?? .allow).rawValue)
        action.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let perms = NSTextField(string: entry?.permissions.joined(separator: ",") ?? "read")
        perms.placeholderString = "read,write,delete"
        perms.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let remove = NSButton(title: "–", target: self, action: #selector(removeTapped(_:)))
        remove.bezelStyle = .rounded
        let row = NSStackView(views: [kind, name, action, perms, remove])
        row.spacing = 8
        rowsStack.addArrangedSubview(row)
        rows.append((kind, name, action, perms))
    }

    @objc private func addTapped() { addRow(nil) }

    @objc private func removeTapped(_ sender: NSButton) {
        guard let row = sender.superview as? NSStackView,
              let idx = rowsStack.arrangedSubviews.firstIndex(of: row) else { return }
        rowsStack.removeArrangedSubview(row); row.removeFromSuperview()
        if rows.indices.contains(idx) { rows.remove(at: idx) }
    }

    /// Collect the current rows into ACL entries (skipping rows without a name).
    private func collectEntries() -> [ACLEntry] {
        rows.compactMap { r in
            let n = r.name.stringValue.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return nil }
            let perms = r.perms.stringValue.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !perms.isEmpty,
                  let kind = ACLEntry.Kind(rawValue: r.kind.titleOfSelectedItem ?? "user"),
                  let action = ACLEntry.Action(rawValue: r.action.titleOfSelectedItem ?? "allow") else { return nil }
            return ACLEntry(kind: kind, name: n, action: action, permissions: perms)
        }
    }

    @objc private func applyTapped() {
        window?.makeFirstResponder(nil)
        // Writing now would clear an ACL nobody was able to see: `chmod -N` empties the list and the
        // rows on screen — none, or whatever was typed since — are all there would be to put back.
        if couldNotRead {
            statusLabel.stringValue = String(localized: "The current ACL could not be read.")
            NSSound.beep()
            return
        }
        if let err = ACLStore.write(collectEntries(), to: path) {
            statusLabel.stringValue = err
            NSSound.beep()
            return
        }
        dismiss()
    }

    @objc private func cancelTapped() { dismiss() }

    /// Dismiss whether presented as a sheet or as a standalone window.
    private func dismiss() {
        guard let win = window else { return }
        if let parent = win.sheetParent { parent.endSheet(win) } else { close() }
    }
}
