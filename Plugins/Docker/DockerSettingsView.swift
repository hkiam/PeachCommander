// SPDX-License-Identifier: Apache-2.0
// DockerSettingsView.swift — the provider's settings, in the host's Settings window.
//
// Everything here was reachable before only by hand-editing `docker.ini`, which is a reasonable
// thing for a file to be and an unreasonable thing for a feature to be: the two decisions that
// actually matter — whether anything may be run inside a container at all, and how much of a
// directory is worth reading before giving up — were invisible unless you had read the source.
//
// Contributed as a view (`PcMakeView` with `container: settings`), the same way the decompiler's
// page is, so it appears beside the host's own pages rather than in a window of the plugin's own.

import AppKit

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let viewId, String(cString: viewId) == "plugin.docker.settings" else { return nil }
    // The host's config root when it offers one, so a scripted or `-ConfigRoot` run edits the same
    // file the rest of the plugin reads. `PfxInit` has usually set this already; taking it again
    // costs nothing and covers a settings page opened in a host that never connected.
    if let services, let get = services.pointee.getContext {
        var buffer = [CChar](repeating: 0, count: 4096)
        if "configRoot".withCString({ get(services.pointee.host, $0, &buffer, 4096) }) == 1 {
            let root = String(cString: buffer)
            if !root.isEmpty { DockerSettings.configRoot = root }
        }
    }
    return Unmanaged.passRetained(DockerSettingsView()).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<DockerSettingsView>.fromOpaque(view).release()
}

final class DockerSettingsView: NSView {
    private var settings = DockerSettings.load()

    private let endpoint = NSTextField()
    private let execFallback = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let probeBudget = NSTextField()
    private let maxBudget = NSTextField()
    private let maxSeconds = NSTextField()
    private let helperImage = NSTextField()
    private let anonymousVolumes = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 620, height: 360))
        build()
        show(settings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Report the page's own controls once it has been laid out, when a scenario asks for it.
    ///
    /// Neither of the host's measuring verbs can reach this page: `windowlayout` stops two levels
    /// under the content view and the accessibility dump does the same, while this sits deeper,
    /// inside the Settings window's scroll view. So the page answers for itself — the frames *and*
    /// the values, which together say it was built, laid out, and filled from the file. Same shape
    /// as `PC_DOCKER_DIALOG_NOMODAL` and the AI plugins' `PC_AI_DIRECT_DUMP`.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, let path = dockerProbe("PC_DOCKER_SETTINGS_DUMP") else { return }
        // Not on the next turn of the runloop but a little after it: the host sizes a contributed
        // page after handing it a window, and a dump taken one hop later caught the view at
        // 514x0 — which reads exactly like a page that collapsed, and was in fact a page that had
        // not been given its height yet. Measuring too early is its own wrong answer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.layoutSubtreeIfNeeded()
            var text = "view=\(Int(self.bounds.width))x\(Int(self.bounds.height))\n"
            for (name, control) in [("endpoint", self.endpoint), ("probeBudget", self.probeBudget),
                                    ("maxBudget", self.maxBudget), ("maxSeconds", self.maxSeconds),
                                    ("helperImage", self.helperImage)] {
                text += "\(name)=\(Int(control.frame.width))x\(Int(control.frame.height))"
                    + " value=\(control.stringValue)\n"
            }
            text += "execFallback=\(self.execFallback.state == .on)\n"
            text += "anonymousVolumes=\(self.anonymousVolumes.state == .on)\n"
            text += "execFallbackTitle=\(self.execFallback.title)\n"
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    // MARK: Layout

    private func build() {
        execFallback.title = L("Let large directories be listed by running ls inside the container")
        execFallback.target = self
        execFallback.action = #selector(changed)
        anonymousVolumes.title = L("Show volumes Docker named with a digest")
        anonymousVolumes.target = self
        anonymousVolumes.action = #selector(changed)

        for field in [endpoint, probeBudget, maxBudget, maxSeconds, helperImage] {
            field.target = self
            field.action = #selector(changed)
            field.delegate = self
        }
        endpoint.placeholderString = L("Leave empty to use the engine that is found")
        helperImage.placeholderString = L("Any image already on this machine")

        let rows = NSStackView(views: [
            row(L("Engine:"), endpoint),
            execFallback,
            row(L("Read at most this much of a directory before falling back (MB):"), probeBudget,
                fieldWidth: 90),
            row(L("Without the fallback, read at most (MB):"), maxBudget, fieldWidth: 90),
            row(L("…and give up after (seconds):"), maxSeconds, fieldWidth: 90),
            row(L("Image for the throwaway container that reads a volume:"), helperImage),
            anonymousVolumes,
        ])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 12
        rows.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            // The bottom is what gives the page a height at all, and it has to be
            // `greaterThanOrEqualTo`: with the rows only pinned at the top, nothing stops the view
            // from being nothing tall, and the host — which sizes a contributed page by what it
            // says it needs — was handed 702x**0**. Everything inside it still had a sensible frame,
            // which is why this is the shape of defect a screenshot and a conflict count both miss.
            bottomAnchor.constraint(greaterThanOrEqualTo: rows.bottomAnchor, constant: 18),
        ])
    }

    /// A label and a field on one line.
    ///
    /// The label is told it is the one that does not grow. Two views that hug their content at the
    /// same priority make AppKit split the row between them, which is satisfiable, wrong, and logs
    /// no Auto Layout conflict at all — the defect the connect dialog shipped with until the VM
    /// scenario measured its frames.
    private func row(_ title: String, _ field: NSTextField, fieldWidth: CGFloat? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 8
        if let fieldWidth {
            field.widthAnchor.constraint(equalToConstant: fieldWidth).isActive = true
        }
        return stack
    }

    // MARK: Values

    private func show(_ settings: DockerSettings) {
        endpoint.stringValue = settings.endpoint
        execFallback.state = settings.execFallback ? .on : .off
        probeBudget.stringValue = String(settings.probeBudgetMB)
        maxBudget.stringValue = String(settings.maxBudgetMB)
        maxSeconds.stringValue = String(settings.maxBudgetSeconds)
        helperImage.stringValue = settings.helperImage
        anonymousVolumes.state = settings.showAnonymousVolumes ? .on : .off
    }

    /// Read the controls back and write the file.
    ///
    /// A number the user emptied or typed nonsense into keeps the value it had rather than becoming
    /// zero: a budget of 0 MB would make every listing fail, and the field is the only place that
    /// mistake could come from.
    @objc private func changed() {
        settings.endpoint = endpoint.stringValue.trimmingCharacters(in: .whitespaces)
        settings.execFallback = execFallback.state == .on
        settings.probeBudgetMB = Int(probeBudget.stringValue) ?? settings.probeBudgetMB
        settings.maxBudgetMB = Int(maxBudget.stringValue) ?? settings.maxBudgetMB
        settings.maxBudgetSeconds = Int(maxSeconds.stringValue) ?? settings.maxBudgetSeconds
        settings.helperImage = helperImage.stringValue.trimmingCharacters(in: .whitespaces)
        settings.showAnonymousVolumes = anonymousVolumes.state == .on
        settings.save()
        show(settings)
    }
}

extension DockerSettingsView: NSTextFieldDelegate {
    /// Saved when the field loses focus as well as on Return. A settings page has no OK button, so
    /// a value typed and then clicked away from would otherwise be discarded without a word.
    func controlTextDidEndEditing(_ notification: Notification) { changed() }
}
