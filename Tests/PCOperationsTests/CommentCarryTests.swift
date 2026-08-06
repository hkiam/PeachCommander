// SPDX-License-Identifier: Apache-2.0
// CommentCarryTests.swift - A file's comment follows the file (F-372).
//
// Before this, nothing in the app carried a comment: renaming a file left it in `descript.ion` under the
// old name, and moving the file left it in the source directory. Both silently, which is the worst
// version — the comment is not reported as lost, it simply is not there any more.
//
// These tests go through the real engines and read the real `descript.ion` afterwards, because the
// interesting failure is not "does carry() work" but "does the engine call it, and with which name".

import XCTest
@testable import PCOperations
import PCFoundation
import PCVFS

final class CommentCarryTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pc-comment-carry-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helpers

    private func dir(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func file(_ name: String, in directory: URL, contents: String = "x") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// The comment recorded for `name` in `directory`, read back from the file on disk.
    private func comment(_ name: String, in directory: URL) -> String? {
        let path = directory.appendingPathComponent("descript.ion")
        guard let text = try? String(contentsOf: path, encoding: .utf8) else { return nil }
        return DescriptionFile(parsing: text).comment(for: name)
    }

    private func setComment(_ text: String, for name: String, in directory: URL) async throws {
        let fs = LocalFS()
        try await CommentStore.setComment(text, for: name,
                                         inDir: VFSPath(filesystemId: fs.scheme, path: directory.path),
                                         on: fs)
    }

    private func makeMove() -> MoveEngine {
        MoveEngine(options: CopyOptions(), control: OperationControl(),
                   resolver: SkipAllResolver(), progress: { _ in })
    }

    private func makeCopy() -> CopyEngine {
        CopyEngine(options: CopyOptions(), control: OperationControl(),
                   resolver: SkipAllResolver(), progress: { _ in })
    }

    // MARK: - Move

    func testMovingAFileTakesItsCommentToTheTargetDirectory() async throws {
        let from = try dir("from"), to = try dir("to")
        let file = try file("notes.txt", in: from)
        try await setComment("the important one", for: "notes.txt", in: from)

        _ = try await makeMove().run(items: [file.path], toDirectory: to.path)

        XCTAssertEqual(comment("notes.txt", in: to), "the important one")
        XCTAssertNil(comment("notes.txt", in: from), "the source must not keep the comment after a move")
    }

    func testTheSourceDescriptionFileIsRemovedWhenItsLastCommentLeaves() async throws {
        // A `descript.ion` holding nothing is litter, and it shows up in every listing.
        let from = try dir("from"), to = try dir("to")
        let file = try file("a.txt", in: from)
        try await setComment("c", for: "a.txt", in: from)

        _ = try await makeMove().run(items: [file.path], toDirectory: to.path)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: from.appendingPathComponent("descript.ion").path))
    }

    func testOtherFilesCommentsStayBehind() async throws {
        let from = try dir("from"), to = try dir("to")
        let moved = try file("moved.txt", in: from)
        _ = try file("stays.txt", in: from)
        try await setComment("mine", for: "moved.txt", in: from)
        try await setComment("not mine", for: "stays.txt", in: from)

        _ = try await makeMove().run(items: [moved.path], toDirectory: to.path)

        XCTAssertEqual(comment("moved.txt", in: to), "mine")
        XCTAssertEqual(comment("stays.txt", in: from), "not mine")
        XCTAssertNil(comment("stays.txt", in: to))
    }

    func testAFileWithoutACommentCreatesNoDescriptionFile() async throws {
        // Otherwise every copy would litter the target with an empty comment file.
        let from = try dir("from"), to = try dir("to")
        let file = try file("plain.txt", in: from)

        _ = try await makeMove().run(items: [file.path], toDirectory: to.path)

        XCTAssertFalse(FileManager.default.fileExists(
            atPath: to.appendingPathComponent("descript.ion").path))
    }

    func testMovingAFolderTakesItsComment() async throws {
        // A folder can carry a comment as well, and the engine takes a different path for one.
        let from = try dir("from"), to = try dir("to")
        let folder = try dir("from/project")
        _ = try file("inner.txt", in: folder)
        try await setComment("the customer's project", for: "project", in: from)

        _ = try await makeMove().run(items: [folder.path], toDirectory: to.path)

        XCTAssertEqual(comment("project", in: to), "the customer's project")
    }

    func testTheCommentFileItselfIsNotGivenAComment() async throws {
        // Moving a `descript.ion` around must not describe it in the target's `descript.ion`.
        let from = try dir("from"), to = try dir("to")
        try await setComment("c", for: "a.txt", in: from)
        let descript = from.appendingPathComponent("descript.ion")

        _ = try await makeMove().run(items: [descript.path], toDirectory: to.path)

        XCTAssertNil(comment("descript.ion", in: to))
    }

    // MARK: - Copy

    func testCopyingAFileGivesTheCopyTheCommentAndKeepsTheOriginal() async throws {
        let from = try dir("from"), to = try dir("to")
        let file = try file("doc.txt", in: from)
        try await setComment("reviewed", for: "doc.txt", in: from)

        _ = try await makeCopy().run(items: [file.path], toDirectory: to.path)

        XCTAssertEqual(comment("doc.txt", in: to), "reviewed")
        XCTAssertEqual(comment("doc.txt", in: from), "reviewed", "a copy leaves the source alone")
    }

    func testCopyingIntoTheSameDirectoryUnderANewNameKeepsBothComments() async throws {
        // The rename-on-collision path: the comment has to go to the name the copy actually got, and the
        // original's comment must survive. Using the copy engine's own rename decision.
        let directory = try dir("both")
        let file = try file("a.txt", in: directory)
        try await setComment("original", for: "a.txt", in: directory)
        let copy = CopyEngine(options: CopyOptions(), control: OperationControl(),
                              resolver: RenameToResolver(newLeaf: "a copy.txt"), progress: { _ in })

        _ = try await copy.run(items: [file.path], toDirectory: directory.path)

        XCTAssertEqual(comment("a.txt", in: directory), "original")
        XCTAssertEqual(comment("a copy.txt", in: directory), "original",
                       "the comment belongs to the name the copy actually got")
    }

    func testAnAppendLeavesTheTargetsOwnComment() async throws {
        // F-086 appends the source's bytes onto the target: the target keeps its identity, so it keeps
        // its comment. The source's comment winning here would overwrite a comment on a file that nobody
        // replaced — the exact kind of silent loss this whole change is about.
        let from = try dir("from"), to = try dir("to")
        let source = try file("log.txt", in: from, contents: "second half\n")
        _ = try file("log.txt", in: to, contents: "first half\n")
        try await setComment("the new part", for: "log.txt", in: from)
        try await setComment("the collected log", for: "log.txt", in: to)
        let copy = CopyEngine(options: CopyOptions(), control: OperationControl(),
                              resolver: AppendResolver(), progress: { _ in })

        _ = try await copy.run(items: [source.path], toDirectory: to.path)

        XCTAssertEqual(try String(contentsOf: to.appendingPathComponent("log.txt"), encoding: .utf8),
                       "first half\nsecond half\n", "the append itself must still have happened")
        XCTAssertEqual(comment("log.txt", in: to), "the collected log")
    }

    func testAnOverwriteDoesTakeTheSourcesComment() async throws {
        // The counterpart: an overwrite replaces the file, so the comment describes the new content.
        let from = try dir("from"), to = try dir("to")
        let source = try file("a.txt", in: from, contents: "new")
        _ = try file("a.txt", in: to, contents: "old")
        try await setComment("the new one", for: "a.txt", in: from)
        try await setComment("the old one", for: "a.txt", in: to)
        let copy = CopyEngine(options: CopyOptions(), control: OperationControl(),
                              resolver: OverwriteResolver(), progress: { _ in })

        _ = try await copy.run(items: [source.path], toDirectory: to.path)

        XCTAssertEqual(comment("a.txt", in: to), "the new one")
    }

    // MARK: - carry() itself

    func testCarryDoesNothingWhenThereIsNoComment() async throws {
        let from = try dir("from"), to = try dir("to")
        _ = try file("a.txt", in: from)
        await CommentStore.carryLocal(from: from.appendingPathComponent("a.txt").path,
                                      to: to.appendingPathComponent("a.txt").path, keepSource: false)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: to.appendingPathComponent("descript.ion").path))
    }

    func testCarryingWithinOneDirectoryIsARename() async throws {
        let directory = try dir("one")
        _ = try file("old.txt", in: directory)
        try await setComment("keep me", for: "old.txt", in: directory)

        await CommentStore.carryLocal(from: directory.appendingPathComponent("old.txt").path,
                                      to: directory.appendingPathComponent("new.txt").path,
                                      keepSource: false)

        XCTAssertEqual(comment("new.txt", in: directory), "keep me")
        XCTAssertNil(comment("old.txt", in: directory))
    }

    func testCarryingToTheSameNameInTheSameDirectoryKeepsTheComment() async throws {
        // The degenerate case — carry(a → a) — must not delete the comment it just wrote.
        let directory = try dir("one")
        _ = try file("a.txt", in: directory)
        try await setComment("still here", for: "a.txt", in: directory)

        await CommentStore.carryLocal(from: directory.appendingPathComponent("a.txt").path,
                                      to: directory.appendingPathComponent("a.txt").path,
                                      keepSource: false)

        XCTAssertEqual(comment("a.txt", in: directory), "still here")
    }

    // MARK: - Encoding and multi-line, through the store (F-374)

    func testEditingAUTF16FileKeepsItUTF16AndTheOtherComments() async throws {
        // The data-loss case. Total Commander writes UTF-16 when a comment needs characters the codepage
        // cannot hold. Reading that as UTF-8 gives replacement characters, and writing it back as UTF-8
        // destroys every comment in the directory — including the ones nobody touched.
        let directory = try dir("utf16")
        _ = try file("a.txt", in: directory)
        _ = try file("b.txt", in: directory)
        var bytes = Data([0xFF, 0xFE])
        bytes.append("a.txt Grüße aus Zürich\nb.txt 日本語\n".data(using: .utf16LittleEndian)!)
        try bytes.write(to: directory.appendingPathComponent("descript.ion"))

        try await setComment("neu", for: "a.txt", in: directory)

        let after = try Data(contentsOf: directory.appendingPathComponent("descript.ion"))
        XCTAssertEqual(Array(after.prefix(2)), [0xFF, 0xFE], "the file must still be UTF-16 LE")
        let doc = DescriptionFile(parsing: DescriptionFile.decode(after).text)
        XCTAssertEqual(doc.comment(for: "a.txt"), "neu")
        XCTAssertEqual(doc.comment(for: "b.txt"), "日本語",
                       "the comment nobody touched must survive the write")
    }

    func testAMultiLineCommentSurvivesTheStore() async throws {
        let directory = try dir("multi")
        _ = try file("a.txt", in: directory)
        try await setComment("erste Zeile\nzweite Zeile", for: "a.txt", in: directory)

        // On disk it is the escape plus Total Commander's marker bytes…
        let raw = try String(contentsOf: directory.appendingPathComponent("descript.ion"), encoding: .utf8)
        XCTAssertTrue(raw.contains("erste Zeile\\nzweite Zeile"), raw.debugDescription)
        XCTAssertTrue(raw.contains("\u{04}\u{C2}"), raw.debugDescription)
        // …and read back through the app it is two lines again.
        XCTAssertEqual(comment("a.txt", in: directory), "erste Zeile\nzweite Zeile")
    }

    func testAUTF8FileStaysUTF8() async throws {
        let directory = try dir("utf8")
        _ = try file("a.txt", in: directory)
        try await setComment("Grüße", for: "a.txt", in: directory)
        let after = try Data(contentsOf: directory.appendingPathComponent("descript.ion"))
        XCTAssertNotEqual(Array(after.prefix(2)), [0xFF, 0xFE])
        XCTAssertEqual(comment("a.txt", in: directory), "Grüße")
    }

    func testACommentCarriedOutOfAUTF16FileArrivesIntact() async throws {
        // Carrying a comment reads one file and writes another; a non-ASCII comment must not be mangled
        // on the way, and the target keeps its own encoding rather than inheriting the source's.
        let from = try dir("from16"), to = try dir("to8")
        let source = try file("a.txt", in: from)
        var bytes = Data([0xFF, 0xFE])
        bytes.append("a.txt Grüße aus Zürich\n".data(using: .utf16LittleEndian)!)
        try bytes.write(to: from.appendingPathComponent("descript.ion"))

        _ = try await makeMove().run(items: [source.path], toDirectory: to.path)

        XCTAssertEqual(comment("a.txt", in: to), "Grüße aus Zürich")
    }
}

/// Answers every collision with "append" — the F-086 merge path.
private final class AppendResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .append }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .skip }

}

/// Answers every collision with "overwrite".
private final class OverwriteResolver: OperationResolver {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .skip }
}

/// A resolver that answers every collision with the same new name — the copy engine's rename path.
private final class RenameToResolver: OperationResolver {
    let newLeaf: String
    init(newLeaf: String) { self.newLeaf = newLeaf }
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision {
        .rename(newLeaf)
    }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .skip }
}
