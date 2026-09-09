// SPDX-License-Identifier: Apache-2.0
// OverwriteResolver.swift - Interactive overwrite/error resolver (I04)
//
// Bridges the pure PCOperations `OperationResolver` protocol to NSAlert so a
// running TransferQueue can ask the user how to resolve target-exists
// conflicts and per-file errors. "All" choices are remembered for the
// lifetime of this resolver (i.e. for the rest of the current operation).

import AppKit
import PCFoundation
import PCOperations

/// Interactive, NSAlert-backed `OperationResolver` used by file-operation UI flows.
final class InteractiveResolver: OperationResolver, @unchecked Sendable {
    private let logger = PCFoundationLogger.logger
    private let parentWindow: NSWindow?

    /// A blanket choice made via an "…All" button that applies to all subsequent
    /// conflicts in this operation (F-086).
    enum Blanket: Equatable {
        case none
        case overwriteAll
        case skipAll
        /// Overwrite only when the source is newer than the target, else skip.
        case overwriteIfSourceNewer
        /// Overwrite only when the source is larger than the target, else skip.
        case overwriteIfSourceLarger
    }

    /// The automatic decision for a conditional blanket given the two files, or
    /// nil when the blanket needs the interactive dialog (`.none`).
    static func autoDecision(_ blanket: Blanket, source: FileFacts, target: FileFacts) -> OverwriteDecision? {
        switch blanket {
        case .none: return nil
        case .overwriteAll: return .overwrite
        case .skipAll: return .skip
        case .overwriteIfSourceNewer: return OverwriteRules.overwriteIfSourceNewer(source: source, target: target)
        case .overwriteIfSourceLarger: return OverwriteRules.overwriteIfSourceLarger(source: source, target: target)
        }
    }

    /// One recorded per-file failure that was skipped, for the end-of-run error
    /// log (F-089).
    struct Problem: Sendable, Equatable {
        let path: String
        let message: String
    }

    private let lock = NSLock()
    private var blanket: Blanket = .none
    private var problemLog: [Problem] = []

    /// The failures skipped so far this operation (thread-safe snapshot).
    func problems() -> [Problem] {
        lock.lock(); defer { lock.unlock() }
        return problemLog
    }

    private func record(_ path: String, _ message: String) {
        lock.lock(); defer { lock.unlock() }
        problemLog.append(Problem(path: path, message: message))
    }

    /// - Parameter parentWindow: The window the alert is logically associated with.
    init(parentWindow: NSWindow?) {
        self.parentWindow = parentWindow
    }

    private func currentBlanket() -> Blanket {
        lock.lock()
        defer { lock.unlock() }
        return blanket
    }

    private func setBlanket(_ value: Blanket) {
        lock.lock()
        defer { lock.unlock() }
        blanket = value
    }

    // MARK: - OperationResolver

    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision {
        if let auto = Self.autoDecision(currentBlanket(), source: source, target: target) {
            return auto
        }

        return await MainActor.run {
            // Build the button set dynamically so "Append" appears only when both
            // sides are regular files (F-086) — appending onto a folder is nonsense.
            // Each choice carries a stable key beside its title. The titles are localized, so a
            // script that named one would be asserting the language the guest happens to run in —
            // the trap a scenario already walked into once with a window title.
            var choices: [Choice] = [
                Choice("overwrite", String(localized: "Overwrite"), { .overwrite }),
                Choice("overwriteall", String(localized: "Overwrite All"),
                       { self.setBlanket(.overwriteAll); return .overwrite }),
                Choice("overwriteallolder", String(localized: "Overwrite All Older"), {
                    self.setBlanket(.overwriteIfSourceNewer)
                    return Self.autoDecision(.overwriteIfSourceNewer, source: source, target: target) ?? .skip
                }),
                Choice("overwritealllarger", String(localized: "Overwrite All Larger"), {
                    self.setBlanket(.overwriteIfSourceLarger)
                    return Self.autoDecision(.overwriteIfSourceLarger, source: source, target: target) ?? .skip
                }),
            ]
            if !source.isDirectory && !target.isDirectory {
                choices.append(Choice("append", String(localized: "Append"),
                                      { OverwriteDecision.append }))
            }
            let tail: [Choice] = [
                Choice("rename", String(localized: "Auto-Rename"),
                       { .rename(OverwriteRules.autoRenameName(target.name)) }),
                Choice("skip", String(localized: "Skip"), { .skip }),
                Choice("skipall", String(localized: "Skip All"),
                       { self.setBlanket(.skipAll); return .skip }),
                Choice("abort", String(localized: "Cancel"), { .abort }),
            ]
            choices.append(contentsOf: tail)
            return Self.ask(source: source, target: target, choices: choices)
        }
    }

