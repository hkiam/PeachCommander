// SPDX-License-Identifier: Apache-2.0
// TrashedItemCollector.swift - Catching what a trashing reported, across the actor it happened on.
//
// The queue hands its result to a `@Sendable` closure from a detached task, and the caller reads it
// afterwards on the main actor. `SourceDigests` in the copy path is the same shape for the same
// reason, and its comment is the one to read: a plain `var` captured in a sending closure is a data
// race the compiler will not always catch, so the box does the locking and nobody has to remember.

import Foundation
import PCFoundation

final class TrashedItemCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var collected: [TrashedItem] = []

    func add(_ items: [TrashedItem]) {
        lock.lock(); defer { lock.unlock() }
        collected.append(contentsOf: items)
    }

    var items: [TrashedItem] {
        lock.lock(); defer { lock.unlock() }
        return collected
    }
}

/// The same box for the paths a move merged rather than moved. Its own type rather than a generic
/// one: two boxes with names that say what is in them read better at the call site than one that
/// does not.
final class MergedItemCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var collected: [String] = []

    func add(_ paths: [String]) {
        lock.lock(); defer { lock.unlock() }
        collected.append(contentsOf: paths)
    }

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return collected
    }
}
