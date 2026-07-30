import XCTest
@testable import PCVFS

final class BinaryHeuristicTests: XCTestCase {
    func testPlainTextIsNotBinary() {
        XCTAssertFalse(BinaryHeuristic.isProbablyBinary(Array("Hello, world!\nLine two\ttabbed\r\n".utf8)))
    }

    func testEmptyIsNotBinary() {
        XCTAssertFalse(BinaryHeuristic.isProbablyBinary([]))
    }

    func testManyNullsIsBinary() {
        var bytes = Array("text".utf8)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 20))
        XCTAssertTrue(BinaryHeuristic.isProbablyBinary(bytes))
    }

    func testTabsNewlinesStayText() {
        // TAB(0x09), LF(0x0A), CR(0x0D) are text; only <0x09 and NUL count as binary.
        let bytes: [UInt8] = Array(repeating: 0x09, count: 50) + Array(repeating: 0x0A, count: 50)
        XCTAssertFalse(BinaryHeuristic.isProbablyBinary(bytes))
    }

    func testJustUnderThresholdIsText() {
        // 5 non-text out of 100 = exactly 5% → not > threshold → text.
        var bytes = [UInt8](repeating: 0x41, count: 95)
        bytes.append(contentsOf: [UInt8](repeating: 0, count: 5))
        XCTAssertFalse(BinaryHeuristic.isProbablyBinary(bytes))
    }
}
