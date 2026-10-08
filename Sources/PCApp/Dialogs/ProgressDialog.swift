// SPDX-License-Identifier: Apache-2.0
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
    /// What the transfer manager needs to take the transfer over as it stands (F-085).
    private(set) var isPaused = false
    private(set) var lastProgress = OpProgress()
    private(set) var speedLimit: Int64?
    /// "Background" (SPEC-004 §4, F-085): hand the running transfer to the transfer manager. The
    /// owner of the transfer decides what that means — it is the one holding the queue — and closes
    /// this window; the button only says it was asked.
    var onBackground: (() -> Void)?

    private let currentItemLabel = NSTextField(labelWithString: "")
    /// The current file (SPEC-004 §4), shown when `FileProgressBarRule` says it is worth it. Its row is
    /// reserved from the start for an operation that copies bytes, so the window never changes height
    /// under the pointer — a bar appearing later would push the buttons down just as someone aims at
    /// Cancel. An operation that moves no bytes (a delete) has no row at all.
    private let fileProgressIndicator = NSProgressIndicator()
    private var fileBarRule = FileProgressBarRule()
    private let measuresFiles: Bool
    private let totalProgressIndicator = NSProgressIndicator()
    private let filesLabel = NSTextField(labelWithString: "")
    private let bytesLabel = NSTextField(labelWithString: "")
    private let speedLabel = NSTextField(labelWithString: "")
    /// The same choices as a job in the transfer manager: throttle the copy that is in the way now,
    /// without having had to start it in the background. Only where bytes are copied — a delete has
    /// nothing to throttle.
    private let speedPopup = TransferManagerWindowController.makeSpeedPopup(selecting: nil)
    private let backgroundButton = NSButton()
    private let pauseButton = NSButton()
    private let cancelButton = NSButton()

    /// Builds the window (not yet shown; call `present(over:)`).
    /// - Parameter measuresFiles: the operation copies file data (a copy or a move), so it gets the
    ///   file bar's row and the speed menu.
    init(title: String, control: OperationControl, measuresFiles: Bool = false) {
        self.control = control
        self.measuresFiles = measuresFiles

        let window = NSWindow(
            contentRect: NSMakeRect(0, 0, 520, 190),
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
        backgroundButton.isHidden = onBackground == nil
        window.center()
        window.makeKeyAndOrderFront(nil)
        if let parent {
            parent.addChildWindow(window, ordered: .above)
        }
    }

    /// Updates the labels and progress bar from a live `OpProgress` snapshot.
    func update(_ progress: OpProgress) {
        lastProgress = progress
        currentItemLabel.stringValue = progress.currentItem

        if measuresFiles, fileBarRule.update(progress), let fileFraction = progress.currentFileFraction {
            fileProgressIndicator.isHidden = false
            if progress.isWaitingForSource {
                fileProgressIndicator.isIndeterminate = true
                fileProgressIndicator.startAnimation(nil)
            } else {
                fileProgressIndicator.stopAnimation(nil)
                fileProgressIndicator.isIndeterminate = false
                fileProgressIndicator.doubleValue = fileFraction
            }
        }

        // While the totals are still being counted they only grow, and a fraction of them would run
        // backwards; the bar waits for the count to finish. While a source is still being delivered no
        // byte moves, and a fraction would stand still and then jump.
        if progress.bytesTotal > 0, !progress.isIndeterminate {
            // The animation an indeterminate phase started has to be stopped, not just switched off:
            // left running, the bar stays drawn at its start however far the copy gets — which is
            // every copy, since the first report always arrives while the totals are being counted.
            totalProgressIndicator.stopAnimation(nil)
            totalProgressIndicator.isIndeterminate = false
            totalProgressIndicator.minValue = 0
            totalProgressIndicator.maxValue = 1
            totalProgressIndicator.doubleValue = progress.fraction
        } else {
            totalProgressIndicator.isIndeterminate = true
            totalProgressIndicator.startAnimation(nil)
        }

        let filesFormat = String(localized: "%d / %d files")
        filesLabel.stringValue = String(format: filesFormat, progress.filesDone, progress.filesTotal)

        // While another app delivers a source, what has arrived is the figure that moves.
        let receiving = progress.isWaitingForSource && progress.bytesToReceive > 0
        let done = ByteSize(receiving ? progress.bytesReceived : progress.bytesDone).formatted(style: .kb)
        let total = ByteSize(receiving ? progress.bytesToReceive : progress.bytesTotal).formatted(style: .kb)
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
        fileProgressIndicator.stopAnimation(nil)
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

        for bar in [fileProgressIndicator, totalProgressIndicator] {
            bar.style = .bar
            bar.isIndeterminate = false
            bar.minValue = 0
            bar.maxValue = 1
            bar.doubleValue = 0
        }
        // Plain constraints, not a stack: a hidden view keeps its frame here, which is what reserves the
        // file bar's row (see `fileProgressIndicator`). Fixed heights, so neither bar can be squeezed.
        fileProgressIndicator.isHidden = true
        let bars = measuresFiles ? [fileProgressIndicator, totalProgressIndicator] : [totalProgressIndicator]
        var above = currentItemLabel.bottomAnchor
        for bar in bars {
            bar.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.topAnchor.constraint(equalTo: above, constant: bar === bars[0] ? 12 : 8),
                bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
                bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
                bar.heightAnchor.constraint(equalToConstant: 20),
            ])
            above = bar.bottomAnchor
        }

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

        backgroundButton.title = String(localized: "Background",
                                        comment: "Button in the copy progress window: continue the running copy in the background transfer manager")
        backgroundButton.bezelStyle = .rounded
        backgroundButton.action = #selector(backgroundAction)
        backgroundButton.target = self
        backgroundButton.toolTip = String(localized: "Run in background")

        cancelButton.title = String(localized: "Cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1B}"
        cancelButton.action = #selector(cancelAction)
        cancelButton.target = self

        speedPopup.isHidden = !measuresFiles
        speedPopup.target = self
        speedPopup.action = #selector(speedChanged)
        buttons.addView(speedPopup, in: .leading)
        buttons.addView(backgroundButton, in: .trailing)
        buttons.addView(pauseButton, in: .trailing)
        buttons.addView(cancelButton, in: .trailing)
        content.addSubview(buttons)
        // Space on a focused Background would send the copy away unnoticed; on Cancel it does what
        // Escape already does.
        window.initialFirstResponder = cancelButton

        NSLayoutConstraint.activate([
            currentItemLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            currentItemLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            currentItemLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),

            filesLabel.topAnchor.constraint(equalTo: totalProgressIndicator.bottomAnchor, constant: 10),
            filesLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            bytesLabel.topAnchor.constraint(equalTo: filesLabel.bottomAnchor, constant: 6),
            bytesLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            speedLabel.centerYAnchor.constraint(equalTo: bytesLabel.centerYAnchor),
            speedLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            speedLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bytesLabel.trailingAnchor, constant: 10),

            buttons.topAnchor.constraint(equalTo: bytesLabel.bottomAnchor, constant: 16),
            buttons.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
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

    /// The `progressbackground` automation verb: the button, as clicked.
    func automationPressBackground() { backgroundAction() }

    @objc private func backgroundAction() {
        backgroundButton.isEnabled = false
        onBackground?()
    }

    @objc private func speedChanged() {
        let choice = TransferManagerWindowController.speedChoices[max(0, speedPopup.indexOfSelectedItem)]
        speedLimit = choice.bytesPerSecond
        let control = self.control
        Task { await control.setSpeedLimit(choice.bytesPerSecond) }
    }

    @objc private func cancelAction() {
        cancelButton.isEnabled = false
        let control = self.control
        Task { await control.cancel() }
    }
}
