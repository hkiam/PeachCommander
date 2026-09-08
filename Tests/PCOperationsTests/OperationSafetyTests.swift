// SPDX-License-Identifier: Apache-2.0
// OperationSafetyTests.swift - What copy, move and delete must never do to a file.
//
// Every case here was found by reading the three engines and then measuring the suspect rather than
// asserting it, and three of them lost data outright: a move deleted a source whose copy had been
// skipped, a rename onto the source's own name truncated it to nothing, and a cancelled overwrite
// left neither the old file nor the new one. The rest are the same family one step further out —
// a decision the code claimed to honour and did not.
//
// The engines had tests for the paths that work. These are for the paths where something is lost.

import XCTest
@testable import PCOperations
import PCFoundation

/// Answers one collision with a fixed name, then skips. Two answers, because "ask again" is the
/// behaviour under test and a resolver that always says the same thing cannot show it.
private final class RenameThenSkipResolver: OperationResolver, @unchecked Sendable {
    private let newName: String
    private let lock = NSLock()
    private var asked = 0
    var timesAsked: Int { lock.lock(); defer { lock.unlock() }; return asked }

    init(renameTo newName: String) { self.newName = newName }

    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision {
        lock.lock(); asked += 1; let round = asked; lock.unlock()
        return round == 1 ? .rename(newName) : .skip
    }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

/// Answers a collision with the name the source already has.
private final class RenameToTheSameNameResolver: OperationResolver, @unchecked Sendable {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision {
        .rename(source.name)
    }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

private final class AppendingResolver: OperationResolver, @unchecked Sendable {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .append }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

private final class ReplacingResolver: OperationResolver, @unchecked Sendable {
    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }
    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision { .abort }
}

final class OperationSafetyTests: XCTestCase {
    private var root: URL!
    private let fm = FileManager.default
    /// Directories made unwritable during a test, put back so the tree can be torn down.
    private var lockedDirectories: [URL] = []

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("pc-safety-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for dir in lockedDirectories {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        }
        lockedDirectories = []
        try? fm.removeItem(at: root)
        root = nil
    }

    // MARK: - Helpers

    private func makeDirectory(_ rel: String) throws -> URL {
        let url = root.appendingPathComponent(rel)
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func write(_ text: String, _ rel: String) throws -> URL {
        let url = root.appendingPathComponent(rel)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.data(using: .utf8)!.write(to: url)
        return url
    }

    private func lock(_ dir: URL) throws {
        try fm.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path)
        lockedDirectories.append(dir)
    }

    private func text(_ url: URL) -> String? { try? String(contentsOf: url, encoding: .utf8) }

    // MARK: - A move must not delete what it did not copy

    /// The copy fails, the resolver skips the failure, and `run` returns without throwing — so the
    /// delete that followed it took a file that existed nowhere else. Measured before the fix: the
    /// payload was gone from the source and had never reached the destination.
    func test_aMoveWhoseCopyFailedAndWasSkippedKeepsTheSource() async throws {
        let src = try makeDirectory("srcdir")
        let payload = try write("important", "srcdir/payload.txt")
        let destParent = try makeDirectory("dest")
        let destDir = try makeDirectory("dest/srcdir")   // exists → merge → the copy+delete path
        try lock(destDir)                                // → the child's copy cannot be written

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { _ in })
        _ = try? await engine.run(items: [src.path], toDirectory: destParent.path)

        XCTAssertEqual(text(payload), "important",
                       "the source was deleted although the copy never happened")
    }

    /// The same rule one level down: the tree was copied, but one child inside it was skipped, so
    /// deleting the source tree would take that child with it.
    func test_aMoveWhoseChildWasSkippedKeepsTheWholeSource() async throws {
        let src = try makeDirectory("tree")
        let mine = try write("mine", "tree/both.txt")
        try write("keep me", "tree/only-here.txt")
        let destParent = try makeDirectory("dest")
        _ = try makeDirectory("dest/tree")
        let theirs = try write("theirs", "dest/tree/both.txt")

        // SkipAllResolver merges the directories without asking and skips the file collision.
        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { _ in })
        _ = try? await engine.run(items: [src.path], toDirectory: destParent.path)