    /// The same conflict, asked about ONE item (F-081).
    ///
    /// A rename is a move within a folder, so a name that is taken is the question this dialog
    /// already asks — deliberately the same window, the same wording and the same side-by-side
    /// preview, because a user who has answered it once for a copy should not meet a second,
    /// unfamiliar dialog for a rename.
    ///
    /// What it drops is everything that only means something for a *batch*: the "…All" buttons and
    /// the blanket they set have nothing left to apply to, and "Append" would merge two files rather
    /// than rename one. Not on the `OperationResolver` protocol for that reason — the engines resolve
    /// item after item and need the blanket this one must not have.
    func resolveSingleOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision {
        await MainActor.run {
            Self.ask(source: source, target: target, choices: [
                Choice("overwrite", String(localized: "Overwrite"), { .overwrite }),
                Choice("rename", String(localized: "Auto-Rename"),
                       { .rename(OverwriteRules.autoRenameName(target.name)) }),
                Choice("skip", String(localized: "Skip"), { .skip }),
                Choice("abort", String(localized: "Cancel"), { .abort }),
            ])
        }
    }

    /// Put the conflict up and return what was chosen. Shared so the one-item dialog cannot drift
    /// away from the batch one in wording, style or preview.
    /// One button of the conflict dialog: a stable key for a script, the localized title for a
    /// person, and the closure that both of them run.
    struct Choice {
        let key: String
        let title: String
        let make: () -> OverwriteDecision

        init(_ key: String, _ title: String, _ make: @escaping () -> OverwriteDecision) {
            self.key = key
            self.title = title
            self.make = make
        }
    }

    #if DEBUG
    private static var scriptedAnswers: [String] = []

    /// Queue one answer for the next overwrite conflict, by key (automation only).
    ///
    /// The conflict dialog had no scripted route at all, so every path behind it was unreachable
    /// from a scenario — including the two that decide whether an undo is safe to offer: "Append"
    /// merges the files and makes the naive inverse destructive, and "Overwrite" makes it correct.
    /// A one-line filter in the panel decides between them and could not be exercised end to end.
    static func queueScriptedAnswer(_ key: String) {
        scriptedAnswers.append(key.lowercased())
    }

    // No `hasScriptedAnswers` counterpart to `InputDialog`'s, deliberately: the one thing it would
    // prove — that the conflict dialog was really reached — is already settled by what the answer
    // *did*. Only "Append" produces a merged target, and the scenario asserts that on disk. An
    // instrument with no reader is the shape this session has been removing, not adding.
    #endif

    @MainActor
    private static func ask(source: FileFacts, target: FileFacts,
                            choices: [Choice]) -> OverwriteDecision {
        #if DEBUG
        // Answered from a script, without ever showing the dialog. Inside `ask` rather than at the
        // two callers, for the reason `DefaultAutomationCore.record` writes down: every consumer
        // passes through here, so this is the one place that has to remember.
        //
        // The chosen `Choice`'s own closure runs, so a scripted "Overwrite All" sets the blanket
        // exactly as a click does. A queued key that matches nothing is consumed and answered
        // `.abort` with a log line: falling through to the real dialog would hang the run, and
        // silently ignoring it would let a mistyped scenario pass.
        if !scriptedAnswers.isEmpty {
            let wanted = scriptedAnswers.removeFirst()
            if let choice = choices.first(where: { $0.key == wanted }) {
                NSLog("[automation] overwrite: %@ for %@", wanted, target.name)
                return choice.make()
            }
            NSLog("[automation] overwrite: no choice named %@ (have: %@)", wanted,
                  choices.map(\.key).joined(separator: ","))
            return .abort
        }
        #endif
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Replace “\(target.name)”?")
        alert.informativeText = Self.overwriteInfo(source: source, target: target)
        alert.accessoryView = Self.previewAccessory(source: source, target: target)   // F-086
        for choice in choices { alert.addButton(withTitle: choice.title) }
        let idx = Self.buttonIndex(for: alert.runModal())
        return choices.indices.contains(idx) ? choices[idx].make() : .abort
    }


    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision {
        if case .skipAll = currentBlanket() {
            record(path, "\(error)")   // continue-on-error: log every skipped failure (F-089)
            return .skip
        }

        let decision = await MainActor.run { () -> ErrorDecision in
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = String(localized: "Error")
            alert.informativeText = "\(path): \(error)"

            alert.addButton(withTitle: String(localized: "Retry"))
            alert.addButton(withTitle: String(localized: "Skip"))
            alert.addButton(withTitle: String(localized: "Skip All"))
            alert.addButton(withTitle: String(localized: "Abort"))

            switch Self.buttonIndex(for: alert.runModal()) {
            case 0: return .retry
            case 1: return .skip
            case 2:
                self.setBlanket(.skipAll)
                return .skip
            default: return .abort
            }
        }
        if decision == .skip { record(path, "\(error)") }
        return decision
    }

