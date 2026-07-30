// SPDX-License-Identifier: Apache-2.0
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

/// Heap box holding the work closure, so the C trampoline can invoke it through a
/// raw `void *`. Deliberately a class (not a stack value + `withoutActuallyEscaping`):
/// `siglongjmp` unwinds out of the closure without running the calling frame's ARC
/// cleanup, which leaves a retain on the closure context behind. That tripped
/// `withoutActuallyEscaping`'s escape check and trapped the process — turning the
/// crash this guard exists to survive into a hard abort (F-230).
private final class GuardThunk {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

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
    public func guarded<T>(_ id: String, _ work: @escaping () -> T) -> T? {
        if isQuarantined(id) { return nil }
        var result: T?
        // +1 retained by hand: on the crash path the release below is never reached,
        // so the box is intentionally leaked rather than freed from a frame that
        // siglongjmp already abandoned.
        let raw = Unmanaged.passRetained(GuardThunk { result = work() }).toOpaque()
        let signo = pc_guard_call({ ptr in
            Unmanaged<GuardThunk>.fromOpaque(ptr!).takeUnretainedValue().run()
        }, raw)
        if signo != 0 {
            // Leak `raw`: the guarded call faulted mid-flight, so its ARC state is
            // not provably consistent and releasing could double-free. One box per
            // crashed plugin, which is then quarantined for the rest of the session.
            quarantine(id)
            PCFoundationLogger.logger.error("Plugin \(id, privacy: .public) crashed (signal \(signo)); quarantined")
            return nil
        }
        Unmanaged<GuardThunk>.fromOpaque(raw).release()
        return result
    }
}
