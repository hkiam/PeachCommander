// SPDX-License-Identifier: Apache-2.0
// WorkspaceChipHitTests.swift - The order the regions are tested in (F-499).

import XCTest
@testable import PCFoundation

final class WorkspaceChipHitTests: XCTestCase {

    private let chip = CGRect(x: 10, y: 2, width: 120, height: 20)

    private func region(_ point: CGPoint, chips: [CGRect]? = nil,
                        showsClose: @escaping (Int) -> Bool = { _ in true },
                        plus: CGRect? = nil) -> WorkspaceChipHit.Region {
        WorkspaceChipHit.region(at: point, chips: chips ?? [chip],
                                showsClose: showsClose, plus: plus)
    }

    func test_theCloseGlyphIsTestedBeforeTheChipItSitsIn() throws {
        let close = try XCTUnwrap(WorkspaceChipHit.closeRect(in: chip, showsClose: true))
        XCTAssertTrue(chip.contains(CGPoint(x: close.midX, y: close.midY)),
                      "the ✕ lies inside its chip — which is what makes the order decide it")

        XCTAssertEqual(region(CGPoint(x: close.midX, y: close.midY)), .close(0))

        // And the wrong order really would swallow it: a chip-first pass returns the chip for the
        // very same point. Asserted rather than assumed, because this defect shipped once before in
        // the drive bar and neither the compiler nor a screenshot could see it (F-385).
        let chipFirst: WorkspaceChipHit.Region =
            chip.contains(CGPoint(x: close.midX, y: close.midY)) ? .chip(0) : .none
        XCTAssertEqual(chipFirst, .chip(0), "the wrong order is wrong for a reachable point")
    }

    func test_aClickOnTheNameSwitchesRatherThanDeletes() {
        XCTAssertEqual(region(CGPoint(x: chip.minX + 20, y: chip.midY)), .chip(0))
    }

    func test_theLastWorkspaceHasNoCloseGlyphAtAll() throws {
        // It cannot be deleted, so it is not drawn — the rule the "+" already follows. A click where
        // the ✕ would have been switches instead of doing nothing.
        XCTAssertNil(WorkspaceChipHit.closeRect(in: chip, showsClose: false))
        let close = try XCTUnwrap(WorkspaceChipHit.closeRect(in: chip, showsClose: true))
        XCTAssertEqual(region(CGPoint(x: close.midX, y: close.midY), showsClose: { _ in false }),
                       .chip(0))
    }

    func test_aChipWithNoRoomForANameBesideItGetsNoGlyph() {
        // Better no ✕ than a ✕ sitting on the last letter of the name: the name is what identifies
        // the workspace, so it is the glyph that gives way.
        let narrow = CGRect(x: 0, y: 2, width: WorkspaceChipHit.closeSide + 10, height: 20)
        XCTAssertNil(WorkspaceChipHit.closeRect(in: narrow, showsClose: true))
        let swatch = CGRect(x: 0, y: 2, width: 24, height: 20)
        XCTAssertNil(WorkspaceChipHit.closeRect(in: swatch, showsClose: true))
    }

    func test_theGlyphStaysInsideItsChip() throws {
        for width in [60.0, 84.0, 120.0, 170.0] {
            let rect = CGRect(x: 7, y: 2, width: width, height: 20)
            guard let close = WorkspaceChipHit.closeRect(in: rect, showsClose: true) else { continue }
            XCTAssertTrue(rect.contains(close), "the ✕ left its chip at width \(width)")
            XCTAssertGreaterThanOrEqual(close.minX - rect.minX, WorkspaceChipHit.minimumNameWidth,
                                        "the ✕ ate the name at width \(width)")
        }
    }

    func test_theSecondChipsGlyphDeletesTheSecondWorkspace() throws {
        let second = CGRect(x: 140, y: 2, width: 120, height: 20)
        let close = try XCTUnwrap(WorkspaceChipHit.closeRect(in: second, showsClose: true))
        XCTAssertEqual(region(CGPoint(x: close.midX, y: close.midY), chips: [chip, second]),
                       .close(1))
    }

    func test_thePlusAndFreeSpace() {
        let plus = CGRect(x: 200, y: 2, width: 22, height: 20)
        XCTAssertEqual(region(CGPoint(x: plus.midX, y: plus.midY), plus: plus), .new)
        XCTAssertEqual(region(CGPoint(x: 400, y: 10), plus: plus), .none)
        // A zero rect is how the view says "no + is drawn"; it must not swallow the origin.
        XCTAssertEqual(region(CGPoint(x: 0, y: 0), plus: .zero), .none)
    }
}
