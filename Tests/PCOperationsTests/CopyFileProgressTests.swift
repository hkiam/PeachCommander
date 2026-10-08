// SPDX-License-Identifier: Apache-2.0
// CopyFileProgressTests.swift - The second bar: how far the file being copied is (SPEC-004 §4).
//
// Over a few large files the total barely moves, and the progress window had only the total — the
// spec asked for a bar per file from the start and the help page described one. These pin what that
// bar is fed: bytes of the current file that rise to its size, and start again with the next one.

import XCTest
@testable import PCOperations
import PCFoundation

private struct OverwriteResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Every report the copy makes, in order.
private final class Reports: @unchecked Sendable {
    private let lock = NSLock()
    private var all: [OpProgress] = []
    func sink() -> @Sendable (OpProgress) -> Void { { [self] p in lock.lock(); all.append(p); lock.unlock() } }
    var snapshot: [OpProgress] { lock.lock(); defer { lock.unlock() }; return all }
}

final class CopyFileProgressTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-cpfileprog-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        for d in [src!, dst!] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func file(_ name: String, bytes: Int) throws -> URL {
        let url = src.appendingPathComponent(name)
        try Data(repeating: 0x5A, count: bytes).write(to: url)
        return url
    }

    private func copy(_ files: [URL], clone: Bool) async throws -> [OpProgress] {
        var o = CopyOptions()
        o.useCloneWhenPossible = clone
        o.chunkSize = 4096          // several chunks per file, so the bar has steps to take
        let reports = Reports()
        let engine = CopyEngine(options: o, control: OperationControl(),
                                resolver: OverwriteResolver(), progress: reports.sink())
        _ = try await engine.run(items: files.map(\.path), toDirectory: dst.path)
        return reports.snapshot
    }

    /// The bar for one file climbs chunk by chunk to the file's size — never past it, never back.
    func testTheFileBarRisesToTheFileSize() async throws {
        let big = try file("big.bin", bytes: 40_000)
        let reports = try await copy([big], clone: false).filter { $0.currentFileBytesTotal > 0 }

        XCTAssertGreaterThan(reports.count, 2, "a streamed file reports per chunk")
        XCTAssertTrue(reports.allSatisfy { $0.currentFileBytesTotal == 40_000 })
        let done = reports.map(\.currentFileBytesDone)
        XCTAssertEqual(done, done.sorted(), "the file bar never runs backwards")
        XCTAssertEqual(done.last, 40_000)
        XCTAssertEqual(reports.last?.currentFileFraction, 1)
    }

    /// The next file starts its own bar: its total, and done counted from zero again.
    func testTheNextFileStartsItsBarAgain() async throws {
        let first = try file("a.bin", bytes: 20_000)
        let second = try file("b.bin", bytes: 12_000)
        let reports = try await copy([first, second], clone: false).filter { $0.currentFileBytesTotal > 0 }

        let ofSecond = reports.filter { $0.currentFileBytesTotal == 12_000 }
        XCTAssertFalse(ofSecond.isEmpty)
        XCTAssertLessThan(ofSecond.first?.currentFileBytesDone ?? .max, 12_000,
                          "the second file's bar starts below full, not where the first one ended")
        XCTAssertEqual(ofSecond.last?.currentFileBytesDone, 12_000)
        // The total still runs over both files — the second bar does not replace the first.
        XCTAssertEqual(reports.last?.bytesDone, 32_000)
    }

    /// A clone reads nothing, so there are no steps — but the file is copied, and the bar says full.
    func testAClonedFileShowsAsFull() async throws {
        let big = try file("big.bin", bytes: 40_000)
        let last = try await copy([big], clone: true).last { $0.currentFileBytesTotal > 0 }
        XCTAssertEqual(last?.currentFileFraction, 1)
    }

    /// Nothing to measure is nil, not zero: the dialog keeps the file bar hidden for a delete.
    func testNoFileMeansNoFraction() {
        XCTAssertNil(OpProgress(filesTotal: 3, filesDone: 1).currentFileFraction)
    }
}
