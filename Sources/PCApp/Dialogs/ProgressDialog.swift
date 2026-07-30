// ProgressDialog.swift - Live progress window for file operations (I04)
//
// Shown (non-app-modal) while a TransferQueue runs, so an interactive
// overwrite/error NSAlert (see OverwriteResolver.swift) can still appear on
// top of it. Driven by `update(_:)` calls fed from the operation's OpEvent
// stream; Pause/Resume/Cancel forward to the shared `OperationControl`.

import AppKit
import PCFoundation
import PCOperations

/// Live progress window for a running copy/move/delete operation.
@MainActor
final class ProgressDialog: NSWindowController {
    private let logger = PCFoundationLogger.logger

    private let control: OperationControl
    private var isPaused = false

    private let currentItemLabel = NSTextField(labelWithString: "")
    private let totalProgressIndicator = NSProgressIndicator()
    private let filesLabel = NSTextField(labelWithString: "")
    private let bytesLabel = NSTextField(labelWithString: "")
    private let speedLabel = NSTextField(labelWithString: "")
    private let pauseButton = NSButton()
    private let cancelButton = NSButton()

    /// Builds the window (not yet shown; call `present(over:)`).
    init(title: String, control: OperationControl) {
        self.control = control

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 420, 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        super.init(window: window)
        setupDialog()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shows the window centered, as a titled (non-app-modal) window, so an
    /// interactive overwrite/error alert can still be presented above it.
    func present(over parent: NSWindow?) {
        guard let window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        if let parent {
            parent.addChildWindow(window, ordered: .above)
        }
    }

    /// Updates the labels and progress bar from a live `OpProgress` snapshot.
    func update(_ progress: OpProgress) {
        currentItemLabel.stringValue = progress.currentItem

        if progress.bytesTotal > 0 {
            totalProgressIndicator.isIndeterminate = false
            totalProgressIndicator.minValue = 0
            totalProgressIndicator.maxValue = 1
            totalProgressIndicator.doubleValue = Double(progress.bytesDone) / Double(progress.bytesTotal)
        } else {
            totalProgressIndicator.isIndeterminate = true
            totalProgressIndicator.startAnimation(nil)
        }

        let filesFormat = String(localized: "%d / %d files")
        filesLabel.stringValue = String(format: filesFormat, progress.filesDone, progress.filesTotal)

        let done = ByteSize(progress.bytesDone).formatted(style: .kb)
        let total = ByteSize(progress.bytesTotal).formatted(style: .kb)
        let bytesFormat = String(localized: "%@ / %@")
        bytesLabel.stringValue = String(format: bytesFormat, done, total)

        let speed = ByteSize(Int64(progress.bytesPerSecond)).formatted(style: .kb)
        if progress.bytesPerSecond > 0, progress.bytesTotal > progress.bytesDone {
            let eta = Double(progress.bytesTotal - progress.bytesDone) / progress.bytesPerSecond
            speedLabel.stringValue = String(format: String(localized: "%@/s · %@ left"), speed, Self.formatETA(eta))
        } else {
            speedLabel.stringValue = String(localized: "\(speed)/s")
        }
    }

    /// Format a remaining-seconds estimate as h:mm:ss / m:ss / Ns.
    private static func formatETA(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        if s >= 60 { return String(format: "%d:%02d", s / 60, s % 60) }
        return String(format: String(localized: "%ds"), s)
    }

    /// Closes the window.
    func finish() {
        totalProgressIndicator.stopAnimation(nil)
        if let window, let parent = window.parent {
            parent.removeChildWindow(window)
        }
        close()
    }

    private func setupDialog() {
        guard let window else { return }
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        currentItemLabel.translatesAutoresizingMaskIntoConstraints = false
        currentItemLabel.font = Fonts.system13
        currentItemLabel.lineBreakMode = .byTruncatingMiddle
        currentItemLabel.maximumNumberOfLines = 1
        content.addSubview(currentItemLabel)

        totalProgressIndicator.translatesAutoresizingMaskIntoConstraints = false
        totalProgressIndicator.style = .bar
        totalProgressIndicator.isIndeterminate = false
        totalProgressIndicator.minValue = 0
        totalProgressIndicator.maxValue = 1
        totalProgressIndicator.doubleValue = 0
        content.addSubview(totalProgressIndicator)

        filesLabel.translatesAutoresizingMaskIntoConstraints = false
        filesLabel.font = Fonts.monospacedDigit13
        content.addSubview(filesLabel)

        bytesLabel.translatesAutoresizingMaskIntoConstraints = false
        bytesLabel.font = Fonts.monospacedDigit13
        content.addSubview(bytesLabel)

        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = Fonts.monospacedDigit13
        speedLabel.alignment = .right
        content.addSubview(speedLabel)

        let buttons = NSStackView()
        buttons.translatesAutoresizingMaskIntoConstraints = false
        buttons.orientation = .horizontal
        buttons.spacing = 10

        pauseButton.title = String(localized: "Pause")
        pauseButton.bezelStyle = .rounded
        pauseButton.action = #selector(togglePause)
        pauseButton.target = self

        cancelButton.title = String(localized: "Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.action = #selector(cancelAction)
        cancelButton.target = self

        buttons.addView(pauseButton, in: .trailing)
        buttons.addView(cancelButton, in: .trailing)
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            currentItemLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            currentItemLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            currentItemLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            totalProgressIndicator.topAnchor.constraint(equalTo: currentItemLabel.bottomAnchor, constant: 12),
            totalProgressIndicator.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            totalProgressIndicator.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            filesLabel.topAnchor.constraint(equalTo: totalProgressIndicator.bottomAnchor, constant: 10),
            filesLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            bytesLabel.topAnchor.constraint(equalTo: filesLabel.bottomAnchor, constant: 6),
            bytesLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            speedLabel.centerYAnchor.constraint(equalTo: bytesLabel.centerYAnchor),
            speedLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            speedLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bytesLabel.trailingAnchor, constant: 10),

            buttons.topAnchor.constraint(equalTo: bytesLabel.bottomAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
    }

    @objc private func togglePause() {
        isPaused.toggle()
        pauseButton.title = isPaused ? String(localized: "Resume") : String(localized: "Pause")
        let control = self.control
        if isPaused {
            Task { await control.pause() }
        } else {
            Task { await control.resume() }
        }
    }

    @objc private func cancelAction() {
        cancelButton.isEnabled = false
        let control = self.control
        Task { await control.cancel() }
    }
}
