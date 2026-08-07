// SPDX-License-Identifier: Apache-2.0
// CommentToolsTests.swift - get_comment / set_comment through the automation core (F-380).
//
// Writing a comment is the assistant changing something the user will read later and did not type, so
// two things have to hold and neither is obvious from the code:
//
//   * it is gated like any other write — a plan first, and nothing written until the user agrees;
//   * the plan says what the comment will *say*. "Write 34 characters" gives the user nothing to decide
//     with, and this is a case where the content is the entire decision.
//
// The empty string is the third: it is how a comment is removed, so it must survive as far as the host
// as "clear this" and must not be dropped on the way for looking like a missing argument.

import XCTest
@testable import PCAutomation

final class CommentToolsTests: XCTestCase {

    private func argsData(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }

    // MARK: - Reading

    func test_getComment_readsImmediately_evenReadOnly() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let out = try await core.invoke(tool: "get_comment",
                                        arguments: argsData(["path": "/a/f.txt"]), policy: .readOnly)
        guard case .ok(let payload) = out else { return XCTFail("expected ok, got \(out)") }
        let dict = try JSONSerialization.jsonObject(with: XCTUnwrap(payload)) as? [String: Any]
        XCTAssertEqual(dict?["comment"] as? String, "an existing comment")
    }

    func test_aFileWithNoComment_answersAnEmptyString() async throws {
        // Not a missing key and not an error: an agent asked to tell "no comment" from "the tool did not
        // answer" will get it wrong, and here the difference means nothing.
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let out = try await core.invoke(tool: "get_comment",
                                        arguments: argsData(["path": "/a/nothing.txt"]), policy: .readOnly)
        guard case .ok(let payload) = out else { return XCTFail("expected ok, got \(out)") }
        let dict = try JSONSerialization.jsonObject(with: XCTUnwrap(payload)) as? [String: Any]
        XCTAssertEqual(dict?["comment"] as? String, "")
    }

    // MARK: - Writing is gated

    func test_setComment_isRefusedUnderAReadOnlyPolicy() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "set_comment",
                                        arguments: argsData(["path": "/a/f.txt", "comment": "new"]),
                                        policy: .readOnly)
        guard case .refused = out else { return XCTFail("expected refused, got \(out)") }
        let calls = await bridge.setCommentCalls
        XCTAssertTrue(calls.isEmpty, "a refused write must not reach the host")
    }

    func test_setComment_asksFirstAndSaysWhatItWillWrite() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "set_comment",
                                        arguments: argsData(["path": "/a/f.txt",
                                                             "comment": "the 2026 export, superseded"]),
                                        policy: .standard)
        guard case .needsConfirmation(let plan, let token) = out else {
            return XCTFail("expected confirmation, got \(out)")
        }
        // The words themselves, not their number — this is what the user is agreeing to.
        XCTAssertTrue(plan.contains("the 2026 export, superseded"), "plan was: \(plan)")
        XCTAssertTrue(plan.contains("/a/f.txt"), "plan was: \(plan)")
        let before = await bridge.setCommentCalls
        XCTAssertTrue(before.isEmpty, "must not write before confirmation")

        guard case .ok = try await core.confirm(token: token) else { return XCTFail("confirm failed") }
        let after = await bridge.setCommentCalls
        XCTAssertEqual(after.count, 1)
        XCTAssertEqual(after.first?.path, "/a/f.txt")
        XCTAssertEqual(after.first?.comment, "the 2026 export, superseded")
    }

    // MARK: - The empty string means "remove"

    func test_anEmptyCommentReachesTheHostAsAClear() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "set_comment",
                                        arguments: argsData(["path": "/a/f.txt", "comment": ""]),
                                        policy: PermissionPolicy(autonomy: .autonomous))
        guard case .ok = out else { return XCTFail("expected ok, got \(out)") }
        let calls = await bridge.setCommentCalls
        XCTAssertEqual(calls.count, 1)
        XCTAssertNil(calls.first?.comment, "an empty string is how a comment is removed")
        let remaining = await bridge.comments["/a/f.txt"]
        XCTAssertNil(remaining)
    }

    func test_theRemovalPlanSaysRemoval() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let out = try await core.invoke(tool: "set_comment",
                                        arguments: argsData(["path": "/a/f.txt", "comment": ""]),
                                        policy: .standard)
        guard case .needsConfirmation(let plan, _) = out else { return XCTFail("expected confirmation") }
        XCTAssertTrue(plan.lowercased().contains("remove"), "plan was: \(plan)")
    }

    func test_aMissingCommentArgumentFails_ratherThanClearing() async throws {
        // Leaving the argument out is a malformed call, not an instruction to delete the comment —
        // the difference between the two is a comment the user never asked to lose.
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "set_comment", arguments: argsData(["path": "/a/f.txt"]),
                                        policy: PermissionPolicy(autonomy: .autonomous))
        guard case .failed = out else { return XCTFail("expected failed, got \(out)") }
        let calls = await bridge.setCommentCalls
        XCTAssertTrue(calls.isEmpty)
    }

    // MARK: - The catalogue

    func test_theToolsAreInTheCatalogueUnderTheRightCapability() throws {
        let byName = Dictionary(uniqueKeysWithValues: AutomationCatalog.tools.map { ($0.name, $0) })
        // The capability is what the policy gates on: `set_comment` under `.read` would write without
        // ever asking, and no test of the core's dispatch would notice.
        XCTAssertEqual(byName["get_comment"]?.capability, .read)
        XCTAssertEqual(byName["set_comment"]?.capability, .write)
        XCTAssertEqual(byName["set_comment"]?.parameters.map(\.name), ["path", "comment"])
        XCTAssertEqual(byName["set_comment"]?.parameters.allSatisfy(\.required), true)
    }
}
