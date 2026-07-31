// SPDX-License-Identifier: Apache-2.0
// DownloadURLWindowController.swift - wget-style "Download from URL" dialog (F-330).
//
// Collects one or more URLs (one per line) and, for a single URL, a cleaned,
// editable target filename (auto-suggested) plus an optional SHA-256 to verify.
// Also gathers optional Basic-auth credentials, custom request headers (Referer,
// Cookie, …), and toggles for background / queue-for-later / self-signed TLS.
// The URL box is pre-filled from the clipboard when it looks like a link.

import AppKit
import PCFoundation
import PCNet

struct DownloadBatchInput {
    var urls: [String]
    /// The edited target name — used only when there is exactly one URL.
    var singleFileName: String?
    var username: String
    var password: String
    var headers: [String: String]
    /// Expected SHA-256 to verify after download — single URL only.
    var expectedSHA256: String?
    var allowInsecureTLS: Bool
    var background: Bool
    var queueForLater: Bool
    /// Optional HTTP/SOCKS proxy for the request (F-330).
    var proxy: ProxyConfig?
}

final class DownloadURLWindowController: ModalWindowController, NSTextViewDelegate, NSTextFieldDelegate {
    var onStart: ((DownloadBatchInput) -> Void)?

    private let urlView = NSTextView()
    private let nameField = NSTextField()
    private let shaField = NSTextField()
    private let userField = NSTextField()
    private let passField = NSSecureTextField()
    private let headerView = NSTextView()
    private let proxyHostField = NSTextField()
    private let proxyPortField = NSTextField()
    private let proxyTypePopup = NSPopUpButton()
    private let countLabel = NSTextField(labelWithString: "")
    private let backgroundCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let queueCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let insecureCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var userEditedName = false

