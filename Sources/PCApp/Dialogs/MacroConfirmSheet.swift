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
    static var dumpPath: String? { AutomationProbe.value("PC_MACRO_CONFIRM_DUMP") }
    static var appliesEverything: Bool { AutomationProbe.isOn("PC_MACRO_CONFIRM_APPLY") }
    /// Row ids to strike out during a probe run, as `PC_MACRO_CONFIRM_REJECT=1,3`.
    static var rejected: Set<String> {
        let raw = AutomationProbe.value("PC_MACRO_CONFIRM_REJECT") ?? ""
        return Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                      .filter { !$0.isEmpty })
    }
    /// Where to write a picture of the sheet instead of showing it: `PC_MACRO_CONFIRM_SHOT=<path>`.
    static var shotPath: String? { AutomationProbe.value("PC_MACRO_CONFIRM_SHOT") }

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

    @MainActor
    private static func accessoryView(for rows: [PlanItem],
                                      into checkboxes: inout [(id: String, button: NSButton)]) -> NSView {
        var boxes: [NSView] = []
        for row in rows {
            // The row in the reader's language. `row.text` stays English and stays what the model and
            // the log see; this window is the one place a person reads it, and it was the one place
            // still saying "Permanently delete a.pdf" under translated chrome.
            let title = PlanPhraseText.text(of: row)
            let box = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            box.state = .on
            box.lineBreakMode = .byTruncatingMiddle
            box.toolTip = title             // the full text, when the label had to be truncated
            boxes.append(box)
            checkboxes.append((row.id, box))
        }
        // A macro's rows are a sequence, not a list of independent items, and this is where that
        // difference becomes visible: strike out the step that creates the folder and the step that
        // fills it goes with it. Without this the macro ran, made it to the dependent step, failed
        // there and stopped — having already carried out everything in between, which is the one
        // outcome the dialog exists to prevent.
        let links = StepLinks(rows: rows, boxes: checkboxes)
        for (_, box) in checkboxes {
            box.target = links
            box.action = #selector(StepLinks.stateChanged(_:))
        }
        let list = AccessoryLayout.scrollingList(boxes, width: 420, maxHeight: 260)
        let view = AccessoryLayout.stack([list], width: 420)
        // The alert owns the accessory and the accessory owns the coordinator; without this the
        // target is deallocated as soon as this method returns and the checkboxes do nothing.
        objc_setAssociatedObject(view, &StepLinks.key, links, .OBJC_ASSOCIATION_RETAIN)
        return view
    }

    /// Where to put the alert so it reads as belonging to `window`.
    private static func centred(_ alert: NSAlert, over window: NSWindow) -> NSPoint {
        let size = alert.window.frame.size
        let frame = window.frame
        return NSPoint(x: frame.midX - size.width / 2,
                       y: frame.midY - size.height / 2 + frame.height / 6)
    }
}

/// Keeps the checkboxes of a macro's plan consistent with the macro's own step dependencies.
///
/// Unchecking a step unchecks everything downstream of it and disables those boxes, so the
/// dependency is visible rather than merely enforced later by a failure. Checking it back on undoes
/// exactly that and no more: a step the *user* had struck out stays struck out.
@MainActor
private final class StepLinks: NSObject {
    nonisolated(unsafe) static var key: UInt8 = 0

    /// For each step id, the ids of the steps that cannot run without it. The transitive closure, so
    /// striking out step 1 also reaches a step 3 that only names step 2.
    private let dependents: [String: Set<String>]
    private let boxes: [String: NSButton]
    /// Boxes this coordinator turned off, so switching the step above back on restores what the user
    /// chose rather than everything. Without it, unchecking and re-checking one row silently dropped
    /// every row below it from the run.
    private var switchedOffByUs: Set<String> = []

    init(rows: [PlanItem], boxes: [(id: String, button: NSButton)]) {
        var direct: [String: Set<String>] = [:]
        for row in rows {
            for needed in row.dependsOn { direct[needed, default: []].insert(row.id) }
        }
        // Closure by repeated expansion. A macro is a handful of steps and the graph points strictly
        // backwards, so this terminates in at most that many rounds.
        var closed = direct
        for _ in rows.indices {
            var grew = false
            for (step, reached) in closed {
                let next = reached.union(reached.flatMap { closed[$0] ?? [] })
                if next != reached { closed[step] = next; grew = true }
            }
            if !grew { break }
        }
        self.dependents = closed
        self.boxes = Dictionary(boxes.map { ($0.id, $0.button) }, uniquingKeysWith: { a, _ in a })
        super.init()
    }

    @objc func stateChanged(_ sender: NSButton) {
        guard let id = boxes.first(where: { $0.value === sender })?.key,
              let reached = dependents[id] else { return }
        for dependent in reached {
            guard let box = boxes[dependent] else { continue }
            if sender.state != .on {
                box.isEnabled = false
                if box.state == .on { box.state = .off; switchedOffByUs.insert(dependent) }
            } else {
                // Only re-enabled if nothing *else* still holds it down — two steps can depend on the
                // same earlier one, and bringing one back must not free a row the other still needs.
                guard !isHeldDown(dependent) else { continue }
                box.isEnabled = true
                if switchedOffByUs.remove(dependent) != nil { box.state = .on }
            }
        }
    }

    /// Whether some other struck-out step still stands between `dependent` and running.
    private func isHeldDown(_ dependent: String) -> Bool {
        dependents.contains { step, reached in
            reached.contains(dependent) && boxes[step]?.state != .on
        }
    }

}
