// SPDX-License-Identifier: Apache-2.0
// FileHeadLineTests.swift - The first line, and nothing behind it.
//
// This exists because a comment in `SyncStateStore.records()` claimed the header alone was read
// while the code read the whole file — the shape of defect that is invisible in review and costs
// nothing until the file is a two-hundred-thousand-path record and the window lists a hundred of
// them.

import XCTest
import PCFoundation

final class FileHeadLineTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-headline-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func write(_ data: Data, _ name: String = "f.jsonl") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// The claim the whole helper exists for: the answer does not depend on how much follows it.
    ///
    /// Twelve megabytes of tail, and a cap of four kilobytes. If the implementation read the file
    /// whole this would still return the right line — reading too much is not *wrong*, only
    /// expensive — so the assertion that carries the weight is the second one: a first line beyond
    /// the cap is refused, which is only possible if the read stops there.
    func test_theFirstLineIsFoundWhateverFollowsIt() throws {
        var bytes = Data(#"{"version":1,"leftRoot":"/a"}"#.utf8)
        bytes.append(UInt8(ascii: "\n"))
        bytes.append(Data(repeating: UInt8(ascii: "x"), count: 12 * 1024 * 1024))
        let url = try write(bytes)

        let line = FileHeadLine.read(at: url, maxBytes: 4096)
        XCTAssertEqual(line.flatMap { String(data: $0, encoding: .utf8) },
                       #"{"version":1,"leftRoot":"/a"}"#)
    }

    /// A first line longer than the cap is nil, not a truncated line. Half a JSON object decodes as
    /// nothing anyway, and a caller handed a shortened line could not tell it from a broken one.
    func test_aFirstLineBeyondTheCapIsRefusedRatherThanCutShort() throws {
        var bytes = Data(repeating: UInt8(ascii: "y"), count: 5000)
        bytes.append(UInt8(ascii: "\n"))
        bytes.append(Data("second".utf8))
        let url = try write(bytes)

        XCTAssertNil(FileHeadLine.read(at: url, maxBytes: 4096),
                     "a line past the cap came back anyway, so the read did not stop at the cap")
        // …and with room for it, the same file answers.
        XCTAssertEqual(FileHeadLine.read(at: url, maxBytes: 8192)?.count, 5000)
    }

    /// A file with no newline is its own first line, provided it fits. That is the hand-written
    /// case; every writer in this project terminates its header.
    func test_aFileWithNoNewlineIsItsOwnFirstLine() throws {
        let url = try write(Data("only this".utf8))
        XCTAssertEqual(FileHeadLine.read(at: url).flatMap { String(data: $0, encoding: .utf8) },
                       "only this")
    }

    /// Nothing to answer with: no file, an empty file, and a file that begins with the newline.
    func test_theEmptyCasesAnswerNil() throws {
        XCTAssertNil(FileHeadLine.read(at: dir.appendingPathComponent("absent.jsonl")))
        XCTAssertNil(FileHeadLine.read(at: try write(Data())))
        XCTAssertNil(FileHeadLine.read(at: try write(Data("\nsecond".utf8), "leading.jsonl")))
    }

    /// The line comes back without its newline, so a decoder does not have to strip one. Exercised
    /// across the chunk boundary, which is where an accumulating reader goes wrong if it goes wrong:
    /// the helper reads in 4096-byte chunks.
    func test_theNewlineIsNotPartOfTheAnswer() throws {
        for length in [1, 4095, 4096, 4097, 8191, 8192] {
            var bytes = Data(repeating: UInt8(ascii: "a"), count: length)
            bytes.append(UInt8(ascii: "\n"))
            bytes.append(Data(repeating: UInt8(ascii: "b"), count: 100))
            let url = try write(bytes, "len\(length).jsonl")
            XCTAssertEqual(FileHeadLine.read(at: url, maxBytes: 65536)?.count, length,
                           "wrong length at \(length)")
        }
    }
}
