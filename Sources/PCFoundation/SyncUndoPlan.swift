// SPDX-License-Identifier: Apache-2.0
// SyncUndoPlan.swift - Putting back what a run deleted, and refusing everything else.
//
// The help file has always said the honest thing: a deleted file goes to the Trash and can be put
// back from the Finder, and that is the whole safety net. It was unusable, because nobody can pick
// this run's files out of several hundred items in there. `SyncStatus.deleted` now carries the path
// the move itself reported, so the run knows exactly which items it put down — and once you know
// that, putting one back is `moveItem` to a path you wrote down at the same moment.
//
// Which is worth being precise about, because this project asserted the opposite. `AuditLog` says
// "macOS offers no public way to put an item back from the Trash". That is true of Finder's *Put
// Back*, which restores an origin the system remembers for itself. It is not true of moving a file
// to a path of your own recording: the app is deliberately not sandboxed
// (`Resources/PeachCommander.entitlements`), and a volume's Trash is on that volume, so the move is
// a rename and cannot half-succeed. Measured before any of this was built.
//
// The direction matters. Putting a deletion back and taking a copy away are not two halves of one
// feature, they are opposites:
//
//   * put back, guard wrong → a file is there that the user wanted gone. Deletable again.
//   * take a copy away, guard wrong → a file the user has edited since goes to the Trash. Gone.
//
// By the rule this repo already writes down for `makeDirectoryThroughFileSystem` — undoing a
// creation is a real delete, so the folder stays — the put-back is the one that passes and taking a
// copy away is the one that has to argue for itself. Only the put-back is built.
//
// Everything here is pure. The filesystem is reached through an injected probe, which is
// `SyncPlanGuard`'s reason for taking its scopes as values: the whole guard matrix is then testable
// without a single temporary file.

import Foundation

/// What the filesystem says about one path, right now.
///
/// Size and time are not enough on their own and `FileStamp` says why: the usual way a program
/// replaces a file is to write a temporary one and rename it over the old, which yields a new inode
/// while a rename *preserves* the source's mtime — and the sync path sets the source's timestamp on
/// purpose. So "same size, same time, different file" is not exotic here, it is what a second run
/// produces. The stamp is size, mtime and inode together, from `lstat`, which also answers the
/// symlink case a size-and-date check cannot.
public struct SyncUndoFacts: Equatable, Sendable {
    public var exists: Bool
    public var size: Int64
    public var modifiedUnix: Double
    public var isDirectory: Bool
    public var isSymbolicLink: Bool
    public var inode: UInt64?

    public init(exists: Bool, size: Int64 = 0, modifiedUnix: Double = 0,
                isDirectory: Bool = false, isSymbolicLink: Bool = false, inode: UInt64? = nil) {
        self.exists = exists
        self.size = size
        self.modifiedUnix = modifiedUnix
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.inode = inode
    }

    public static let absent = SyncUndoFacts(exists: false)
}

public enum SyncUndoPlan {

    /// One reason something will not be put back. `SyncPlanGuard.Refusal`'s shape and its rule:
    /// every reason at once, before the confirmation, rather than one at a time as the run
    /// discovers them.
    public struct Refusal: Equatable, Sendable {
        /// The relative path, or `"(the run)"` when the whole record is refused.
        public let subject: String
        public let reason: String
        public init(subject: String, reason: String) {
            self.subject = subject
            self.reason = reason
        }

        public static let wholeRun = "(the run)"
    }

    /// Move this item from the Trash back where it came from.
    public struct Step: Equatable, Sendable {
        public let relativePath: String
        /// Where it is now.
        public let from: String
        /// Where it was.
        public let to: String
        public init(relativePath: String, from: String, to: String) {
            self.relativePath = relativePath
            self.from = from
            self.to = to
        }
    }

