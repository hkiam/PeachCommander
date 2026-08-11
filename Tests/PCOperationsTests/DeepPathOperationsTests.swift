// SPDX-License-Identifier: Apache-2.0
// DeepPathOperationsTests.swift - Copy, move and delete past PATH_MAX (F-383).
//
// The VFS layer could already list and open such files; these are the engines, which do their own
// path calls and so had to be routed separately. What is under test is the whole operation, not the
// helper: an engine that resolved one call through a descriptor and left the next one path-based would
// pass a unit test of the helper and still fail here.
//
// Copying is where the interesting cases are, because both ends can be deep independently — clonefile
// and rename each take two paths, so "source deep, target shallow" and the reverse are separate risks.

import XCTest
@testable import PCOperations
import PCFoundation

final class DeepPathOperationsTests: XCTestCase {
    private var root: URL!
    private var deep: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PCOps-Deep-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        deep = try buildDeepTree(under: root, segments: 40, segmentLength: 60)
        XCTAssertGreaterThan(deep.utf8.count, Int(PATH_MAX), "the fixture is not deep enough")
    }

    override func tearDownWithError() throws {
        if let root {
            let parent = (root.path as NSString).deletingLastPathComponent
            let fd = DeepPath.openDirectory(parent)
            if fd >= 0 {
                _ = DeepPath.removeRecursively((root.path as NSString).lastPathComponent, in: fd)
                close(fd)
            }
        }
        root = nil
        deep = nil
        try super.tearDownWithError()
    }

    private func buildDeepTree(under base: URL, segments: Int, segmentLength: Int) throws -> String {
        let name = String(repeating: "d", count: segmentLength)
        let fm = FileManager.default
        let previous = fm.currentDirectoryPath
        defer { fm.changeCurrentDirectoryPath(previous) }
        guard fm.changeCurrentDirectoryPath(base.path) else { throw XCTSkip("cannot enter fixture root") }
        var path = base.path
        for _ in 0..<segments {
            guard mkdir(name, 0o755) == 0 || errno == EEXIST else { throw XCTSkip("mkdir failed") }
            guard fm.changeCurrentDirectoryPath(name) else { throw XCTSkip("cannot descend") }
            path += "/" + name
        }
        return path
    }

    @discardableResult
    private func write(_ contents: String, to path: String) throws -> String {
        let fd = DeepPath.open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        try XCTSkipUnless(fd >= 0, "could not create \(path)")
        defer { close(fd) }
        _ = contents.withCString { Darwin.write(fd, $0, strlen($0)) }
        return path
    }

    private func read(_ path: String) -> String? {
        let fd = DeepPath.open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let n = Darwin.read(fd, &buffer, buffer.count)
        guard n >= 0 else { return nil }
        return String(bytes: buffer[0..<n], encoding: .utf8)
    }

    private func copyEngine() -> CopyEngine {
        CopyEngine(options: CopyOptions(), control: OperationControl(),
                   resolver: SkipAllResolver(), progress: { _ in })
    }

    private func deleteEngine() -> DeleteEngine {
        DeleteEngine(control: OperationControl(), progress: { _ in })
    }

    // MARK: - Copy

    func testCopyingOutOfADeepDirectory() async throws {
        let source = try write("carried out", to: deep + "/source.txt")
        let target = root.appendingPathComponent("out.txt").path

        _ = try await copyEngine().run(items: [source],
                                   toDirectory: (target as NSString).deletingLastPathComponent)

        XCTAssertEqual(read(root.appendingPathComponent("source.txt").path), "carried out")
    }

    func testCopyingIntoADeepDirectory() async throws {
        let source = root.appendingPathComponent("in.txt").path
        try write("carried in", to: source)

        _ = try await copyEngine().run(items: [source], toDirectory: deep)

        XCTAssertEqual(read(deep + "/in.txt"), "carried in")
    }

    /// Both ends deep, which is also the case that exercises `clonefileat` with two walked
    /// descriptors — the same-volume fast path is on by default and this is a same-volume copy.
    func testCopyingWithinTheDeepDirectory() async throws {
        let source = try write("cloned", to: deep + "/clone-me.txt")
        let intoDir = deep + "/sub"
        XCTAssertEqual(DeepPath.mkdir(intoDir, 0o755), 0)

        _ = try await copyEngine().run(items: [source], toDirectory: intoDir)

        XCTAssertEqual(read(intoDir + "/clone-me.txt"), "cloned")
    }

    func testCopyingAWholeDirectoryTreeOutOfDepth() async throws {
        let branch = deep + "/branch"
        XCTAssertEqual(DeepPath.mkdir(branch, 0o755), 0)
        try write("a", to: branch + "/a.txt")
        try write("b", to: branch + "/b.txt")

        _ = try await copyEngine().run(items: [branch], toDirectory: root.path)

        XCTAssertEqual(read(root.appendingPathComponent("branch/a.txt").path), "a")
        XCTAssertEqual(read(root.appendingPathComponent("branch/b.txt").path), "b")
    }

    // MARK: - Move

    func testMovingOutOfADeepDirectory() async throws {
        let source = try write("moved", to: deep + "/move-me.txt")

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { _ in })
        _ = try await engine.run(items: [source], toDirectory: root.path)

        XCTAssertEqual(read(root.appendingPathComponent("move-me.txt").path), "moved")
        XCTAssertFalse(DeepPath.exists(source), "the source should be gone after a move")
    }

    // MARK: - Delete

    func testDeletingPermanentlyAtDepth() async throws {
        let doomed = try write("x", to: deep + "/doomed.txt")

        _ = try await deleteEngine().permanentDelete(items: [doomed])

        XCTAssertFalse(DeepPath.exists(doomed))
    }

    func testDeletingANonEmptyTreeAtDepth() async throws {
        let branch = deep + "/tree"
        XCTAssertEqual(DeepPath.mkdir(branch, 0o755), 0)
        try write("leaf", to: branch + "/leaf.txt")

        _ = try await deleteEngine().permanentDelete(items: [branch])

        XCTAssertFalse(DeepPath.exists(branch))
    }

    // MARK: - The shallow path is untouched

    func testAnOrdinaryCopyStillWorks() async throws {
        let source = root.appendingPathComponent("plain.txt").path
        try write("plain", to: source)
        let into = root.appendingPathComponent("into", isDirectory: true)
        try FileManager.default.createDirectory(at: into, withIntermediateDirectories: true)

        _ = try await copyEngine().run(items: [source], toDirectory: into.path)

        XCTAssertEqual(read(into.appendingPathComponent("plain.txt").path), "plain")
    }
}
