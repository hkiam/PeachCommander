// SPDX-License-Identifier: Apache-2.0
// MacroRecorder.swift — building a macro out of what just happened (F-478).
//
// There is no recorder in the usual sense. Nothing watches the user and nothing has to be switched on
// first: every action that went through the Automation Core is already in the audit log, with its
// arguments, so "make a macro out of that" is a read of a file that was written anyway.
//
// **The honest limit, which belongs in the help page too.** The log holds what went through the
// Automation Core — the assistant, an MCP client, another macro. It does NOT hold manual panel work:
// F5, F6, a rename in the panel. Those paths do not record, so a user who copies a folder by hand and
// then asks for a macro of it will be shown nothing. Making them record is a separate change across
// many operation paths and is not this.
//
// Turning an entry back into a step is deliberately literal: the arguments are the ones that ran, with
// no attempt to generalise a path back into `%P` or `%S`. A guessed generalisation is the failure mode
// here — a macro that quietly means "the folder I happened to be in that day" is worse than one whose
// paths are visibly absolute and can be edited.

import Foundation

public enum MacroRecorder {

    /// One candidate step, and whether it can be replayed at all.
    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let tool: String
        /// What the row reads.
        public let text: String
        /// The step, when there is one. Nil when the entry cannot be replayed.
        public let step: MacroStep?
        /// Why it cannot, when it cannot.
        public let unavailable: String?

        public var isReplayable: Bool { step != nil }
    }

    /// The recent log entries as macro candidates, newest first — the order `recent` returns and the
    /// order the reader saw them happen in, reversed.
    ///
    /// Read actions never reach the log, so what comes back is the changes: exactly the set somebody
    /// means by "what I just did".
    public static func candidates(from entries: [AuditEntry]) -> [Candidate] {
        entries.enumerated().map { index, entry in
            let id = String(index + 1)
            // Built from the *verbatim* arguments where there are any, not from `entry.arguments`: that
            // one is clipped at 60 characters per value for a log reader, and a row reading
            // "move destination=/private/tmp/claude-501/-Users-maik1-Sources-github-PeachCom…" tells
            // nobody which move it was. What distinguishes two moves is the file name, which is at the
            // end of a path — exactly the part clipping removes.
            let text = MacroPlan.describe(tool: entry.tool, argumentsJSON: entry.argumentsJSON)
                ?? "\(entry.tool) \(entry.arguments)"
            // `run_macro` is skipped as a candidate: recording it would build a macro that runs a
            // macro, which the runner refuses anyway. Better to say so here than to offer a row that
            // cannot work.
            if entry.tool == "run_macro" {
                return Candidate(id: id, tool: entry.tool, text: text, step: nil,
                                 unavailable: "a macro cannot run another macro")
            }
            guard entry.outcome == "ok" else {
                return Candidate(id: id, tool: entry.tool, text: text, step: nil,
                                 unavailable: "this action did not succeed")
            }
            guard let json = entry.argumentsJSON else {
                return Candidate(id: id, tool: entry.tool, text: text, step: nil,
                                 unavailable: "its arguments were too large to record in full")
            }
            guard let step = step(tool: entry.tool, argumentsJSON: json) else {
                return Candidate(id: id, tool: entry.tool, text: text, step: nil,
                                 unavailable: "its arguments could not be read back")
            }
            return Candidate(id: id, tool: entry.tool, text: text, step: step, unavailable: nil)
        }
    }

    /// Build a macro from the candidates the user kept.
    ///
    /// `keeping` names rows to include; the steps come out in the order they *happened*, not the order
    /// they were listed. The list is newest-first because that is how somebody looks for what they just
    /// did, and a macro has to run oldest-first or it undoes itself.
    public static func macro(id: String, title: String, from candidates: [Candidate],
                             keeping kept: Set<String>) -> Macro {
        let steps = candidates
            .filter { kept.contains($0.id) }
            .compactMap(\.step)
            .reversed()
        return Macro(id: id, title: title, steps: Array(steps))
    }

    static func step(tool: String, argumentsJSON: String) -> MacroStep? {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }
        var arguments: [String: MacroArgument] = [:]
        for (key, value) in dict {
            guard let argument = argument(for: value) else { return nil }
            arguments[key] = argument
        }
        return MacroStep(tool: tool, arguments: arguments)
    }

    /// A logged JSON value as a macro argument.
    ///
    /// Refuses anything a macro argument cannot hold — a nested object, a mixed array — rather than
    /// flattening it into something that looks close. `NSNumber` has to be tested for booleanness
    /// before numberness: JSONSerialization gives `true` as an NSNumber, and read as a number it would
    /// turn a flag into `1`.
    private static func argument(for value: Any) -> MacroArgument? {
        if let s = value as? String { return .text(s) }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return .flag(n.boolValue) }
            return .number(n.doubleValue)
        }
        if let list = value as? [String] { return .list(list) }
        if let list = value as? [Any], list.isEmpty { return .list([]) }
        return nil
    }
}
