// SPDX-License-Identifier: Apache-2.0
// OperationControlSpeedTests.swift - The per-job speed limit that can be changed mid-transfer (F-085).
//
// The limit had one home: `CopyOptions.maxBytesPerSecond`, a value copied into the engine when the
// operation starts and fed from a single global setting. That answers "slow all copies down", which
// is not the question a background transfer manager raises — that one is "slow *this* one down,
// the one saturating the disk right now, without touching the others". So it moved onto the control,
// which the engine already holds and already consults per chunk.
//
// Three states, and the difference between two of them is the point: nil means "defer to the
// operation", 0 means "no limit, whatever the operation was told", and a positive value is a cap.

import XCTest
@testable import PCOperations

final class OperationControlSpeedTests: XCTestCase {

    func test_aFreshControlDefersToTheOperation() async {
        let control = OperationControl()
        let limit = await control.speedLimit
        XCTAssertNil(limit, "a control that was never told a limit must not impose one")
    }

    func test_theLimitCanBeSetAndRead() async {
        let control = OperationControl()
        await control.setSpeedLimit(64 * 1024)
        let limit = await control.speedLimit
        XCTAssertEqual(limit, 64 * 1024)
    }

    func test_zeroIsNotTheSameAsNoOverride() async {
        // The distinction the engine reads as `control.speedLimit ?? options.maxBytesPerSecond`.
        // Zero is an override meaning "let this one run flat out" and must survive a configured
        // global limit; nil is "no opinion" and must not.
        let control = OperationControl()
        await control.setSpeedLimit(0)
        let zero = await control.speedLimit
        XCTAssertEqual(zero, 0, "0 must be an override, not an absent one")

        await control.setSpeedLimit(nil)
        let cleared = await control.speedLimit
        XCTAssertNil(cleared, "setting nil hands the decision back to the operation")
    }

    func test_theLimitCanBeChangedWhileTheOperationWouldBeRunning() async {
        // The reason it lives on the control at all: an options struct is copied into the engine at
        // the start, so a change to it would only ever affect the *next* transfer.
        let control = OperationControl()
        await control.setSpeedLimit(1024)
        await control.setSpeedLimit(8 * 1024)
        let limit = await control.speedLimit
        XCTAssertEqual(limit, 8 * 1024)
    }

    func test_theLimitIsIndependentOfPauseAndCancel() async {
        // They share a control; setting one must not disturb the others, or "slow it down" would
        // quietly become "pause it".
        let control = OperationControl()
        await control.setSpeedLimit(2048)
        let paused = await control.isPaused
        let cancelled = await control.isCancelled
        XCTAssertFalse(paused)
        XCTAssertFalse(cancelled)

        await control.pause()
        let stillLimited = await control.speedLimit
        XCTAssertEqual(stillLimited, 2048, "pausing must not clear the limit")
    }
}
