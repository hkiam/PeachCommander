// SPDX-License-Identifier: Apache-2.0
// OneShotFlag.swift - A boolean that can be set once and read without `await`.

import Foundation

/// A latch: false until something sets it, then true forever, readable from any thread.
///
/// It exists because two of the app's operations have to carry one bit across a boundary that
/// `async` cannot cross:
///
///   * **Cancelling a transfer.** `OperationControl.cancel()` sets a flag on an actor, and the only
///     place a transfer can be stopped mid-file is a plugin's progress callback — which is
///     synchronous and runs on the connection's queue. Something has to hold "cancelled" where that
///     callback can read it without suspending.
///   * **Undoing a partial listing.** The callback that paints partial rows is `@Sendable` and so
///     cannot capture a mutable local, but the code that has to take those rows back if the load then
///     fails needs to know whether anything was painted.
///
/// Two near-identical private copies of this existed for a week before they were noticed, which is
/// the argument for it living here rather than beside either use.
public final class OneShotFlag: @unchecked Sendable {
    private var flag = false
    private let lock = NSLock()

    public init() {}

    public var isSet: Bool {
        lock.lock(); defer { lock.unlock() }
        return flag
    }

    public func set() {
        lock.lock(); flag = true; lock.unlock()
    }
}
