// SPDX-License-Identifier: Apache-2.0
// DeleteEngine.swift - Trash (batched) and permanent recursive delete
// (SPEC-004 §7). Symlink-safe: never descends into symlinked directories.

import Foundation
import PCFoundation

public final class DeleteEngine {
    private let control: OperationControl
    private let resolver: OperationResolver
    private let progress: @Sendable (OpProgress) -> Void
    private let logger = PCFoundationLogger.logger
    private var state = OpProgress()

    /// - Parameter resolver: Consulted per item that cannot be removed, the way copy and move have
    ///   always consulted one. It defaults to `OverwriteAllResolver`, whose answer to an error is
    ///   `.abort` — which is exactly what this engine did before it could ask, so nothing that
    ///   already calls it changes behaviour.
    public init(control: OperationControl,
                resolver: OperationResolver = OverwriteAllResolver(),
                progress: @escaping @Sendable (OpProgress) -> Void = { _ in }) {
        self.control = control
        self.resolver = resolver
        self.progress = progress
    }

    /// Move items to the Trash, and return the ones that got there.
    ///
    /// A failure goes to the resolver: retried, skipped (the rest of the batch still goes), or
    /// thrown. The default resolver throws, and then nothing is returned at all — which used to be
    /// the only behaviour, under a doc comment promising the successful paths. One item too deep for
    /// `trashItem` therefore abandoned the whole selection without saying what had already moved.
    @discardableResult
    public func moveToTrash(items: [String]) async throws -> [String] {
        var processed: [String] = []
        for path in items {
            try await control.checkpoint()
            while true {
                do {
                    // `trashItem` is URL-only and there is no fd-relative equivalent, so an item whose
                    // path is past PATH_MAX cannot be put in the Trash — it fails here and the caller
                    // reports a failed delete. Permanent delete below does reach it (F-383).
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    processed.append(path)
                } catch {
                    switch await resolver.resolveError(.deleteFailed(path), path: path) {
                    case .retry: continue
                    case .skip: break
                    case .abort: throw OperationError.deleteFailed(path)
                    }
                }
                break
            }
        }
        return processed
    }

    /// Permanently delete items (recursive, cancellable). Returns the ones fully removed.
    ///
    /// "Fully": a directory whose child the resolver skipped cannot itself be removed, so it is not
    /// reported as processed either — which is what `MoveEngine` needs to hear before it believes a
    /// source is gone.
    @discardableResult
    public func permanentDelete(items: [String]) async throws -> [String] {
        state.filesTotal = countItems(items)
        report()
        var processed: [String] = []
        for path in items {
            try await control.checkpoint()
            if try await deleteNode(path) { processed.append(path) }
        }
        return processed
    }

    // MARK: - Recursion

    /// Whether the item is gone. `false` means the resolver chose to skip it.
    @discardableResult
    private func deleteNode(_ path: String) async throws -> Bool {
        try await control.checkpoint()
        guard let kind = FSLowLevel.kind(of: path) else { return true } // already gone
        switch kind {
        case .file, .symlink:
            // unlink removes the link itself, never the symlink target.
            while DeepPath.unlink(path) != 0 {
                switch await resolver.resolveError(.deleteFailed(path), path: path) {
                case .retry: continue
                case .skip: return false
                case .abort: throw OperationError.deleteFailed(path)
                }
            }
            state.filesDone += 1
            report()
            return true
        case .directory:
            let children = DeepPath.contentsOfDirectory(path) ?? []
            var complete = true
            for child in children {
                if try await !deleteNode((path as NSString).appendingPathComponent(child)) {
                    complete = false
                }
            }
            // A directory with something still in it cannot be removed, and asking about that would
            // be asking twice about the child that stayed.
            guard complete else { return false }
            while DeepPath.rmdir(path) != 0 {
                switch await resolver.resolveError(.deleteFailed(path), path: path) {
                case .retry: continue
                case .skip: return false
                case .abort: throw OperationError.deleteFailed(path)
                }
            }
            state.filesDone += 1
            report()
            return true
        }
    }

    private func countItems(_ items: [String]) -> Int {
        var count = 0
        var stack = items
        while let path = stack.popLast() {
            guard let kind = FSLowLevel.kind(of: path) else { continue }
            count += 1
            if kind == .directory, let children = DeepPath.contentsOfDirectory(path) {
                for c in children { stack.append((path as NSString).appendingPathComponent(c)) }
            }
        }
        return count
    }

    private func report() { progress(state) }
}
