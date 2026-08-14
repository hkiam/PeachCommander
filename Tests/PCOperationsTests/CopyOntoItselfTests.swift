// SPDX-License-Identifier: Apache-2.0
// CopyOntoItselfTests.swift - Copying a file to where it already is must not destroy it (F-080, F-399).
//
// Reachable from the UI without trying: F5 prompts for a target and offers the other panel's
// directory, and both panels showing the same folder is an ordinary thing to be doing. The target
// then equals the source — and the engine's overwrite path removes the target before it reads the
// source, which is the wrong order when they are the same file.

import XCTest
@testable import PCOperations
import PCFoundation

/// Answers "overwrite" to everything, which is what a user pressing the default button does.
private final class OverwritingResolver: OperationResolver, @unchecked Sendable {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

final class CopyOntoItselfTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("pc-onto-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    func test_copyingAFileIntoItsOwnDirectoryLeavesItIntact() async throws {
        let file = root.appendingPathComponent("keep.txt")
        try "the only copy".data(using: .utf8)!.write(to: file)

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: OverwritingResolver(), progress: { _ in })
        // No new name, no mask: the target directory *is* the source's directory.
        _ = try? await engine.run(items: [file.path], toDirectory: root.path)

        // Whatever the engine decides to do about it, the file must still be there with its content.
        // Anything else is data loss from an operation the user would describe as "nothing happened".
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path),
                      "the source file was destroyed by copying it onto itself")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "the only copy")
    }

    func test_copyingADirectoryIntoItselfLeavesItsContentsIntact() async throws {
        // The same fault once per file, and the folder is the thing people drag around. The engine
        // merges into an existing directory, so a target equal to the source used to walk the
        // children and copy each onto itself.
        let dir = root.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let inner = dir.appendingPathComponent("inner.txt")
        try "inside".data(using: .utf8)!.write(to: inner)

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: OverwritingResolver(), progress: { _ in })
        _ = try? await engine.run(items: [dir.path], toDirectory: root.path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: inner.path),
                      "the folder's contents were destroyed by copying it onto itself")
        XCTAssertEqual(try String(contentsOf: inner, encoding: .utf8), "inside")
    }

    func test_aCopyToARealTargetStillWorks() async throws {
        // The guard must refuse one thing and nothing else: a same-named file in a *different*
        // directory is the ordinary case and has to keep copying.
        let file = root.appendingPathComponent("a.txt")
        try "content".data(using: .utf8)!.write(to: file)
        let dst = root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: OverwritingResolver(), progress: { _ in })
        _ = try await engine.run(items: [file.path], toDirectory: dst.path)

        XCTAssertEqual(try String(contentsOf: dst.appendingPathComponent("a.txt"), encoding: .utf8),
                       "content")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "the source went missing")
    }

    func test_insideIsAboutPathBoundariesNotPrefixes() {
        // `/a/bc` is not inside `/a/b`, however much it looks like it. Getting this wrong the eager
        // way refuses honest copies; the lax way is what destroys a folder.
        XCTAssertTrue(CopyEngine.isInside("/a/b/c.txt", "/a/b"))
        XCTAssertTrue(CopyEngine.isInside("/a/b/deep/c.txt", "/a/b/"))
        XCTAssertFalse(CopyEngine.isInside("/a/bc/c.txt", "/a/b"))
        XCTAssertFalse(CopyEngine.isInside("/a/b", "/a/b"))          // the directory itself, not inside it
        XCTAssertTrue(CopyEngine.isInside("/a/B/c.txt", "/a/b"))     // the volume is case-insensitive
    }
}
