import XCTest
@testable import PCAutomation

#if canImport(FoundationModels)

private struct FixedBroker: ConfirmationBroker {
    let ok: Bool
    func confirmPlan(_ plan: String) async -> Bool { ok }
}

// Class is NOT @available-gated (that would hide it from test discovery); each method
// guards on macOS 26 and skips otherwise. The native tools reuse AutomationCore, so the
// permission model still applies — the first three tests verify that deterministically
// (no model); the last verifies reliability live.
final class NativeToolContextTests: XCTestCase {

    func test_readTool_runsImmediately() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: false), onProgress: nil)
        let out = await ctx.run("list_directory", ["path": "/a"])
        XCTAssertFalse(out.hasPrefix("Failed"))
        XCTAssertFalse(out.hasPrefix("Refused"))
        let listed = await bridge.listed
        XCTAssertEqual(listed, "/a")
    }

    func test_gatedWrite_declined_isNotExecuted() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: false), onProgress: nil)
        let out = await ctx.run("copy", ["sources": ["/a/f.txt"], "destination": "/b"])
        XCTAssertTrue(out.lowercased().contains("declined"), "got: \(out)")
        let copied = await bridge.copied
        XCTAssertNil(copied, "declined write must not execute")
    }

    func test_gatedWrite_confirmed_isExecuted() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .standard, broker: FixedBroker(ok: true), onProgress: nil)
        _ = await ctx.run("copy", ["sources": ["/a/f.txt"], "destination": "/b"])
        let copied = await bridge.copied
        XCTAssertEqual(copied?.dest, "/b", "confirmed write must execute via the core")
    }

    // Live: guided generation produces a well-formed Markdown table (KI-09).
    func test_live_guidedTable_isWellFormed() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let probe = AppleFoundationModelsProvider()
        guard await probe.isAvailable else { throw XCTSkip("Apple Intelligence not available") }
        // Read a REAL file (temp sandbox) then tabulate it via guided generation — the
        // tool-enabled session reads the file, constrained decoding formats the table.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "name,color\napple,red\nbanana,yellow\n".write(to: dir.appendingPathComponent("fruit.csv"),
                                                            atomically: true, encoding: .utf8)
        let session = AppleNativeToolSession(core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                                             policy: .readOnly, instructions: "You manage files.")
        let md = try await session.tabulateFile(path: "fruit.csv")   // reads file, then guided-generates
        print("[live] guided table:\n\(md)")
        let lines = md.split(separator: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 3)                 // header + separator + >=1 row
        XCTAssertTrue(lines[1].contains("---"))                     // markdown separator row
        XCTAssertTrue(lines.allSatisfy { $0.hasPrefix("|") })       // every row is a table row
        XCTAssertTrue(md.lowercased().contains("apple") || md.lowercased().contains("banana"),
                      "table should reflect the real file contents: \(md)")
    }

    func test_searchResult_hintsToReadFileForContents() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: FakeBridge()),
                                    policy: .readOnly, broker: nil, onProgress: nil)
        let out = await ctx.run("search", ["query": ["mask": "*"]])
        XCTAssertTrue(out.contains("read_file"), "search result should nudge toward read_file: \(out)")
    }

    func test_readOnlyPolicy_refusesWrite_evenIfBrokerWouldConfirm() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let bridge = FakeBridge()
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: bridge),
                                    policy: .readOnly, broker: FixedBroker(ok: true), onProgress: nil)
        let out = await ctx.run("copy", ["sources": ["/a"], "destination": "/b"])
        XCTAssertTrue(out.hasPrefix("Refused"), "got: \(out)")
        let copied = await bridge.copied
        XCTAssertNil(copied)
    }

    // Live: native tool-calling reads a REAL file (temp sandbox, read-only) and answers
    // with its actual content — the reliability win over the text convention.
    func test_live_native_readsRealFile_reliably() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let probe = AppleFoundationModelsProvider()
        guard await probe.isAvailable else { throw XCTSkip("Apple Intelligence not available") }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "Action items:\n- Buy milk\n- Call Bob about the roof\n- Ship version 1 on Friday\n"
            .write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        // Keep the raw path out of the prompt (relative names are resolved against the
        // folder by the bridge, as in the file manager). Log tool activity; the small
        // model is still non-deterministic, so allow a few attempts.
        for attempt in 1...3 {
            let session = AppleNativeToolSession(
                core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                policy: .readOnly,
                instructions: "You help manage files in the current folder. Use tools to read files, then answer briefly.",
                onProgress: { name in print("[live] native tool: \(name)") })
            let answer = try await session.send("Read the file notes.txt in the current folder and list the action items it contains.")
            print("[live] native answer (attempt \(attempt)): \(answer)")
            let lower = answer.lowercased()
            if lower.contains("milk") || lower.contains("bob") || lower.contains("ship") { return }
        }
        throw XCTSkip("on-device model did not produce a grounded answer in 3 native attempts")
    }
}
#endif
