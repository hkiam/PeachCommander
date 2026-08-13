// SPDX-License-Identifier: Apache-2.0
// ChunkRegexSearcherTests.swift - Regex search over a file read in overlapping windows (F-151).
//
// The interesting cases are all at the seams, so the tests use a tiny `chunkSize` to put a boundary
// exactly where it hurts: a match that straddles two windows, a multi-byte character split across
// one, and a match longer than the overlap — which is the documented limit, pinned here so that
// changing it is a decision rather than a surprise.

import XCTest
@testable import PCVFS

final class ChunkRegexSearcherTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunkregex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
    }

    private func slice(_ contents: String) throws -> FileSlice {
        let url = dir.appendingPathComponent("f-\(UUID().uuidString).txt")
        try Data(contents.utf8).write(to: url)
        return try XCTUnwrap(FileSlice(path: url.path))
    }

    private func regex(_ pattern: String, caseInsensitive: Bool = false) throws -> NSRegularExpression {
        let made = ChunkRegexSearcher.compile(pattern, caseInsensitive: caseInsensitive)
        XCTAssertNil(made.error, "pattern did not compile: \(made.error ?? "")")
        return try XCTUnwrap(made.regex)
    }

    // MARK: - Compiling

    func test_aBadPatternIsReportedRatherThanSilentlyFindingNothing() {
        let made = ChunkRegexSearcher.compile("([unclosed", caseInsensitive: false)
        XCTAssertNil(made.regex)
        XCTAssertNotNil(made.error, "a malformed pattern must say so — otherwise it reads as 'not found'")
    }

    // MARK: - Finding

    func test_findsAMatchAndReportsItsByteOffset() throws {
        let s = try slice("alpha beta gamma")
        let offset = ChunkRegexSearcher.search(try regex("b[et]+a"), in: s)
        XCTAssertEqual(offset, 6)
    }

    func test_offsetsAreBytesNotCharacters() throws {
        // "Größe" is 6 bytes in UTF-8, not 5. Assuming one byte per character puts the viewer's
        // cursor in the wrong place in every file with an umlaut in it.
        let s = try slice("Größe: 12\nname: x")
        let offset = ChunkRegexSearcher.search(try regex("name"), in: s)
        XCTAssertEqual(offset, Int64("Größe: 12\n".utf8.count))
    }

    func test_searchStartsWhereItIsToldTo() throws {
        let s = try slice("needle ... needle")
        let first = try XCTUnwrap(ChunkRegexSearcher.search(try regex("needle"), in: s))
        let second = ChunkRegexSearcher.search(try regex("needle"), in: s, from: first + 1)
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 11)
    }

    func test_caseInsensitivityIsHonoured() throws {
        let s = try slice("Hello World")
        XCTAssertNil(ChunkRegexSearcher.search(try regex("hello"), in: s))
        XCTAssertEqual(ChunkRegexSearcher.search(try regex("hello", caseInsensitive: true), in: s), 0)
    }

    func test_nothingToFindAnswersNil() throws {
        let s = try slice("abc")
        XCTAssertNil(ChunkRegexSearcher.search(try regex("zzz"), in: s))
    }

    // MARK: - The seams

    func test_aMatchStraddlingAWindowBoundaryIsStillFound() throws {
        // 100 bytes of filler, then the match — with 64-byte windows it begins in one and ends in
        // the next. This is the case the overlap exists for, and the one a naive chunked search
        // gets wrong while looking perfectly healthy on small files.
        let s = try slice(String(repeating: "x", count: 100) + "FINDME" + String(repeating: "y", count: 100))
        let offset = ChunkRegexSearcher.search(try regex("FINDME"), in: s,
                                               chunkSize: 64, maxMatchLength: 16)
        XCTAssertEqual(offset, 100)
    }

    func test_aMultiByteCharacterSplitByAWindowIsNotCorrupted() throws {
        // Each "ä" is two bytes. With a window that lands mid-character, a decoder that does not
        // step over the continuation byte produces replacement characters — and every offset after
        // it shifts, which is worse than not matching at all.
        let text = String(repeating: "ä", count: 60) + "TARGET"
        let s = try slice(text)
        let offset = ChunkRegexSearcher.search(try regex("TARGET"), in: s,
                                               chunkSize: 33, maxMatchLength: 8)
        XCTAssertEqual(offset, Int64(String(repeating: "ä", count: 60).utf8.count))
    }

    func test_aMatchLongerThanTheOverlapIsTheDocumentedLimit() throws {
        // Not a bug — a stated limit. The overlap is how long a straddling match may be, and a
        // pattern has no length to derive it from. Pinned so that raising the default is a
        // decision somebody makes on purpose.
        let filler = String(repeating: "x", count: 50)
        let long = String(repeating: "L", count: 40)
        let s = try slice(filler + long + filler)
        // Overlap 8: the 40-character match cannot survive a boundary…
        XCTAssertNil(ChunkRegexSearcher.search(try regex("L{40}"), in: s,
                                               chunkSize: 64, maxMatchLength: 8))
        // …and with an overlap at least as long as the match, it is found.
        XCTAssertEqual(ChunkRegexSearcher.search(try regex("L{40}"), in: s,
                                                 chunkSize: 64, maxMatchLength: 48), 50)
    }

    // MARK: - Backwards

    func test_backwardsFindsTheLastMatchBeforeAPoint() throws {
        let s = try slice("hit ... hit ... hit")
        let last = ChunkRegexSearcher.searchBackwards(try regex("hit"), in: s, before: 19)
        XCTAssertEqual(last, 16)
        let middle = ChunkRegexSearcher.searchBackwards(try regex("hit"), in: s, before: 16)
        XCTAssertEqual(middle, 8)
    }

    func test_backwardsFromTheStartHasNoAnswer() throws {
        let s = try slice("hit")
        XCTAssertNil(ChunkRegexSearcher.searchBackwards(try regex("hit"), in: s, before: 0))
    }

    // MARK: - Line anchors

    func test_caretMeansLineStart() throws {
        // grep's meaning, and what anyone typing `^ERROR` expects — not "start of the decoded
        // window", which in a large file is a place of no significance.
        let s = try slice("prelude\nERROR here\n")
        XCTAssertEqual(ChunkRegexSearcher.search(try regex("^ERROR"), in: s), 8)
        XCTAssertEqual(ChunkRegexSearcher.search(try regex("here$"), in: s), 14)
    }

    func test_aWindowStartingMidLineOffersNoFalseLineStart() throws {
        // The trap line anchors open: with windows every 64 bytes, one begins in the middle of the
        // filler line, and a naive `^` would match there and report a "line start" that is not one.
        // The only real match is on the last line.
        let text = String(repeating: "a", count: 200) + "\nREAL start\n"
        let s = try slice(text)
        let hit = ChunkRegexSearcher.search(try regex("^[aR]"), in: s, chunkSize: 64, maxMatchLength: 16)
        // Two honest answers exist: the very first line, at 0. Anything between 1 and 200 would be a
        // window edge masquerading as a line start.
        XCTAssertEqual(hit, 0)
    }

    func test_aLineStartAfterTheFirstWindowIsStillFound() throws {
        // The other side of that trim: dropping the partial first line must not drop a *real* line
        // start that lies further into the window.
        let text = String(repeating: "a", count: 200) + "\nTARGET line\n"
        let s = try slice(text)
        let hit = ChunkRegexSearcher.search(try regex("^TARGET"), in: s, chunkSize: 64, maxMatchLength: 16)
        XCTAssertEqual(hit, 201)
    }
}
