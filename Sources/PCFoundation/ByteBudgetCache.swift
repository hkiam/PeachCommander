// SPDX-License-Identifier: Apache-2.0
// ByteBudgetCache.swift - Least-recently-used, bounded by bytes rather than by count.
//
// Pulled out of the thumbnail cache so the part worth checking can be checked: PCApp has no
// unit-test bundle (`Tools/test.sh --changed` says so itself), and a cache whose eviction nobody
// tests is a cache that quietly holds everything or quietly holds nothing. What is left in PCApp is
// the one thing that genuinely needs AppKit — asking an `NSImage` how many pixels it decoded to.
//
// A count-based limit is the wrong shape here for the same reason it was wrong for the archive
// cache: "128 thumbnails" says nothing about memory when one of them is a 40-megapixel photograph's
// preview.

import Foundation

public final class ByteBudgetCache<Value> {

    private struct Entry {
        let value: Value
        let bytes: Int
        var usedAt: UInt64
    }

    private var entries: [String: Entry] = [:]
    private var held = 0
    /// A monotonic tick rather than a timestamp: two values stored in the same millisecond still
    /// need an order, or the eviction picks between them by coin toss.
    private var clock: UInt64 = 0

    public let maxBytes: Int

    public init(maxBytes: Int) {
        self.maxBytes = maxBytes
    }

    public var report: (count: Int, bytes: Int) { (entries.count, held) }

    public func value(for key: String) -> Value? {
        guard var hit = entries[key] else { return nil }
        clock += 1
        hit.usedAt = clock
        entries[key] = hit
        return hit.value
    }

    /// Store `value`, replacing any entry under the same key and evicting the least recently used
    /// until the budget holds again.
    ///
    /// **An entry larger than the whole budget is kept, not stored and immediately dropped.** The
    /// work of producing it has already been paid for, and handing it back once before throwing it
    /// away is worth more than an accounting number that always holds. (`MemberStage` learned the
    /// same thing the hard way: a budget that undoes the work it was asked for is worse than a
    /// budget briefly exceeded.)
    public func store(_ value: Value, bytes: Int, for key: String) {
        let cost = max(0, bytes)
        if let previous = entries.removeValue(forKey: key) { held -= previous.bytes }
        clock += 1
        entries[key] = Entry(value: value, bytes: cost, usedAt: clock)
        held += cost
        evict(protecting: key)
    }

    public func remove(_ key: String) {
        guard let gone = entries.removeValue(forKey: key) else { return }
        held -= gone.bytes
    }

    public func removeAll() {
        entries.removeAll()
        held = 0
    }

    private func evict(protecting key: String?) {
        guard held > maxBytes else { return }
        let order = entries
            .filter { $0.key != key }
            .sorted { $0.value.usedAt < $1.value.usedAt }
            .map(\.key)
        for candidate in order {
            guard held > maxBytes else { return }
            remove(candidate)
        }
    }
}
