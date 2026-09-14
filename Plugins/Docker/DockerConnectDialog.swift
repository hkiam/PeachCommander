// SPDX-License-Identifier: Apache-2.0
// DockerConnectDialog.swift — the one dialog this plugin has.
//
// It is short because there is nothing to type: the engines on this Mac are found, and the field
// is there for the one case discovery cannot cover — an engine somewhere else, given as a
// `DOCKER_HOST` value. There is no password: access to a Docker daemon is granted by the socket's
// own permissions, and this plugin deliberately stores no credential of any kind.

import AppKit

final class DockerConnectDialog: NSObject {
    private let window: NSWindow
    private let endpointCombo = NSComboBox()
    private let execCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let candidates: [DockerEndpoint]
    private var confirmed = false

    init(candidates: [DockerEndpoint], settings: DockerSettings) {
        self.candidates = candidates
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 190),
                          styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = L("Connect to Docker")
        window.center()
        // Programmatically created windows are released on close unless this is turned off, and
        // this object keeps a strong reference — the same over-release the WebDAV dialog hit.
        window.isReleasedWhenClosed = false
        execCheck.state = settings.execFallback ? .on : .off
        build(settings: settings)
    }

    struct Result {
        var endpoint: DockerEndpoint
        var execFallback: Bool
    }

    func run() -> Result? {
        // A modal opened from an automation script never returns. The runner is an async task on the
        // main actor and does not resume inside the modal's nested runloop, so `quit` never lands and
        // the run has to be killed — which is also why this window could not be measured at all.
        //
        // It has to be measurable: it is the one new window this plugin brings, and the repository's
        // Auto Layout baseline is zero everywhere, so a conflict here is a regression nobody would
        // otherwise see. Under this variable the window is shown and laid out without the modal loop
        // and the connect is cancelled, so a scenario can measure the real article with
        // `windowlayout` instead of a stand-in. Same shape as the AI plugins' `PC_AI_DIRECT_DUMP`.
        if dockerProbe("PC_DOCKER_DIALOG_NOMODAL") != nil {
            window.orderFront(nil)
            window.contentView?.layoutSubtreeIfNeeded()
            return nil
        }
        NSApp.runModal(for: window)
        window.orderOut(nil)
        guard confirmed else { return nil }
        let typed = endpointCombo.stringValue.trimmingCharacters(in: .whitespaces)
        // A row that was picked from the list keeps its label ("Colima", "Podman"); anything else
        // is a URL somebody typed and is labelled by its host.
        let chosen = candidates.first(where: { $0.url == typed })
            ?? DockerEndpoint.parse(typed, label: Self.label(for: typed))
        guard let chosen else { return nil }
        return Result(endpoint: chosen, execFallback: execCheck.state == .on)
    }

    private static func label(for url: String) -> String {
        if url.hasPrefix("unix://") || url.hasPrefix("/") { return "Docker" }
        let rest = url.drop(while: { $0 != "/" }).drop(while: { $0 == "/" })
        let host = rest.prefix(while: { $0 != "/" && $0 != ":" })
        return host.isEmpty ? "Docker" : String(host)
    }

    private func build(settings: DockerSettings) {
        guard let content = window.contentView else { return }

        let title = NSTextField(labelWithString: L("Engine:"))
        // A programmatically created NSTextField hugs its content at priority 250 — the same as the
        // combo box beside it — so the row has two views that are equally willing to stretch and
        // AppKit splits the width between them: measured at 448 pt for the word "Engine:" and 408
        // for the field, in a 900 pt window, with **zero** Auto Layout conflicts. The layout is
        // satisfiable and merely wrong, which is the class the conflict count cannot see. Saying the
        // label is the one that does not grow leaves the rest to the field.
        title.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        endpointCombo.addItems(withObjectValues: candidates.map(\.url))
        endpointCombo.stringValue = settings.endpoint.isEmpty
            ? (candidates.first?.url ?? "unix:///var/run/docker.sock")
            : settings.endpoint
        endpointCombo.completes = true

        let found: String
        if candidates.isEmpty {
            found = L("No Docker engine was found on this Mac. Enter an address to connect to one.")
        } else {
            found = String(format: L("Found: %@"),
                           candidates.map(\.label).joined(separator: ", "))
        }
        let hint = NSTextField(labelWithString: found)
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        execCheck.title = L("Let large directories be listed by running ls inside the container")
        execCheck.toolTip = L("Off, the provider uses only Docker's archive API and never runs anything inside a container. On, a directory too large to read as an archive is listed by a running container itself.")

        let note = NSTextField(wrappingLabelWithString:
            L("A Docker connection carries the same rights on this Mac as the user running Peach Commander. Treat it as a privileged resource."))
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor

        for view in [title, endpointCombo, hint, execCheck, note] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }

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
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            endpointCombo.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            endpointCombo.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            endpointCombo.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            hint.topAnchor.constraint(equalTo: endpointCombo.bottomAnchor, constant: 6),
            hint.leadingAnchor.constraint(equalTo: endpointCombo.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            execCheck.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 12),
            execCheck.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            execCheck.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            note.topAnchor.constraint(equalTo: execCheck.bottomAnchor, constant: 10),
            note.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            note.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: note.bottomAnchor, constant: 10),
        ])
    }

    @objc private func ok() { confirmed = true; NSApp.stopModal() }
    @objc private func dismiss() { confirmed = false; NSApp.stopModal() }
}
