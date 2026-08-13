// SPDX-License-Identifier: Apache-2.0
// DeadlineTests.swift - Waiting for something that may never finish (F-214).
//
// This exists because of a measured whole-app freeze: quitting waits for every mount to be closed,
// a stalled SFTP session never closes, and `.terminateLater` means the app then never quits. The
// property being protected is narrow and absolute — *the wait ends* — so that is what is asserted,
// including for an operation that never finishes at all.

import XCTest
@testable import PCFoundation

final class DeadlineTests: XCTestCase {

    func test_workThatFinishesInTimeReportsSo() async {
        let done = await withDeadline(seconds: 5) {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(done)
    }

    /// A flag the runaway work checks, so the test can end it once the assertions are made.
    private final class Stop: @unchecked Sendable {
        private let lock = NSLock()
        private var stopped = false
        func stop() { lock.lock(); stopped = true; lock.unlock() }
        var isStopped: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    }

    func test_theWaitEndsEvenWhenTheWorkNeverDoes() async {
        // The whole point. An operation that ignores cancellation and does not return must not be
        // able to hold the caller: that is the shape of a blocked C call on a socket, which is what
        // the quit path actually hit.
        //
        // `try?` on the sleep is not laziness — it is what makes this operation ignore cancellation,
        // which is the condition being tested. The flag is how the test cleans up after itself: a
        // genuinely endless task would outlive this case and keep running for the rest of the suite.
        let stop = Stop()
        let start = Date()
        let done = await withDeadline(seconds: 0.3) {
            while !stop.isStopped { try? await Task.sleep(nanoseconds: 20_000_000) }
        }
        let waited = Date().timeIntervalSince(start)
        stop.stop()
        XCTAssertFalse(done, "reported success for work that never finished")
        XCTAssertLessThan(waited, 3.0, "the deadline did not end the wait")
    }

    func test_theDeadlineIsNotPaidWhenTheWorkIsQuick() async {
        // A correct-but-useless implementation could always wait the full deadline. It must not:
        // quitting would then always take three seconds, which users read as a slow app.
        let start = Date()
        _ = await withDeadline(seconds: 5) { }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0)
    }

    func test_aThrowingOperationIsNotThisFunctionsProblem() async {
        // The operation is non-throwing by signature, so a caller must absorb its own errors. What is
        // asserted here is that ordinary early exit still counts as finishing.
        let done = await withDeadline(seconds: 5) {
            if Bool.random() || true { return }
        }
        XCTAssertTrue(done)
    }

    func test_zeroSecondsStillReturns() async {
        // Degenerate but reachable if a deadline is ever computed rather than written down.
        let done = await withDeadline(seconds: 0) {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertFalse(done)
    }
}
