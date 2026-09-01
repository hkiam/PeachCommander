// SPDX-License-Identifier: Apache-2.0
// TransferRateEstimatorTests.swift - The measurement that turns megabytes into seconds (F-479).
//
// Two of these guard against teaching the estimator a number that would then decide what a user gets
// to see: a tiny read measures latency, and a read served from a cache completes in no time at all.

import XCTest
@testable import PCFoundation

final class TransferRateEstimatorTests: XCTestCase {

    private let mb: Int64 = 1024 * 1024

    func testNothingIsKnownUntilSomethingIsMeasured() {
        XCTAssertNil(TransferRateEstimator().rate(for: "smb://team"))
    }

    func testOneSampleIsTheEstimate() {
        let estimator = TransferRateEstimator()
        estimator.record(key: "smb://team", bytes: 10 * mb, seconds: 2)
        XCTAssertEqual(try XCTUnwrap(estimator.rate(for: "smb://team")), Double(5 * mb), accuracy: 1)
    }

    func testASecondSampleMovesTheEstimateWithoutReplacingIt() {
        let estimator = TransferRateEstimator()
        estimator.record(key: "k", bytes: 10 * mb, seconds: 1)     // 10 MB/s
        estimator.record(key: "k", bytes: 10 * mb, seconds: 10)    // 1 MB/s
        // Weighted, not replaced: one stalled read must not condemn the mount, and one fast read
        // must not clear a link that has been slow all afternoon.
        let rate = try? XCTUnwrap(estimator.rate(for: "k"))
        XCTAssertEqual(rate ?? 0, Double(mb) * 6.4, accuracy: Double(mb) * 0.1)
    }

    func testATinyReadMeasuresLatencyAndIsIgnored() {
        let estimator = TransferRateEstimator()
        estimator.record(key: "sftp://host", bytes: 3 * 1024, seconds: 0.4)
        XCTAssertNil(estimator.rate(for: "sftp://host"), "a 3 KB read is a round trip, not a rate")
    }

    func testAReadWithNoDurationAtAllIsIgnored() {
        // Not a measurement — nothing can take zero time. Distinct from the case below.
        let estimator = TransferRateEstimator()
        estimator.record(key: "k", bytes: 100 * mb, seconds: 0)
        XCTAssertNil(estimator.rate(for: "k"))
    }

    func testAReadTooFastToTimeIsClampedRatherThanDiscarded() {
        // A read can finish faster than the clock can say. Discarding those — which the first
        // version did — kept the conservative fallback in place on the *fastest* links, which is
        // backwards. The clamp bounds the answer instead of throwing it away.
        let estimator = TransferRateEstimator()
        estimator.record(key: "k", bytes: mb, seconds: 0.000_01)
        let rate = try? XCTUnwrap(estimator.rate(for: "k"))
        XCTAssertEqual(rate ?? 0, Double(mb) / 0.001, accuracy: 1)
    }

    func testAMeasurementExpires() {
        let estimator = TransferRateEstimator()
        let then = Date(timeIntervalSince1970: 1_000_000)
        estimator.record(key: "k", bytes: 10 * mb, seconds: 1, now: then)
        XCTAssertNotNil(estimator.rate(for: "k", now: then.addingTimeInterval(60)))
        XCTAssertNil(estimator.rate(for: "k", now: then.addingTimeInterval(TransferRateEstimator.staleAfter + 1)),
                     "a VPN that was fast this morning is not this afternoon")
    }

    func testAStaleSampleIsReplacedRatherThanBlendedWith() {
        let estimator = TransferRateEstimator()
        let then = Date(timeIntervalSince1970: 1_000_000)
        estimator.record(key: "k", bytes: 100 * mb, seconds: 1, now: then)                 // 100 MB/s
        let later = then.addingTimeInterval(TransferRateEstimator.staleAfter + 1)
        estimator.record(key: "k", bytes: 10 * mb, seconds: 10, now: later)                // 1 MB/s
        XCTAssertEqual(try XCTUnwrap(estimator.rate(for: "k", now: later)), Double(mb), accuracy: 1)
    }

    func testAMountCanBeForgotten() {
        let estimator = TransferRateEstimator()
        estimator.record(key: "k", bytes: 10 * mb, seconds: 1)
        estimator.forget(key: "k")
        XCTAssertNil(estimator.rate(for: "k"))
    }

    // MARK: - The bounded probe, for the source nothing else measures

    func testProbingARealFileTeachesARate() throws {
        // A mounted share is an ordinary local path, so nothing stages from it and nothing times it.
        // This is the only measurement that source ever gets.
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-probe-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 0x41, count: 512 * 1024).write(to: file)
        let estimator = TransferRateEstimator()
        estimator.probe(path: file.path, key: "share")
        XCTAssertNotNil(estimator.rate(for: "share"))
    }

    func testProbingReadsNoMoreThanItsCap() throws {
        // A 500 MB file must cost the same probe as a 2 MB one, or the measurement is the very
        // expense it exists to avoid.
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-probe-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 0x41, count: 4 * 1024 * 1024).write(to: file)
        let estimator = TransferRateEstimator()
        let started = Date()
        estimator.probe(path: file.path, key: "capped", maxBytes: 128 * 1024)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2.0)
        XCTAssertNotNil(estimator.rate(for: "capped"))
    }

    func testProbingSomethingThatIsNotThereIsHarmless() {
        let estimator = TransferRateEstimator()
        estimator.probe(path: "/no/such/file", key: "missing")
        XCTAssertNil(estimator.rate(for: "missing"))
    }

    func testProbingATinyFileTeachesNothing() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-probe-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(repeating: 0x41, count: 1024).write(to: file)
        let estimator = TransferRateEstimator()
        estimator.probe(path: file.path, key: "tiny")
        XCTAssertNil(estimator.rate(for: "tiny"), "a 1 KB read is latency, not a rate")
    }

    func testMountsAreKeptApart() {
        let estimator = TransferRateEstimator()
        estimator.record(key: "fast", bytes: 100 * mb, seconds: 1)
        estimator.record(key: "slow", bytes: 1 * mb, seconds: 4)
        XCTAssertGreaterThan(try XCTUnwrap(estimator.rate(for: "fast")),
                             try XCTUnwrap(estimator.rate(for: "slow")))
    }
}
