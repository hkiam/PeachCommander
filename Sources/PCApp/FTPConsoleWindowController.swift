// SPDX-License-Identifier: Apache-2.0
// FTPConsoleWindowController.swift - FTP protocol log + custom-command console (F-217).
//
// Shows the live raw FTP control-channel traffic (commands sent, replies received)
// captured by the session's FTPProtocolLog, and lets the user type a raw FTP
// command (e.g. SITE, STAT, FEAT) and see its reply — the "raw command line" TC
// offers for FTP sites.

import AppKit
import PCFoundation
import PCNet

final class FTPConsoleWindowController: NSWindowController {
    private let fs: FTPFileSystem
    private let log: FTPProtocolLog
    private let textView = NSTextView()
    private let commandField = NSTextField()

    init(fs: FTPFileSystem, log: FTPProtocolLog) {
        self.fs = fs
        self.log = log
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "FTP Console")
        super.init(window: window)
        buildUI()
        // Seed with the traffic so far, then observe new lines live.
        for entry in log.snapshot() { append(entry) }
        log.onAppend = { [weak self] entry in
            DispatchQueue.main.async { self?.append(entry) }
        }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Detach the observer so a closed console doesn't retain/notify us.
    func detach() { log.onAppend = nil }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 6, height: 6)
        scroll.documentView = textView
        content.addSubview(scroll)

        let prompt = NSTextField(labelWithString: String(localized: "Command:"))
        prompt.font = Fonts.system13
        prompt.translatesAutoresizingMaskIntoConstraints = false
        commandField.placeholderString = "STAT / FEAT / SITE HELP / NOOP …"
        commandField.font = Fonts.monospacedDigit13
        commandField.target = self
        commandField.action = #selector(sendCommand)
        commandField.translatesAutoresizingMaskIntoConstraints = false
        let send = NSButton(title: String(localized: "Send"), target: self, action: #selector(sendCommand))
        send.bezelStyle = .rounded; send.keyEquivalent = "\r"
        send.translatesAutoresizingMaskIntoConstraints = false

        let clear = NSButton(title: String(localized: "Clear"), target: self, action: #selector(clearLog))
        clear.bezelStyle = .rounded
        let copy = NSButton(title: String(localized: "Copy"), target: self, action: #selector(copyLog))
        copy.bezelStyle = .rounded
        let close = NSButton(title: String(localized: "Close"), target: self, action: #selector(closeConsole))
        close.bezelStyle = .rounded; close.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [clear, copy, close]); buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(prompt); content.addSubview(commandField)
        content.addSubview(send); content.addSubview(buttons)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: commandField.topAnchor, constant: -10),

            prompt.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            prompt.centerYAnchor.constraint(equalTo: commandField.centerYAnchor),
            commandField.leadingAnchor.constraint(equalTo: prompt.trailingAnchor, constant: 8),
            commandField.trailingAnchor.constraint(equalTo: send.leadingAnchor, constant: -8),
            commandField.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -10),
            send.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            send.centerYAnchor.constraint(equalTo: commandField.centerYAnchor),
            send.widthAnchor.constraint(equalToConstant: 70),

            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    func present() {
        window?.center(); showWindow(nil); window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(commandField)
    }

    /// Append one log line, colour-coded (sent vs received), and scroll to the end.
    private func append(_ entry: FTPProtocolLog.Entry) {
        let prefix = entry.outgoing ? "→ " : "← "
        let color: NSColor = entry.outgoing ? .systemBlue : .labelColor
        let line = NSAttributedString(string: prefix + entry.text + "\n", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color,
        ])
        textView.textStorage?.append(line)
        textView.scrollToEndOfDocument(nil)
    }

    @objc private func sendCommand() {
        let line = commandField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        commandField.stringValue = ""
        Task { @MainActor in
            // The command + reply are captured by the protocol log automatically;
            // surface any transport error as a synthetic log line.
            do { _ = try await fs.sendRawCommand(line) }
            catch { self.append(.init(outgoing: false, text: "! \(error)")) }
        }
    }

    @objc private func clearLog() {
        log.clear()
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }

    @objc private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func closeConsole() { close() }

    override func close() { detach(); super.close() }
}
