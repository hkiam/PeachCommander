// MoveEngine.swift - Move/rename with same-volume rename(2) fast path and
// cross-device copy+delete fallback (SPEC-004 §2).

import Foundation
import PCFoundation

public final class MoveEngine {
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
                    if try await moveOne(src: src, dst: dst, dstDir: dstDir) { processed.append(src) }
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

    /// Returns true if the source was moved (false if skipped).
    private func moveOne(src: String, dst dst0: String, dstDir: String) async throws -> Bool {
        var dst = dst0
        guard let srcKind = FSLowLevel.kind(of: src) else { throw OperationError.sourceNotFound(src) }
        let targetKind = FSLowLevel.kind(of: dst)

        if targetKind != nil {
            // Directory-into-directory merges without asking; otherwise resolve.
            if !(srcKind == .directory && targetKind == .directory) {
                switch await resolveOverwrite(src: src, dst: dst) {
                case .skip: return false
                case .abort: throw OperationError.aborted(dst)
                case .rename(let newLeaf):
                    dst = (dstDir as NSString).appendingPathComponent(newLeaf)
                case .append where srcKind == .file:
                    // F-086: append the source onto the target, then delete the source
                    // (a move that merges content). No prompting inside the copy.
                    let ce = CopyEngine(options: options, control: control,
                                        resolver: SkipAllResolver(), progress: progress)
                    try await ce.appendRegularFile(from: src, to: dst)
                    try? FileManager.default.removeItem(atPath: src)
                    return true
                case .overwrite, .append:
                    // rename(2) atomically replaces a file target; remove dir/symlink targets first.
                    // (`.append` reaches here only for a non-file source → treat as replace.)
                    if FSLowLevel.kind(of: dst) == .directory || srcKind != .file {
                        try? FileManager.default.removeItem(atPath: dst)
                    }
                }
            }
        }

        let sameDevice = FSLowLevel.sameDevice(src, dst)
        let canRename = sameDevice && !(srcKind == .directory && FSLowLevel.kind(of: dst) == .directory)
        if canRename {
            let rc = src.withCString { s in dst.withCString { d in rename(s, d) } }
            if rc == 0 { return true }
            // Fall through to copy+delete on failure (e.g. EXDEV races, dir merges).
        }

        // Cross-device or dir-merge: copy the whole item, then delete the source.
        let copy = CopyEngine(options: options, control: control, resolver: resolver, progress: progress)
        _ = try await copy.run(items: [src], toDirectory: (dst as NSString).deletingLastPathComponent)
        // Only delete the source after a successful copy.
        let del = DeleteEngine(control: control, progress: progress)
        _ = try await del.permanentDelete(items: [src])
        return true
    }

    private func resolveOverwrite(src: String, dst: String) async -> OverwriteDecision {
        let sf = FSLowLevel.facts(of: src) ?? FileFacts(path: src, name: (src as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        let df = FSLowLevel.facts(of: dst) ?? FileFacts(path: dst, name: (dst as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        return await resolver.resolveOverwrite(source: sf, target: df)
    }
}
