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

    /// The shortest duration a sample may claim.
    ///
    /// A read can finish faster than the clock can say, and the first version of this *discarded*
    /// those — which kept the conservative fallback in place on exactly the fastest links, the
    /// opposite of what the measurement is for. Clamping instead bounds the rate at
    /// `bytes / floor` — 64 MB/s for the smallest sample accepted — which is a floor on
    /// "immeasurably fast", not an infinity.
    private static let floorSeconds = 0.001

    /// Record one completed read of `bytes` that took `seconds`.
    ///
    /// Ignores samples too small to mean anything (that is latency, not throughput) and
    /// non-positive durations, which are not measurements at all.
    public func record(key: String, bytes: Int64, seconds: Double, now: Date = Date()) {
        guard bytes >= Self.minimumBytes, seconds > 0 else { return }
        let rate = Double(bytes) / max(seconds, Self.floorSeconds)
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

    /// Read the first `maxBytes` of `path` and record what that cost.
    ///
    /// For the one source that is never staged and so never measured: a **mounted share**. It is an
    /// ordinary local path, so `MemberStage` hands it straight back and nothing times it — which
    /// left the time budget permanently inert on exactly the case it was written for, with only the
    /// conservative byte fallback ever applying.
    ///
    /// Bounded on purpose. A megabyte is enough to measure a link and small enough that probing a
    /// 500 MB file costs the same as probing a 2 MB one, and the bytes land in the file cache the
    /// preview is about to read from anyway. Call it off the main thread; never call it for a file a
    /// sync provider has not materialised, since reading one is what downloads it.
    public func probe(path: String, key: String, maxBytes: Int = 1024 * 1024) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        let started = Date()
        guard let data = try? handle.read(upToCount: maxBytes) else { return }
        record(key: key, bytes: Int64(data.count), seconds: Date().timeIntervalSince(started))
    }
}
