// SPDX-License-Identifier: Apache-2.0
// AISheets.swift — the small AppKit pieces a direct action needs to show its work.
//
// A direct action has no chat panel to write into, so it needs three things of its own: something
// that says it is working and can be stopped, something that shows a list of proposals the reader
// can strike rows out of, and something that shows a block of text they can copy.
//
// The host offers `presentInfo`, which is one button and one string — enough to report an outcome,
// not enough to ask "rename these thirty-eight, but not those two". So these are built here, over
// `services.parentWindow`, the way the Git plugin already builds its own alerts.

import AppKit

/// The verification hook, in the shape this plugin already uses for the chat (PC_AI_PROBE,
/// PC_AI_RENDER). A direct action ends in a modal sheet, and a modal is what turns an automation
/// run into a run that hangs until somebody clicks it — the launch-time alerts cost exactly that
/// before they were guarded. With `PC_AI_DIRECT_DUMP=<path>` set, a sheet writes what it would
/// have shown to that file and does not appear; `PC_AI_DIRECT_APPLY=1` then answers it as though
/// every row had been approved, so the writes underneath are exercised too.
enum AISheetProbe {
    static var dumpPath: String? { ProcessInfo.processInfo.environment["PC_AI_DIRECT_DUMP"] }
    static var appliesEverything: Bool {
        ProcessInfo.processInfo.environment["PC_AI_DIRECT_APPLY"] == "1"
    }

    /// Append one record, because a single run exercises several actions.
    static func record(_ lines: [String]) {
        guard let path = dumpPath else { return }
        let block = lines.joined(separator: "\n") + "\n---\n"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// A sheet that says what is happening and can be cancelled.
///
/// Cancellation is cooperative: the caller checks `isCancelled` between files. There is nothing to
/// interrupt inside one generation, and stopping between files is the granularity a reader means
/// when they press Cancel on "file 12 of 40".
@MainActor
final class AIProgressSheet {
    let parentWindow: NSWindow?
    private var panel: NSWindow?
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private(set) var isCancelled = false

    init(parent: NSWindow?) { self.parentWindow = parent }

    func begin(_ text: String) {
        isCancelled = false
        guard AISheetProbe.dumpPath == nil else { return }
        guard let parentWindow, panel == nil else { return }

        title.stringValue = text
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        detail.stringValue = ""
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        bar.style = .bar
        bar.isIndeterminate = true
        bar.startAnimation(nil)

        let cancel = NSButton(title: String(localized: "Cancel", comment: "AI: stop a direct action"),
                              target: self, action: #selector(cancelTapped))
        cancel.keyEquivalent = "\u{1b}"

        let stack = NSStackView(views: [title, bar, detail, cancel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        NSLayoutConstraint.activate([
            bar.widthAnchor.constraint(equalToConstant: 320),
            detail.widthAnchor.constraint(equalToConstant: 320),
        ])

        let sheet = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        sheet.contentView = stack
        sheet.setContentSize(stack.fittingSize)
        panel = sheet
        parentWindow.beginSheet(sheet)
    }

    func update(_ name: String, done: Int, total: Int) {
        detail.stringValue = total > 1
            ? String(format: String(localized: "%1$@ (%2$lld of %3$lld)",
                                    comment: "AI: progress, file name and position"),
                     name, done + 1, total)
            : name
        if total > 1 {
            bar.isIndeterminate = false
            bar.minValue = 0
            bar.maxValue = Double(total)
            bar.doubleValue = Double(done)
        }
    }

    func end() {
        guard let panel else { return }
        bar.stopAnimation(nil)
        parentWindow?.endSheet(panel)
        panel.orderOut(nil)
        self.panel = nil
    }

    @objc private func cancelTapped() { isCancelled = true }
}

/// A list of proposals the reader approves as a whole, minus the rows they strike out.
@MainActor
enum AIProposalSheet {

    struct Row {
        let id: String
        let text: String
        /// A second, dimmed line — the model's reason, or the comment it proposes. May be empty.
        let detail: String
    }

    /// Ask, then hand back the ids still ticked. Not called at all when the reader cancels, so a
    /// caller never has to distinguish "approved nothing" from "did not approve".
    static func ask(title: String, message: String, rows: [Row], applyTitle: String,
                    parent: NSWindow?, then: @escaping ([String]) -> Void) {
        guard !rows.isEmpty else { return }
        if AISheetProbe.dumpPath != nil {
            AISheetProbe.record(["PROPOSAL \(title)", message]
                                + rows.map { "\($0.id)\t\($0.text)\t\($0.detail)" })
            if AISheetProbe.appliesEverything { then(rows.map(\.id)) }
            return
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message.isEmpty
            ? String(format: String(localized: "%lld change(s) to apply. Untick anything you want left alone.",
                                    comment: "AI: proposal sheet subtitle"), rows.count)
            : message
        alert.addButton(withTitle: applyTitle)
        alert.addButton(withTitle: String(localized: "Cancel", comment: "AI: decline the proposals"))

        var boxes: [(id: String, box: NSButton)] = []
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 6
        for row in rows {
            let box = NSButton(checkboxWithTitle: row.text, target: nil, action: nil)
            box.state = .on
            boxes.append((row.id, box))
            if row.detail.isEmpty {
                list.addArrangedSubview(box)
            } else {
                let why = NSTextField(labelWithString: row.detail)
                why.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
                why.textColor = .secondaryLabelColor
                why.lineBreakMode = .byTruncatingTail
                let pair = NSStackView(views: [box, why])
                pair.orientation = .vertical
                pair.alignment = .leading
                pair.spacing = 1
                pair.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                why.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                list.addArrangedSubview(pair)
            }
        }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460,
                                                height: min(320, max(60, rows.count * 34))))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        list.frame = NSRect(x: 0, y: 0, width: 440, height: list.fittingSize.height)
        scroll.documentView = list
        alert.accessoryView = scroll

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            then(boxes.filter { $0.box.state == .on }.map(\.id))
        }
        if let parent { alert.beginSheetModal(for: parent, completionHandler: handler) }
        else { handler(alert.runModal()) }
    }
}

/// A block of text the reader can read and copy — what a summary is.
@MainActor
enum AITextSheet {
    static func show(title: String, body: String, parent: NSWindow?) {
        if AISheetProbe.dumpPath != nil {
            AISheetProbe.record(["TEXT \(title)", body])
            return
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: String(localized: "Copy", comment: "AI: copy the summary"))
        alert.addButton(withTitle: String(localized: "Close", comment: "AI: dismiss the summary"))

        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 460, height: 260))
        text.string = body
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 4, height: 4)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 260))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = text
        alert.accessoryView = scroll

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertFirstButtonReturn else { return }
            // The clipboard, honestly: the assistant used to be asked for this and answered by
            // calling the file-copy tool and reporting a success that never happened.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(body, forType: .string)
        }
        if let parent { alert.beginSheetModal(for: parent, completionHandler: handler) }
        else { handler(alert.runModal()) }
    }
}
