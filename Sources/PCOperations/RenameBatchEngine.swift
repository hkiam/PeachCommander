// SPDX-License-Identifier: Apache-2.0
// RenameBatchEngine.swift - Rename many files in one directory without losing any (F-170…F-176).
//
// The hard part is not the new names, it is that a batch can contain a *cycle*: `a → b` together with
// `b → a`, or a longer rotation. Renamed one at a time in the obvious order, the first move destroys the
// second file. So every rename goes to a unique temporary name first and only then to its final one —
// after which no target can still be occupied by a member of the same batch.
//
// This lived inside the panel controller, where it could not be tested, and its undo did *not* stage:
// reversing a swap moved `b` onto the still-present `a`, both moves failed, and the user was told
// nothing. Same two phases both ways now.

import Foundation

public enum RenameBatchEngine {

    /// One completed rename, and how to put it back.
    public struct Step: Equatable, Sendable {
        public let from: String       // where the file is now
        public let to: String         // where it was
        public init(from: String, to: String) { self.from = from; self.to = to }
    }

    public struct Outcome: Sendable {
        /// Successful renames, in the order they happened, as the log an undo replays.
        public let log: [Step]
        /// Names the batch asked for and could not deliver, with the reason as far as it is known.
        public let failed: [(name: String, reason: String)]
        public init(log: [Step], failed: [(name: String, reason: String)]) {
            self.log = log
            self.failed = failed
        }
    }

    /// Apply `pairs` (old leaf → new leaf) inside `dir`.
    ///
    /// Skipped rather than attempted: an unchanged name, an empty one, and one containing a path
    /// separator — a batch rename may not move a file to another directory. Those, and any rename the
    /// file system refuses (a target that already exists outside the batch), come back in `failed` so
    /// the caller can say so; they used to be dropped in silence.
    @discardableResult
    public static func apply(dir: String, pairs: [(old: String, new: String)]) -> Outcome {
        let fm = FileManager.default
        var staged: [(temp: String, finalName: String, old: String)] = []
        var failed: [(name: String, reason: String)] = []

        for (old, new) in pairs {
            guard old != new else { continue }                     // nothing asked for
            guard !new.isEmpty, !new.contains("/"), !new.contains("\0"), new != ".", new != ".." else {
                failed.append((old, "not a usable file name: \"\(new)\""))
                continue
            }
            let oldPath = (dir as NSString).appendingPathComponent(old)
            let tempPath = (dir as NSString).appendingPathComponent(".pcren-" + UUID().uuidString)
            do {
                try fm.moveItem(atPath: oldPath, toPath: tempPath)
                staged.append((tempPath, new, old))
            } catch {
                failed.append((old, error.localizedDescription))
            }
        }

        var log: [Step] = []
        for entry in staged {
            let finalPath = (dir as NSString).appendingPathComponent(entry.finalName)
            let oldPath = (dir as NSString).appendingPathComponent(entry.old)
            do {
                try fm.moveItem(atPath: entry.temp, toPath: finalPath)
                log.append(Step(from: finalPath, to: oldPath))
            } catch {
                // Put it back under its own name; a file left parked under a dotted temporary name would
                // be invisible in the panel and look deleted.
                try? fm.moveItem(atPath: entry.temp, toPath: oldPath)
                failed.append((entry.old, error.localizedDescription))
            }
        }
        return Outcome(log: log, failed: failed)
    }

    /// Reverse a log produced by `apply`, and return the moves that succeeded.
    ///
    /// Staged in two phases like `apply`, for exactly the same reason: undoing a swap means moving `b`
    /// back to `a` while `a` is still occupied by the other half of the same swap. Single-phase, both
    /// moves failed and the undo silently did nothing at all.
    @discardableResult
    public static func undo(_ log: [Step]) -> [Step] {
        let fm = FileManager.default
        var staged: [(temp: String, step: Step)] = []
        for step in log.reversed() {
            let temp = ((step.from as NSString).deletingLastPathComponent as NSString)
                .appendingPathComponent(".pcren-" + UUID().uuidString)
            if (try? fm.moveItem(atPath: step.from, toPath: temp)) != nil {
                staged.append((temp, step))
            }
        }
        var undone: [Step] = []
        for (temp, step) in staged {
            if (try? fm.moveItem(atPath: temp, toPath: step.to)) != nil {
                undone.append(step)
            } else {
                try? fm.moveItem(atPath: temp, toPath: step.from)   // give it its name back
            }
        }
        return undone
    }
}
