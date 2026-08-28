// SPDX-License-Identifier: Apache-2.0
// MacroAskSheet.swift — the values a macro asks for before it runs (F-478).
//
// Shown *before* the confirmation, never instead of it. The order matters and is the whole reason this
// dialog exists where it does: the answers go into the plan, so the rows a person approves already say
// "Move the selection into “Rechnungen”" rather than "into whatever you are about to type". A macro
// that asked when it reached the step would have been approved on a guess.
//
// One field per question, in the order the macro asks them, with the macro's own wording as the label —
// that text is the user's, written in their `macros.json`, and translating it would mean translating
// something the app did not write.
//
// Same construction as the other two macro sheets: an NSAlert with an accessory view, because a window
// controller would add a title bar, a remembered size and a key-view loop this does not want.

import AppKit
import PCAutomation

enum MacroAskSheet {

    /// Ask, and return the answers keyed by question — or nil if the user cancelled, which cancels
    /// the macro before anything has been proposed, let alone run.
    @MainActor
    static func present(_ questions: [MacroQuestion], macroTitle: String,
                        in window: NSWindow?) -> [String: String]? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Before running this macro")
        alert.informativeText = String(format:
            String(localized: "“%@” needs these values."), macroTitle)
        alert.addButton(withTitle: String(localized: "Continue"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        var fields: [(prompt: String, field: NSTextField)] = []
        alert.accessoryView = accessory(questions, into: &fields)

        if let probe = MacroAskProbe.answers {
            MacroAskProbe.record(questions.map { "ask: \($0.prompt) = \($0.defaultValue)" })
            // Only the questions this macro actually asked, so a probe carrying answers for a different
            // macro cannot smuggle a value into this one.
            return Dictionary(uniqueKeysWithValues: questions.map {
                ($0.prompt, probe[$0.prompt] ?? $0.defaultValue)
            })
        }
        if MacroAskProbe.cancels {
            MacroAskProbe.record(questions.map { "ask: \($0.prompt) = \($0.defaultValue)" }
                                 + ["answer: cancelled"])
            return nil
        }

        if let window { alert.window.setFrameOrigin(centred(alert, over: window)) }
        // The first field takes the keystrokes, or the dialog opens with the focus on a button and the
        // first thing typed goes nowhere.
        alert.window.initialFirstResponder = fields.first?.field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Dictionary(uniqueKeysWithValues: fields.map { ($0.prompt, $0.field.stringValue) })
    }

    @MainActor
    private static func accessory(_ questions: [MacroQuestion],
                                  into fields: inout [(prompt: String, field: NSTextField)]) -> NSView {
        var rows: [NSView] = []
        for question in questions {
            let label = NSTextField(wrappingLabelWithString: question.prompt)
            label.font = .systemFont(ofSize: NSFont.systemFontSize)
            let field = NSTextField(string: question.defaultValue)
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: Self.accessoryWidth).isActive = true
            rows.append(label)
            rows.append(field)
            fields.append((question.prompt, field))
        }
        // Tab moves between the fields in the order they are asked. Without the loop being wired the
        // ring is whatever AppKit inferred from the view tree, which for a stack of pairs is not it.
        for (index, entry) in fields.enumerated() {
            entry.field.nextKeyView = fields[(index + 1) % fields.count].field
        }
        return AccessoryLayout.stack(rows, width: Self.accessoryWidth)
    }

    private static func centred(_ alert: NSAlert, over window: NSWindow) -> NSPoint {
        let size = alert.window.frame.size
        let frame = window.frame
        return NSPoint(x: frame.midX - size.width / 2,
                       y: frame.midY - size.height / 2 + frame.height / 6)
    }

    private static let accessoryWidth: CGFloat = 380
}

/// The headless answer for this dialog, in the shape the other macro sheets already use — a modal is
/// what turns an automation run into a run that hangs until somebody clicks it (F-436).
///
///   PC_MACRO_ASK=Question=value;Other=value   answer the fields (missing ones keep their default)
///   PC_MACRO_ASK_CANCEL=1                     cancel instead, so "it asked and nothing ran" is checkable
///   PC_MACRO_ASK_DUMP=<path>                  write what the sheet would have shown
enum MacroAskProbe {
    /// Parsed from `PC_MACRO_ASK`, or nil when this run does not answer the sheet.
    ///
    /// `;` between pairs and `=` inside one. A question containing either cannot be answered from the
    /// environment, which is a limit of the harness and not of the feature.
    static var answers: [String: String]? {
        guard let raw = ProcessInfo.processInfo.environment["PC_MACRO_ASK"], !raw.isEmpty else {
            return nil
        }
        var out: [String: String] = [:]
        for pair in raw.split(separator: ";") {
            guard let separator = pair.firstIndex(of: "=") else { continue }
            out[String(pair[pair.startIndex..<separator])] = String(pair[pair.index(after: separator)...])
        }
        return out
    }

    static var cancels: Bool { ProcessInfo.processInfo.environment["PC_MACRO_ASK_CANCEL"] == "1" }

    static func record(_ lines: [String]) {
        guard let path = ProcessInfo.processInfo.environment["PC_MACRO_ASK_DUMP"] else { return }
        let block = lines.joined(separator: "\n") + "\n---\n"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
    }
}
