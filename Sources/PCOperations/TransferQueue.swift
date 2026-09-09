// SPDX-License-Identifier: Apache-2.0
// TransferQueue.swift - Runs a file operation and emits a coalesced event stream
// (SPEC-004 §1). Cancellation/pause go through the shared OperationControl.

import Foundation
import PCFoundation

/// The kind of operation to run.
public enum OperationKind: Sendable {
    case copy(items: [String], toDirectory: String, options: CopyOptions)
    case move(items: [String], toDirectory: String, options: CopyOptions)
    case trash(items: [String])
    case delete(items: [String])
    /// An app-supplied operation (e.g. pack/unpack) run through the same queue so
    /// it backgrounds + shows in the transfer manager. Throw OperationError.cancelled
    /// to report a user cancel. Returns the processed source paths.
    /// An operation the caller implements.
    ///
    /// `progress` is `@escaping` because an operation that hands a transfer to a backend has to give
    /// that backend somewhere to report to: a plugin mount's progress callback fires from inside a
    /// blocking call, and the only way a percentage gets out of it is a closure the operation stored
    /// before it started.
    case custom(run: @Sendable (_ control: OperationControl,
                                _ progress: @escaping @Sendable (OpProgress) -> Void)
                                async throws -> [String])
}

/// Throttles progress events to <= `hz` per second, thread-safely.
final class ProgressThrottle: @unchecked Sendable {
    private let continuation: AsyncStream<OpEvent>.Continuation
    private let minInterval: TimeInterval
    private var lastEmit = Date.distantPast
    private let lock = NSLock()

    init(_ continuation: AsyncStream<OpEvent>.Continuation, hz: Double = 30) {
        self.continuation = continuation
        self.minInterval = 1.0 / hz
    }

    func emit(_ progress: OpProgress) {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        guard now.timeIntervalSince(lastEmit) >= minInterval else { return }
        lastEmit = now
        continuation.yield(.progress(progress))
    }
}

/// Executes one operation, exposing a live `AsyncStream<OpEvent>`.
public final class TransferQueue: @unchecked Sendable {
    /// Shared cancel/pause control for the running operation.
    public let control = OperationControl()

    /// Where each trashed item went, for a caller that will offer to put it back.
    ///
    /// A sink rather than a richer return type, which is `CopyOptions.digestSink`'s shape and its
    /// reason: the value only exists inside the operation, every other caller of `execute` wants
    /// the paths it already gets, and widening the return type for one of them would touch them all.
    ///
    /// Called once, after the trashing, with the items that actually moved. Nothing is reported for
    /// a permanent delete — there is nowhere for it to have gone.
    public var trashSink: (@Sendable ([TrashedItem]) -> Void)?

    /// Which items a move **merged** into their target instead of moving.
    ///
    /// A second narrow sink rather than one bag, for `CopyOptions.digestSink`'s reason: each answers
    /// one question and is named for it. This one exists because `[String]` of processed paths reads
    /// as "these were moved here", and for an `.append` that reading turns an undo into a
    /// destruction — see `MoveEngine.merged`.
    public var mergedSink: (@Sendable ([String]) -> Void)?

    public init() {}

    /// Start `kind` and return the coalesced event stream. The operation runs in
    /// a detached task; cancelling the stream (or `control.cancel()`) stops it.
    public func run(_ kind: OperationKind,
                    resolver: OperationResolver = OverwriteAllResolver()) -> AsyncStream<OpEvent> {
        let control = self.control
        // Captured before the detached task, because the property is read from another actor there
        // and reading it inside would be reading it at an unpredictable moment.
        let trashSink = self.trashSink
        let mergedSink = self.mergedSink
        return AsyncStream { continuation in
            let throttle = ProgressThrottle(continuation)
            let progress: @Sendable (OpProgress) -> Void = { throttle.emit($0) }
            // Detached so heavy file I/O never runs on the caller's actor (e.g. main).
            let task = Task.detached {
                do {
                    let processed = try await TransferQueue.execute(kind, control: control,
                                                                    resolver: resolver, progress: progress,
                                                                    trashSink: trashSink,
                                                                    mergedSink: mergedSink)
                    continuation.yield(.completed(processed: processed))
                } catch let error as OperationError {
                    continuation.yield(error == .cancelled ? .cancelled : .failed(error))
                } catch {
                    continuation.yield(.failed(.aborted("\(error)")))
                }
                continuation.finish()
            }
            continuation.onTermination = { reason in
                if case .cancelled = reason {
                    Task { await control.cancel() }
                }
                task.cancel()
            }
        }
    }

    /// Convenience: run to completion and return processed source paths.
    @discardableResult
    public func runToCompletion(_ kind: OperationKind,
                                resolver: OperationResolver = OverwriteAllResolver()) async throws -> [String] {
        try await TransferQueue.execute(kind, control: control, resolver: resolver,
                                        progress: { _ in }, trashSink: trashSink,
                                        mergedSink: mergedSink)
    }

    static func execute(_ kind: OperationKind,
                        control: OperationControl,
                        resolver: OperationResolver,
                        progress: @escaping @Sendable (OpProgress) -> Void,
                        trashSink: (@Sendable ([TrashedItem]) -> Void)? = nil,
                        mergedSink: (@Sendable ([String]) -> Void)? = nil) async throws -> [String] {
        switch kind {
        case let .copy(items, dstDir, options):
            let engine = CopyEngine(options: options, control: control, resolver: resolver, progress: progress)
            return try await engine.run(items: items, toDirectory: dstDir)
        case let .move(items, dstDir, options):
            let engine = MoveEngine(options: options, control: control, resolver: resolver, progress: progress)
            let moved = try await engine.run(items: items, toDirectory: dstDir)
            // Handed over before the paths are returned, so a caller deciding what to offer an undo
            // for is looking at the same operation the result describes.
            if !engine.merged.isEmpty { mergedSink?(engine.merged) }
            return moved
        // The resolver reaches delete too, now that delete can ask. It is the same question F-089
        // already asks for copy and move — retry, skip, or abort — and the reason it was worth
        // wiring: a background delete used to abandon the rest of the selection over one locked
        // item, and an interactive one reported a failure where it could have asked.
        case let .trash(items):
            let engine = DeleteEngine(control: control, resolver: resolver, progress: progress)
            let moved = try await engine.moveToTrash(items: items)
            // Handed over before the paths are returned, so a caller that offers to put these back
            // is looking at the same set the operation reports as done.
            trashSink?(moved)
            return moved.map(\.originalPath)
        case let .delete(items):
            let engine = DeleteEngine(control: control, resolver: resolver, progress: progress)
            return try await engine.permanentDelete(items: items)
        case let .custom(run):
            return try await run(control, progress)
        }
    }
}
