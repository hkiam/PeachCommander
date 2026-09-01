// SPDX-License-Identifier: Apache-2.0
// ImplicitWorkBudgetTests.swift - What the cursor alone may cause to be read (F-479).
//
// The rule this guards is the one the report was about: 32 MB is nothing on a disk and half a minute
// over a VPN, so a single byte ceiling is the wrong shape. The cases below are the crossings —
// same size, different source; same source, different measured link.

import XCTest
@testable import PCFoundation

final class ImplicitWorkBudgetTests: XCTestCase {

    private let mb: Int64 = 1024 * 1024
    private let limits = ImplicitWorkLimits.standard

    // MARK: - The local disk keeps working the way it always has

    func testALargeFileOnALocalDiskIsPreviewedByDefault() {
        // localBytes is 0 in the shipping limits, and 0 means no limit: refusing local previews
        // would be a regression against every version so far.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 800 * mb, limits: limits), .go)
    }

    func testALocalCeilingIsHonouredWhenTheUserSetsOne() {
        var limits = self.limits
        limits.localBytes = 10 * mb
        guard case .onRequest(.tooBig(let bytes, let limit)) =
                ImplicitWorkBudget.decide(locality: .fast, bytes: 40 * mb, limits: limits)
        else { return XCTFail("a set local ceiling must apply") }
        XCTAssertEqual(bytes, 40 * mb)
        XCTAssertEqual(limit, 10 * mb)
    }

    // MARK: - The same file, somewhere else

    func testTheSameSizeIsAllowedLocallyAndDeclinedOnAShare() {
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 32 * mb, limits: limits), .go)
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 32 * mb, limits: limits).reason,
                       .tooBig(bytes: 32 * mb, limit: 4 * mb))
    }

    func testASmallRemoteFileStillGoesThrough() {
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 200 * 1024, limits: limits), .go)
    }

    func testRemoteCanBeSwitchedOffEntirely() {
        var limits = self.limits
        limits.allowRemote = false
        // Off means off, not "off above the ceiling": a 1 KB file is declined too.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 1024, limits: limits).reason,
                       .remoteDisabled)
    }

    // MARK: - A measured link decides in both directions

    func testAFastMeasuredShareShowsMoreThanTheFallbackWould() {
        // 100 MB/s measured, 1.5 s budget: 32 MB needs 0.32 s, well inside it — even though the
        // untested fallback would have refused at 4 MB.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 32 * mb,
                                                 ratePerSecond: 100 * Double(mb), limits: limits), .go)
    }

    func testASlowMeasuredLinkDeclinesWhatTheFallbackWouldHaveAllowed() {
        // 300 KB/s: 2 MB is under the 4 MB fallback and still seven seconds of waiting.
        guard case .onRequest(.tooSlow(_, let seconds, let budget)) =
                ImplicitWorkBudget.decide(locality: .remote, bytes: 2 * mb,
                                          ratePerSecond: 300 * 1024, limits: limits)
        else { return XCTFail("a measured slow link must decline inside the byte fallback") }
        XCTAssertEqual(seconds, 6.83, accuracy: 0.1)
        XCTAssertEqual(budget, 1.5)
    }

    func testAMeasurementIsIgnoredOnALocalDisk() {
        // A slow disk read must not start refusing local previews; the byte ceiling governs there.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 500 * mb,
                                                 ratePerSecond: 1024, limits: limits), .go)
    }

    func testTheTimeBudgetCanBeSwitchedOff() {
        var limits = self.limits
        limits.seconds = 0
        // With no time budget the byte fallback governs again, measurement or not.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 32 * mb,
                                                 ratePerSecond: 100 * Double(mb), limits: limits).reason,
                       .tooBig(bytes: 32 * mb, limit: 4 * mb))
    }

    // MARK: - Dormant: the answer that must not depend on size

    func testADatalessFileIsNeverMaterialisedByTheCursor() {
        // Four kilobytes, and still a round trip to a provider plus a download. Asked before any
        // size question on purpose.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .dormant, bytes: 4096, limits: limits).reason,
                       .dormant)
    }

    func testDormantCanBeAllowedAndIsThenJudgedLikeAnyRemoteFile() {
        var limits = self.limits
        limits.allowDormant = true
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .dormant, bytes: 1024, limits: limits), .go)
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .dormant, bytes: 40 * mb, limits: limits).reason,
                       .tooBig(bytes: 40 * mb, limit: 4 * mb))
    }

    // MARK: - Archives

    func testAnArchiveMemberIsCappedByTheDecompressionCeiling() {
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 64 * mb,
                                                 inArchive: true, limits: limits).reason,
                       .tooBig(bytes: 64 * mb, limit: 32 * mb))
    }

    func testAnOrdinaryMemberOfALocalArchiveIsPreviewed() {
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 2 * mb,
                                                 inArchive: true, limits: limits), .go)
    }

    func testAnArchiveOnAShareInheritsTheWorseOfTheTwo() {
        // 8 MB is inside the archive ceiling and outside the remote one.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: 8 * mb,
                                                 inArchive: true, limits: limits).reason,
                       .tooBig(bytes: 8 * mb, limit: 4 * mb))
    }

    func testAFormatThatRescansPerMemberIsNeverFollowedByTheCursor() {
        // The cost has nothing to do with the member's size: a 2 KB file in a 5,000-member tarball
        // costs a full pass either way.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 2048, inArchive: true,
                                                 rescansPerRead: true, limits: limits).reason,
                       .rescansPerRead)
    }

    // MARK: - The explicit gesture

    func testAnExplicitGestureIsHeldToNothing() {
        // Cmd+Y, Enter and F3 ask the same function with the unrestricted limits, so there is one
        // rule with two settings rather than two rules.
        for locality in SourceLocality.allCases {
            XCTAssertEqual(ImplicitWorkBudget.decide(locality: locality, bytes: 4 * 1024 * mb,
                                                     inArchive: true,
                                                     limits: .unrestricted), .go, "\(locality)")
        }
    }

    func testEvenAnExplicitGestureIsToldAboutARescanningFormat() {
        // Not declined — `rescansPerRead` is only ever passed by a caller that wants the automatic
        // answer suppressed, and the explicit paths do not pass it.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .fast, bytes: 2048, rescansPerRead: true,
                                                 limits: .unrestricted).reason, .rescansPerRead)
    }

    // MARK: - Shapes that must not crash or refuse by accident

    func testAnUnknownSizeIsTreatedAsNothing() {
        // A directory-shaped entry reports -1 in this codebase; it must not become an enormous read.
        XCTAssertEqual(ImplicitWorkBudget.decide(locality: .remote, bytes: -1, limits: limits), .go)
    }
}
