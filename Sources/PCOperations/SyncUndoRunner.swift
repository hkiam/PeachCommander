// SPDX-License-Identifier: Apache-2.0
// SyncUndoRunner.swift - Carrying out a put-back, and checking again immediately before each move.
//
// `SyncUndoPlan` decides; this does. The split is `SyncPlanGuard`/`SyncExecutor`'s, and the reason
// for re-checking rather than trusting the plan is specific: between the plan and the move sits a
// confirmation dialog a person reads. That is a time window with an unbounded pause in the middle of
// it, so every guard the plan applied is applied again here, against the filesystem as it is at the
// moment of the move.
//
// The probe is the real one — `FileStamp`, which is `lstat` and therefore answers the symlink case —
// and it lives here rather than in `PCFoundation` because that is where the filesystem belongs.

import Foundation
import PCFoundation
import PCVFS

public enum SyncUndoRunner {

    /// What became of one step.
    public enum StepResult: Sendable, Equatable {
        case putBack(relativePath: String, to: String)
        /// Refused at the last moment: the world changed between the plan and the move.
        case refused(relativePath: String, reason: String)
        case failed(relativePath: String, message: String)
    }

    public struct Report: Sendable, Equatable {
        public let results: [StepResult]
        public init(results: [StepResult]) { self.results = results }

        public var putBack: [String] {
            results.compactMap { if case .putBack(let path, _) = $0 { return path } else { return nil } }
        }
        public var refusals: [(path: String, reason: String)] {
            results.compactMap {
                if case .refused(let path, let reason) = $0 { return (path, reason) } else { return nil }
            }
        }
        public var failures: [(path: String, message: String)] {
            results.compactMap {
                if case .failed(let path, let message) = $0 { return (path, message) } else { return nil }
            }
        }
    }

    /// The facts about one path, as the plan wants them.
    ///
    /// `FileStamp` rather than `attributesOfItem`, for the reason written at the top of that file:
    /// size and mtime alone cannot tell a file from its replacement, because the usual replacement
    /// is a rename that preserves the mtime. And `lstat`, so a symlink is reported as itself instead
    /// of as whatever it points at.
    public static func facts(at path: String) -> SyncUndoFacts {
        var st = stat()
        guard lstat(path, &st) == 0 else { return .absent }
        return SyncUndoFacts(exists: true,
                             size: Int64(st.st_size),
                             modifiedUnix: Double(st.st_mtimespec.tv_sec)
                                + Double(st.st_mtimespec.tv_nsec) / 1_000_000_000,
                             isDirectory: (st.st_mode & S_IFMT) == S_IFDIR,
                             isSymbolicLink: (st.st_mode & S_IFMT) == S_IFLNK,
                             inode: UInt64(st.st_ino))
    }

    /// Carry out the steps, in the order given — which `SyncUndoPlan` has already made
    /// shallowest-first, so a folder is back before anything that lived in it.
    public static func run(_ steps: [SyncUndoPlan.Step], header: SyncRunHeader) -> Report {
        let fm = FileManager.default
        var results: [StepResult] = []
        for step in steps {
            // The whole guard again, on this one step, now.
            let inTrash = facts(at: step.from)
            guard inTrash.exists else {
                results.append(.refused(relativePath: step.relativePath,
                                        reason: "it is no longer in the Trash"))
                continue
            }
            guard !facts(at: step.to).exists else {
                results.append(.refused(relativePath: step.relativePath,
                                        reason: "something is at that path again"))
                continue
            }
            let destination = URL(fileURLWithPath: step.to)
            guard PathContainment.isInside(destination,
                                           root: URL(fileURLWithPath: header.leftRoot))
                    || PathContainment.isInside(destination,
                                                root: URL(fileURLWithPath: header.rightRoot)) else {
                results.append(.refused(relativePath: step.relativePath,
                                        reason: "it came from outside both folders of this run"))
                continue
            }
            do {
                // The parent may be gone — a mirror deletes a folder and its contents, and only the
                // folder's own row recreates it. Created rather than refused, because refusing would
                // make a whole subtree un-put-backable for the sake of one empty directory.
                let parent = destination.deletingLastPathComponent()
                if !facts(at: parent.path).exists {
                    try fm.createDirectory(at: parent, withIntermediateDirectories: true)
                }
                try fm.moveItem(at: URL(fileURLWithPath: step.from), to: destination)
                results.append(.putBack(relativePath: step.relativePath, to: step.to))
            } catch {
                results.append(.failed(relativePath: step.relativePath,
                                       message: error.localizedDescription))
            }
        }
        return Report(results: results)
    }
}