        XCTAssertEqual(text(mine), "mine", "the skipped child was deleted from the source")
        XCTAssertEqual(text(theirs), "theirs", "the destination's file was replaced after all")
    }

    /// And a move that copies everything still finishes: the guard must refuse one thing only.
    func test_aCompleteMoveAcrossADirectoryMergeStillRemovesTheSource() async throws {
        let src = try makeDirectory("tree")
        try write("payload", "tree/file.txt")
        let destParent = try makeDirectory("dest")
        _ = try makeDirectory("dest/tree")

        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: ReplacingResolver(), progress: { _ in })
        let moved = try await engine.run(items: [src.path], toDirectory: destParent.path)

        XCTAssertEqual(moved, [src.path])
        XCTAssertFalse(fm.fileExists(atPath: src.path), "the source tree should be gone")
        XCTAssertEqual(text(destParent.appendingPathComponent("tree/file.txt")), "payload")
    }

    // MARK: - A rename must not resolve to the source itself

    /// `.overwrite` and `.append` both refused to arrive at the same file; `.rename` did not, and a
    /// rename that keeps the name in the source's own directory therefore opened the file for
    /// reading and truncated it for writing. Measured: 0 bytes.
    func test_aRenameOntoTheSourcesOwnNameLeavesTheFileIntact() async throws {
        let file = try write("the only copy", "keep.txt")

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: RenameToTheSameNameResolver(), progress: { _ in })
        _ = try? await engine.run(items: [file.path], toDirectory: root.path)

        XCTAssertEqual(text(file), "the only copy", "the source was truncated by a rename onto itself")
    }

    // MARK: - An overwrite must not lose the file it is replacing

    /// The target used to be removed *before* the write, so a cancel in between left neither the old
    /// file nor a whole new one. Measured with a throttled copy and a cancel after 400 ms: the
    /// target was simply gone.
    func test_aCancelledOverwriteLeavesThePreviousFileIntact() async throws {
        let src = root.appendingPathComponent("big.bin")
        try Data(repeating: 0x41, count: 48 * 1024 * 1024).write(to: src)
        let destDir = try makeDirectory("target")
        let dst = try write("the previous version, which the user still has", "target/big.bin")

        let control = OperationControl()
        // Slow enough that the cancel lands mid-copy: unthrottled, 48 MiB is gone before the cancel
        // can be scheduled and the test measures nothing.
        await control.setSpeedLimit(2_000_000)
        var options = CopyOptions()
        options.useCloneWhenPossible = false              // force the streaming path
        let engine = CopyEngine(options: options, control: control,
                                resolver: ReplacingResolver(), progress: { _ in })

        let task = Task { try await engine.run(items: [src.path], toDirectory: destDir.path) }
        try? await Task.sleep(nanoseconds: 400_000_000)
        await control.cancel()
        _ = try? await task.value

        XCTAssertEqual(text(dst), "the previous version, which the user still has",
                       "cancelling the copy destroyed the file it was going to replace")
        let leftovers = (try? fm.contentsOfDirectory(atPath: destDir.path)) ?? []
        XCTAssertEqual(leftovers, ["big.bin"], "a partial copy was left behind: \(leftovers)")
    }

    /// The control: an overwrite that is allowed to finish still replaces the target.
    func test_anOverwriteThatFinishesReplacesTheTarget() async throws {
        try write("new", "a.txt")
        let destDir = try makeDirectory("dest")
        let dst = try write("old", "dest/a.txt")

        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: ReplacingResolver(), progress: { _ in })
        _ = try await engine.run(items: [root.appendingPathComponent("a.txt").path],
                                 toDirectory: destDir.path)

        XCTAssertEqual(text(dst), "new")
        XCTAssertEqual((try? fm.contentsOfDirectory(atPath: destDir.path)) ?? [], ["a.txt"])
    }

    // MARK: - An append must not be onto the same file

    /// `copyRegularFile` refuses it; `appendRegularFile` — the entry a move uses — did not, and
    /// appending a file onto itself reads what it is writing: it fills the volume. Not measured with
    /// the defect in place, for that reason.
    func test_appendingAFileOntoItselfIsRefused() async throws {
        let file = try write("payload", "self.txt")
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { _ in })
        do {
            try await engine.appendRegularFile(from: file.path, to: file.path)
            XCTFail("appending a file onto itself was allowed")
        } catch let error as OperationError {
            XCTAssertEqual(error, .sameFile(file.path))
        }
        XCTAssertEqual(text(file), "payload")
    }

    /// And a move that answers "append" onto the file itself leaves it alone.
    func test_aMoveAppendingAFileOntoItselfLeavesItAlone() async throws {
        let file = try write("payload", "self.txt")
        let engine = MoveEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: AppendingResolver(), progress: { _ in })
        _ = try? await engine.run(items: [file.path], toDirectory: root.path)
        XCTAssertEqual(text(file), "payload", "the file grew by being appended to itself")
    }

    // MARK: - A rename must not silently take a third file's place

    /// Choosing another name is how a user avoids overwriting something. When that other name is
    /// taken too, the answer is to ask again — which `OverwriteRules.autoRenameName` has documented
    /// all along ("a further conflict simply re-prompts") and which nothing did: the second name was
    /// written over whatever had it.
    func test_aRenameOntoATakenNameAsksAgainInsteadOfReplacingIt() async throws {
        try write("the source", "a.txt")
        let destDir = try makeDirectory("dest")
        try write("in the way", "dest/a.txt")
        let taken = try write("somebody else's file", "dest/taken.txt")

        let resolver = RenameThenSkipResolver(renameTo: "taken.txt")
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: resolver, progress: { _ in })
        _ = try? await engine.run(items: [root.appendingPathComponent("a.txt").path],
                                  toDirectory: destDir.path)

        XCTAssertEqual(text(taken), "somebody else's file",
                       "the renamed-to file was replaced without anyone being asked")
        XCTAssertGreaterThan(resolver.timesAsked, 1, "the second collision was never resolved")
    }

    // MARK: - A renamed directory target has to be created

    /// The target existed as a *file*, the resolver said "rename", and the code did nothing at all:
    /// the file stayed, no directory was made — `exists(dst)` was true — and the children were then
    /// copied to paths underneath a regular file.
    func test_aRenamedDirectoryTargetIsCreatedUnderTheNewName() async throws {
        let src = try makeDirectory("folder")
        try write("inside", "folder/inner.txt")
        let destDir = try makeDirectory("dest")
        let blocker = try write("a file where the folder should go", "dest/folder")

        let resolver = RenameThenSkipResolver(renameTo: "folder-2")
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: resolver, progress: { _ in })
        _ = try? await engine.run(items: [src.path], toDirectory: destDir.path)

        XCTAssertEqual(text(blocker), "a file where the folder should go",
                       "the file in the way was destroyed")
        XCTAssertEqual(text(destDir.appendingPathComponent("folder-2/inner.txt")), "inside",
                       "the folder was not created under the name the resolver chose")
    }

    // MARK: - A delete can be asked about, like a copy

    /// Copy and move have consulted a resolver per failed item since they were written; delete threw
    /// on the first one, abandoning the rest of the selection and reporting nothing about what had
    /// already gone.
    func test_aDeleteCanSkipAnItemItCannotRemoveAndSayItDidNotFinish() async throws {
        let dir = try makeDirectory("locked")
        let stubborn = try write("cannot be removed", "locked/stuck.txt")
        try lock(dir)                                    // unlink inside it fails

        let skipping = DeleteEngine(control: OperationControl(), resolver: SkipAllResolver())
        let removed = try await skipping.permanentDelete(items: [dir.path])

        XCTAssertEqual(removed, [], "a directory that still has something in it was reported as removed")
        XCTAssertEqual(text(stubborn), "cannot be removed")

        // And the default is unchanged: it throws, exactly as before it could ask.
        let aborting = DeleteEngine(control: OperationControl())
        do {
            _ = try await aborting.permanentDelete(items: [dir.path])
            XCTFail("the default resolver should still abort")
        } catch let error as OperationError {
            XCTAssertEqual(error, .deleteFailed(stubborn.path))
        }
    }

    /// An ordinary delete still reports what it removed.
    func test_anOrdinaryDeleteStillReportsWhatItRemoved() async throws {
        let dir = try makeDirectory("gone")
        try write("x", "gone/a.txt")
        let engine = DeleteEngine(control: OperationControl())
        let removed = try await engine.permanentDelete(items: [dir.path])
        XCTAssertEqual(removed, [dir.path])
        XCTAssertFalse(fm.fileExists(atPath: dir.path))
    }

    // MARK: - The total the progress bar counts up to

    /// With `followSymlinks` the copy takes what the link points at — possibly a whole directory —
    /// while the plan counted the link as one file, so the progress ran past its own total.
    func test_aFollowedSymlinkIsCountedByWhatItPointsAt() async throws {
        let real = try makeDirectory("real")
        for i in 0..<3 { try write("x", "real/f\(i).txt") }
        let link = root.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)
        let destDir = try makeDirectory("dest")

        var options = CopyOptions()
        options.followSymlinks = true
        let seen = TotalsBox()
        let engine = CopyEngine(options: options, control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { seen.record($0.filesTotal) })
        _ = try await engine.run(items: [link.path], toDirectory: destDir.path)

        XCTAssertEqual(seen.maximum, 3, "the plan counted the link rather than what it points at")
    }

    /// Without the option the link itself is the one file being copied.
    func test_anUnfollowedSymlinkIsStillOneFile() async throws {
        let real = try makeDirectory("real")
        for i in 0..<3 { try write("x", "real/f\(i).txt") }
        let link = root.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)
        let destDir = try makeDirectory("dest")

        let seen = TotalsBox()
        let engine = CopyEngine(options: CopyOptions(), control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { seen.record($0.filesTotal) })
        _ = try await engine.run(items: [link.path], toDirectory: destDir.path)

        XCTAssertEqual(seen.maximum, 1)
    }

    /// A link pointing at itself must not recurse until the stack runs out.
    func test_aSelfReferentialSymlinkIsRefusedRatherThanRecursing() async throws {
        let link = root.appendingPathComponent("loop")
        try fm.createSymbolicLink(at: link, withDestinationURL: link)
        let destDir = try makeDirectory("dest")

        var options = CopyOptions()
        options.followSymlinks = true
        let engine = CopyEngine(options: options, control: OperationControl(),
                                resolver: SkipAllResolver(), progress: { _ in })
        _ = try? await engine.run(items: [link.path], toDirectory: destDir.path)

        XCTAssertEqual((try? fm.contentsOfDirectory(atPath: destDir.path)) ?? [], [])
    }
}

/// Collects the highest `filesTotal` the engine reported, off whatever thread it reported from.
private final class TotalsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var highest = 0
    func record(_ value: Int) { lock.lock(); highest = max(highest, value); lock.unlock() }
    var maximum: Int { lock.lock(); defer { lock.unlock() }; return highest }
}
