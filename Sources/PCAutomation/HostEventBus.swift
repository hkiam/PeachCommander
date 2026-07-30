// HostEventBus.swift - the concrete multiplexing event bus behind AutomationCore.events().
//
// The host emits typed HostEvents here; every subscriber gets its own AsyncStream.
// Thread-safe so the (main-actor) host can emit while background consumers read.

import Foundation

public final class HostEventBus: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<HostEvent>.Continuation] = [:]

    public init() {}

    /// A new subscription. The stream ends when the consumer stops iterating.
    public func stream() -> AsyncStream<HostEvent> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock(); continuations[id] = continuation; lock.unlock()
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.continuations[id] = nil; self.lock.unlock()
            }
        }
    }

    /// Broadcast an event to all current subscribers.
    public func emit(_ event: HostEvent) {
        lock.lock(); let targets = Array(continuations.values); lock.unlock()
        for c in targets { c.yield(event) }
    }

    /// Current subscriber count (for tests/diagnostics).
    public var subscriberCount: Int {
        lock.lock(); defer { lock.unlock() }; return continuations.count
    }
}
