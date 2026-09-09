// SPDX-License-Identifier: Apache-2.0
// MoveEngine.swift - Move/rename with same-volume rename(2) fast path and
// cross-device copy+delete fallback (SPEC-004 §2).

import Foundation
import PCFoundation

public final class MoveEngine {
    /// Items that were **merged** into their target rather than moved to it.
    ///
    /// `.append` (F-086) concatenates the source onto an existing file and then removes the source,
    /// so the operation happened and the source path is free — but the file at the target is neither
    /// the source nor what was there before. A caller that reads `run`'s result as "these were moved
    /// here" and offers to move them back would put merged content at the source path and destroy
    /// the target, which is a worse answer than offering nothing. Same shape as
    /// `CopyEngine.skipped`, and for the same reason: the engine knows and used to throw it away.
    public private(set) var merged: [String] = []

    private let options: CopyOptions
    private let control: OperationControl
    private let resolver: OperationResolver
    private let progress: @Sendable (OpProgress) -> Void
    private let logger = PCFoundationLogger.logger

    public init(options: CopyOptions,
                control: OperationControl,
                resolver: OperationResolver,
                progress: @escaping @Sendable (OpProgress) -> Void) {
        self.options = options
        self.control = control
        self.resolver = resolver
        self.progress = progress
    }

    /// Move each item into `dstDir`. Returns the source paths fully processed.
    @discardableResult
    public func run(items: [String], toDirectory dstDir: String) async throws -> [String] {
        var processed: [String] = []
        for src in items {
            try await control.checkpoint()
            var leaf = (src as NSString).lastPathComponent
            if let mask = options.renameMask { leaf = CopyRenameMask.apply(mask, to: leaf) }   // F-080
            let dst = (dstDir as NSString).appendingPathComponent(leaf)
            // Per-item error resolution (F-089): retry / skip (continue) / abort.
            while true {
                do {
                    if let outcome = try await moveOne(src: src, dst: dst, dstDir: dstDir) {
                        processed.append(src)
                        // Carry the file's comment to where the file now is (F-372). Best effort, and
                        // after the move: the bytes are already there, so a comment that cannot follow
                        // must not turn a completed move into a failure.
                        if outcome.carryComment {
                            await CommentStore.carryLocal(from: src, to: outcome.path, keepSource: false)
                        }
                    }
                    break
                } catch let error as OperationError {
                    if error == .cancelled { throw error }
                    switch await resolver.resolveError(error, path: src) {
                    case .retry: continue
                    case .skip: break
                    case .abort: throw error
                    }
                    break
                }
            }
        }
        return processed
    }

    /// Where the item ended up, and whether its comment should follow — nil if it was skipped.
    ///
    /// The final path rather than a Bool: on a name collision the resolver may rename the target, and the
    /// caller has to know the name the file actually has to carry its comment to it.
    ///
    /// `carryComment` is false for an append: appending A onto B *merges* content, so B is still B and
    /// keeps its own comment. Letting A's comment win there would silently overwrite a comment on a file
    /// nobody replaced.
    private func moveOne(src: String, dst dst0: String,
                         dstDir: String) async throws -> (path: String, carryComment: Bool)? {
        var dst = dst0
        guard let srcKind = FSLowLevel.kind(of: src) else { throw OperationError.sourceNotFound(src) }

        // A loop rather than one question, and it re-reads the target each time round: a `.rename`
        // can land on a name that is taken too, and `rename(2)` would then have replaced *that* file
        // without anyone being asked — the opposite of what choosing a new name is for.
        var rounds = 0
        while let targetKind = FSLowLevel.kind(of: dst) {
            rounds += 1
            guard rounds <= Self.maximumConflictRounds else { throw OperationError.aborted(dst) }
            // Directory-into-directory merges without asking; otherwise resolve.
            if !(srcKind == .directory && targetKind == .directory) {
                switch await resolveOverwrite(src: src, dst: dst) {
                case .skip: return nil
                case .abort: throw OperationError.aborted(dst)
                case .rename(let newLeaf):
                    let next = (dstDir as NSString).appendingPathComponent(newLeaf)
                    guard next != dst else { throw OperationError.aborted(dst) }
                    dst = next
                    continue
                case .append where srcKind == .file:
                    // F-086: append the source onto the target, then delete the source
                    // (a move that merges content). No prompting inside the copy.
                    let ce = CopyEngine(options: options, control: control,
                                        resolver: SkipAllResolver(), progress: progress)
                    try await ce.appendRegularFile(from: src, to: dst)
                    _ = DeepPath.removeItem(src)
                    merged.append(src)
                    return (dst, false)
                case .overwrite, .append:
                    // rename(2) atomically replaces a file target; remove dir/symlink targets first.
                    // (`.append` reaches here only for a non-file source → treat as replace.)
                    if targetKind == .directory || srcKind != .file {
                        _ = DeepPath.removeItem(dst)
                    }
                }
            }
            break
        }

        let sameDevice = FSLowLevel.sameDevice(src, dst)
        let canRename = sameDevice && !(srcKind == .directory && FSLowLevel.kind(of: dst) == .directory)
        if canRename {
            let rc = DeepPath.rename(src, to: dst)
            if rc == 0 { return (dst, true) }
            // Fall through to copy+delete on failure (e.g. EXDEV races, dir merges).
        }

        // Cross-device or dir-merge: copy the whole item, then delete the source.
        let copy = CopyEngine(options: options, control: control, resolver: resolver, progress: progress)
        let copied = try await copy.run(items: [src],
                                        toDirectory: (dst as NSString).deletingLastPathComponent)
        // Only delete the source after a successful copy — which is what the comment here used to
        // say while the code deleted it either way. `run` reports what it managed to copy and does
        // *not* throw when the resolver answers "skip" to a failure, so a copy that never happened
        // was followed by a delete that did: measured, the file was gone from both sides.
        //
        // `skipped` as well as `copied`, because they answer different questions. A directory whose
        // child was skipped still counts as copied, and deleting the source tree would take that
        // child with it. When anything was left behind the whole source stays: a move that half
        // happened leaves duplicates the user can see and act on, which is the recoverable failure.
        guard copied.contains(src), copy.skipped.isEmpty else { return nil }
        let del = DeleteEngine(control: control, progress: progress)
        _ = try await del.permanentDelete(items: [src])
        return (dst, true)
    }

    /// See `CopyEngine.maximumConflictRounds`.
    private static let maximumConflictRounds = 64

    private func resolveOverwrite(src: String, dst: String) async -> OverwriteDecision {
        let sf = FSLowLevel.facts(of: src) ?? FileFacts(path: src, name: (src as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        let df = FSLowLevel.facts(of: dst) ?? FileFacts(path: dst, name: (dst as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        return await resolver.resolveOverwrite(source: sf, target: df)
    }
}
