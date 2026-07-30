// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

/// In-memory ByteSource so the engine is testable without touching the filesystem.
private struct MemSource: ByteSource {
    let data: [UInt8]
    var count: Int64 { Int64(data.count) }
    func bytes(at offset: Int64, length: Int) -> [UInt8] {
        let start = Int(offset)
        let end = min(start + length, data.count)
        guard start < end else { return [] }
        return Array(data[start..<end])
    }
}

final class BinaryDiffTests: XCTestCase {
    private func src(_ bytes: [UInt8]) -> MemSource { MemSource(data: bytes) }

    func testIdentical() {
        let r = BinaryDiff.compare(src([1, 2, 3, 4]), src([1, 2, 3, 4]))
        XCTAssertTrue(r.equal)
        XCTAssertNil(r.firstDifference)
        XCTAssertEqual(r.differingBytes, 0)
        XCTAssertTrue(r.ranges.isEmpty)
    }

    func testSingleByteDifference() {
        let r = BinaryDiff.compare(src([1, 2, 3, 4]), src([1, 9, 3, 4]))
        XCTAssertFalse(r.equal)
        XCTAssertEqual(r.firstDifference, 1)
        XCTAssertEqual(r.differingBytes, 1)
        XCTAssertEqual(r.ranges, [1..<2])
    }

    func testMultipleCoalescedRuns() {
        // Differ at [1,2] and [5]; equal elsewhere.
        let a = src([0, 1, 2, 3, 4, 5, 6])
        let b = src([0, 9, 8, 3, 4, 9, 6])
        let r = BinaryDiff.compare(a, b)
        XCTAssertEqual(r.ranges, [1..<3, 5..<6])
        XCTAssertEqual(r.differingBytes, 3)
        XCTAssertEqual(r.firstDifference, 1)
    }

    func testDifferentSizesSharedPrefix() {
        let r = BinaryDiff.compare(src([1, 2, 3]), src([1, 2, 3, 4, 5]))
        XCTAssertFalse(r.equal)
        XCTAssertEqual(r.differingBytes, 0)          // common prefix identical
        XCTAssertEqual(r.firstDifference, 3)         // where the shorter file ends
        XCTAssertEqual(r.sizeA, 3)
        XCTAssertEqual(r.sizeB, 5)
        XCTAssertTrue(r.ranges.isEmpty)
    }

    func testRunSpanningChunkBoundary() {
        // Force tiny chunks so a differing run crosses a boundary.
        let a = src(Array(repeating: 0, count: 10))
        var bb = Array<UInt8>(repeating: 0, count: 10)
        bb[3] = 1; bb[4] = 1; bb[5] = 1   // run 3..<6 spans the chunk edge at 4
        let r = BinaryDiff.compare(a, src(bb), chunk: 4)
        XCTAssertEqual(r.ranges, [3..<6])
        XCTAssertEqual(r.differingBytes, 3)
    }

    func testMaxRangesTruncation() {
        // Alternating diffs => many single-byte runs; cap at 2.
        let a = src([0, 0, 0, 0, 0, 0])
        let b = src([1, 0, 1, 0, 1, 0])   // runs at 0,2,4
        let r = BinaryDiff.compare(a, b, maxRanges: 2)
        XCTAssertEqual(r.ranges.count, 2)
        XCTAssertTrue(r.truncatedRanges)
        XCTAssertEqual(r.differingBytes, 3)          // counting continues past the cap
    }

    func testEmptyVersusNonEmpty() {
        let r = BinaryDiff.compare(src([]), src([1, 2]))
        XCTAssertFalse(r.equal)
        XCTAssertEqual(r.firstDifference, 0)
        XCTAssertEqual(r.differingBytes, 0)
        XCTAssertEqual(r.sizeA, 0)
        XCTAssertEqual(r.sizeB, 2)
    }

    // Regression for the "not byte-for-byte" report: over real mmap'd files, a shared
    // prefix must NOT be flagged as differing (only the actual differing byte is).
    func testOverRealFileSlicesSharedPrefix() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("bindiff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var a = [UInt8](repeating: 0xAB, count: 5000)   // spans multiple 64 KiB-internal chunks trivially
        var b = a
        a += [1, 2, 3]
        b += [1, 9, 3]                                   // differ only at offset 5001
        let fa = dir.appendingPathComponent("a.bin"); try Data(a).write(to: fa)
        let fb = dir.appendingPathComponent("b.bin"); try Data(b).write(to: fb)

        let sa = try XCTUnwrap(FileSlice(path: fa.path))
        let sb = try XCTUnwrap(FileSlice(path: fb.path))
        let r = BinaryDiff.compare(sa, sb)
        XCTAssertEqual(r.firstDifference, 5001)
        XCTAssertEqual(r.differingBytes, 1)
        XCTAssertEqual(r.ranges, [5001..<5002])

        // Identical files compare equal.
        let same = BinaryDiff.compare(try XCTUnwrap(FileSlice(path: fa.path)),
                                      try XCTUnwrap(FileSlice(path: fa.path)))
        XCTAssertTrue(same.equal)
    }
}
