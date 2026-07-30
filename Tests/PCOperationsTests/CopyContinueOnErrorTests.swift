import XCTest
@testable import PCOperations
import PCFoundation

/// A resolver that skips every per-file error and records what it skipped — the
/// engine-facing half of the "continue on error" + error log feature (F-089).
private final class RecordingSkipResolver: OperationResolver, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var skipped: [String] = []
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision {
        lock.lock(); skipped.append(path); lock.unlock()
        return .skip
    }
}

final class CopyContinueOnErrorTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-coe-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testFailingItemIsSkippedAndOthersContinue() async throws {
        let a = src.appendingPathComponent("a.txt")
        let c = src.appendingPathComponent("c.txt")
        try "A".data(using: .utf8)!.write(to: a)
        try "C".data(using: .utf8)!.write(to: c)
        let missing = src.appendingPathComponent("gone.txt").path   // never created → sourceNotFound

        let resolver = RecordingSkipResolver()
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: resolver, progress: { _ in })
        let processed = try await engine.run(items: [a.path, missing, c.path], toDirectory: dst.path)

        // The two good files copied; the missing one was skipped, not aborting the run.
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("a.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("c.txt").path))
        XCTAssertEqual(Set(processed), Set([a.path, c.path]))
        XCTAssertEqual(resolver.skipped, [missing])
    }
}
