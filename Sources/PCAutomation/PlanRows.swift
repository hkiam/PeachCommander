// SPDX-License-Identifier: Apache-2.0
// PlanRows.swift - A gated plan as rows the user can strike out (F-450).
//
// `needsConfirmation` carries one string, and for a single action that is the right shape: "Delete
// report.pdf" is agreed to or not. It is the wrong shape for the request that made this necessary —
// "clean up my Downloads" — where the answer is usually "yes, except those three". Without rows the only
// answers are all and nothing, and a user who wants all-but-three has to reject the whole plan and
// describe the exception in prose, which the model then has to get right on the second attempt.
//
// The rows are derived from the arguments rather than declared by the model, for the same reason the
// plan text is: what the user strikes out has to be what the tool will actually skip, and that is a
// property of the arguments and nothing else.

import Foundation

/// One line of a plan, addressable on its own.
public struct PlanItem: Sendable, Equatable, Codable {
    /// Stable within this plan. It is the argument value the row stands for, so striking the row out
    /// and filtering the arguments cannot disagree about which item was meant.
    public let id: String
    /// What the user reads.
    public let text: String
    public init(id: String, text: String) { self.id = id; self.text = text }
}

public enum PlanRows {

    /// The rows of a plan for `tool`, or none when the action cannot sensibly be divided.
    ///
    /// A `write_file` is not a list, and neither is a `make_directory`: striking out the only row would
    /// be the same as cancelling, and offering that as a choice is noise.
    public static func of(tool: String, arguments: Data?) -> [PlanItem] {
        let dict = object(arguments)
        switch tool {
        case "rename_batch":
            guard let old = dict["old_names"] as? [String], let new = dict["new_names"] as? [String],
                  old.count == new.count else { return [] }
            return zip(old, new).filter { $0 != $1 }.map { PlanItem(id: $0, text: "\($0) → \($1)") }
        case "move", "copy":
            guard let sources = dict["sources"] as? [String], sources.count > 1 else { return [] }
            return sources.map { PlanItem(id: $0, text: ($0 as NSString).lastPathComponent) }
        case "move_to_trash", "delete_permanently":
            guard let paths = dict["paths"] as? [String], paths.count > 1 else { return [] }
            return paths.map { PlanItem(id: $0, text: ($0 as NSString).lastPathComponent) }
        // A macro's rows are its steps, but they cannot be derived from the arguments — those hold
        // only the macro's id. The Core answers for this one out of its macro lookup; see
        // `DefaultAutomationCore.planItems`. Named here so a reader of this switch is not left to
        // conclude that a macro is indivisible.
        case "run_macro":
            return []
        default:
            return []
        }
    }

    /// `arguments` with the rejected rows removed, or nil when nothing would be left to do.
    ///
    /// Nil rather than an empty list: a `move` with no sources is not a smaller move, it is a request
    /// that no longer says anything, and running it would report success for having done nothing.
    public static func arguments(tool: String, arguments: Data?,
                                 rejecting rejected: Set<String>) -> Data?? {
        guard !rejected.isEmpty else { return .some(arguments) }
        var dict = object(arguments)
        switch tool {
        case "rename_batch":
            guard let old = dict["old_names"] as? [String], let new = dict["new_names"] as? [String],
                  old.count == new.count else { return .some(arguments) }
            // Pairwise, so a struck-out row takes its new name with it. Filtering the two lists
            // separately would shift every pair after the gap onto the wrong name — the batch would
            // still apply, and it would rename the wrong files.
            let kept = zip(old, new).filter { !rejected.contains($0.0) }
            guard !kept.isEmpty else { return .none }
            dict["old_names"] = kept.map(\.0)
            dict["new_names"] = kept.map(\.1)
        case "move", "copy":
            guard let sources = dict["sources"] as? [String] else { return .some(arguments) }
            let kept = sources.filter { !rejected.contains($0) }
            guard !kept.isEmpty else { return .none }
            dict["sources"] = kept
        case "move_to_trash", "delete_permanently":
            guard let paths = dict["paths"] as? [String] else { return .some(arguments) }
            let kept = paths.filter { !rejected.contains($0) }
            guard !kept.isEmpty else { return .none }
            dict["paths"] = kept
        // The struck-out rows are step ids, so they can be written into the arguments here without
        // knowing anything about the macro — which keeps this file pure. The runner skips exactly
        // these, so what the user left out is left out by the thing doing the work.
        case "run_macro":
            dict["skip_steps"] = Array(rejected).sorted()
        default:
            return .some(arguments)
        }
        return .some(try? JSONSerialization.data(withJSONObject: dict))
    }

    private static func object(_ data: Data?) -> [String: Any] {
        guard let data, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return o
    }
}
