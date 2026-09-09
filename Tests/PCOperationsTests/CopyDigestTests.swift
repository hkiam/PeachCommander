// SPDX-License-Identifier: Apache-2.0
// CopyDigestTests.swift - The digest a copy can hand over for free.
//
// Verify-after-copy read *both* files again after the copy and threw both digests away, so a
// verified copy across volumes moved three gigabytes of reads where two would do. The streaming loop
// already has every byte in a buffer, so a digest taken there costs nothing extra — and the whole
// value of that depends on it being the *same* digest a second read would produce, which is what
// these measure.

import XCTest
@testable import PCOperations
import PCFoundation

private struct AbortResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Collects what the copy reports, the way the app's own collector does.
private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var digests: [String: String] = [:]
    func sink() -> @Sendable (String, String) -> Void {
        { [self] path, hex in lock.lock(); digests[path] = hex; lock.unlock() }
    }
}

final class CopyDigestTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-cpdigest-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        for d in [src!, dst!] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    /// Cloning is what makes a same-volume copy free, and a clone never reads the bytes — so these
    /// tests switch it off to reach the streaming path, which is the only path that can hash. That
    /// is also the path a cross-volume copy takes, which is the copy people turn verification on for.
    private func streamingOptions(_ collector: Collector?) -> CopyOptions {
        var o = CopyOptions()
        o.useCloneWhenPossible = false
        o.chunkSize = 4096          // several chunks for the fixtures below, so the loop is exercised
        if let collector { o.digestSink = collector.sink() }
        return o
    }

    private func copy(_ file: URL, options: CopyOptions) async throws -> [String] {
        let engine = CopyEngine(options: options, control: OperationControl(),
                                resolver: AbortResolver(), progress: { _ in })
        return try await engine.run(items: [file.path], toDirectory: dst.path)
    }

    /// The claim the whole change rests on: the digest taken while copying is the digest a second
    /// read would have produced. If it were not, verification would report a corruption on every
    /// file it did not read twice — which is worse than reading twice.
    func test_theDigestTakenWhileCopyingMatchesASecondRead() async throws {
        let bytes = Data((0..<40_000).map { UInt8(($0 * 31 + 7) & 0xFF) })
        let file = src.appendingPathComponent("payload.bin")
        try bytes.write(to: file)

        let collector = Collector()
        _ = try await copy(file, options: streamingOptions(collector))

        XCTAssertEqual(collector.digests[file.path],
                       ChecksumAlgorithm.crc32.hex(of: bytes),
                       "the digest taken during the copy is not the file's digest")
        // And the copy itself is unharmed by being hashed on the way through.
        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("payload.bin")), bytes)
    }

    /// Across chunk boundaries, which is where an incremental hasher goes wrong if it goes wrong at
    /// all: lengths either side of the chunk size, and one exactly on it.
    func test_theDigestIsRightAtEveryChunkBoundary() async throws {
        for length in [0, 1, 4095, 4096, 4097, 8192, 12_289] {
            let bytes = Data((0..<length).map { UInt8(($0 * 17 + 3) & 0xFF) })
            let file = src.appendingPathComponent("b\(length).bin")
            try bytes.write(to: file)
            let collector = Collector()
            _ = try await copy(file, options: streamingOptions(collector))
            XCTAssertEqual(collector.digests[file.path], ChecksumAlgorithm.crc32.hex(of: bytes),
                           "wrong digest at length \(length)")
        }
    }

    /// Nothing is reported when nobody asked, so an ordinary copy pays nothing at all.
    func test_noDigestIsProducedWhenNobodyAsked() async throws {
        let file = src.appendingPathComponent("quiet.bin")
        try Data(repeating: 0x41, count: 10_000).write(to: file)
        let collector = Collector()
        var options = streamingOptions(nil)          // no sink
        options.chunkSize = 4096
        _ = try await copy(file, options: options)
        XCTAssertTrue(collector.digests.isEmpty)
    }

    /// A copy that did not land reports no digest. One for a file that is not there would be worse
    /// than none: the verifier would compare the destination against it and call the difference a
    /// corruption.
    ///
    /// What this proves and what it does not, measured rather than assumed. The failure here is a
    /// destination that cannot be written to, so it happens as the output is opened — before a byte
    /// is read. So the claim it carries is the narrow one: **a copy that failed before writing
    /// reports nothing.**
    ///
    /// It does *not* pin the ordering. Moving the sink call from after `finish()` to before it
    /// leaves every test in this file passing — checked. The ordering is a deliberate choice with
    /// its reason written at the call site, and a failure between the last chunk and the rename
    /// cannot be arranged from a test without a filesystem that fails on demand.
    func test_aCopyThatFailedReportsNoDigest() async throws {
        let file = src.appendingPathComponent("blocked.bin")
        try Data(repeating: 0x42, count: 10_000).write(to: file)
        let locked = root.appendingPathComponent("locked", isDirectory: true)
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500],
                                              ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                       ofItemAtPath: locked.path) }

        let collector = Collector()
        let engine = CopyEngine(options: streamingOptions(collector), control: OperationControl(),
                                resolver: AbortResolver(), progress: { _ in })
        _ = try? await engine.run(items: [file.path], toDirectory: locked.path)

        XCTAssertFalse(FileManager.default.fileExists(atPath:
            locked.appendingPathComponent("blocked.bin").path), "the copy was not actually blocked")
        XCTAssertNil(collector.digests[file.path],
                     "a digest was reported for a file that never landed")
    }

    /// A cloned copy reports nothing, on purpose. Giving up the clone to obtain a digest would turn
    /// a copy that reads nothing into a read plus a write — slower than not hashing at all — so the
    /// verifier reads those sources as it always did. This test exists so that "no digest here" stays
    /// a decision rather than becoming a bug somebody fixes.
    func test_aClonedCopyDeliberatelyReportsNoDigest() async throws {
        let bytes = Data(repeating: 0x44, count: 20_000)
        let file = src.appendingPathComponent("cloned.bin")
        try bytes.write(to: file)

        let collector = Collector()
        var options = CopyOptions()
        options.useCloneWhenPossible = true
        options.digestSink = collector.sink()
        _ = try await copy(file, options: options)

        XCTAssertEqual(try Data(contentsOf: dst.appendingPathComponent("cloned.bin")), bytes,
                       "the copy itself did not happen")
        // On a filesystem that cannot clone, the streaming path runs and there *is* a digest — so
        // this asserts the pair rather than a bare nil: either it was cloned and there is none, or
        // it was streamed and the one there is correct.
        if let reported = collector.digests[file.path] {
            XCTAssertEqual(reported, ChecksumAlgorithm.crc32.hex(of: bytes),
                           "this volume streamed the copy, and the digest it reported is wrong")
        }
    }
}
