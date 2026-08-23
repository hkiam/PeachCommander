// SPDX-License-Identifier: Apache-2.0
// S3ConnectDialog.swift — the connect sheet.
//
// Modelled on `ConnectDialog` in Plugins/WebDAV/webdav.swift, including the trap noted there:
// a programmatically created NSWindow releases itself when it closes unless told otherwise, and this
// object holds a strong reference — so `isReleasedWhenClosed = false` is load-bearing, not tidiness.

import AppKit

/// What the user filled in. The secret is separate from the profile because the profile is written to
/// disk and the secret is not.
struct S3ConnectResult {
    let profile: S3Profile
    let secret: String
    /// Whether to keep this connection in the profile list (and its secret in the Keychain).
    let remember: Bool
}

final class S3ConnectDialog: NSObject, NSComboBoxDelegate {
    private let window: NSWindow
    private let profiles: [S3Profile]

    private let profileCombo = NSComboBox()
    private let hostField = NSTextField(string: "")
    private let regionField = NSTextField(string: "")
    private let keyField = NSTextField(string: "")
    private let secretField = NSSecureTextField(string: "")
    private let tlsCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pathStyleCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let anonymousCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rememberCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var confirmed = false

    init(profiles: [S3Profile]) {
        self.profiles = profiles
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
                          styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = L("Connect to S3 Storage")
        window.center()
        window.isReleasedWhenClosed = false
        build()
        apply(profiles.first ?? S3Profile.makeDefault())
    }

    func run() -> S3ConnectResult? {
        NSApp.runModal(for: window)
        window.orderOut(nil)
        guard confirmed else { return nil }
        let anonymous = anonymousCheck.state == .on
        let key = anonymous ? "" : keyField.stringValue.trimmingCharacters(in: .whitespaces)
        let secret = anonymous ? "" : secretField.stringValue
        let host = normalisedHost()
        let profile = S3Profile(
            name: profileCombo.stringValue.trimmingCharacters(in: .whitespaces),
            host: host,
            useTLS: tlsCheck.state == .on,
            region: regionField.stringValue.trimmingCharacters(in: .whitespaces),
            pathStyle: pathStyleCheck.state == .on,
            accessKeyID: key,
            anonymous: anonymous)
        guard !profile.host.isEmpty else { return nil }
        return S3ConnectResult(profile: profile, secret: secret,
                               remember: rememberCheck.state == .on && !profile.name.isEmpty)
    }

    /// Accept a pasted URL in the host field, because that is what people paste.
    private func normalisedHost() -> String {
        var host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        if let range = host.range(of: "://") { host = String(host[range.upperBound...]) }
        if let slash = host.firstIndex(of: "/") { host = String(host[host.startIndex..<slash]) }
        return host
    }

    // MARK: - Layout

    private func build() {
        guard let content = window.contentView else { return }
        profileCombo.addItems(withObjectValues: profiles.map(\.name))
        profileCombo.completes = true
        profileCombo.delegate = self

        tlsCheck.title = L("Use HTTPS")
        pathStyleCheck.title = L("Path-style addressing (MinIO, Ceph, an IP address)")
        anonymousCheck.title = L("Connect anonymously (public bucket)")
        anonymousCheck.target = self
        anonymousCheck.action = #selector(anonymousChanged)
        rememberCheck.title = L("Remember this connection")
        rememberCheck.state = .on

        let rows = NSStackView(views: [
            row(L("Name:"), profileCombo),
            row(L("Endpoint:"), hostField),
            row(L("Region:"), regionField),
            row(L("Access key ID:"), keyField),
            row(L("Secret access key:"), secretField),
            tlsCheck, pathStyleCheck, anonymousCheck, rememberCheck,
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(rows)

        let connect = NSButton(title: L("Connect"), target: self, action: #selector(ok))
        connect.bezelStyle = .rounded
        connect.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(dismiss))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, connect])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            rows.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            rows.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: rows.bottomAnchor, constant: 12),
        ])
    }

    private func row(_ label: String, _ field: NSView) -> NSView {
        let text = NSTextField(labelWithString: label)
        text.alignment = .right
        text.translatesAutoresizingMaskIntoConstraints = false
        text.widthAnchor.constraint(equalToConstant: 130).isActive = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
        let stack = NSStackView(views: [text, field])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    // MARK: - Behaviour

    private func apply(_ profile: S3Profile) {
        hostField.stringValue = profile.host
        regionField.stringValue = profile.region
        keyField.stringValue = profile.accessKeyID
        tlsCheck.state = profile.useTLS ? .on : .off
        pathStyleCheck.state = profile.pathStyle ? .on : .off
        anonymousCheck.state = profile.anonymous ? .on : .off
        if !profile.name.isEmpty { profileCombo.stringValue = profile.name }
        // The secret is deliberately left empty even for a saved profile: it lives in the Keychain,
        // and the connect path loads it when the field is blank. Pre-filling it would mean reading a
        // secret out of the Keychain to put it on screen, which is a thing to do only when asked.
        secretField.stringValue = ""
        anonymousChanged()
    }

    @objc private func anonymousChanged() {
        let anonymous = anonymousCheck.state == .on
        keyField.isEnabled = !anonymous
        secretField.isEnabled = !anonymous
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
        // Reading the selection here would give the *previous* index — AppKit posts this before the
        // field's value catches up. Deferred by one turn of the loop, which is the usual answer.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let index = self.profileCombo.indexOfSelectedItem
            guard index >= 0, index < self.profiles.count else { return }
            self.apply(self.profiles[index])
        }
    }

    @objc private func ok() { confirmed = true; NSApp.stopModal() }
    @objc private func dismiss() { confirmed = false; NSApp.stopModal() }
}
