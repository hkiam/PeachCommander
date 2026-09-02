// SPDX-License-Identifier: Apache-2.0
import XCTest
import CoreGraphics
@testable import PCFoundation

final class PanelViewModeTests: XCTestCase {
    func testModeCycle() {
        XCTAssertEqual(PanelViewMode.details.next, .brief)
        XCTAssertEqual(PanelViewMode.brief.next, .icons)
        XCTAssertEqual(PanelViewMode.icons.next, .gallery)
        XCTAssertEqual(PanelViewMode.gallery.next, .details)   // wraps
    }

    func testRawValueRoundTrip() {
        for mode in PanelViewMode.allCases {
            XCTAssertEqual(PanelViewMode(rawValue: mode.rawValue), mode)
        }
    }

    // MARK: - GridLayout

    private let grid = GridLayout(itemWidth: 80, itemHeight: 80, spacing: 10, edgeInset: 8)

    func testColumns() {
        // usable = 300 - 16 + 10 = 294; per = 90 → 3 columns.
        XCTAssertEqual(grid.columns(forWidth: 300), 3)
        XCTAssertEqual(grid.columns(forWidth: 50), 1)      // always at least 1
        XCTAssertEqual(grid.columns(forWidth: 1000), 11)
    }

    func testRowsAndContentHeight() {
        XCTAssertEqual(grid.rows(count: 7, width: 300), 3)   // 3 cols → 3 rows
        XCTAssertEqual(grid.rows(count: 0, width: 300), 0)
        // 3 rows: 16 + 3*80 + 2*10 = 276
        XCTAssertEqual(grid.contentHeight(count: 7, width: 300), 276)
    }

    func testFrame() {
        // index 4 → col 1, row 1 (3 columns).
        let f = grid.frame(at: 4, width: 300)
        XCTAssertEqual(f.origin.x, 8 + 1 * 90)   // 98
        XCTAssertEqual(f.origin.y, 8 + 1 * 90)   // 98
        XCTAssertEqual(f.size.width, 80)
    }

    func testHitTest() {
        // Center of item 4 (98..178, 98..178).
        XCTAssertEqual(grid.index(at: CGPoint(x: 130, y: 130), width: 300, count: 7), 4)
        // In the gap between columns → nil.
        XCTAssertNil(grid.index(at: CGPoint(x: 92, y: 130), width: 300, count: 7))
        // Past the end (index 8 with count 7) → nil.
        XCTAssertNil(grid.index(at: CGPoint(x: 130, y: 220), width: 300, count: 7))
    }

    // MARK: - Column-major (brief)

    func testRowsPerColumnAndColumns() {
        // usable = 300 - 16 + 10 = 294; per = 90 → 3 rows per column.
        XCTAssertEqual(grid.rowsPerColumn(forHeight: 300), 3)
        XCTAssertEqual(grid.rowsPerColumn(forHeight: 40), 1)          // at least 1
        XCTAssertEqual(grid.columnsNeeded(count: 7, height: 300), 3)  // 3 rows → ceil(7/3)=3
        XCTAssertEqual(grid.columnsNeeded(count: 0, height: 300), 0)
    }

    func testColumnMajorFrameAndContentWidth() {
        // 3 rows/col. Index 4 → col 1, row 1.
        let f = grid.frameColumnMajor(at: 4, height: 300)
        XCTAssertEqual(f.origin.x, 8 + 1 * 90)   // 98
        XCTAssertEqual(f.origin.y, 8 + 1 * 90)   // 98
        // 3 columns: 16 + 3*80 + 2*10 = 276.
        XCTAssertEqual(grid.contentWidth(count: 7, height: 300), 276)
    }

    func testColumnMajorHitTest() {
        // Item 4 sits at col 1, row 1 → center (130,130).
        XCTAssertEqual(grid.indexColumnMajor(at: CGPoint(x: 130, y: 130), height: 300, count: 7), 4)
        // Gap between rows → nil.
        XCTAssertNil(grid.indexColumnMajor(at: CGPoint(x: 130, y: 92), height: 300, count: 7))
        // Past the end (col 3 would be index 9) → nil.
        XCTAssertNil(grid.indexColumnMajor(at: CGPoint(x: 310, y: 20), height: 300, count: 7))
    }
    // MARK: - What a viewport covers (F-479 follow-up)

    /// 110×92 cells, 12 spacing, 12 inset — the gallery's own geometry. A 400 pt wide grid holds
    /// three columns; a 200 pt tall viewport reaches into the third row.
    private var gallery: GridLayout {
        GridLayout(itemWidth: 110, itemHeight: 92, spacing: 12, edgeInset: 12)
    }

    func testAViewportAtTheTopCoversTheFirstRowsOnly() {
        let range = gallery.indexes(intersecting: CGRect(x: 0, y: 0, width: 400, height: 200),
                                    width: 400, count: 300)
        XCTAssertEqual(range.lowerBound, 0)
        // Three columns. Row 0 sits at y 12…104 and row 1 at 116…208, so a 200 pt viewport touches
        // two rows — row 2 starts at 220, past it. Six items, not nine: the first version of this
        // expectation said nine and was wrong about the geometry, which the cross-check below caught.
        XCTAssertEqual(range.upperBound, 6)
    }

