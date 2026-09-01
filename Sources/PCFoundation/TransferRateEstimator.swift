// SPDX-License-Identifier: Apache-2.0
// TransferRateEstimator.swift - How fast one mount actually is (F-479).
//
// `ImplicitWorkBudget` wants to answer in seconds rather than megabytes, and nothing in the app knew
// how fast anything was: `CopyEngine.throughput()` computes it per operation and throws it away.
// This keeps one exponentially-weighted number per mount, so the second preview on a share is judged
// by what the first one actually cost rather than by a guess.
//
// Fed from `MemberStage`, which is the one place that reads a whole file off a mount for the purpose
// of showing it. Any other whole-file read may feed it too, with two rules that are the reason this
// is not simply wired into the copy engine: a **throttled** transfer (SPEC-004's speed limit) and a
// **clonefile** copy both measure something other than the link, and either would teach a number that
// then decides what the user gets to see.
//
// Deliberately not persisted. A VPN that was fast this morning is not this afternoon, and a number
// restored from a previous session would decide a preview before anything had been measured at all.

import Foundation

public final class TransferRateEstimator: @unchecked Sendable {

    /// Shared by every consumer; a mount is a fact about the machine, not about one window.
    public static let shared = TransferRateEstimator()

    /// Below this a sample is latency rather than throughput — a 3 KB read over SFTP measures the
    /// round trip and would put the estimate at a few hundred KB/s on a fast link.
    public static let minimumBytes: Int64 = 64 * 1024

    /// After this, what was measured describes a network that may no longer exist.
    public static let staleAfter: TimeInterval = 5 * 60

    /// Weight of the newest sample. High enough that a link going bad is noticed within two reads,
    /// low enough that one stalled read does not condemn the mount.
    private static let alpha = 0.4

    private struct Sample {
        var bytesPerSecond: Double
        var at: Date
    }

    private let lock = NSLock()
    private var samples: [String: Sample] = [:]

    public init() {}

    /// Record one completed whole-file read of `bytes` that took `seconds`.
    ///
    /// Silently ignores samples too small to mean anything and non-positive durations (a read served
    /// from a cache completes in no measurable time and would teach an infinite rate).
    public func record(key: String, bytes: Int64, seconds: Double, now: Date = Date()) {
        guard bytes >= Self.minimumBytes, seconds > 0.001 else { return }
        let rate = Double(bytes) / seconds
        lock.lock()
        defer { lock.unlock() }
        if let previous = samples[key], now.timeIntervalSince(previous.at) <= Self.staleAfter {
            samples[key] = Sample(bytesPerSecond: previous.bytesPerSecond * (1 - Self.alpha) + rate * Self.alpha,
                                  at: now)
        } else {
            samples[key] = Sample(bytesPerSecond: rate, at: now)
        }
    }

    /// Bytes per second for `key`, or nil when nothing recent has been measured.
    public func rate(for key: String, now: Date = Date()) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard let sample = samples[key], now.timeIntervalSince(sample.at) <= Self.staleAfter else { return nil }
        return sample.bytesPerSecond
    }

    /// Forget one mount — it was unmounted, or the connection was hung up.
    public func forget(key: String) {
        lock.lock()
        defer { lock.unlock() }
        samples.removeValue(forKey: key)
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll()
    }
}
