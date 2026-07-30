import XCTest
@testable import PCOperations
import PCFoundation

/// A resolver that always answers a target-exists conflict with `.append` (F-086).
private struct AppendResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .append }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

final class CopyAppendTests: XCTestCase {
    private var root: URL!, src: URL!, dst: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-append-\(UUID().uuidString)")
        src = root.appendingPathComponent("src"); dst = root.appendingPathComponent("dst")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func testAppendConcatenatesSourceOntoTarget() async throws {
        let srcFile = src.appendingPathComponent("log.txt")
        let dstFile = dst.appendingPathComponent("log.txt")
        try "AAA".data(using: .utf8)!.write(to: srcFile)
        try "BBB".data(using: .utf8)!.write(to: dstFile)   // pre-existing target

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AppendResolver(), progress: { _ in })
        _ = try await engine.run(items: [srcFile.path], toDirectory: dst.path)

        // Target keeps its bytes, with the source appended onto the end.
        XCTAssertEqual(try String(contentsOf: dstFile), "BBBAAA")
        // Source is untouched (this was a copy, not a move).
        XCTAssertEqual(try String(contentsOf: srcFile), "AAA")
    }

    func testAppendCreatesTargetWhenMissing() async throws {
        // If the "existing" target was removed before writing, append still creates it.
        let srcFile = src.appendingPathComponent("new.txt")
        try "hello".data(using: .utf8)!.write(to: srcFile)
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AppendResolver(), progress: { _ in })
        _ = try await engine.run(items: [srcFile.path], toDirectory: dst.path)
        // No conflict → normal copy path (resolver never consulted).
        XCTAssertEqual(try String(contentsOf: dst.appendingPathComponent("new.txt")), "hello")
    }
}
