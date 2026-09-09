// SPDX-License-Identifier: Apache-2.0
// TrashRestore.swift - Putting one item back from the Trash, with the guards that make it safe.
//
// One place, because there are now two callers: the synchronisation run log's put-back, and the
// assistant undoing a `move_to_trash`. Two copies of "check, then move" over a step that can
// overwrite somebody's file is how the copies drift apart.
//
// The whole operation is a `moveItem` — the Trash of a volume is on that volume, so it is a rename
// and cannot half-succeed — and the reason it is possible at all is that the *system* reported where
// the item went. `AuditLog` used to state the opposite: "macOS offers no public way to put an item
// back from the Trash." That is true of Finder's own **Put Back**, which restores an origin the OS
// remembers for itself; it is not true of a path we wrote down at the moment of deletion. Measured
// before any of this was built.
//
// The guards are few and each one has a failure it prevents:
//
//   * the item is still where it was reported to be — otherwise there is nothing to move;
//   * the old path is **free** — a put-back that overwrites is a deletion wearing a recovery's
//     clothes, and it is the only way this operation can destroy anything;
//   * both are checked again immediately before the move, because between deciding and doing there
//     is usually a person reading a confirmation.

import Foundation

public enum TrashRestore {

    /// What became of one attempt.
    public enum Outcome: Sendable, Equatable {
        case restored(to: String)
        /// Deliberately not done, with the reason in the user's terms.
        case refused(reason: String)
        case failed(message: String)

        public var didRestore: Bool {
            if case .restored = self { return true }
            return false
        }
    }

    /// Why this pair cannot be put back, judged from the filesystem as it is now. Nil when it can.
    ///
    /// Separated from `restore` so a caller can arm a button — or show a whole plan's refusals
    /// before asking — without doing anything, which is the rule
    /// `DefaultAutomationCore.refusalBeforeAsking` states: a gated action that cannot work must not
    /// be proposed.
    public static func refusal(from trashedPath: String, to originalPath: String) -> String? {
        // `lstat`, so a symlink is judged as itself. A check that followed the link would call a
        // dangling one's path free and the restore would then replace the link somebody left there.
        guard exists(trashedPath) else { return "it is no longer in the Trash" }
        guard !exists(originalPath) else { return "something is at that path again" }
        return nil
    }

    /// Move it back, re-checking first.
    public static func restore(from trashedPath: String, to originalPath: String) -> Outcome {
        if let reason = refusal(from: trashedPath, to: originalPath) { return .refused(reason: reason) }
        let destination = URL(fileURLWithPath: originalPath)
        do {
            // The parent may be gone — a folder deleted as a whole takes its own directory entry
            // with it, and only that folder's own row recreates it. Created rather than refused,
            // because refusing would make a whole subtree unrecoverable for the sake of one empty
            // directory.
            let parent = destination.deletingLastPathComponent()
            if !exists(parent.path) {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            }
            try FileManager.default.moveItem(at: URL(fileURLWithPath: trashedPath), to: destination)
            return .restored(to: originalPath)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    /// `lstat` rather than `FileManager.fileExists`, which follows symlinks and would answer "no"
    /// for a dangling one — the path is occupied all the same.
    static func exists(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0
    }
}
