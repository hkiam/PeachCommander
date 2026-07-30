// PluginGuard.swift - In-process crash guard + quarantine for plugin calls (F-230).
//
// Wraps a synchronous plugin C call so a fatal signal from a misbehaving plugin
// (SIGSEGV/SIGBUS/SIGILL/SIGFPE) is caught (via the CPluginGuard C shim) rather
// than crashing the whole app. A plugin that crashes is quarantined so it is not
// called again for the rest of the session.
//
// This is a pragmatic in-process guard, not a sandbox: recovering from a
// memory-corruption signal can leave some host state inconsistent, which is why a
// crashed plugin is treated as untrusted and quarantined. True isolation would
// need an out-of-process host.

import Foundation
import CPluginGuard
import PCFoundation

public final class PluginGuard: @unchecked Sendable {
    /// Shared guard used by the plugin adapters.
    public static let shared = PluginGuard()

    private var quarantined: Set<String> = []
    private let lock = NSLock()

    public init() {}

    /// Whether `id` has been quarantined after a crash.
    public func isQuarantined(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return quarantined.contains(id)
    }

    /// Quarantine `id` so it is skipped by future guarded calls.
    public func quarantine(_ id: String) {
        lock.lock(); quarantined.insert(id); lock.unlock()
    }

    /// The plugin ids quarantined so far this session (thread-safe snapshot).
    public func quarantinedIDs() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return quarantined
    }

    /// Run `work` (a plugin call) under the fatal-signal guard. Returns `work`'s
    /// result, or nil — quarantining `id` — if the plugin crashed or is already
    /// quarantined (F-230).
    public func guarded<T>(_ id: String, _ work: () -> T) -> T? {
        if isQuarantined(id) { return nil }
        var result: T?
        // A no-argument closure the C trampoline can invoke through a raw pointer.
        // pc_guard_call runs it synchronously, so it never truly escapes.
        let signo: Int32 = withoutActuallyEscaping({ result = work() }) { thunk in
            var thunk = thunk
            return withUnsafeMutablePointer(to: &thunk) { ptr in
                pc_guard_call({ raw in
                    raw!.assumingMemoryBound(to: (() -> Void).self).pointee()
                }, UnsafeMutableRawPointer(ptr))
            }
        }
        if signo != 0 {
            quarantine(id)
            PCFoundationLogger.logger.error("Plugin \(id, privacy: .public) crashed (signal \(signo)); quarantined")
            return nil
        }
        return result
    }
}
