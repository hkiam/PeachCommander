// SPDX-License-Identifier: Apache-2.0
// Deadline.swift - Wait for a piece of work, but not indefinitely.
//
// Written for quitting. `applicationShouldTerminate` answers `.terminateLater`, which means the app
// stays alive until the delegate replies — and AppKit spends that wait inside
// `-[NSApplication terminate:]` running a restricted event loop, which the user experiences as a
// frozen window. So anything on that path that can hang forever hangs the whole application, and
// closing a network mount is exactly such a thing: measured against an SFTP server that accepted the
// connection and then stopped answering, the app was asked to quit and was still there 41 seconds
// later, killable only with `kill -9`.
//
// **A task group cannot do this**, which is worth stating because it is the obvious first attempt and
// it hangs. `withTaskGroup` waits for every child before it returns, so racing the work against a
// sleep inside a group only decides *which finished first* — the group still cannot return until the
// work does. Cancelling the children does not help either: cancellation is cooperative, `await
// task.value` on a non-throwing Task ignores it outright, and the work being defended against is
// blocked in a C library on a socket where nothing can hear the request. That version was written
// here, and the test for "work that never finishes" hung the whole suite until it was replaced.
//
// So: one continuation, resumed by whichever side gets there first, and nothing waits on the loser.
//
// What this does NOT do is stop the work. The operation keeps running, detached, and that is the
// honest description: the caller has stopped *waiting* for it. On the quit path that is exactly right
// — the process is about to exit and take the socket with it — but a caller that needs the work
// actually abandoned has to arrange that itself.

import Foundation

/// Resumes a continuation exactly once, whoever asks first.
private final class SingleResume: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    /// True if this call was the one that resumed it.
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

/// Run `operation`, giving up the wait after `seconds`.
///
/// Returns true if the operation finished in time, false if the deadline won. Never throws and never
/// waits longer than `seconds`, whatever the operation does — including an operation that ignores
/// cancellation and never returns at all.
@discardableResult
public func withDeadline(seconds: Double,
                         _ operation: @escaping @Sendable () async -> Void) async -> Bool {
    let gate = SingleResume()
    return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        let work = Task {
            await operation()
            if gate.claim() { cont.resume(returning: true) }
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            if gate.claim() {
                // Asked, not compelled: whether it makes any difference is up to the operation. The
                // wait is over either way, which is the part that was promised.
                work.cancel()
                cont.resume(returning: false)
            }
        }
    }
}
