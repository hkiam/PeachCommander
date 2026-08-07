// SPDX-License-Identifier: Apache-2.0
// Execution tests for DefaultAutomationCore against a fake host bridge:
// policy gating (refuse/confirm/allow), plan-then-confirm, dispatch, and events.

import XCTest
@testable import PCAutomation

/// Records what the core asked the host to do.
actor FakeBridge: AutomationHostBridge {
    var contextCalls = 0
    var listed: String?
    var ranCommand: String?
    var opened: String?
    var copied: (sources: [String], dest: String)?
    var trashed: [String]?
    var madeDir: String?
    var setConfigKV: (String, String)?
    var comments: [String: String] = ["/a/f.txt": "an existing comment"]
    var setCommentCalls: [(path: String, comment: String?)] = []

    func context() -> AutomationContext {
        contextCalls += 1
        return AutomationContext(activePanelPath: "/a", inactivePanelPath: "/b",
                                 cursorPath: "/a/f.txt", selection: ["/a/f.txt"],
                                 tabPaths: ["/a"], viewMode: "details")
    }
    func listDirectory(_ path: String) -> [AutomationEntry] {
        listed = path
        return [AutomationEntry(name: "f.txt", path: path + "/f.txt", isDirectory: false, size: 3, modified: nil)]
    }
    func stat(_ path: String) -> AutomationEntry {
        AutomationEntry(name: (path as NSString).lastPathComponent, path: path, isDirectory: false, size: 3, modified: nil)
    }
    func readFile(_ path: String, maxBytes: Int) -> String { "hello" }
    func search(queryJSON: Data) -> [AutomationEntry] { [] }
    func getConfig(_ key: String) -> String? { key == "Display.NaturalSort" ? "1" : nil }
    func listCommandsJSON() -> Data { Data("[]".utf8) }
    func listPluginsJSON() -> Data { Data("[]".utf8) }
    func openPath(_ path: String) { opened = path }
    func openInPanel(_ path: String, side: String) { opened = path }
    func setSelection(mask: String) {}
    func runCommand(_ id: String) { ranCommand = id }
    func copy(sources: [String], destination: String) { copied = (sources, destination) }
    func move(sources: [String], destination: String) {}
    func rename(path: String, newName: String) {}
    func makeDirectory(_ path: String) { madeDir = path }
    func setConfig(_ key: String, _ value: String) { setConfigKV = (key, value) }
    func moveToTrash(_ paths: [String]) { trashed = paths }
    func deletePermanently(_ paths: [String]) {}
    func getComment(_ path: String) -> String? { comments[path] }
    func setComment(_ path: String, comment: String?) {
        setCommentCalls.append((path, comment))
        if let comment { comments[path] = comment } else { comments[path] = nil }
    }
}

final class DefaultAutomationCoreTests: XCTestCase {

    private func argsData(_ dict: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: dict)
    }

    func test_readTool_runsImmediately_evenReadOnly() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "get_context", arguments: nil, policy: .readOnly)
        guard case .ok(let payload) = out else { return XCTFail("expected ok, got \(out)") }
        let ctx = try JSONDecoder().decode(AutomationContext.self, from: XCTUnwrap(payload))
        XCTAssertEqual(ctx.activePanelPath, "/a")
        let calls = await bridge.contextCalls
        XCTAssertEqual(calls, 1)
    }

    func test_listDirectory_returnsEntries() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let out = try await core.invoke(tool: "list_directory", arguments: argsData(["path": "/a"]), policy: .readOnly)
        guard case .ok(let payload) = out else { return XCTFail() }
        let entries = try JSONDecoder().decode([AutomationEntry].self, from: XCTUnwrap(payload))
        XCTAssertEqual(entries.first?.name, "f.txt")
    }

    func test_runCommand_allowedUnderReadOnly() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "run_command", arguments: argsData(["command_id": "cm_RereadSource"]), policy: .readOnly)
        XCTAssertEqual(out, .ok(payload: nil))
        let ran = await bridge.ranCommand
        XCTAssertEqual(ran, "cm_RereadSource")
    }

    func test_writeTool_underReadOnly_isRefused_andNotExecuted() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "copy", arguments: argsData(["sources": ["/a/f.txt"], "destination": "/b"]), policy: .readOnly)
        guard case .refused = out else { return XCTFail("expected refused, got \(out)") }
        let copied = await bridge.copied
        XCTAssertNil(copied)
    }

    func test_writeTool_underConfirmWrites_needsConfirmation_thenExecutes() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "copy",
                                        arguments: argsData(["sources": ["/a/f.txt", "/a/g.txt"], "destination": "/b"]),
                                        policy: .standard)
        guard case .needsConfirmation(let plan, let token) = out else { return XCTFail("expected confirmation, got \(out)") }
        XCTAssertTrue(plan.contains("2 item"))
        let before = await bridge.copied
        XCTAssertNil(before, "must not copy before confirmation")
        let pending = await core.pendingCount
        XCTAssertEqual(pending, 1)

        let out2 = try await core.confirm(token: token)
        XCTAssertEqual(out2, .ok(payload: nil))
        let copied = await bridge.copied
        XCTAssertEqual(copied?.dest, "/b")
        XCTAssertEqual(copied?.sources.count, 2)
        let pendingAfter = await core.pendingCount
        XCTAssertEqual(pendingAfter, 0, "confirmation is consumed")
    }

    func test_deleteTool_underAutonomous_executesImmediately() async throws {
        let bridge = FakeBridge()
        let core = DefaultAutomationCore(bridge: bridge)
        let out = try await core.invoke(tool: "move_to_trash",
                                        arguments: argsData(["paths": ["/a/f.txt"]]),
                                        policy: PermissionPolicy(autonomy: .autonomous))
        XCTAssertEqual(out, .ok(payload: nil))
        let trashed = await bridge.trashed
        XCTAssertEqual(trashed, ["/a/f.txt"])
    }

    func test_confirm_withUnknownToken_fails() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let out = try await core.confirm(token: "nope")
        guard case .failed = out else { return XCTFail() }
    }

    func test_unknownTool_throws() async {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        do {
            _ = try await core.invoke(tool: "frobnicate", arguments: nil, policy: .standard)
            XCTFail("expected throw")
        } catch let e as AutomationError {
            XCTAssertEqual(e, .unknownTool("frobnicate"))
        } catch { XCTFail("wrong error \(error)") }
    }

    func test_missingArgument_failsGracefully() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        // copy with no destination, autonomous so it reaches execute
        let out = try await core.invoke(tool: "copy", arguments: argsData(["sources": ["/a"]]),
                                        policy: PermissionPolicy(autonomy: .autonomous))
        guard case .failed = out else { return XCTFail("expected failed, got \(out)") }
    }

    func test_events_areDelivered() async throws {
        let core = DefaultAutomationCore(bridge: FakeBridge())
        let stream = core.events()
        core.eventBus.emit(.panelChanged(side: .left, path: "/x"))
        var it = stream.makeAsyncIterator()
        let e = await it.next()
        XCTAssertEqual(e, .panelChanged(side: .left, path: "/x"))
    }
}
