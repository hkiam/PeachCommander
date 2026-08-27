// SPDX-License-Identifier: Apache-2.0
// MacroRecorderSheet.swift — "make a macro out of what just happened" (F-478).
//
// Same construction as `MacroConfirmSheet` and for the same reasons: an NSAlert with an accessory view,
// because a window controller would add a title bar, a remembered size and a key-view loop that this
// dialog does not want.
//
// Rows that cannot be replayed are shown *disabled with their reason* rather than left out. A user who
// did five things and is offered three needs to know what happened to the other two — silently dropping
// them reads as the feature having missed them.

import AppKit
import PCAutomation

enum MacroRecorderSheet {

    struct Result {
        let id: String
        let title: String
        let kept: Set<String>
        let addsButton: Bool
    }

    @MainActor
    static func present(candidates: [MacroRecorder.Candidate], existingIDs: [String],
                        in window: NSWindow?) -> Result? {
        let nameField = NSTextField(string: String(localized: "My macro"))
        nameField.placeholderString = String(localized: "Macro name")
        let buttonBox = NSButton(checkboxWithTitle: String(localized: "Also add a button for it"),
                                 target: nil, action: nil)
        buttonBox.state = .on
        var checkboxes: [(id: String, button: NSButton)] = []

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Make a macro from recent actions")
        alert.informativeText = String(localized: """
            These are the actions that went through the assistant or another macro, newest first. \
            Keep the ones the macro should repeat.
            """)
        alert.addButton(withTitle: String(localized: "Save Macro"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.accessoryView = accessory(candidates: candidates, nameField: nameField,
                                        buttonBox: buttonBox, into: &checkboxes)

        if let shot = MacroRecorderProbe.shotPath {
            MacroRecorderProbe.record(["shot: " + DialogShot.capture(alert, to: shot)])
        }
        if let probe = MacroRecorderProbe.answer {
            MacroRecorderProbe.record(["title: \(probe.title)"]
                + candidates.map { "row \($0.id): \($0.text)"
                    + ($0.isReplayable ? "" : " [unavailable: \($0.unavailable ?? "")]") })
            return Result(id: MacroStore.proposedID(for: probe.title, existing: existingIDs),
                          title: probe.title, kept: probe.kept, addsButton: probe.addsButton)
        }

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let title = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        let kept = Set(checkboxes.filter { $0.button.state == .on }.map(\.id))
        return Result(id: MacroStore.proposedID(for: title, existing: existingIDs),
                      title: title.isEmpty ? String(localized: "My macro") : title,
                      kept: kept, addsButton: buttonBox.state == .on)
    }

    private static func accessory(candidates: [MacroRecorder.Candidate], nameField: NSTextField,
                                  buttonBox: NSButton,
                                  into checkboxes: inout [(id: String, button: NSButton)]) -> NSView {
        var boxes: [NSView] = []
        for candidate in candidates {
            let title = candidate.isReplayable
                ? candidate.text
                : "\(candidate.text)  —  \(candidate.unavailable ?? "")"
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.lineBreakMode = .byTruncatingMiddle
            box.toolTip = title
            // Unavailable rows are visible and unusable, not hidden. Off by default even when usable:
            // "everything I did in the last half hour" is rarely the macro somebody means.
            box.isEnabled = candidate.isReplayable
            box.state = .off
            boxes.append(box)
            if candidate.isReplayable { checkboxes.append((candidate.id, box)) }
        }

        let scroll = AccessoryLayout.scrollingList(boxes, width: Self.accessoryWidth, maxHeight: 240)

        let nameLabel = NSTextField(labelWithString: String(localized: "Name:"))
        let nameRow = NSStackView(views: [nameLabel, nameField])
        nameRow.orientation = .horizontal
        nameRow.spacing = 6
        nameRow.translatesAutoresizingMaskIntoConstraints = false
        // The field takes the rest of the row. Without this the stack gives both views their intrinsic
        // width and the field ends up a few characters wide, next to a label with nothing holding it.
        nameField.setContentHuggingPriority(.init(1), for: .horizontal)
        nameRow.widthAnchor.constraint(equalToConstant: Self.accessoryWidth).isActive = true

        return AccessoryLayout.stack([scroll, nameRow, buttonBox], width: Self.accessoryWidth)
    }

    /// One width for every row in the accessory, so the list, the name field and the checkbox line up.
    private static let accessoryWidth: CGFloat = 460
}

/// The headless answer for this dialog, in the shape `MacroConfirmProbe` and the AI plugins' sheets
/// already use: a modal turns an automation run into a run that hangs until somebody clicks it.
///
///   PC_MACRO_RECORD=<title>          answer the sheet with this name
///   PC_MACRO_RECORD_KEEP=1,2         which rows to keep (default: none, i.e. nothing is saved)
///   PC_MACRO_RECORD_BUTTON=0         do not add a button (default: add one)
///   PC_MACRO_RECORD_DUMP=<path>      write what the sheet would have shown
enum MacroRecorderProbe {
    struct Answer {
        let title: String
        let kept: Set<String>
        let addsButton: Bool
    }

    static var answer: Answer? {
        let env = ProcessInfo.processInfo.environment
        guard let title = env["PC_MACRO_RECORD"], !title.isEmpty else { return nil }
        let kept = Set((env["PC_MACRO_RECORD_KEEP"] ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        return Answer(title: title, kept: kept, addsButton: env["PC_MACRO_RECORD_BUTTON"] != "0")
    }

    /// Where to write a picture of the sheet instead of showing it: `PC_MACRO_RECORD_SHOT=<path>`.
    static var shotPath: String? { ProcessInfo.processInfo.environment["PC_MACRO_RECORD_SHOT"] }

    static func record(_ lines: [String]) {
        guard let path = ProcessInfo.processInfo.environment["PC_MACRO_RECORD_DUMP"] else { return }
        let block = lines.joined(separator: "\n") + "\n---\n"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
    }
}
