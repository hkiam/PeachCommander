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
    case custom(run: @Sendable (_ control: OperationControl,
                                _ progress: @Sendable (OpProgress) -> Void) async throws -> [String])
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

    public init() {}

    /// Start `kind` and return the coalesced event stream. The operation runs in
    /// a detached task; cancelling the stream (or `control.cancel()`) stops it.
    public func run(_ kind: OperationKind,
                    resolver: OperationResolver = OverwriteAllResolver()) -> AsyncStream<OpEvent> {
        let control = self.control
        return AsyncStream { continuation in
            let throttle = ProgressThrottle(continuation)
            let progress: @Sendable (OpProgress) -> Void = { throttle.emit($0) }
            // Detached so heavy file I/O never runs on the caller's actor (e.g. main).
            let task = Task.detached {
                do {
                    let processed = try await TransferQueue.execute(kind, control: control,
                                                                    resolver: resolver, progress: progress)
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
        try await TransferQueue.execute(kind, control: control, resolver: resolver, progress: { _ in })
    }

    static func execute(_ kind: OperationKind,
                        control: OperationControl,
                        resolver: OperationResolver,
                        progress: @escaping @Sendable (OpProgress) -> Void) async throws -> [String] {
        switch kind {
        case let .copy(items, dstDir, options):
            let engine = CopyEngine(options: options, control: control, resolver: resolver, progress: progress)
            return try await engine.run(items: items, toDirectory: dstDir)
        case let .move(items, dstDir, options):
            let engine = MoveEngine(options: options, control: control, resolver: resolver, progress: progress)
            return try await engine.run(items: items, toDirectory: dstDir)
        case let .trash(items):
            let engine = DeleteEngine(control: control, progress: progress)
            return try await engine.moveToTrash(items: items)
        case let .delete(items):
            let engine = DeleteEngine(control: control, progress: progress)
            return try await engine.permanentDelete(items: items)
        case let .custom(run):
            return try await run(control, progress)
        }
    }
}