    func testScrollingMovesTheRangeAndDoesNotGrowIt() {
        let top = gallery.indexes(intersecting: CGRect(x: 0, y: 0, width: 400, height: 200),
                                  width: 400, count: 300)
        let down = gallery.indexes(intersecting: CGRect(x: 0, y: 1040, width: 400, height: 200),
                                   width: 400, count: 300)
        XCTAssertGreaterThan(down.lowerBound, top.lowerBound)
        // Not "the same count": a viewport straddles two or three rows depending on where it sits,
        // so the honest invariant is that scrolling moves the window without widening it by more
        // than the one row that straddling can add.
        XCTAssertLessThanOrEqual(down.count, top.count + gallery.columns(forWidth: 400))
    }

    func testTheRangeNeverRunsPastTheEnd() {
        // Scrolled to the bottom of a short listing, and far past the end of a long one.
        let short = gallery.indexes(intersecting: CGRect(x: 0, y: 0, width: 400, height: 2000),
                                    width: 400, count: 4)
        XCTAssertEqual(short, 0..<4)
        let past = gallery.indexes(intersecting: CGRect(x: 0, y: 100_000, width: 400, height: 200),
                                   width: 400, count: 4)
        XCTAssertTrue(past.isEmpty, "past the end is empty, not a crash and not a wrap")
    }

    func testAnEmptyListingCoversNothing() {
        XCTAssertTrue(gallery.indexes(intersecting: CGRect(x: 0, y: 0, width: 400, height: 200),
                                      width: 400, count: 0).isEmpty)
    }

    /// A row half-scrolled off the top is still on screen and still needs its thumbnail.
    func testARowPartlyVisibleIsIncluded() {
        let range = gallery.indexes(intersecting: CGRect(x: 0, y: 60, width: 400, height: 60),
                                    width: 400, count: 300)
        XCTAssertEqual(range.lowerBound, 0, "row 0 is still partly visible at y=60")
        XCTAssertGreaterThanOrEqual(range.upperBound, 3)
    }

    func testEveryVisibleIndexAgreesWithItsOwnFrame() {
        // The range is computed from arithmetic; `frame(at:)` is what the drawing uses. They have to
        // agree, or a thumbnail is fetched for a cell nobody can see — or worse, not fetched for one
        // they can.
        let rect = CGRect(x: 0, y: 300, width: 400, height: 250)
        let range = gallery.indexes(intersecting: rect, width: 400, count: 300)
        for i in range {
            XCTAssertTrue(gallery.frame(at: i, width: 400).intersects(rect),
                          "index \(i) is in the range but its cell is outside the viewport")
        }
        // And nothing just outside the range intersects.
        for i in [range.lowerBound - 4, range.upperBound + 3] where i >= 0 && i < 300 {
            XCTAssertFalse(gallery.frame(at: i, width: 400).intersects(rect),
                           "index \(i) is outside the range but its cell is visible")
        }
    }

    /// The one that took the app down — but not in the way it first looks.
    ///
    /// `visibleRect` is `CGRect.infinite` (not `.zero`) while a view has no clipping ancestor, which
    /// is the state during a switch to gallery view. Feeding that in trapped inside `Int(Double)`,
    /// because Swift's conversion is a runtime check rather than a saturation — and `CGRect.infinite`
    /// is built from *finite* numbers (its corner is -8.99e307), so an `isFinite` guard sails past it.
    ///
    /// What it must **not** do is trap. What it should *answer* is what the geometry says: an
    /// infinite viewport intersects every cell. Deciding that "no clip yet" means "nothing is on
    /// screen" is the view's business, not this function's — `IconGridView` refuses the rect, and
    /// this asserts the honest arithmetic so the two cannot both be changed to agree on a wrong one.
    func testAnInfiniteViewportCoversEverythingWithoutTrapping() {
        XCTAssertEqual(gallery.indexes(intersecting: .infinite, width: 400, count: 300), 0..<300)
        XCTAssertEqual(gallery.indexesColumnMajor(intersecting: .infinite, height: 400, count: 300),
                       0..<300)
    }

    func testAbsurdButFiniteCoordinatesAreClampedNotConverted() {
        // Short of infinity and still far outside `Int`: the clamp, not the guard, is what holds.
        let huge = CGRect(x: 0, y: 1e300, width: 400, height: 1e300)
        XCTAssertTrue(gallery.indexes(intersecting: huge, width: 400, count: 300).isEmpty)
        let fromZero = CGRect(x: 0, y: 0, width: 400, height: 1e300)
        let range = gallery.indexes(intersecting: fromZero, width: 400, count: 300)
        XCTAssertEqual(range, 0..<300, "a viewport taller than the content covers all of it")
    }

    func testANegativeOrEmptyViewportCoversNothing() {
        XCTAssertTrue(gallery.indexes(intersecting: .zero, width: 400, count: 300).isEmpty)
        XCTAssertTrue(gallery.indexes(intersecting: CGRect(x: 0, y: -5000, width: 400, height: 10),
                                      width: 400, count: 300).isEmpty)
    }

    func testBriefFlowsByColumnAndCoversWhatIsVisible() {
        let brief = GridLayout(itemWidth: 200, itemHeight: 18, spacing: 2, edgeInset: 6)
        let rows = brief.rowsPerColumn(forHeight: 400)
        let range = brief.indexesColumnMajor(intersecting: CGRect(x: 0, y: 0, width: 420, height: 400),
                                             height: 400, count: 1000)
        XCTAssertEqual(range.lowerBound, 0)
        // Two full columns fit in 420 pt at 202 pt each, so the third is reached.
        XCTAssertEqual(range.upperBound, 3 * rows)
    }

}
