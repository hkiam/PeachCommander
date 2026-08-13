// SPDX-License-Identifier: Apache-2.0
// TransferScheduleTests.swift - "Start all" must not start everything at once (F-085).
//
// The download list held its jobs until the user started them, and then started every one of them —
// each with its own queue and its own control, so twenty queued downloads became twenty concurrent
// transfers. Over FTP that is worse than useless, and a background transfer manager exists precisely
// so transfers take turns.
//
// The rule is tested here rather than through the manager, which is an AppKit object no test bundle
// can reach — and because whether the transfers overlap cannot be observed from outside without
// timing them: on APFS a same-volume copy can finish so fast that sequential and concurrent look
// identical.

import XCTest
@testable import PCOperations

final class TransferScheduleTests: XCTestCase {

    func testTheFirstHeldJobIsTheOneThatStarts() {
        XCTAssertEqual(TransferSchedule.nextToStart([.queued, .queued, .queued]), 0)
    }

    func testNothingStartsWhileOneIsRunning() {
        XCTAssertNil(TransferSchedule.nextToStart([.running, .queued, .queued]),
                     "a second transfer began underneath the one already running")
    }

    func testAPausedJobStillHoldsTheSlot() {
        // It was started and the user may resume it. Beginning another underneath is exactly the
        // concurrency this exists to avoid.
        XCTAssertNil(TransferSchedule.nextToStart([.paused, .queued]))
    }

    func testTheNextOneStartsOnceTheFirstIsDone() {
        XCTAssertEqual(TransferSchedule.nextToStart([.done, .queued, .queued]), 1)
    }

    func testAFailedJobDoesNotStrandTheRestOfTheList() {
        XCTAssertEqual(TransferSchedule.nextToStart([.failed, .queued]), 1)
        XCTAssertEqual(TransferSchedule.nextToStart([.cancelled, .queued]), 1)
    }

    func testNothingLeftToStart() {
        XCTAssertNil(TransferSchedule.nextToStart([.done, .done]))
        XCTAssertNil(TransferSchedule.nextToStart([]))
    }

    func testAWholeListDrainsOneAtATime() {
        // The loop the manager performs: start, finish, start the next. Three jobs must produce three
        // starts in order, never two at once.
        var statuses: [TransferJobStatus] = [.queued, .queued, .queued]
        var startedInOrder: [Int] = []
        while let next = TransferSchedule.nextToStart(statuses) {
            startedInOrder.append(next)
            statuses[next] = .running
            XCTAssertEqual(statuses.filter { $0 == .running }.count, 1, "two jobs were running at once")
            XCTAssertNil(TransferSchedule.nextToStart(statuses), "a third started mid-transfer")
            statuses[next] = .done
        }
        XCTAssertEqual(startedInOrder, [0, 1, 2])
    }

    // MARK: - Reordering the queue (F-085)

    func test_onlyAQueuedJobCanBeMoved() {
        let s: [TransferJobStatus] = [.running, .queued, .done]
        XCTAssertTrue(TransferSchedule.canReorder(s, at: 1))
        XCTAssertFalse(TransferSchedule.canReorder(s, at: 0), "a running job cannot be reordered")
        XCTAssertFalse(TransferSchedule.canReorder(s, at: 2), "a finished job is history")
        XCTAssertFalse(TransferSchedule.canReorder(s, at: 9), "out of range")
    }

    func test_movingStepsToTheNeighbouringQueuedPosition() {
        let s: [TransferJobStatus] = [.queued, .queued, .queued]
        XCTAssertEqual(TransferSchedule.moveTarget(s, from: 2, delta: -1), 1)
        XCTAssertEqual(TransferSchedule.moveTarget(s, from: 0, delta: 1), 1)
    }

    func test_movingStepsOverFinishedJobsRatherThanLandingOnThem() {
        // A completed transfer between two queued ones is history: nudging the lower one up should
        // move it past the finished row, not swap places with something that already happened.
        let s: [TransferJobStatus] = [.queued, .done, .failed, .queued]
        XCTAssertEqual(TransferSchedule.moveTarget(s, from: 3, delta: -1), 0)
    }

    func test_aQueuedJobNeverCrossesTheRunningOne() {
        // The barrier. Promoting a job above the transfer in flight changes nothing — that one still
        // has to finish first — while looking like it did something, which is how a control teaches
        // people it is broken.
        let s: [TransferJobStatus] = [.queued, .running, .queued]
        XCTAssertNil(TransferSchedule.moveTarget(s, from: 2, delta: -1))
        // …and the same for a paused job, which still holds the slot.
        let paused: [TransferJobStatus] = [.queued, .paused, .queued]
        XCTAssertNil(TransferSchedule.moveTarget(paused, from: 2, delta: -1))
    }

    func test_theEndsOfTheListDoNotWrap() {
        let s: [TransferJobStatus] = [.queued, .queued]
        XCTAssertNil(TransferSchedule.moveTarget(s, from: 0, delta: -1))
        XCTAssertNil(TransferSchedule.moveTarget(s, from: 1, delta: 1))
    }

    func test_movingTheFirstQueuedJobUpIsWhatStartsItNext() {
        // The point of the whole feature, stated as the rule it changes: after the move, the job
        // that was second is the one `nextToStart` picks.
        var s: [TransferJobStatus] = [.queued, .queued]
        XCTAssertEqual(TransferSchedule.nextToStart(s), 0)
        let target = TransferSchedule.moveTarget(s, from: 1, delta: -1)
        XCTAssertEqual(target, 0)
        s.swapAt(1, target!)
        XCTAssertEqual(TransferSchedule.nextToStart(s), 0)
    }
}
