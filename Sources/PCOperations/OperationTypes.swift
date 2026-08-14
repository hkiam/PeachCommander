// SPDX-License-Identifier: Apache-2.0
// OperationTypes.swift - Shared value types for the file-operation engine
//
// SPEC-004 §1. Pure Foundation (no AppKit). All engines are VFS-adjacent but the
// I03/I04 local fast paths operate directly on POSIX paths.

import Foundation
import PCFoundation

/// Live progress of an operation (SPEC-004 §4).
public struct OpProgress: Sendable, Equatable {
    public var filesTotal: Int
    public var filesDone: Int
    public var bytesTotal: Int64
    public var bytesDone: Int64
    public var currentItem: String
    public var bytesPerSecond: Double

    public init(filesTotal: Int = 0, filesDone: Int = 0,
                bytesTotal: Int64 = 0, bytesDone: Int64 = 0,
                currentItem: String = "", bytesPerSecond: Double = 0) {
        self.filesTotal = filesTotal
        self.filesDone = filesDone
        self.bytesTotal = bytesTotal
        self.bytesDone = bytesDone
        self.currentItem = currentItem
        self.bytesPerSecond = bytesPerSecond
    }
}

/// An event emitted by the engine / transfer queue (SPEC-004 §1).
public enum OpEvent: Sendable {
    case progress(OpProgress)
    case log(String)
    case completed(processed: [String])
    case failed(OperationError)
    case cancelled
}

/// Typed engine errors (mapped to user text in PCApp only).
public enum OperationError: Error, Sendable, Equatable {
    case cancelled
    case sourceNotFound(String)
    case cannotCreateDirectory(String)
    case cannotCreateFile(String)
    case readFailed(String)
    case writeFailed(String)
    case renameFailed(String)
    case deleteFailed(String)
    case aborted(String)
    case invalidName(String)
    /// Source and target are the same file, or the target lies inside the source directory.
    ///
    /// Its own case because the two ways this used to end were both destructive and neither was
    /// reported: overwriting a file with itself deleted it — the engine removes the target before
    /// reading the source — and copying a directory into itself did that to every file in it.
    case sameFile(String)
}

/// How to resolve a target-exists conflict (SPEC-004 §5).
public enum OverwriteDecision: Sendable, Equatable {
    case overwrite
    case skip
    case rename(String)   // new leaf name
    /// Append the source file's bytes to the existing target (F-086). Only
    /// meaningful for regular files; engines treat it as `.overwrite` otherwise.
    case append
    case abort
}

/// How to resolve a per-file error (SPEC-004 §6).
public enum ErrorDecision: Sendable, Equatable {
    case retry
    case skip
    case abort
}

/// Basic file facts passed to a conflict resolver.
public struct FileFacts: Sendable, Equatable {
    public let path: String
    public let name: String
    public let size: Int64
    public let modified: Date?
    public let isDirectory: Bool
    public init(path: String, name: String, size: Int64, modified: Date?, isDirectory: Bool) {
        self.path = path
        self.name = name
        self.size = size
        self.modified = modified
        self.isDirectory = isDirectory
    }
}

/// Resolves conflicts and errors. UI provides an interactive implementation;
/// tests provide deterministic ones.
public protocol OperationResolver: Sendable {
    /// Target already exists. Return how to proceed.
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision
    /// A per-file error occurred. Return how to proceed.
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision
}

/// Always overwrites; aborts on error. Useful default for non-interactive runs/tests.
public struct OverwriteAllResolver: OperationResolver {
    public init() {}
    public func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    public func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Skips conflicts and errors.
public struct SkipAllResolver: OperationResolver {
    public init() {}
    public func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .skip }
    public func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .skip }
}

/// Options for copy/move (SPEC-004 §3).
public struct CopyOptions: Sendable {
    public var preserveMetadata: Bool = true
    public var useCloneWhenPossible: Bool = true
    public var followSymlinks: Bool = false
    public var onlyNewer: Bool = false
    public var chunkSize: Int = 1 << 20
    /// Throughput ceiling in bytes/second; 0 = unlimited (SPEC-004 §1 speed limit).
    public var maxBytesPerSecond: Int64 = 0
    /// Wildcard rename mask applied to each top-level item's name (F-080), e.g.
    /// "*.bak". Nil keeps the original names. See `CopyRenameMask`.
    public var renameMask: String? = nil
    public init() {}
}

/// Cooperative cancellation + pause control shared with the UI.
public actor OperationControl {
    private var cancelled = false
    private var paused = false

    public init() {}

    /// Bytes per second this operation may use, or nil to keep whatever it was started with.
    ///
    /// Lives on the control rather than in the operation's options because it has to be changeable
    /// *while the transfer runs* — the whole point is to throttle the copy that is saturating the
    /// disk right now, and options are a value copied into the engine when it starts. The engine
    /// asks per chunk, so a change takes effect within one chunk instead of at the next operation.
    private var speedLimitOverride: Int64?

    public func cancel() { cancelled = true }
    public func pause() { paused = true }
    public func resume() { paused = false }
    public var isCancelled: Bool { cancelled }
    public var isPaused: Bool { paused }

    /// Set (or with nil, drop) the live limit. 0 means "no limit", which is not the same as nil:
    /// nil defers to the operation's own option, 0 overrides a configured global limit with none.
    public func setSpeedLimit(_ bytesPerSecond: Int64?) { speedLimitOverride = bytesPerSecond }
    public var speedLimit: Int64? { speedLimitOverride }

    /// Throws `.cancelled` if cancelled; otherwise blocks while paused.
    public func checkpoint() async throws {
        if cancelled { throw OperationError.cancelled }
        while paused {
            if cancelled { throw OperationError.cancelled }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
