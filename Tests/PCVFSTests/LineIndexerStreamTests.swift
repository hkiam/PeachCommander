// LineIndexerStreamTests.swift - streaming line-offset scan for huge files (F-112).

import XCTest
@testable import PCVFS

final class LineIndexerStreamTests: XCTestCase {
    private func scan(_ s: String, maxLines: Int = 1_000_000) -> LineIndexer.StreamIndex {
        var bytes = Array(s.utf8)
        return bytes.withUnsafeMutableBytes { raw in
            LineIndexer.lineStartOffsets(in: UnsafeRawBufferPointer(raw), maxLines: maxLines)
        }
    }

    func testMatchesByteArrayVersion() {
        let s = "alpha\nbeta\r\ngamma\rdelta"
        let stream = scan(s)
        let ints = LineIndexer.lineStarts(in: Array(s.utf8)).map(Int64.init)
        XCTAssertEqual(stream.starts, ints)
        XCTAssertFalse(stream.truncated)
        XCTAssertEqual(stream.contentEnd, Int64(s.utf8.count))
    }

    func testTrailingNewlineNoEmptyLine() {
        let s = "a\n"
        let stream = scan(s)
        XCTAssertEqual(stream.starts, [0])
        XCTAssertEqual(stream.contentEnd, 2)
    }

    func testEmpty() {
        let stream = scan("")
        XCTAssertTrue(stream.starts.isEmpty)
        XCTAssertEqual(stream.contentEnd, 0)
    }

    func testTruncationAtMaxLines() {
        // 10 lines, cap at 3 → keep 3 starts, mark truncated, contentEnd bounds line 3.
        let s = (0..<10).map { "line\($0)" }.joined(separator: "\n")
        let stream = scan(s, maxLines: 3)
        XCTAssertTrue(stream.truncated)
        XCTAssertEqual(stream.starts.count, 3)
        // contentEnd is the start of the 4th line (offset just past "line0\nline1\nline2\n").
        XCTAssertEqual(stream.contentEnd, Int64("line0\nline1\nline2\n".utf8.count))
    }

    func testLargeInputIndexesEveryLine() {
        // 100k lines well past any 16 MB byte boundary in aggregate content.
        let n = 100_000
        let s = (0..<n).map { "row-\($0)" }.joined(separator: "\n")
        let stream = scan(s)
        XCTAssertFalse(stream.truncated)
        XCTAssertEqual(stream.starts.count, n)
    }
}
