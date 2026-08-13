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
    // A proxy that asks for a login had a user and a password in the model and a `proxyuser` key in the
    // ini, and no way to set either — so an authenticated proxy could not be used at all (F-210).
    private let proxyUserField = NSTextField()
    private let proxyPasswordField = NSSecureTextField()
    private let scpCheck = NSButton(checkboxWithTitle: "Transfer via SCP (SFTP only)", target: nil, action: nil)
    private let insecureTLSCheck = NSButton(checkboxWithTitle: "Accept self-signed certificate (FTPS)", target: nil, action: nil)
    /// What is wrong with the site as it currently stands, in the same words `connectToSite`
    /// would refuse it with. Shown while typing rather than on Connect: the point is to stop a
    /// combination being saved, not to complain about it after the fact.
    private let warningLabel = NSTextField(wrappingLabelWithString: "")
    private var updatingForm = false

    private static let protoOrder: [FtpProtocol] = [.ftp, .ftpsImplicit, .ftps, .sftp]
    private static let protoNames = ["FTP", "FTPS (implicit)", "FTPS (explicit)", "SFTP"]

    init(sitesURL: URL, store: SecretStore) {
        self.sitesURL = sitesURL
        self.store = store
        let text = (try? String(contentsOf: sitesURL, encoding: .utf8)) ?? ""
        self.sites = FtpSitesFile.parse(text)
        // Taller than the 420 it was: thirteen form rows already did not fit in it, and the warning
        // line under them has to be readable without resizing the window to find out what is wrong.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
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
        protoPopup.target = self; protoPopup.action = #selector(protocolChanged)
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
        proxyUserField.placeholderString = String(localized: "user (blank = no login)")
        proxyPasswordField.placeholderString = String(localized: "password")
        for f in [proxyHostField, proxyPortField, proxyUserField] { f.delegate = self }
        proxyPasswordField.delegate = self
        let proxyRow = NSStackView(views: [proxyHostField, proxyPortField, proxyTypePopup])
        proxyRow.orientation = .horizontal; proxyRow.spacing = 6
        proxyPortField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        let proxyLoginRow = NSStackView(views: [proxyUserField, proxyPasswordField])
        proxyLoginRow.orientation = .horizontal; proxyLoginRow.spacing = 6

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
            [label(String(localized: "Proxy login:")), proxyLoginRow],
            [NSGridCell.emptyContentView, scpCheck],
            [NSGridCell.emptyContentView, insecureTLSCheck]
        ])
        form.translatesAutoresizingMaskIntoConstraints = false
        form.rowSpacing = 7; form.columnSpacing = 8
        form.column(at: 1).xPlacement = .fill
        form.column(at: 1).width = 300

        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        warningLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        warningLabel.textColor = .systemOrange
        warningLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let connect = NSButton(title: String(localized: "Connect"), target: self, action: #selector(connect))
        connect.bezelStyle = .rounded; connect.keyEquivalent = "\r"
        let save = NSButton(title: String(localized: "Save"), target: self, action: #selector(saveSites))
        save.bezelStyle = .rounded
        let close = NSButton(title: String(localized: "Close"), target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded; close.keyEquivalent = "\u{1b}"
        let bottom = NSStackView(views: [close, NSView(), save, connect])
        bottom.orientation = .horizontal; bottom.translatesAutoresizingMaskIntoConstraints = false

        for v in [listScroll, listButtons, form, warningLabel, bottom] { content.addSubview(v) }
        NSLayoutConstraint.activate([
            warningLabel.topAnchor.constraint(greaterThanOrEqualTo: form.bottomAnchor, constant: 8),
            warningLabel.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            warningLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            warningLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottom.topAnchor, constant: -8),
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

    /// Fill the whole form from the selected site. Only on a *selection* change: it rewrites the
    /// password field from the Keychain, so calling it while the user is filling the form in
    /// would throw away a password they had typed but not yet saved.
    private func updateForm() {
        updatingForm = true; defer { updatingForm = false }
        let on = sites.indices.contains(selected)
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
        proxyUserField.stringValue = s.proxyUser ?? ""
        // The proxy password lives in the Keychain like the site's own, never in ftp-sites.ini.
        proxyPasswordField.stringValue = ((try? FtpCredentials.proxyPassword(for: s, in: store)) ?? nil) ?? ""
        scpCheck.state = s.useSCP ? .on : .off
        insecureTLSCheck.state = s.allowInsecureTLS ? .on : .off
        let storedPassword = on ? ((try? FtpCredentials.password(for: s, in: store)) ?? nil) : nil
        passwordField.stringValue = storedPassword ?? ""
        updateEnabledState()
    }

    /// Grey out every setting the selected protocol does not read, and say what is left that
    /// cannot work. Cheap and re-run on every keystroke and click, so the form answers "does this
    /// combination mean anything" while it is being built rather than when Connect is pressed.
    private func updateEnabledState() {
        let on = sites.indices.contains(selected)
        let s = on ? sites[selected] : FtpSite(name: "", host: "")
        func gate(_ setting: FtpSiteSetting) -> Bool {
            on && FtpConnectionRules.applies(setting, to: s)
        }
        for c in [nameField, hostField, portField, remoteDirField] { c.isEnabled = on }
        protoPopup.isEnabled = on
        userField.isEnabled = gate(.user)
        passwordField.isEnabled = gate(.password)
        anonymousCheck.isEnabled = gate(.anonymous)
        passiveCheck.isEnabled = gate(.passive)
        for c in [proxyHostField, proxyPortField] { c.isEnabled = gate(.proxy) }
        proxyTypePopup.isEnabled = gate(.proxy)
        proxyUserField.isEnabled = gate(.proxyLogin)
        proxyPasswordField.isEnabled = gate(.proxyLogin)
        scpCheck.isEnabled = gate(.scp)
        insecureTLSCheck.isEnabled = gate(.insecureTLS)
        // An anonymous login is "anonymous" — showing the previous user name in a field the user
        // can no longer edit says the connection will use it, and it will not.
        if on, s.auth == .anonymous { userField.stringValue = s.user }
        // Passive is not optional behind a proxy; the box is ticked and locked rather than left
        // showing a choice that the connection would override anyway.
        if on, !FtpConnectionRules.applies(.passive, to: s), s.proto != .sftp {
            passiveCheck.state = .on
        }
        let problems = on ? FtpConnectionRules.problems(with: s) : []
        warningLabel.stringValue = problems.map(MainWindowController.describe).joined(separator: "\n")
        warningLabel.textColor = problems.contains(where: \.isBlocking) ? .systemRed : .systemOrange
    }

    private func commitForm() {
        guard sites.indices.contains(selected), !updatingForm else { return }
        var s = sites[selected]
        s.name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        s.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        // Protocol before port: the port's fallback is "this protocol's default", and reading it
        // from the protocol being replaced gave an ftp 21 to a site the user had just made SFTP.
        s.proto = Self.protoOrder[max(0, protoPopup.indexOfSelectedItem)]
        s.port = Int(portField.stringValue.trimmingCharacters(in: .whitespaces)) ?? s.proto.defaultPort
        s.auth = anonymousCheck.state == .on ? .anonymous : .password
        // The anonymous login has one user name, and the field holding it is disabled — taking
        // whatever it still showed would save a name the connection never uses.
        s.user = s.auth == .anonymous ? "anonymous"
                                      : userField.stringValue.trimmingCharacters(in: .whitespaces)
        s.remoteDir = remoteDirField.stringValue
        let ph = proxyHostField.stringValue.trimmingCharacters(in: .whitespaces)
        s.proxyHost = ph.isEmpty ? nil : ph
        s.proxyPort = Int(proxyPortField.stringValue) ?? s.proxyPort
        s.proxyType = ProxyKind.allCases[max(0, proxyTypePopup.indexOfSelectedItem)]
        let pu = proxyUserField.stringValue.trimmingCharacters(in: .whitespaces)
        s.proxyUser = pu.isEmpty ? nil : pu
        // After the proxy, because whether the choice exists at all depends on it: behind a proxy
        // the data connection must be passive, and the box the user cannot untick is not a choice
        // that should be recorded as "off".
        // SFTP is excluded: passive means nothing there either, but the site's stored value is
        // none of this dialog's business — forcing it would rewrite every SFTP site on selection.
        s.passive = passiveCheck.state == .on
            || (s.proto != .sftp && !FtpConnectionRules.applies(.passive, to: s))
        // Saved against the *committed* site, so the account key matches the host/user just typed.
        let pp = proxyPasswordField.stringValue
        if !pp.isEmpty { try? FtpCredentials.saveProxyPassword(pp, for: s, in: store) }
        s.proxyPassword = pp.isEmpty ? nil : pp
        s.useSCP = scpCheck.state == .on
        s.allowInsecureTLS = insecureTLSCheck.state == .on
        sites[selected] = s
        tableView.reloadData(forRowIndexes: IndexSet(integer: selected), columnIndexes: IndexSet(integer: 0))
    }

    /// The protocol popup, which is the one control that moves another: picking SFTP after FTP
    /// leaves port 21 in the field, and a site that cannot connect is the only sign of it.
    ///
    /// Read before `commitForm`, because the model still holds the protocol being replaced —
    /// which is exactly what decides whether the port in the field was a default or a choice.
    @objc private func protocolChanged() {
        guard sites.indices.contains(selected) else { return }
        let old = sites[selected].proto
        let new = Self.protoOrder[max(0, protoPopup.indexOfSelectedItem)]
        if new != old {
            let typed = Int(portField.stringValue.trimmingCharacters(in: .whitespaces))
            portField.stringValue = String(
                FtpConnectionRules.port(changingTo: new, from: old, current: typed))
        }
        commitForm()
        updateEnabledState()
    }

    @objc private func formControlChanged() { commitForm(); updateEnabledState() }
    func controlTextDidChange(_ obj: Notification) { commitForm(); updateEnabledState() }
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
        // A beep for "no host" was the whole of the feedback here, and said nothing about which
        // of the settings above it meant. The rules name the problem; the label has been showing
        // it while the form was filled in, and this repeats it where the click happened.
        let blocking = FtpConnectionRules.blockingProblems(with: site)
        guard blocking.isEmpty else {
            let alert = NSAlert()
            alert.messageText = String(localized: "This site cannot be connected yet")
            alert.informativeText = blocking.map(MainWindowController.describe).joined(separator: "\n\n")
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window ?? NSApp.mainWindow ?? NSWindow()) { _ in }
            return
        }
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
