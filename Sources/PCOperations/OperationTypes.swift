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
    /// The totals are still being counted while the work already runs, so they only grow and are not
    /// yet something to show a fraction of.
    public var isCounting: Bool
    /// `currentItem` is being waited for: another app is still delivering it (see
    /// `CopyOptions.coordinateSourceReads`). No byte moves meanwhile, so a fraction would sit still and
    /// then jump — the bar shows activity instead.
    public var isWaitingForSource: Bool
    /// What the sources lacked on disk when the copy began — bytes another app still had to deliver —
    /// and how much of it has arrived. Zero unless the copy reads its sources coordinated.
    ///
    /// Part of the one fraction rather than a second bar: the delivery is where a paste from a remote
    /// session spends its time, and the copy after it is a clone. Counted together, the bar fills while
    /// the content arrives and never runs backwards when the copy begins.
    public var bytesToReceive: Int64
    public var bytesReceived: Int64
    /// The file being copied right now, in bytes — the second bar (SPEC-004 §4). Over a few large files
    /// the total barely moves for minutes, and this is what shows the copy is getting anywhere. Zero
    /// when the operation moves no file data (a delete, a trash) or no file has started yet.
    public var currentFileBytesTotal: Int64
    public var currentFileBytesDone: Int64

    /// How far the current file is, from 0 to 1, or nil when there is no file to measure.
    public var currentFileFraction: Double? {
        guard currentFileBytesTotal > 0 else { return nil }
        return min(1, Double(currentFileBytesDone) / Double(currentFileBytesTotal))
    }

    /// Neither the totals nor the bytes done say how far the work is, so a fraction would mislead. A
    /// wait whose delivery can be measured is not one of those.
    public var isIndeterminate: Bool { isCounting || (isWaitingForSource && bytesToReceive == 0) }

    /// How far the work is, from 0 to 1: bytes received and copied against both totals, or files when
    /// there are no bytes to go by.
    public var fraction: Double {
        let total = bytesTotal + bytesToReceive
        if total > 0 { return min(1, Double(bytesDone + min(bytesReceived, bytesToReceive)) / Double(total)) }
        if filesTotal > 0 { return min(1, Double(filesDone) / Double(filesTotal)) }
        return 0
    }

    public init(filesTotal: Int = 0, filesDone: Int = 0,
                bytesTotal: Int64 = 0, bytesDone: Int64 = 0,
                currentItem: String = "", bytesPerSecond: Double = 0,
                isCounting: Bool = false, isWaitingForSource: Bool = false,
                bytesToReceive: Int64 = 0, bytesReceived: Int64 = 0,
                currentFileBytesTotal: Int64 = 0, currentFileBytesDone: Int64 = 0) {
        self.filesTotal = filesTotal
        self.filesDone = filesDone
        self.bytesTotal = bytesTotal
        self.bytesDone = bytesDone
        self.currentItem = currentItem
        self.bytesPerSecond = bytesPerSecond
        self.isCounting = isCounting
        self.isWaitingForSource = isWaitingForSource
        self.bytesToReceive = bytesToReceive
        self.bytesReceived = bytesReceived
        self.currentFileBytesTotal = currentFileBytesTotal
        self.currentFileBytesDone = currentFileBytesDone
    }
}

/// Whether the progress window's second bar — the current file — is worth showing (SPEC-004 §4).
///
/// Not always, which is what showing it always got wrong. For a single file it repeats the total bar
/// exactly. Over many small files it flickers between empty and full thirty times a second and says
/// nothing, and on a slow share those small files are where the time goes. What the bar is for is a
/// file that takes long enough to wonder whether it is moving, so that is the rule: more than one file
/// in the job, and a file still unfinished half a second after its first report. Time rather than size,
/// because a megabyte over SMB can take longer than a gigabyte on the internal disk. Once shown it
/// stays, so a run of small files after a large one does not make it blink.
public struct FileProgressBarRule: Sendable {
    public static let delay: TimeInterval = 0.5

    public private(set) var isShown = false
    private var file = ""
    private var lastDone: Int64 = 0
    private var since: Date?

    public init() {}

    /// Feed one report; returns whether the bar is to be shown.
    public mutating func update(_ p: OpProgress, now: Date = Date()) -> Bool {
        if isShown { return true }
        // While a source is still being delivered the file figures are the previous file's.
        guard !p.isWaitingForSource, p.filesTotal > 1, p.currentFileBytesTotal > 0,
              p.currentFileBytesDone < p.currentFileBytesTotal else {
            since = nil
            return false
        }
        // A new file: another name, or the same name starting again from fewer bytes.
        if since == nil || p.currentItem != file || p.currentFileBytesDone < lastDone {
            file = p.currentItem
            since = now
        }
        lastDone = p.currentFileBytesDone
        if let since, now.timeIntervalSince(since) >= Self.delay { isShown = true }
        return isShown
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
    /// Told the CRC-32 of each source file the copy actually *read*, as it reads it.
    ///
    /// For verify-after-copy, which reads both sides again afterwards and throws both digests away —
    /// so a verified 1 GB copy across volumes moves three gigabytes of reads where two would do. The
    /// streaming loop already has every byte in a buffer, so hashing there is one pass over data
    /// that is already in cache.
    ///
    /// Only the streaming path reports, and that is deliberate rather than an omission: on APFS a
    /// same-volume copy is `clonefile`, which never reads the bytes at all. Giving up the clone in
    /// order to obtain a digest would turn a free copy into a read plus a write and make the whole
    /// operation *slower* — so a cloned file simply has no digest, and the verifier reads its source
    /// as it always did.
    ///
    /// A closure rather than a value on the engine because the engine is built inside
    /// `TransferQueue.execute` and only its `[String]` of processed paths comes back out; threading a
    /// second return value through the queue would touch every operation to serve one of them.
    public var digestSink: (@Sendable (_ sourcePath: String, _ crc32Hex: String) -> Void)? = nil
    /// Ask each source's file presenters for it — a coordinated read — before copying it.
    ///
    /// For sources another app hands over and fills in later. The Windows App puts files copied in a
    /// remote session on the pasteboard as placeholders of the right size, all zeros, and fetches the
    /// bytes over RDP only when a reader coordinates (its `RDCFilePresenter` answers
    /// `relinquishPresentedItemToReader`). Finder coordinates and waits; an uncoordinated copy cloned
    /// the empty placeholder in no time and produced files of the right size with nothing in them.
    ///
    /// Off by default: a panel-to-panel copy has no presenter to wait for. A paste of something another
    /// app put on the pasteboard and a drop from another app set it. Every folder and every file is
    /// read coordinated: a presenter is asked only by a read of its own item.
    public var coordinateSourceReads: Bool = false
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
