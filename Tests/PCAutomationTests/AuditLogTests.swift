// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation
import PCFoundation

// What the assistant did, and taking it back. The core was described as an audited seam and
// recorded nothing; these tests pin what is now recorded, what is deliberately not, and the
// rule that an undo is offered only where a real inverse exists.
final class AuditLogTests: XCTestCase {

    private func log() -> (AuditLog, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (AuditLog(url: dir.appendingPathComponent("actions.jsonl")), dir)
    }

    private func core(_ bridge: FakeBridge, _ log: AuditLog) -> DefaultAutomationCore {
        DefaultAutomationCore(bridge: bridge, audit: log)
    }

    private func args(_ dictionary: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dictionary)
    }

    // MARK: What gets recorded

    func test_write_isRecorded_withItsArguments() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        _ = try await core.invoke(tool: "rename", arguments: args(["path": "/a/f.txt", "new_name": "g.txt"]),
                                  policy: PermissionPolicy(autonomy: .autonomous))
        let entries = log.recent()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.tool, "rename")
        XCTAssertEqual(entries.first?.outcome, "ok")
        XCTAssertTrue(entries.first?.arguments.contains("g.txt") ?? false, "got: \(entries)")
    }

    // A log of every list_directory buries the entries someone opens the log to find.
    func test_reads_areNotRecorded() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        _ = try await core.invoke(tool: "list_directory", arguments: args(["path": "/a"]), policy: .standard)
        _ = try await core.invoke(tool: "get_context", arguments: nil, policy: .standard)
        XCTAssertTrue(log.recent().isEmpty)
    }

    func test_refusal_isRecorded_withItsReason() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        _ = try await core.invoke(tool: "delete_permanently", arguments: args(["paths": ["/a"]]),
                                  policy: .readOnly)
        // Refused before execution: the attempt is what matters, and it is what a user asking
        // "did it try to delete something" needs to see.
        let entries = log.recent()
        XCTAssertEqual(entries.count, 1, "a refused attempt belongs in the log: \(entries)")
        XCTAssertEqual(entries.first?.outcome, "refused")
        XCTAssertNotNil(entries.first?.detail)
    }

    func test_longArguments_areShortened() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        _ = try await core.invoke(tool: "write_file",
                                  arguments: args(["path": "/a/f.txt",
                                                   "content": String(repeating: "x", count: 5000)]),
                                  policy: PermissionPolicy(autonomy: .autonomous))
        guard let entry = log.recent().first else { return XCTFail("nothing recorded") }
        XCTAssertLessThan(entry.arguments.count, 300, "a whole document must not land in the log")
        XCTAssertTrue(entry.arguments.contains("/a/f.txt"))
    }

    // MARK: Undo

    func test_rename_isUndoneByRenamingBack() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let bridge = FakeBridge()
        let core = core(bridge, log)
        let policy = PermissionPolicy(autonomy: .autonomous)
        _ = try await core.invoke(tool: "rename", arguments: args(["path": "/a/f.txt", "new_name": "g.txt"]),
                                  policy: policy)
        let outcome = try await core.undoLast(policy: policy)
        guard case .ok = outcome else { return XCTFail("expected ok, got \(outcome)") }
        let renamed = await bridge.renamed
        XCTAssertEqual(renamed?.path, "/a/g.txt", "the renamed file is what gets renamed back")
        XCTAssertEqual(renamed?.newName, "f.txt")
    }

    func test_move_isUndoneByMovingBack() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let bridge = FakeBridge()
        let core = core(bridge, log)
        let policy = PermissionPolicy(autonomy: .autonomous)
        _ = try await core.invoke(tool: "move",
                                  arguments: args(["sources": ["/a/one.txt", "/a/two.txt"],
                                                   "destination": "/b"]), policy: policy)
        _ = try await core.undoLast(policy: policy)
        let moved = await bridge.moved
        XCTAssertEqual(moved?.sources.sorted(), ["/b/one.txt", "/b/two.txt"])
        XCTAssertEqual(moved?.dest, "/a")
    }

    func test_theSameActionIsNotUndoneTwice() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        let policy = PermissionPolicy(autonomy: .autonomous)
        _ = try await core.invoke(tool: "rename", arguments: args(["path": "/a/f.txt", "new_name": "g.txt"]),
                                  policy: policy)
        _ = try await core.undoLast(policy: policy)
        let second = try await core.undoLast(policy: policy)
        guard case .failed(let reason) = second else { return XCTFail("expected a refusal to repeat") }
        XCTAssertTrue(reason.lowercased().contains("nothing to undo"), "got: \(reason)")
    }

    // An overwrite has no inverse, and the log says so rather than offering a button that lies.
    func test_writeFile_isNotOffered_asUndoable() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let core = core(FakeBridge(), log)
        let policy = PermissionPolicy(autonomy: .autonomous)
        _ = try await core.invoke(tool: "write_file",
                                  arguments: args(["path": "/a/f.txt", "content": "neu"]), policy: policy)
        guard let entry = log.recent().first else { return XCTFail("nothing recorded") }
        XCTAssertFalse(entry.isUndoable)
        XCTAssertEqual(entry.undoUnavailable, "the previous contents were not kept")
        guard case .failed(let reason) = try await core.undoLast(policy: policy) else {
            return XCTFail("an overwrite must not be reported as undone")
        }
        XCTAssertTrue(reason.contains("previous contents"), "the reason has to reach the user: \(reason)")
    }

    // Undoing is a write. A session that may not write may not undo either.
    func test_undo_underReadOnly_isRefused() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let bridge = FakeBridge()
        let core = core(bridge, log)
        _ = try await core.invoke(tool: "rename", arguments: args(["path": "/a/f.txt", "new_name": "g.txt"]),
                                  policy: PermissionPolicy(autonomy: .autonomous))
        let outcome = try await core.undoLast(policy: .readOnly)
        guard case .refused = outcome else { return XCTFail("expected a refusal, got \(outcome)") }
    }

    // MARK: Putting a trashing back

    /// The claim `move_to_trash` has always carried — "(reversible)" in its own description — with
    /// something behind it at last.
    ///
    /// Real files, because the guard that matters is about the filesystem: the old path has to be
    /// free, and the bytes have to come back. A stub could not say either.
    func test_aTrashingIsUndoable_andTheFileComesBack() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let home = dir.appendingPathComponent("home")
        let trash = dir.appendingPathComponent("trash")
        for d in [home, trash] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        let original = home.appendingPathComponent("notes.txt")
        let inTrash = trash.appendingPathComponent("notes.txt")
        try Data("the bytes that have to come back".utf8).write(to: inTrash)

        let bridge = FakeBridge()
        await bridge.setTrash(pairs: [original.path: inTrash.path])
        let core = core(bridge, log)
        let policy = PermissionPolicy(autonomy: .autonomous)
        _ = try await core.invoke(tool: "move_to_trash",
                                  arguments: args(["paths": [original.path]]), policy: policy)

        guard let entry = log.recent().first else { return XCTFail("nothing recorded") }
        XCTAssertTrue(entry.isUndoable, "a trashing that reported where it went has an inverse")
        XCTAssertEqual(entry.undoTool, "put_back")
        XCTAssertNil(entry.undoUnavailable)
        // The Trash path, not something derived from the file's name: the Trash renames on
        // collision, so a name-derived guess points at an earlier file. Decoded rather than matched
        // as text — `JSONSerialization` escapes forward slashes, so the stored arguments read
        // `\/tmp\/…` and a substring test fails on correct output.
        let undo = try JSONSerialization.jsonObject(
            with: Data((entry.undoArguments ?? "").utf8)) as? [String: [String]]
        XCTAssertEqual(undo?["from"], [inTrash.path])
        XCTAssertEqual(undo?["to"], [original.path])

        guard case .ok = try await core.undoLast(policy: policy) else {
            return XCTFail("the undo did not run")
        }
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8),
                       "the bytes that have to come back")
        XCTAssertFalse(FileManager.default.fileExists(atPath: inTrash.path),
                       "it was copied rather than moved back")
    }

    /// A trashing the host could not describe carries no inverse, and says which of the two reasons
    /// it is. Silence here would be a button that fails when pressed.
    func test_aTrashingThatReportedNoDestinationIsNotOffered() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let bridge = FakeBridge()
        await bridge.setTrash(pairs: [:])          // the host reports nothing
        let core = core(bridge, log)
        _ = try await core.invoke(tool: "move_to_trash", arguments: args(["paths": ["/a/f.txt"]]),
                                  policy: PermissionPolicy(autonomy: .autonomous))
        guard let entry = log.recent().first else { return XCTFail("nothing recorded") }
        XCTAssertFalse(entry.isUndoable)
        XCTAssertTrue(entry.undoUnavailable?.contains("did not report where") ?? false,
                      "got: \(entry.undoUnavailable ?? "nil")")
    }

    /// Never over the top of something else. This is the only way a put-back can destroy anything,
    /// and the refusal has to reach the user rather than be silently skipped.
    func test_aPutBackIsRefusedWhenTheOldPathIsOccupiedAgain() async throws {
        let (log, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let home = dir.appendingPathComponent("home")
        let trash = dir.appendingPathComponent("trash")
        for d in [home, trash] {
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        let original = home.appendingPathComponent("notes.txt")
        let inTrash = trash.appendingPathComponent("notes.txt")
        try Data("the old one".utf8).write(to: inTrash)
        try Data("something else entirely".utf8).write(to: original)

        let bridge = FakeBridge()
        let core = core(bridge, log)
        let outcome = try await core.invoke(
            tool: "put_back",
            arguments: args(["from": [inTrash.path], "to": [original.path]]),
            policy: PermissionPolicy(autonomy: .autonomous))
        guard case .ok(let payload) = outcome, let payload else {
            return XCTFail("expected a result, got \(outcome)")
        }
        let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        let refused = object?["refused"] as? [[String: String]] ?? []
        XCTAssertEqual(refused.first?["path"], original.path)
        XCTAssertTrue(refused.first?["reason"]?.contains("at that path again") ?? false,
                      "the reason has to reach the caller: \(refused)")
        XCTAssertTrue((object?["restored"] as? [String] ?? []).isEmpty)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "something else entirely",
                       "the put-back overwrote the file that was there")
        XCTAssertTrue(FileManager.default.fileExists(atPath: inTrash.path),
                      "the item was taken out of the Trash for nothing")
    }

    /// Two lists that are not the same length are refused, not truncated: pairing the wrong Trash
    /// entry with the wrong destination restores a file over another file's path.
    func test_putBackRefusesMismatchedLists() async throws {
        let core = core(FakeBridge(), log().0)
        let outcome = try await core.invoke(
            tool: "put_back", arguments: args(["from": ["/t/a"], "to": ["/h/a", "/h/b"]]),
            policy: PermissionPolicy(autonomy: .autonomous))
        guard case .failed(let error) = outcome else {
            return XCTFail("expected a failure, got \(outcome)")
        }
        XCTAssertTrue(error.contains("same number"), error)
    }

    // MARK: The inverse rules on their own

    func test_inverse_ofRename() {
        let inverse = AuditInverse.of(tool: "rename", arguments: ["path": "/x/a.txt", "new_name": "b.txt"])
        XCTAssertEqual(inverse?.tool, "rename")
        XCTAssertEqual(inverse?.arguments["path"] as? String, "/x/b.txt")
        XCTAssertEqual(inverse?.arguments["new_name"] as? String, "a.txt")
    }

    // Files from two different folders cannot be put back by one move, so no inverse is claimed.
    func test_inverse_ofMoveFromTwoFolders_isNotClaimed() {
        XCTAssertNil(AuditInverse.of(tool: "move",
                                     arguments: ["sources": ["/a/one.txt", "/b/two.txt"],
                                                 "destination": "/c"]))
    }

    func test_unavailableReasons_areStated() {
        XCTAssertNil(AuditInverse.unavailableReason(tool: "rename"))
        XCTAssertNotNil(AuditInverse.unavailableReason(tool: "delete_permanently"))
        XCTAssertNotNil(AuditInverse.unavailableReason(tool: "move_to_trash"))
        XCTAssertNotNil(AuditInverse.unavailableReason(tool: "run_shell"))
    }

    func test_logIsCapped() {
        let (_, dir) = log(); defer { try? FileManager.default.removeItem(at: dir) }
        let capped = AuditLog(url: dir.appendingPathComponent("actions.jsonl"), cap: 3)
        for i in 1...6 {
            capped.append(AuditEntry(at: Double(i), tool: "rename", capability: "write",
                                     arguments: "n=\(i)", outcome: "ok", detail: nil))
        }
        let entries = capped.recent()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.first?.arguments, "n=6", "newest first")
    }
}
