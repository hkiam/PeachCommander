// SPDX-License-Identifier: Apache-2.0
// DeleteEngine.swift - Trash (batched) and permanent recursive delete
// (SPEC-004 §7). Symlink-safe: never descends into symlinked directories.

import Foundation
import PCFoundation

public final class DeleteEngine {
    private let control: OperationControl
    private let progress: @Sendable (OpProgress) -> Void
    private let logger = PCFoundationLogger.logger
    private var state = OpProgress()

    public init(control: OperationControl,
                progress: @escaping @Sendable (OpProgress) -> Void = { _ in }) {
        self.control = control
        self.progress = progress
    }

    /// Move items to the Trash. Returns the paths successfully trashed.
    @discardableResult
    public func moveToTrash(items: [String]) async throws -> [String] {
        var processed: [String] = []
        for path in items {
            try await control.checkpoint()
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                processed.append(path)
            } catch {
                throw OperationError.deleteFailed(path)
            }
        }
        return processed
    }

    /// Permanently delete items (recursive, cancellable). Returns processed paths.
    @discardableResult
    public func permanentDelete(items: [String]) async throws -> [String] {
        state.filesTotal = countItems(items)
        report()
        var processed: [String] = []
        for path in items {
            try await control.checkpoint()
            try await deleteNode(path)
            processed.append(path)
        }
        return processed
    }

    // MARK: - Recursion

    private func deleteNode(_ path: String) async throws {
        try await control.checkpoint()
        guard let kind = FSLowLevel.kind(of: path) else { return } // already gone
        switch kind {
        case .file, .symlink:
            // unlink removes the link itself, never the symlink target.
            let rc = path.withCString { unlink($0) }
            guard rc == 0 else { throw OperationError.deleteFailed(path) }
            state.filesDone += 1
            report()
        case .directory:
            let children = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
            for child in children {
                try await deleteNode((path as NSString).appendingPathComponent(child))
            }
            let rc = path.withCString { rmdir($0) }
            guard rc == 0 else { throw OperationError.deleteFailed(path) }
            state.filesDone += 1
            report()
        }
    }

    private func countItems(_ items: [String]) -> Int {
        var count = 0
        var stack = items
        while let path = stack.popLast() {
            guard let kind = FSLowLevel.kind(of: path) else { continue }
            count += 1
            if kind == .directory, let children = try? FileManager.default.contentsOfDirectory(atPath: path) {
                for c in children { stack.append((path as NSString).appendingPathComponent(c)) }
            }
        }
        return count
    }

    private func report() { progress(state) }
}
