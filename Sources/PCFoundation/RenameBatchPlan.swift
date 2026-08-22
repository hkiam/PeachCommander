// SPDX-License-Identifier: Apache-2.0
// RenameBatchPlan.swift - Checking a whole batch of renames before any of it happens (F-447).
//
// `RenameBatchEngine` applies what it can and reports what it could not, which is right for the
// Multi-Rename window: the user built the rule, saw the preview, and a single refusal is information.
// It is wrong for a batch a language model proposed. There, one bad row is usually a systematic mistake
// — an off-by-one in a counter, a pattern that did not match — and half-applying it leaves a folder the
// user has to untangle by hand. So this says no to the whole thing first, with every reason at once.

import Foundation

public enum RenameBatchPlan {

    public struct Pair: Equatable, Sendable {
        public let old: String
        public let new: String
        public init(old: String, new: String) { self.old = old; self.new = new }
    }

    /// `Error` so it can be the failure half of a `Result`; it is a description, not a thrown thing.
    public struct Problem: Equatable, Sendable, Error {
        public let name: String
        public let reason: String
        public init(name: String, reason: String) { self.name = name; self.reason = reason }
    }

    /// Pair up two parallel lists, or say why they cannot be paired.
    ///
    /// Parallel lists rather than a list of pairs because that is the shape a small model fills in
    /// reliably; the cost is that a length mismatch is possible, and it has to be caught here rather
    /// than silently truncating — a truncated batch renames some files and not others.
    public static func pair(old: [String], new: [String]) -> Result<[Pair], Problem> {
        guard old.count == new.count else {
            return .failure(Problem(name: "(the batch)",
                                    reason: "\(old.count) old name(s) and \(new.count) new one(s) — "
                                    + "they have to line up one to one"))
        }
        guard !old.isEmpty else {
            return .failure(Problem(name: "(the batch)", reason: "no files to rename"))
        }
        return .success(zip(old, new).map { Pair(old: $0, new: $1) })
    }

    /// Everything wrong with the batch, judged against the names the folder holds.
    ///
    /// `existing` is the folder's leaf names. Empty means "unknown", and the checks that need it are
    /// skipped rather than guessed at — a caller that cannot list the folder still gets the name checks.
    public static func problems(in pairs: [Pair], existing: Set<String>) -> [Problem] {
        var problems: [Problem] = []
        let renamedAway = Set(pairs.filter { $0.old != $0.new }.map(\.old))

        var seen: [String: String] = [:]     // new name -> the first old name claiming it
        for pair in pairs {
            if pair.old == pair.new { continue }          // a no-op, skipped by the engine too

            if !existing.isEmpty, !existing.contains(pair.old) {
                problems.append(Problem(name: pair.old, reason: "there is no such file in the folder"))
            }
            if let why = Self.reason(RenameValidator.validate(pair.new)) {
                problems.append(Problem(name: pair.old, reason: "\"\(pair.new)\" \(why)"))
            }
            // Two files onto one name: whichever ran second would fail, and which one that is depends
            // on the order — so the batch is refused rather than being half applied in an order the
            // user did not choose.
            if let first = seen[pair.new] {
                problems.append(Problem(name: pair.old,
                                        reason: "\"\(pair.new)\" is also the new name for \"\(first)\""))
            } else {
                seen[pair.new] = pair.old
            }
            // A collision with a file that is staying put. One that is being renamed away is fine —
            // the engine stages through temporary names, so a swap works.
            if !existing.isEmpty, existing.contains(pair.new), !renamedAway.contains(pair.new) {
                problems.append(Problem(name: pair.old,
                                        reason: "\"\(pair.new)\" already exists and is not being renamed"))
            }
        }

        if problems.isEmpty, pairs.allSatisfy({ $0.old == $0.new }) {
            problems.append(Problem(name: "(the batch)", reason: "every name is already what it should be"))
        }
        return problems
    }

    /// The validator's verdict as something a person — and a model reading the failure — can act on.
    /// `nil` for a name that is fine.
    private static func reason(_ result: RenameValidator.Result) -> String? {
        switch result {
        case .valid:            return nil
        case .empty:            return "is empty"
        case .reserved:         return "is a reserved name"
        case .containsSeparator: return "contains a path separator, and a rename may not move a file"
        }
    }

    /// The batch as a table a person reads before agreeing to it.
    ///
    /// Capped, because a confirmation nobody reads is not a confirmation: at some length the only
    /// honest thing to show is the shape and the count. The dropped rows are stated rather than
    /// silently missing.
    public static func table(_ pairs: [Pair], limit: Int = 30) -> String {
        let real = pairs.filter { $0.old != $0.new }
        guard !real.isEmpty else { return "Nothing to rename." }
        let width = real.prefix(limit).map(\.old.count).max() ?? 0
        var lines = real.prefix(limit).map {
            "  \($0.old.padding(toLength: max(width, $0.old.count), withPad: " ", startingAt: 0))  →  \($0.new)"
        }
        if real.count > limit {
            lines.append("  … and \(real.count - limit) more")
        }
        return "Rename \(real.count) file(s):\n" + lines.joined(separator: "\n")
    }
}
