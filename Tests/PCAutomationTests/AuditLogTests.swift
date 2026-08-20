// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

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
