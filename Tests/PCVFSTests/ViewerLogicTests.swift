// SPDX-License-Identifier: Apache-2.0
// ViewerLogicTests.swift - Unit tests for the pure viewer-support logic
// (FileSlice, LineIndexer, EncodingDetector, HexFormatter, ChunkSearcher)
// built for the Lister (I07).

import XCTest
@testable import PCVFS

final class ViewerLogicTests: XCTestCase {
    private var tempPaths: [String] = []

    override func tearDown() {
        for path in tempPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        tempPaths.removeAll()
        super.tearDown()
    }

    private func makeTempFile(bytes: [UInt8]) -> String {
        let path = NSTemporaryDirectory() + "ViewerLogicTests-\(UUID().uuidString).bin"
        FileManager.default.createFile(atPath: path, contents: Data(bytes))
        tempPaths.append(path)
        return path
    }

    // MARK: - FileSlice

    func testFileSlice_opensAndReadsBytes() throws {
        let path = makeTempFile(bytes: Array("Hello, World!".utf8))
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(slice.count, 13)
        XCTAssertEqual(slice.bytes(at: 0, length: 5), Array("Hello".utf8))
        XCTAssertEqual(slice.bytes(at: 7, length: 6), Array("World!".utf8))
    }

    func testFileSlice_emptyFile() throws {
        let path = makeTempFile(bytes: [])
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(slice.count, 0)
        XCTAssertEqual(slice.bytes(at: 0, length: 10), [])
    }

    func testFileSlice_nilForMissingFile() {
        let missingPath = NSTemporaryDirectory() + "ViewerLogicTests-does-not-exist-\(UUID().uuidString).bin"
        XCTAssertNil(FileSlice(path: missingPath))
    }

    func testFileSlice_clampsOutOfBoundsRead() throws {
        let path = makeTempFile(bytes: [0, 1, 2, 3, 4])
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(slice.bytes(at: 3, length: 100), [3, 4])
        XCTAssertEqual(slice.bytes(at: 10, length: 5), [])
        XCTAssertEqual(slice.bytes(at: 5, length: 5), [])
    }

    func testFileSlice_dataAtOffset() throws {
        let path = makeTempFile(bytes: Array("Hello".utf8))
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(slice.data(at: 0, length: 5), Data(Array("Hello".utf8)))
    }

    func testFileSlice_negativeOffsetReturnsEmpty() throws {
        let path = makeTempFile(bytes: Array("Hello".utf8))
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(slice.bytes(at: -1, length: 5), [])
        XCTAssertEqual(slice.bytes(at: 0, length: 0), [])
    }

    // MARK: - LineIndexer

