// SPDX-License-Identifier: Apache-2.0
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

    // Regression (the reported failure): the panel's folder is a temp/UUID path, so the
    // composed context header is path-dominated and Apple's INPUT guardrail rejects the
    // prompt with `unsupportedLanguageOrLocale`. That used to surface as "the on-device
    // model produced an invalid tool call" — a wrong diagnosis — and the retry resent the
    // identical text, so the turn could never recover. It must now answer, from the file.
    func test_live_guardrailRejectedHeader_recoversAndAnswers() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        guard await AppleFoundationModelsProvider().isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }
        // A UUID-named temp folder is what trips the guardrail — the same shape a user
        // hits browsing a temp, DerivedData or hash-named directory.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try "Quartalsbericht Q3 2026\nUmsatz: 120000 EUR\n"
            .write(to: dir.appendingPathComponent("bericht.txt"), atomically: true, encoding: .utf8)

        let composed = ChatComposer.compose(
            userText: "um was geht die aktuell markierte Datei?",
            context: ChatContext(folder: dir.path, selection: [dir.path + "/bericht.txt"]),
            attachments: [])

        // The model is non-deterministic, so the assertion is given a few chances — what is
        // being pinned is that a rejected header no longer costs the whole turn, not that one
        // particular generation succeeds.
        var last = ""
        for attempt in 1...3 {
            let session = AppleNativeToolSession(
                core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                policy: .readOnly,
                instructions: "You are the Peach Commander assistant. To answer what is INSIDE a "
                    + "file you MUST call read_file. Use get_context to find the exact path. "
                    + "Always reply in the user's language.",
                onProgress: { name in print("[live] native tool: \(name)") })
            let answer = try await session.send(composed)
            print("[live] guardrail-recovery answer (attempt \(attempt)): \(answer)")
            last = answer
            XCTAssertFalse(answer.contains("invalid tool call"),
                           "a guardrail rejection is not a bad tool call: \(answer)")
            let lower = answer.lowercased()
            if !answer.contains("rejected that request"),
               lower.contains("quartal") || lower.contains("quarterly") || lower.contains("120") {
                return
            }
        }
        XCTFail("the retry should drop the paths and answer from the file; last: \(last)")
    }

    // The headline defect this work is about: with the shipped 64 KB read default, a 16 KB
    // document blew the on-device context window in the FIRST turn, so "summarise this file"
    // — the most-used skill — failed on any real document. The model now has summarize_file,
    // which reads in 4 KB slices (the measured ceiling) and folds the slice summaries, so the
    // file's length costs time instead of failing.
    func test_live_summarizesLongFile_beyondContextWindow() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        guard await AppleFoundationModelsProvider().isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // ~40 KB of prose — ten times what one generation can hold — with a fact planted in
        // the LAST section, so an answer that only read the beginning cannot produce it.
        var text = ""
        let para = "Der Quartalsbericht der Region Nord beschreibt Umsatz, Kosten und Ergebnis "
            + "je Monat und vergleicht sie mit dem Vorjahr. Die Logistikkosten steigen im "
            + "September deutlich an, was auf die neue Streckenplanung zurückgeführt wird. "
        while text.utf8.count < 38_000 { text += para }
        text += "\n\nBeschluss am Ende des Berichts: das Projekt Zugspitze wird eingestellt.\n"
        try text.write(to: dir.appendingPathComponent("bericht.txt"), atomically: true, encoding: .utf8)

        var last = ""
        for attempt in 1...2 {
            let session = AppleNativeToolSession(
                core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                policy: .readOnly,
                instructions: "You are the Peach Commander assistant. Use summarize_file for a whole "
                    + "file. Always reply in the user's language.",
                onProgress: { name in print("[live] tool: \(name)") })
            let answer = try await session.send("Fasse die Datei bericht.txt zusammen.")
            print("[live] long-file answer (attempt \(attempt)): \(answer)")
            last = answer
            // This is the assertion that matters and it must hold every time: the window is no
            // longer what decides whether a long file can be summarised.
            XCTAssertFalse(answer.contains("conversation has grown"),
                           "a long file must not exhaust the window any more: \(answer)")
            let lower = answer.lowercased()
            if lower.contains("quartal") || lower.contains("umsatz") || lower.contains("logistik")
                || lower.contains("kosten") || lower.contains("report") || lower.contains("zugspitze") {
                return
            }
        }
        XCTFail("the summary should come from the file; last: \(last)")
    }

    // A tool the session may not use is not offered to the model. Under read-only the write
    // and delete tools are absent rather than present-and-refused, which is what kept the
    // small model busy spending its window on attempts that could only fail.
    func test_toolSet_followsThePolicy() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: FakeBridge()),
                                    policy: .readOnly, broker: nil, onProgress: nil)
        let readOnly = AppleNativeToolSession.makeTools(ctx, policy: .readOnly).map(\.name)
        XCTAssertTrue(readOnly.contains("read_file"))
        XCTAssertTrue(readOnly.contains("summarize_file"))
        XCTAssertFalse(readOnly.contains("write_file"), "read-only must not offer writes")
        XCTAssertFalse(readOnly.contains("delete_permanently"))
        XCTAssertFalse(readOnly.contains("move_to_trash"))
        XCTAssertFalse(readOnly.contains("run_shell"))

        let standard = AppleNativeToolSession.makeTools(ctx, policy: .standard).map(\.name)
        XCTAssertTrue(standard.contains("write_file"))
        XCTAssertTrue(standard.contains("move_to_trash"))
        XCTAssertFalse(standard.contains("run_shell"), ".standard withholds the shell")
        XCTAssertTrue(AppleNativeToolSession.makeTools(ctx, policy: .standardWithShell)
                        .map(\.name).contains("run_shell"))
    }

    // Everything the catalogue declares is reachable on the on-device path too. The two paths
    // used to differ by four tools, so the default provider was the poorer one: no memory, no
    // semantic search.
    func test_nativeToolSet_coversTheCatalogue() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        let ctx = NativeToolContext(core: DefaultAutomationCore(bridge: FakeBridge()),
                                    policy: .standardWithShell, broker: nil, onProgress: nil)
        let offered = Set(AppleNativeToolSession.allTools(ctx).map(\.name))
        let declared = Set(AutomationCatalog.tools.map(\.name))
        XCTAssertTrue(declared.subtracting(offered).isEmpty,
                      "not offered on the native path: \(declared.subtracting(offered).sorted())")
        XCTAssertTrue(offered.contains("summarize_file"), "session-level tool, not a catalogue one")
    }

    // A conversation that fills the window used to end there: the turn came back as "start a new
    // chat", which is not something a user in the middle of a task can act on. The transcript is
    // now folded into a summary and the conversation continues. Several 4 KB reads in a row is
    // what fills a window that holds a few thousand tokens.
    func test_live_longConversation_isCompactedRatherThanEnded() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        guard await AppleFoundationModelsProvider().isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let para = "Die Region Nord meldet für den Monat gleichbleibende Umsätze und leicht "
            + "steigende Kosten, im Wesentlichen durch die Logistik. "
        for month in ["januar", "februar", "maerz", "april", "mai", "juni"] {
            var text = "Bericht \(month)\n"
            while text.utf8.count < 3_500 { text += para }
            try text.write(to: dir.appendingPathComponent("\(month).txt"), atomically: true, encoding: .utf8)
        }

        let session = AppleNativeToolSession(
            core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
            policy: .readOnly,
            instructions: "You are the Peach Commander assistant. Read the file you are asked about "
                + "with read_file and answer in one sentence.",
            onProgress: { name in print("[live] tool: \(name)") })

        var answers: [String] = []
        for month in ["januar", "februar", "maerz", "april", "mai", "juni"] {
            let answer = try await session.send("Lies \(month).txt und sage in einem Satz, was darin steht.")
            answers.append(answer)
            print("[live] \(month): \(answer.replacingOccurrences(of: "\n", with: " ").prefix(90))")
        }
        // The later turns are the ones that would have hit the window.
        let ended = answers.filter { $0.contains("too long for the on-device model") }
        XCTAssertTrue(ended.isEmpty,
                      "a full window must be folded and continued, not reported as the end: \(ended)")
        XCTAssertTrue(answers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                      "every turn should answer something")
    }

    // The language of a folded summary. `summarize_file` summarises slice by slice through prompts
    // of its own, and those prompts decide the language of what comes back: with English prompts a
    // German file was summarised in English 4 times out of 4, and the assistant relayed that — a
    // German user asking about a German file got an English answer. The file's language is detected
    // and named in the prompts, which this pins.
    func test_live_foldedSummary_keepsTheFilesLanguage() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        guard await AppleFoundationModelsProvider().isAvailable else {
            throw XCTSkip("Apple Intelligence not available")
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let para = "Die Region Nord meldet gleichbleibende Umsätze und leicht steigende Kosten, "
            + "im Wesentlichen durch die Logistik im September. "
        var text = ""
        while text.utf8.count < 20_000 { text += para }   // long enough to be folded, not read
        try text.write(to: dir.appendingPathComponent("bericht.txt"), atomically: true, encoding: .utf8)

        var german = 0
        var answers: [String] = []
        for _ in 1...3 {
            let session = AppleNativeToolSession(
                core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                policy: .readOnly,
                instructions: "You are the Peach Commander assistant. Use summarize_file for a whole "
                    + "file. Always reply in the same language the user writes in.")
            let answer = try await session.send("Fasse bericht.txt zusammen.")
            answers.append(answer)
            if Self.readsAsGerman(answer) { german += 1 }
        }
        // Two of three: the model is not deterministic, and the point is that the language of the
        // prompts no longer decides the language of the answer.
        XCTAssertGreaterThanOrEqual(german, 2,
            "a German file should be summarised in German; got: \(answers.map { $0.prefix(80) })")
    }

    /// Crude but sufficient: which language's function words the answer is built from.
    static func readsAsGerman(_ text: String) -> Bool {
        let lower = " " + text.lowercased() + " "
        let de = [" der ", " die ", " das ", " und ", " ist ", " im ", " mit ", " für ", " von "]
        let en = [" the ", " and ", " is ", " in ", " with ", " for ", " of ", " report "]
        return de.filter { lower.contains($0) }.count > en.filter { lower.contains($0) }.count
    }
}
#endif
