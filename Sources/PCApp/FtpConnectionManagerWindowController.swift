// SPDX-License-Identifier: Apache-2.0
// FtpConnectionManagerWindowController.swift - Saved FTP sites manager (I15, cm_FtpConnect).
//
// Lists the sites from ftp-sites.ini on the left, a detail form on the right
// (name/host/port/protocol/user/anonymous/password/remote-dir/passive). New/Delete/
// Save persist the .ini (passwords go to the Keychain via FtpCredentials, never the
// file). Connect hands the selected site + password back to the owner.

import AppKit
import PCFoundation
import PCNet

final class FtpConnectionManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    /// Connect to the selected site with the entered password.
    var onConnect: ((FtpSite, String) -> Void)?

    private let sitesURL: URL
    private let store: SecretStore
    private var sites: [FtpSite]

    private let tableView = NSTableView()
    private let nameField = NSTextField()
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let userField = NSTextField()
    private let passwordField = NSSecureTextField()
    private let remoteDirField = NSTextField()
    private let protoPopup = NSPopUpButton()
    private let anonymousCheck = NSButton(checkboxWithTitle: "Anonymous", target: nil, action: nil)
    private let passiveCheck = NSButton(checkboxWithTitle: "Passive mode (PASV/EPSV)", target: nil, action: nil)
    private let proxyHostField = NSTextField()   // F-212: SOCKS5 proxy for plain FTP
    private let proxyPortField = NSTextField()
    private let proxyTypePopup = NSPopUpButton()
    private let scpCheck = NSButton(checkboxWithTitle: "Transfer via SCP (SFTP only)", target: nil, action: nil)
    private let insecureTLSCheck = NSButton(checkboxWithTitle: "Accept self-signed certificate (FTPS)", target: nil, action: nil)
    private var updatingForm = false

    private static let protoOrder: [FtpProtocol] = [.ftp, .ftpsImplicit, .ftps, .sftp]
    private static let protoNames = ["FTP", "FTPS (implicit)", "FTPS (explicit)", "SFTP"]

    init(sitesURL: URL, store: SecretStore) {
        self.sitesURL = sitesURL
        self.store = store
        let text = (try? String(contentsOf: sitesURL, encoding: .utf8)) ?? ""
        self.sites = FtpSitesFile.parse(text)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 420),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "FTP Connection Manager")
        super.init(window: window)
        buildUI()
        if !sites.isEmpty { selectRow(0) } else { updateForm() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        tableView.headerView = nil
        tableView.addTableColumn(NSTableColumn(identifier: .init("c")))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        let listScroll = NSScrollView()
        listScroll.documentView = tableView
        listScroll.hasVerticalScroller = true
        listScroll.borderType = .bezelBorder
        listScroll.translatesAutoresizingMaskIntoConstraints = false

        let newBtn = bar(String(localized: "New"), #selector(newSite))
        let delBtn = bar(String(localized: "Delete"), #selector(deleteSite))
        let listButtons = NSStackView(views: [newBtn, delBtn])
        listButtons.orientation = .horizontal; listButtons.spacing = 6
        listButtons.translatesAutoresizingMaskIntoConstraints = false

        for f in [nameField, hostField, portField, userField, remoteDirField] { f.delegate = self }
        passwordField.delegate = self
        for p in Self.protoNames { protoPopup.addItem(withTitle: p) }
        protoPopup.target = self; protoPopup.action = #selector(formControlChanged)
        anonymousCheck.title = String(localized: "Anonymous")
        anonymousCheck.target = self; anonymousCheck.action = #selector(formControlChanged)
        passiveCheck.target = self; passiveCheck.action = #selector(formControlChanged)
        scpCheck.title = String(localized: "Transfer via SCP (SFTP only)")
        scpCheck.target = self; scpCheck.action = #selector(formControlChanged)
        insecureTLSCheck.title = String(localized: "Accept self-signed certificate (FTPS)")
        insecureTLSCheck.target = self; insecureTLSCheck.action = #selector(formControlChanged)
        for k in ProxyKind.allCases { proxyTypePopup.addItem(withTitle: k.rawValue.uppercased()) }
        proxyTypePopup.target = self; proxyTypePopup.action = #selector(formControlChanged)
        proxyHostField.placeholderString = String(localized: "host (blank = direct)")
        proxyPortField.placeholderString = String(localized: "port")
        proxyPortField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        for f in [proxyHostField, proxyPortField] { f.delegate = self }
        let proxyRow = NSStackView(views: [proxyHostField, proxyPortField, proxyTypePopup])
        proxyRow.orientation = .horizontal; proxyRow.spacing = 6
        proxyPortField.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let form = NSGridView(views: [
            [label(String(localized: "Name:")), nameField],
            [label(String(localized: "Host:")), hostField],
            [label(String(localized: "Port:")), portField],
            [label(String(localized: "Protocol:")), protoPopup],
            [label(String(localized: "User:")), userField],
            [NSGridCell.emptyContentView, anonymousCheck],
            [label(String(localized: "Password:")), passwordField],
            [label(String(localized: "Remote dir:")), remoteDirField],
            [NSGridCell.emptyContentView, passiveCheck],
            [label(String(localized: "Proxy:")), proxyRow],
            [NSGridCell.emptyContentView, scpCheck],
            [NSGridCell.emptyContentView, insecureTLSCheck]
        ])
        form.translatesAutoresizingMaskIntoConstraints = false
        form.rowSpacing = 7; form.columnSpacing = 8
        form.column(at: 1).xPlacement = .fill
        form.column(at: 1).width = 300

        let connect = NSButton(title: String(localized: "Connect"), target: self, action: #selector(connect))
        connect.bezelStyle = .rounded; connect.keyEquivalent = "\r"
        let save = NSButton(title: String(localized: "Save"), target: self, action: #selector(saveSites))
        save.bezelStyle = .rounded
        let close = NSButton(title: String(localized: "Close"), target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded; close.keyEquivalent = "\u{1b}"
        let bottom = NSStackView(views: [close, NSView(), save, connect])
        bottom.orientation = .horizontal; bottom.translatesAutoresizingMaskIntoConstraints = false

        for v in [listScroll, listButtons, form, bottom] { content.addSubview(v) }
        NSLayoutConstraint.activate([
            listScroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            listScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            listScroll.widthAnchor.constraint(equalToConstant: 200),
            listScroll.bottomAnchor.constraint(equalTo: listButtons.topAnchor, constant: -6),
            listButtons.leadingAnchor.constraint(equalTo: listScroll.leadingAnchor),
            listButtons.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -12),
            form.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            form.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor, constant: 16),
            form.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
            bottom.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bottom.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottom.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
    }

    private func label(_ s: String) -> NSTextField { let l = NSTextField(labelWithString: s); l.alignment = .right; return l }
    private func bar(_ t: String, _ s: Selector) -> NSButton {
        let b = NSButton(title: t, target: self, action: s); b.bezelStyle = .rounded; return b
    }

    // MARK: - Selection / form

    private var selected: Int { tableView.selectedRow }

    private func selectRow(_ row: Int) {
        guard sites.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        updateForm()
    }

    private func updateForm() {
        updatingForm = true; defer { updatingForm = false }
        let on = sites.indices.contains(selected)
        for c in [nameField, hostField, portField, userField, passwordField, remoteDirField] { c.isEnabled = on }
        protoPopup.isEnabled = on; anonymousCheck.isEnabled = on; passiveCheck.isEnabled = on
        for c in [proxyHostField, proxyPortField] { c.isEnabled = on }; proxyTypePopup.isEnabled = on
        scpCheck.isEnabled = on && sites.indices.contains(selected) && sites[selected].proto == .sftp
        insecureTLSCheck.isEnabled = on && sites.indices.contains(selected)
            && (sites[selected].proto == .ftpsImplicit || sites[selected].proto == .ftps)
        let s = on ? sites[selected] : FtpSite(name: "", host: "")
        nameField.stringValue = s.name
        hostField.stringValue = s.host
        portField.stringValue = String(s.port)
        userField.stringValue = s.user
        remoteDirField.stringValue = s.remoteDir
        protoPopup.selectItem(at: Self.protoOrder.firstIndex(of: s.proto) ?? 0)
        anonymousCheck.state = s.auth == .anonymous ? .on : .off
        passiveCheck.state = s.passive ? .on : .off
        proxyHostField.stringValue = s.proxyHost ?? ""
        proxyPortField.stringValue = String(s.proxyPort)
        proxyTypePopup.selectItem(at: ProxyKind.allCases.firstIndex(of: s.proxyType) ?? 0)
        scpCheck.state = s.useSCP ? .on : .off
        insecureTLSCheck.state = s.allowInsecureTLS ? .on : .off
        let storedPassword = on ? ((try? FtpCredentials.password(for: s, in: store)) ?? nil) : nil
        passwordField.stringValue = storedPassword ?? ""
    }

    private func commitForm() {
        guard sites.indices.contains(selected), !updatingForm else { return }
        var s = sites[selected]
        s.name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        s.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        s.port = Int(portField.stringValue) ?? s.proto.defaultPort
        s.proto = Self.protoOrder[max(0, protoPopup.indexOfSelectedItem)]
        s.user = userField.stringValue.trimmingCharacters(in: .whitespaces)
        s.remoteDir = remoteDirField.stringValue
        s.auth = anonymousCheck.state == .on ? .anonymous : .password
        s.passive = passiveCheck.state == .on
        let ph = proxyHostField.stringValue.trimmingCharacters(in: .whitespaces)
        s.proxyHost = ph.isEmpty ? nil : ph
        s.proxyPort = Int(proxyPortField.stringValue) ?? s.proxyPort
        s.proxyType = ProxyKind.allCases[max(0, proxyTypePopup.indexOfSelectedItem)]
        s.useSCP = scpCheck.state == .on
        s.allowInsecureTLS = insecureTLSCheck.state == .on
        sites[selected] = s
        tableView.reloadData(forRowIndexes: IndexSet(integer: selected), columnIndexes: IndexSet(integer: 0))
    }

    @objc private func formControlChanged() { commitForm() }
    func controlTextDidChange(_ obj: Notification) { commitForm() }
    func tableViewSelectionDidChange(_ notification: Notification) { updateForm() }

    // MARK: - Actions

    @objc private func newSite() {
        let s = FtpSite(name: String(localized: "New Site"), host: "", proto: .ftp, user: "anonymous", auth: .anonymous)
        sites.append(s)
        tableView.reloadData()
        selectRow(sites.count - 1)
        window?.makeFirstResponder(nameField)
    }

    @objc private func deleteSite() {
        guard sites.indices.contains(selected) else { return }
        let row = selected
        sites.remove(at: row)
        tableView.reloadData()
        selectRow(min(row, sites.count - 1))
        updateForm()
        persist()
    }

    @objc private func saveSites() { window?.makeFirstResponder(nil); commitForm(); persist() }

    /// Write ftp-sites.ini + store the current site's password in the Keychain.
    private func persist() {
        try? FtpSitesFile.serialize(sites).write(to: sitesURL, atomically: true, encoding: .utf8)
        if sites.indices.contains(selected) {
            let s = sites[selected]
            let pw = passwordField.stringValue
            if s.auth == .password, !pw.isEmpty {
                try? FtpCredentials.savePassword(pw, for: s, in: store)
            }
        }
    }

    @objc private func connect() {
        window?.makeFirstResponder(nil)
        commitForm()
        guard sites.indices.contains(selected) else { NSSound.beep(); return }
        let site = sites[selected]
        guard !site.host.isEmpty else { NSSound.beep(); return }
        persist()   // save before connecting so the site/password stick
        onConnect?(site, passwordField.stringValue)
        close()
    }

    @objc private func closeWindow() { close() }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { sites.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = id; f.lineBreakMode = .byTruncatingTail; return f }()
        let s = sites[row]
        field.stringValue = s.name.isEmpty ? s.host : s.name
        return field
    }
}