    /// What of this run can be put back, and why the rest cannot.
    ///
    /// - Parameter probe: The facts about one absolute path. Called for both roots and for every
    ///   candidate's two ends.
    public static func plan(header: SyncRunHeader, items: [SyncRunItem],
                            probe: (String) -> SyncUndoFacts) -> (steps: [Step],
                                                                  refusals: [Refusal]) {
        var refusals: [Refusal] = []

        func refuseRun(_ reason: String) {
            refusals.append(Refusal(subject: Refusal.wholeRun, reason: reason))
        }

        if header.version > SyncRunHeader.currentVersion {
            refuseRun("the record was written by a newer version of the app")
        }
        if !header.itemsListed {
            refuseRun(header.undoUnavailable
                      ?? "this run was too large for its items to be kept")
        } else if let why = header.undoUnavailable {
            refuseRun(why)
        }

        // The roots, checked before any item. An absolute path in a file is only safe to act on if
        // the folder it names is still the folder it named: `/Volumes/Backup` can be a different
        // disk next week, and a run recorded hourly is often about something that has since moved.
        for (label, root, recordedInode) in [("left", header.leftRoot, header.leftRootInode),
                                             ("right", header.rightRoot, header.rightRootInode)] {
            let facts = probe(root)
            if !facts.exists || !facts.isDirectory {
                refuseRun("the \(label) folder of this run is not there any more: \(root)")
            } else if let recordedInode, let now = facts.inode, recordedInode != now {
                refuseRun("the \(label) folder is not the one this run wrote to: \(root)")
            }
        }

        guard refusals.isEmpty else { return ([], refusals) }

        var steps: [Step] = []
        for item in items {
            switch candidate(item, header: header, probe: probe) {
            case .step(let step): steps.append(step)
            case .refuse(let reason):
                refusals.append(Refusal(subject: item.relativePath, reason: reason))
            case .notADeletion:
                continue        // a copy, a refusal, a failure: nothing was taken away, so nothing
                                // is owed back. Silently, or every run would report a page of
                                // "this was a copy".
            }
        }
        // Shallowest first. Deletions ran deepest-first, so a child cannot land before its folder
        // is back — and `moveItem` does not create the parent.
        steps.sort { $0.relativePath.components(separatedBy: "/").count
                        < $1.relativePath.components(separatedBy: "/").count }
        return (steps, refusals)
    }

    private enum Candidate {
        case step(Step)
        case refuse(String)
        case notADeletion
    }

    private static func candidate(_ item: SyncRunItem, header: SyncRunHeader,
                                 probe: (String) -> SyncUndoFacts) -> Candidate {
        guard item.outcome == SyncRunItem.Outcome.deleted else { return .notADeletion }
        guard item.undoneAt == nil else {
            return .refuse(item.undoUnavailable ?? "this has already been put back")
        }
        guard item.destinationSide == "localDir" else {
            // Said for the side rather than the run, because a run can have one local side and one
            // that is not. An archive rewrite re-stamped every entry it did not touch, and a server
            // deletion was permanent — which the confirmation says before the run, not after.
            return .refuse("a \(item.destinationSide ?? "non-local") side keeps nothing to put back")
        }
        guard item.toTrash == true else {
            return .refuse("this was removed permanently, not put in the Trash")
        }
        guard let trashedPath = item.trashedPath else {
            return .refuse("where this went was not recorded")
        }
        guard let original = item.destinationPath else {
            return .refuse("where this came from was not recorded")
        }
        // Both ends inside the record's own roots — through `PathContainment.isInside`, which
        // resolves symlinks for the part of a path that exists. That matters here and not
        // theoretically: the record's own paths standardise `/private/tmp` to `/tmp` while the file
        // being put back does not exist yet and keeps the long spelling, which is the exact trap
        // that file's header describes.
        let originURL = URL(fileURLWithPath: original)
        guard PathContainment.isInside(originURL, root: URL(fileURLWithPath: header.leftRoot))
                || PathContainment.isInside(originURL,
                                            root: URL(fileURLWithPath: header.rightRoot)) else {
            return .refuse("it came from outside both folders of this run")
        }

        let inTrash = probe(trashedPath)
        guard inTrash.exists else {
            return .refuse("it is no longer in the Trash")
        }
        let atOrigin = probe(original)
        if atOrigin.exists {
            // Never overwrite. Whatever is there now was not put there by this run, and replacing
            // it would make the put-back a deletion of its own.
            return .refuse("something is at that path again")
        }
        return .step(Step(relativePath: item.relativePath, from: trashedPath, to: original))
    }
}
