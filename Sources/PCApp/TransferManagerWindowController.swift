// SPDX-License-Identifier: Apache-2.0
// TransferManagerWindowController.swift - Background transfer manager window (TODOS #135).
//
// Lists the TransferManager's jobs as rows with a progress bar, live throughput,
// and per-job Pause/Resume/Cancel buttons; a toolbar clears finished jobs. The
// row stack is rebuilt whenever the manager reports a change (already throttled to
// ~30 Hz by the underlying TransferQueue), which is plenty for a handful of jobs.

import AppKit
import PCFoundation
import PCOperations

final class TransferManagerWindowController: NSWindowController {
    private let manager = TransferManager.shared
    private let stack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let startAllButton = NSButton()

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = String(localized: "Background Transfer Manager")
        super.init(window: window)
        buildUI()
        manager.onChange = { [weak self] in self?.rebuild() }
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let clear = NSButton(title: String(localized: "Clear Finished"),
                             target: self, action: #selector(clearFinished))
        clear.bezelStyle = .rounded
        toolbar.addArrangedSubview(clear)
        // Start every held download-list job (F-215).
        startAllButton.title = String(localized: "Start All")
        startAllButton.bezelStyle = .rounded
        startAllButton.target = self
        startAllButton.action = #selector(startAll)
        toolbar.addArrangedSubview(startAllButton)
        content.addSubview(toolbar)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedContainerView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        content.addSubview(scroll)

        emptyLabel.stringValue = String(localized: "No transfers.")
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: content.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor)
        ])
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let jobs = manager.jobs
        emptyLabel.isHidden = !jobs.isEmpty
        startAllButton.isHidden = !manager.hasQueuedJobs
        for job in jobs {
            stack.addArrangedSubview(makeRow(job))
        }
    }

    private func makeRow(_ job: TransferManager.Job) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.wantsLayer = true

        let title = NSTextField(labelWithString: job.title)
        title.font = Fonts.bold13
        title.lineBreakMode = .byTruncatingMiddle

        let bar = NSProgressIndicator()
        bar.isIndeterminate = false
        bar.minValue = 0; bar.maxValue = 1
        bar.doubleValue = fraction(job.progress)
        if (job.status == .running || job.status == .paused)
            && job.progress.bytesTotal == 0 && job.progress.filesTotal == 0 {
            bar.isIndeterminate = true; bar.startAnimation(nil)
        }

        let detail = NSTextField(labelWithString: detailText(job))
        detail.font = Fonts.system13
        detail.textColor = .secondaryLabelColor

        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.spacing = 6
        switch job.status {
        case .queued:
            // ▲▼ only where a move is actually possible. A button that is always there and usually
            // refuses teaches people to stop pressing it; `TransferManager.canMove` asks the same
            // rule the move itself obeys, so one is never offered and then declined.
            if manager.canMove(job, by: -1) {
                controls.addArrangedSubview(button("▲", #selector(moveJobUp(_:)), job.id))
            }
            if manager.canMove(job, by: 1) {
                controls.addArrangedSubview(button("▼", #selector(moveJobDown(_:)), job.id))
            }
            controls.addArrangedSubview(button("Start", #selector(startJob(_:)), job.id))
            controls.addArrangedSubview(button("Cancel", #selector(cancelJob(_:)), job.id))
        case .running:
            controls.addArrangedSubview(speedControl(job))
            controls.addArrangedSubview(button("Pause", #selector(pauseJob(_:)), job.id))
            controls.addArrangedSubview(button("Cancel", #selector(cancelJob(_:)), job.id))
        case .paused:
            controls.addArrangedSubview(speedControl(job))
            controls.addArrangedSubview(button("Resume", #selector(resumeJob(_:)), job.id))
            controls.addArrangedSubview(button("Cancel", #selector(cancelJob(_:)), job.id))
        case .done, .failed, .cancelled:
            break
        }

        for v in [title, bar, detail, controls] { v.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(v) }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            title.trailingAnchor.constraint(lessThanOrEqualTo: controls.leadingAnchor, constant: -8),
            controls.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            controls.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            bar.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            detail.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 2),
            detail.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            detail.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
            row.widthAnchor.constraint(greaterThanOrEqualToConstant: 480)
        ])
        return row
    }

    private func button(_ title: String, _ action: Selector, _ id: UUID) -> NSButton {
        let b = NSButton(title: String(localized: String.LocalizationValue(title)), target: self, action: action)
        b.bezelStyle = .rounded
        b.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        return b
    }

    private func fraction(_ p: OpProgress) -> Double {
        if p.bytesTotal > 0 { return min(1, Double(p.bytesDone) / Double(p.bytesTotal)) }
        if p.filesTotal > 0 { return min(1, Double(p.filesDone) / Double(p.filesTotal)) }
        return 0
    }

    private func detailText(_ job: TransferManager.Job) -> String {
        switch job.status {
        case .queued: return String(localized: "Waiting to start")
        case .done: return String(localized: "Completed")
        case .cancelled: return String(localized: "Cancelled")
        case .failed: return String(localized: "Failed: ") + (job.errorText ?? "")
        case .paused, .running:
            let p = job.progress
            let done = SelectionSummaryFormatter.dynamicSize(p.bytesDone)
            let total = SelectionSummaryFormatter.dynamicSize(p.bytesTotal)
            let speed = p.bytesPerSecond > 0 ? "  ·  \(SelectionSummaryFormatter.dynamicSize(Int64(p.bytesPerSecond)))/s" : ""
            let state = job.status == .paused ? String(localized: "Paused") : ""
            let files = "\(p.filesDone)/\(max(p.filesTotal, p.filesDone))"
            return "\(files) files  ·  \(done) / \(total)\(speed)   \(state)"
        }
    }

    private func job(for sender: NSButton) -> TransferManager.Job? {
        guard let idString = sender.identifier?.rawValue, let id = UUID(uuidString: idString) else { return nil }
        return manager.jobs.first { $0.id == id }
    }

    /// Throughput choices for one running job. A popup rather than a field: this is a nudge — "get
    /// out of the way of something else" — not a number anybody wants to type while watching a
    /// progress bar.
    private static let speedChoices: [(title: String, bytesPerSecond: Int64?)] = [
        (String(localized: "Full speed"), 0),
        ("1 MB/s", 1024 * 1024),
        ("5 MB/s", 5 * 1024 * 1024),
        ("20 MB/s", 20 * 1024 * 1024),
        (String(localized: "Default"), nil),
    ]

    private func speedControl(_ job: TransferManager.Job) -> NSView {
        let popup = NSPopUpButton()
        popup.controlSize = .small
        popup.font = Fonts.system13
        for choice in Self.speedChoices { popup.addItem(withTitle: choice.title) }
        let index = Self.speedChoices.firstIndex { $0.bytesPerSecond == job.speedLimit }
            ?? Self.speedChoices.count - 1
        popup.selectItem(at: index)
        popup.target = self
        popup.action = #selector(speedChanged(_:))
        popup.identifier = NSUserInterfaceItemIdentifier(job.id.uuidString)
        popup.toolTip = String(localized: "Limit this transfer's speed. Takes effect immediately and leaves the other transfers alone.")
        return popup
    }

    @objc private func speedChanged(_ sender: NSPopUpButton) {
        guard let id = sender.identifier.flatMap({ UUID(uuidString: $0.rawValue) }),
              let job = manager.jobs.first(where: { $0.id == id }) else { return }
        let choice = Self.speedChoices[max(0, sender.indexOfSelectedItem)]
        manager.setSpeedLimit(job, bytesPerSecond: choice.bytesPerSecond)
    }

    @objc private func moveJobUp(_ sender: NSButton) { if let j = job(for: sender) { manager.move(j, by: -1) } }
    @objc private func moveJobDown(_ sender: NSButton) { if let j = job(for: sender) { manager.move(j, by: 1) } }

    @objc private func pauseJob(_ sender: NSButton) { if let j = job(for: sender) { manager.pause(j) } }
    @objc private func resumeJob(_ sender: NSButton) { if let j = job(for: sender) { manager.resume(j) } }
    @objc private func cancelJob(_ sender: NSButton) { if let j = job(for: sender) { manager.cancel(j) } }
    @objc private func startJob(_ sender: NSButton) { if let j = job(for: sender) { manager.startJob(j) } }
    @objc private func startAll() { manager.startAllQueued() }
    @objc private func clearFinished() { manager.clearFinished() }
}
