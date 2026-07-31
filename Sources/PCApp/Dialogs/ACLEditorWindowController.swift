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
    /// Read the current ACL entries of `path`.
    static func read(_ path: String) -> [ACLEntry] {
        ACLEntry.parse(lsOutput: run("/bin/ls", ["-led", path]) ?? "")
    }

    /// Replace the ACL of `path` with `entries`. Returns nil on success or an error message.
    static func write(_ entries: [ACLEntry], to path: String) -> String? {
        _ = run("/bin/chmod", ["-N", path])                 // clear existing ACL
        for e in entries {
            // chmod inserts each rule; canonical ordering may reorder allow/deny — acceptable.
            if let err = runStderr("/bin/chmod", ["+a", e.ruleString, path]), !err.isEmpty {
                return "\(e.ruleString): \(err)"
            }
        }
        return nil
    }

    private static func run(_ launch: String, _ args: [String]) -> String? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: launch); p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    /// Run and return stderr text (nil = launch failed → treated as error by caller).
    private static func runStderr(_ launch: String, _ args: [String]) -> String? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: launch); p.arguments = args
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        do { try p.run() } catch { return "cannot launch chmod" }
        let data = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class ACLEditorWindowController: NSWindowController {
    private let path: String
    private let rowsStack = FlippedStackView()   // documentView: must be top-origin
    private var rows: [(kind: NSPopUpButton, name: NSTextField, action: NSPopUpButton, perms: NSTextField)] = []
    private let statusLabel = NSTextField(labelWithString: "")

    init(path: String) {
        self.path = path
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = String(localized: "Edit ACL")
        super.init(window: window)
        buildUI()
        for e in ACLStore.read(path) { addRow(e) }
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
        name.placeholderString = "maik1"
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
