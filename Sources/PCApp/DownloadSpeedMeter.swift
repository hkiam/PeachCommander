// DownloadSpeedMeter.swift - smoothed throughput for the download progress UI (F-330).

import Foundation

/// Thread-safe bytes/sec estimate from successive cumulative byte counts.
final class DownloadSpeedMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var lastBytes: Int64 = 0
    private var lastTime = Date()
    private var rateValue: Double = 0

    /// Feed the cumulative bytes downloaded so far; returns a smoothed rate that
    /// updates about twice a second.
    func rate(bytes: Int64) -> Double {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let dt = now.timeIntervalSince(lastTime)
        guard dt >= 0.5 else { return rateValue }
        let instant = Double(max(0, bytes - lastBytes)) / dt
        rateValue = rateValue == 0 ? instant : rateValue * 0.6 + instant * 0.4
        lastBytes = bytes
        lastTime = now
        return rateValue
    }
}