    func testLineIndexer_lf() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\nb\nc".utf8)), [0, 2, 4])
    }

    func testLineIndexer_crlf() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\r\nb".utf8)), [0, 3])
    }

    func testLineIndexer_loneCR() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\rb".utf8)), [0, 2])
    }

    func testLineIndexer_trailingLF_noExtraEmptyLine() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\n".utf8)), [0])
    }

    func testLineIndexer_multipleLinesTrailingLF() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\nb\n".utf8)), [0, 2])
    }

    func testLineIndexer_emptyInput() {
        XCTAssertEqual(LineIndexer.lineStarts(in: []), [])
    }

    func testLineIndexer_singleLF() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("\n".utf8)), [0])
    }

    func testLineIndexer_mixedTerminators() {
        XCTAssertEqual(LineIndexer.lineStarts(in: Array("a\nb\r\nc\rd".utf8)), [0, 2, 5, 7])
    }

    func testLineIndexer_hugeSingleLine() {
        let huge = [UInt8](repeating: UInt8(ascii: "x"), count: 100_000)
        XCTAssertEqual(LineIndexer.lineStarts(in: huge), [0])
    }

    // MARK: - EncodingDetector

    func testEncodingDetector_utf8BOM() {
        let sample: [UInt8] = [0xEF, 0xBB, 0xBF, 0x41, 0x42]
        XCTAssertEqual(EncodingDetector.detect(sample), .utf8)
    }

    func testEncodingDetector_utf16LEBOM() {
        let sample: [UInt8] = [0xFF, 0xFE, 0x41, 0x00]
        XCTAssertEqual(EncodingDetector.detect(sample), .utf16LittleEndian)
    }

    func testEncodingDetector_utf16BEBOM() {
        let sample: [UInt8] = [0xFE, 0xFF, 0x00, 0x41]
        XCTAssertEqual(EncodingDetector.detect(sample), .utf16BigEndian)
    }

    func testEncodingDetector_plainASCII() {
        let sample = Array("Hello, World!".utf8)
        XCTAssertEqual(EncodingDetector.detect(sample), .utf8)
    }

    func testEncodingDetector_validMultibyteUTF8() {
        let sample = Array("café".utf8)
        XCTAssertEqual(EncodingDetector.detect(sample), .utf8)
    }

    func testEncodingDetector_invalidUTF8FallsBackToCP1252() {
        let sample: [UInt8] = [0x41, 0xC3, 0x28]
        XCTAssertEqual(EncodingDetector.detect(sample), .windowsCP1252)
    }

    // MARK: - HexFormatter

    func testHexFormatter_row_shortInput() {
        let bytes = Array("Hello".utf8)
        let row = HexFormatter.row(bytes: bytes, offset: 0)

        let expectedHex = "48 65 6c 6c 6f" + String(repeating: "   ", count: 11)
        let expectedAscii = "Hello" + String(repeating: " ", count: 11)
        XCTAssertEqual(row, "00000000  \(expectedHex)  \(expectedAscii)")
    }

    func testHexFormatter_row_full16ByteRow() {
        let bytes: [UInt8] = Array(0...15)
        let row = HexFormatter.row(bytes: bytes, offset: 0)

        let expected = "00000000  00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f  ................"
        XCTAssertEqual(row, expected)
    }

    func testHexFormatter_row_padsHexColumnsAndAscii() {
        let bytes: [UInt8] = [0xAB]
        let row = HexFormatter.row(bytes: bytes, offset: 16)

        let expectedHex = "ab" + String(repeating: "   ", count: 15)
        let expectedAscii = "." + String(repeating: " ", count: 15)
        XCTAssertEqual(row, "00000010  \(expectedHex)  \(expectedAscii)")
    }

    func testHexFormatter_row_nonPrintableBytesBecomeDot() {
        let bytes: [UInt8] = [0x00, 0x41, 0x7f, 0x20]
        let row = HexFormatter.row(bytes: bytes, offset: 0, bytesPerRow: 4)

        XCTAssertEqual(row, "00000000  00 41 7f 20  .A. ")
    }

    func testHexFormatter_row_customBytesPerRow() {
        let bytes: [UInt8] = [0x41, 0x42, 0x43, 0x44]
        let row = HexFormatter.row(bytes: bytes, offset: 0, bytesPerRow: 8)

        let expectedHex = "41 42 43 44" + String(repeating: "   ", count: 4)
        let expectedAscii = "ABCD" + String(repeating: " ", count: 4)
        XCTAssertEqual(row, "00000000  \(expectedHex)  \(expectedAscii)")
    }

    // MARK: - ChunkSearcher.firstIndex

    func testChunkSearcher_firstIndex_basicHit() {
        let haystack = Array("hello world".utf8)
        let needle = Array("world".utf8)
        XCTAssertEqual(ChunkSearcher.firstIndex(of: needle, in: haystack), 6)
    }

    func testChunkSearcher_firstIndex_miss() {
        let haystack = Array("hello world".utf8)
        let needle = Array("xyz".utf8)
        XCTAssertNil(ChunkSearcher.firstIndex(of: needle, in: haystack))
    }

    func testChunkSearcher_firstIndex_fromOffset() {
        let haystack = Array("ababab".utf8)
        let needle = Array("ab".utf8)
        XCTAssertEqual(ChunkSearcher.firstIndex(of: needle, in: haystack, from: 1), 2)
    }

    func testChunkSearcher_firstIndex_emptyNeedleReturnsFrom() {
        let haystack = Array("hello".utf8)
        XCTAssertEqual(ChunkSearcher.firstIndex(of: [], in: haystack, from: 3), 3)
    }

    func testChunkSearcher_firstIndex_needleLongerThanHaystackIsNil() {
        let haystack = Array("ab".utf8)
        let needle = Array("abcdef".utf8)
        XCTAssertNil(ChunkSearcher.firstIndex(of: needle, in: haystack))
    }

    // MARK: - ChunkSearcher.search (streamed over FileSlice)

    func testChunkSearcher_search_findsMatchAcrossChunkBoundary() throws {
        var content = [UInt8](repeating: UInt8(ascii: "x"), count: 20)
        content[7] = UInt8(ascii: "A")
        content[8] = UInt8(ascii: "B")
        content[9] = UInt8(ascii: "C")

        let path = makeTempFile(bytes: content)
        let slice = try XCTUnwrap(FileSlice(path: path))

        let result = ChunkSearcher.search(Array("ABC".utf8), in: slice, from: 0, chunkSize: 8)
        XCTAssertEqual(result, 7)
    }

    func testChunkSearcher_search_miss() throws {
        var content = [UInt8](repeating: UInt8(ascii: "x"), count: 20)
        content[7] = UInt8(ascii: "A")
        content[8] = UInt8(ascii: "B")
        content[9] = UInt8(ascii: "C")

        let path = makeTempFile(bytes: content)
        let slice = try XCTUnwrap(FileSlice(path: path))

        let result = ChunkSearcher.search(Array("ZZZ".utf8), in: slice, from: 0, chunkSize: 8)
        XCTAssertNil(result)
    }

    func testChunkSearcher_search_fromOffsetPastEarlierMatchFindsLater() throws {
        var content = [UInt8](repeating: UInt8(ascii: "x"), count: 15)
        content[2] = UInt8(ascii: "A")
        content[3] = UInt8(ascii: "B")
        content[10] = UInt8(ascii: "A")
        content[11] = UInt8(ascii: "B")

        let path = makeTempFile(bytes: content)
        let slice = try XCTUnwrap(FileSlice(path: path))

        let result = ChunkSearcher.search(Array("AB".utf8), in: slice, from: 5)
        XCTAssertEqual(result, 10)
    }

    func testChunkSearcher_search_emptyNeedleReturnsFrom() throws {
        let path = makeTempFile(bytes: Array("hello world".utf8))
        let slice = try XCTUnwrap(FileSlice(path: path))

        XCTAssertEqual(ChunkSearcher.search([], in: slice, from: 3), 3)
    }

    // MARK: - ChunkSearcher case-insensitive + backward (F-113)

    func testChunkSearcher_firstIndex_caseInsensitive() {
        let hay = Array("Hello WORLD".utf8)
        XCTAssertNil(ChunkSearcher.firstIndex(of: Array("world".utf8), in: hay))
        XCTAssertEqual(ChunkSearcher.firstIndex(of: Array("world".utf8), in: hay, caseInsensitive: true), 6)
        XCTAssertEqual(ChunkSearcher.firstIndex(of: Array("hello".utf8), in: hay, caseInsensitive: true), 0)
    }

    func testChunkSearcher_lastIndex_backward() {
        let hay = Array("ab_ab_ab".utf8)   // matches at 0, 3, 6
        XCTAssertEqual(ChunkSearcher.lastIndex(of: Array("ab".utf8), in: hay), 6)
        XCTAssertEqual(ChunkSearcher.lastIndex(of: Array("ab".utf8), in: hay, upTo: 6), 3)
        XCTAssertEqual(ChunkSearcher.lastIndex(of: Array("AB".utf8), in: hay, caseInsensitive: true), 6)
        XCTAssertNil(ChunkSearcher.lastIndex(of: Array("zz".utf8), in: hay))
    }

    func testChunkSearcher_search_caseInsensitiveOverSlice() throws {
        let path = makeTempFile(bytes: Array("xxxxHELLOxxxx".utf8))
        let slice = try XCTUnwrap(FileSlice(path: path))
        XCTAssertNil(ChunkSearcher.search(Array("hello".utf8), in: slice, from: 0, chunkSize: 8))
        XCTAssertEqual(ChunkSearcher.search(Array("hello".utf8), in: slice, from: 0, chunkSize: 8,
                                            caseInsensitive: true), 4)
    }

    func testChunkSearcher_searchBackward_findsLastMatchBeforeCursor() throws {
        // "AB" at offsets 2 and 10.
        var content = [UInt8](repeating: UInt8(ascii: "x"), count: 15)
        content[2] = UInt8(ascii: "A"); content[3] = UInt8(ascii: "B")
        content[10] = UInt8(ascii: "A"); content[11] = UInt8(ascii: "B")
        let path = makeTempFile(bytes: content)
        let slice = try XCTUnwrap(FileSlice(path: path))

        // From the end: last match is at 10.
        XCTAssertEqual(ChunkSearcher.searchBackward(Array("AB".utf8), in: slice, chunkSize: 4), 10)
        // Before offset 10: the earlier match at 2. (Exercises chunk overlap.)
        XCTAssertEqual(ChunkSearcher.searchBackward(Array("AB".utf8), in: slice, before: 10, chunkSize: 4), 2)
        XCTAssertNil(ChunkSearcher.searchBackward(Array("AB".utf8), in: slice, before: 2, chunkSize: 4))
    }

    func testChunkSearcher_search_smallChunkSizeStillFindsMatchAtStart() throws {
        let content = Array("needle-at-start-then-lots-of-padding-bytes-follow".utf8)
        let path = makeTempFile(bytes: content)
        let slice = try XCTUnwrap(FileSlice(path: path))

        let result = ChunkSearcher.search(Array("needle".utf8), in: slice, from: 0, chunkSize: 8)
        XCTAssertEqual(result, 0)
    }
}