    // MARK: - Helpers

    /// Maps an alert's modal response to a zero-based button index, so alerts
    /// with more than three buttons (no named `NSApplication.ModalResponse`
    /// constants beyond the third) can still be switched over.
    private static func buttonIndex(for response: NSApplication.ModalResponse) -> Int {
        response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    /// A side-by-side "Source ▸ Target" preview (thumbnail + size/date) shown as the
    /// overwrite alert's accessory view (F-086). Thumbnails come from QuickLook via
    /// NSWorkspace icons as a fast, dependency-free fallback for any file type.
    private static func previewAccessory(source: FileFacts, target: FileFacts) -> NSView {
        let container = NSStackView(views: [
            filePreview(title: String(localized: "Source"), facts: source),
            arrowLabel(),
            filePreview(title: String(localized: "Target"), facts: target),
        ])
        container.orientation = .horizontal
        container.alignment = .top
        container.spacing = 14
        container.frame = NSRect(x: 0, y: 0, width: 340, height: 132)
        return container
    }

    private static func arrowLabel() -> NSView {
        let l = NSTextField(labelWithString: "▸")
        l.font = .systemFont(ofSize: 20)
        l.textColor = .secondaryLabelColor
        let wrap = NSStackView(views: [l]); wrap.alignment = .centerY
        wrap.heightAnchor.constraint(equalToConstant: 96).isActive = true
        return wrap
    }

    /// One column: title, a 64×64 thumbnail, and a size/date caption.
    private static func filePreview(title: String, facts: FileFacts) -> NSView {
        let head = NSTextField(labelWithString: title)
        head.font = .boldSystemFont(ofSize: 11)
        head.alignment = .center

        let image = NSImageView()
        image.imageScaling = .scaleProportionallyUpOrDown
        image.image = thumbnail(for: facts)
        image.widthAnchor.constraint(equalToConstant: 64).isActive = true
        image.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let sizeText = facts.isDirectory ? String(localized: "Folder")
            : ByteSize(facts.size).formatted(style: .kb)
        let dateText = facts.modified.map { dateFormatter.string(from: $0) } ?? String(localized: "unknown")
        let caption = NSTextField(labelWithString: "\(sizeText)\n\(dateText)")
        caption.font = .systemFont(ofSize: 10)
        caption.textColor = .secondaryLabelColor
        caption.alignment = .center
        caption.maximumNumberOfLines = 2

        let col = NSStackView(views: [head, image, caption])
        col.orientation = .vertical
        col.alignment = .centerX
        col.spacing = 4
        col.widthAnchor.constraint(equalToConstant: 120).isActive = true
        return col
    }

    /// A thumbnail for the file: a real image preview for image files, otherwise the
    /// Finder icon for its type. Directories get the generic folder icon.
    private static func thumbnail(for facts: FileFacts) -> NSImage {
        if !facts.isDirectory,
           let img = NSImage(contentsOfFile: facts.path), img.isValid,
           Self.imageExtensions.contains((facts.name as NSString).pathExtension.lowercased()) {
            return img
        }
        return NSWorkspace.shared.icon(forFile: facts.path)
    }

    private static let imageExtensions: Set<String> =
        ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "webp"]

    private static func overwriteInfo(source: FileFacts, target: FileFacts) -> String {
        let targetSize = ByteSize(target.size).formatted(style: .kb)
        let sourceSize = ByteSize(source.size).formatted(style: .kb)
        let targetDate = target.modified.map { dateFormatter.string(from: $0) }
            ?? String(localized: "unknown")
        let sourceDate = source.modified.map { dateFormatter.string(from: $0) }
            ?? String(localized: "unknown")

        return String(localized: """
            Target: \(targetSize), \(targetDate)
            Source: \(sourceSize), \(sourceDate)
            """)
    }
}