    init(prefillURL: String) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 470),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = String(localized: "Download from URL")
        super.init(window: window)
        window.delegate = self   // closing the window must end the modal session
        buildUI()
        if !prefillURL.isEmpty {
            urlView.string = prefillURL
            nameField.stringValue = DownloadName.suggested(fromURL: prefillURL)
        }
        updateForURLs()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func runModalDialog() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(urlView)
        NSApp.runModal(for: window)
    }

    private func makeTextArea(_ view: NSTextView, height: CGFloat) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: height).isActive = true
        view.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.delegate = self
        scroll.documentView = view
        return scroll
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        for f in [nameField, shaField, userField] { f.font = Fonts.system13; f.delegate = self }
        passField.font = Fonts.system13
        nameField.placeholderString = String(localized: "target file name")
        shaField.placeholderString = String(localized: "expected SHA-256 (optional)")
        shaField.font = Fonts.monospacedDigit13
        userField.placeholderString = String(localized: "user (optional)")
        passField.placeholderString = String(localized: "password (optional)")
        countLabel.font = NSFont.systemFont(ofSize: 11); countLabel.textColor = .secondaryLabelColor
        backgroundCheck.title = String(localized: "Download in background"); backgroundCheck.state = .on
        queueCheck.title = String(localized: "Queue for later (don't start yet)")
        insecureCheck.title = String(localized: "Allow untrusted certificate")

        func labeled(_ title: String, _ control: NSView, baseline: Bool = true) -> NSView {
            let l = NSTextField(labelWithString: title); l.font = Fonts.system13; l.alignment = .right
            l.widthAnchor.constraint(equalToConstant: 90).isActive = true
            l.setContentHuggingPriority(.required, for: .horizontal)
            let row = NSStackView(views: [l, control]); row.orientation = .horizontal
            row.spacing = 8; row.alignment = baseline ? .firstBaseline : .top
            return row
        }
        let creds = NSStackView(views: [userField, passField]); creds.spacing = 8; creds.distribution = .fillEqually

        let ok = NSButton(title: String(localized: "Download"), target: self, action: #selector(startTapped))
        ok.bezelStyle = .rounded; ok.keyEquivalent = "\r"
        let cancel = NSButton(title: String(localized: "Cancel"), target: self, action: #selector(cancelTapped))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, ok]); buttons.spacing = 10

        let hint = NSTextField(labelWithString: String(localized: "Headers, one per line — e.g. “Referer: …” or “Cookie: …”"))
        hint.font = NSFont.systemFont(ofSize: 10); hint.textColor = .secondaryLabelColor

        // Optional proxy row: host, port, type.
        proxyHostField.font = Fonts.system13; proxyHostField.placeholderString = String(localized: "proxy host (optional)")
        proxyPortField.font = Fonts.system13; proxyPortField.placeholderString = String(localized: "port")
        proxyPortField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        proxyTypePopup.addItems(withTitles: ["HTTP", "SOCKS5"])
        let proxyRow = NSStackView(views: [proxyHostField, proxyPortField, proxyTypePopup])
        proxyRow.spacing = 8

        let stack = NSStackView(views: [
            labeled(String(localized: "URL(s):"), makeTextArea(urlView, height: 60), baseline: false),
            countLabel,
            labeled(String(localized: "Save as:"), nameField),
            labeled(String(localized: "Verify:"), shaField),
            labeled(String(localized: "Auth:"), creds),
            labeled(String(localized: "Proxy:"), proxyRow),
            labeled(String(localized: "Headers:"), makeTextArea(headerView, height: 44), baseline: false),
            hint,
            backgroundCheck, queueCheck, insecureCheck,
        ])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack); content.addSubview(buttons)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])
    }

    /// The non-empty, trimmed URL lines.
    private func urls() -> [String] {
        urlView.string.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Enable per-file controls only for a single URL; show a count for batches.
    private func updateForURLs() {
        let list = urls()
        let single = list.count == 1
        nameField.isEnabled = single
        shaField.isEnabled = single
        if single, !userEditedName { nameField.stringValue = DownloadName.suggested(fromURL: list[0]) }
        if list.count > 1 {
            countLabel.stringValue = String(localized: "\(list.count) URLs — file names are derived automatically")
            nameField.stringValue = ""
        } else {
            countLabel.stringValue = ""
        }
    }

    func textDidChange(_ notification: Notification) {
        if (notification.object as? NSTextView) === urlView { updateForURLs() }
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as? NSTextField) === nameField { userEditedName = true }
    }

    private func parseHeaders() -> [String: String] {
        var out: [String: String] = [:]
        for line in headerView.string.split(whereSeparator: \.isNewline) {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, !value.isEmpty { out[name] = value }
        }
        return out
    }

    @objc private func startTapped() {
        let list = urls()
        guard !list.isEmpty else { NSSound.beep(); return }
        let sha = shaField.stringValue.trimmingCharacters(in: .whitespaces)
        // Optional proxy (host required; port defaults per type).
        var proxy: ProxyConfig?
        let proxyHost = proxyHostField.stringValue.trimmingCharacters(in: .whitespaces)
        if !proxyHost.isEmpty {
            let kind: ProxyKind = proxyTypePopup.indexOfSelectedItem == 1 ? .socks5 : .http
            let port = Int(proxyPortField.stringValue.trimmingCharacters(in: .whitespaces)) ?? (kind == .socks5 ? 1080 : 8080)
            proxy = ProxyConfig(kind: kind, host: proxyHost, port: port)
        }
        NSApp.stopModal(); window?.orderOut(nil)
        onStart?(DownloadBatchInput(
            urls: list,
            singleFileName: list.count == 1 ? DownloadName.sanitize(nameField.stringValue) : nil,
            username: userField.stringValue.trimmingCharacters(in: .whitespaces),
            password: passField.stringValue,
            headers: parseHeaders(),
            expectedSHA256: (list.count == 1 && !sha.isEmpty) ? sha : nil,
            allowInsecureTLS: insecureCheck.state == .on,
            background: backgroundCheck.state == .on,
            queueForLater: queueCheck.state == .on,
            proxy: proxy))
    }

    @objc private func cancelTapped() { NSApp.stopModal(); window?.orderOut(nil) }
}
