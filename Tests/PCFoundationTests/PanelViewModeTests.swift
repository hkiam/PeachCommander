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
}
