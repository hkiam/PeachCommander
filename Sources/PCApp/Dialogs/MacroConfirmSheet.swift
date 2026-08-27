// SPDX-License-Identifier: Apache-2.0
// MacroConfirmSheet.swift — approving a macro, one step at a time (F-478).
//
// The Core hands back a plan and its rows; this puts them in front of the user and returns which rows
// they struck out. Built on NSAlert with an accessory view rather than as its own window controller,
// because everything a window controller would add here — a title bar, a size to remember, a key-view
// loop to install — is something this dialog does not want, and NSAlert already gets Return, Escape
// and the localized button placement right.
//
// The rows are checkboxes rather than a table: a macro has a handful of steps, and a checkbox says
// "this will happen" in a way a selected table row does not. A macro long enough to need scrolling
// gets it, capped so the dialog cannot grow taller than a small screen.

import AppKit
import PCAutomation

/// The verification hook, in the shape `AISheetProbe` already uses in the AI plugins.
///
/// This dialog is modal, and a modal is what turns an automation run into a run that hangs until
/// somebody clicks it — the launch-time alerts cost exactly that before they were guarded (F-436). So
/// with `PC_MACRO_CONFIRM_DUMP=<path>` set the sheet writes what it would have shown and does not
/// appear; `PC_MACRO_CONFIRM_APPLY=1` then answers it as though every row had been approved, so the
/// steps underneath are exercised too, and `PC_MACRO_CONFIRM_REJECT=1,3` strikes those rows out.
enum MacroConfirmProbe {
    static var dumpPath: String? { ProcessInfo.processInfo.environment["PC_MACRO_CONFIRM_DUMP"] }
    static var appliesEverything: Bool {
        ProcessInfo.processInfo.environment["PC_MACRO_CONFIRM_APPLY"] == "1"
    }
    /// Row ids to strike out during a probe run, as `PC_MACRO_CONFIRM_REJECT=1,3`.
    static var rejected: Set<String> {
        let raw = ProcessInfo.processInfo.environment["PC_MACRO_CONFIRM_REJECT"] ?? ""
        return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                      .filter { !$0.isEmpty })
    }
    /// Where to write a picture of the sheet instead of showing it: `PC_MACRO_CONFIRM_SHOT=<path>`.
    static var shotPath: String? { ProcessInfo.processInfo.environment["PC_MACRO_CONFIRM_SHOT"] }

    /// Whether this run answers the sheet at all. Without `APPLY` a probe run *cancels*, which is what
    /// makes "the dialog appeared and nothing ran" a checkable outcome rather than an absence.
    static var isActive: Bool {
        dumpPath != nil || shotPath != nil || appliesEverything || !rejected.isEmpty
    }

    static func record(_ lines: [String]) {
        guard let path = dumpPath else { return }
        let block = lines.joined(separator: "\n") + "\n---\n"
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        try? (existing + block).write(toFile: path, atomically: true, encoding: .utf8)
    }
}

enum MacroConfirmSheet {

    /// Present the plan. Returns the ids of the rows the user struck out, or nil if they cancelled.
    ///
    /// An empty set means "run all of it" — which is different from nil, and the difference is the
    /// whole point: the Core reports every row struck out as a cancellation, and a cancelled *dialog*
    /// must not be reported as one, because nothing was ever proposed to the user's satisfaction.
    @MainActor
    static func present(plan: String, rows: [PlanItem], in window: NSWindow?) -> Set<String>? {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Run this macro?")
        alert.informativeText = plan
        alert.addButton(withTitle: String(localized: "Run"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        var checkboxes: [(id: String, button: NSButton)] = []
        if !rows.isEmpty {
            alert.accessoryView = accessoryView(for: rows, into: &checkboxes)
        }

        // The probe answers only after the alert is fully built, so a shot is of the real thing and the
        // dumped rows are the ones the accessory holds — not a description of what it was going to be.
        if MacroConfirmProbe.isActive {
            var lines = ["plan: \(plan)"] + rows.map { "row \($0.id): \($0.text)" }
            if let shot = MacroConfirmProbe.shotPath {
                lines.append("shot: " + DialogShot.capture(alert, to: shot))
            }
            let runs = MacroConfirmProbe.appliesEverything || !MacroConfirmProbe.rejected.isEmpty
            lines.append("answer: " + (runs
                ? "run, rejecting [\(MacroConfirmProbe.rejected.sorted().joined(separator: ","))]"
                : "cancelled"))
            MacroConfirmProbe.record(lines)
            return runs ? MacroConfirmProbe.rejected : nil
        }

        // App-modal rather than a sheet: the caller needs the answer to decide whether to confirm the
        // token, and a sheet's completion handler cannot give it one synchronously. `window` is still
        // used to place the alert over the right window.
        if let window { alert.window.setFrameOrigin(centred(alert, over: window)) }
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return Set(checkboxes.filter { !($0.button.state == .on) }.map(\.id))
    }

    private static func accessoryView(for rows: [PlanItem],
                                      into checkboxes: inout [(id: String, button: NSButton)]) -> NSView {
        var boxes: [NSView] = []
        for row in rows {
            let box = NSButton(checkboxWithTitle: row.text, target: nil, action: nil)
            box.state = .on
            box.lineBreakMode = .byTruncatingMiddle
            box.toolTip = row.text          // the full text, when the label had to be truncated
            boxes.append(box)
            checkboxes.append((row.id, box))
        }
        let list = AccessoryLayout.scrollingList(boxes, width: 420, maxHeight: 260)
        return AccessoryLayout.stack([list], width: 420)
    }

    /// Where to put the alert so it reads as belonging to `window`.
    private static func centred(_ alert: NSAlert, over window: NSWindow) -> NSPoint {
        let size = alert.window.frame.size
        let frame = window.frame
        return NSPoint(x: frame.midX - size.width / 2,
                       y: frame.midY - size.height / 2 + frame.height / 6)
    }
}
