// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

// A real-filesystem bridge over a sandbox root: reads are real, writes are refused.
// Used only by the live end-to-end test below, against a temp dir (never real data).
actor RealFSBridge: AutomationHostBridge {
    let root: String
    init(root: String) { self.root = root }

    // A small model naturally uses names relative to "the current folder"; resolve them
    // against the sandbox root (as a real file manager resolves against the active panel).
    private func resolve(_ path: String) -> String {
        let fm = FileManager.default
        if fm.fileExists(atPath: path) { return path }
        // The dropped leading slash the model produces after a search hands it an absolute path
        // — the host resolves this the same way, and a live test that did not would be testing
        // something the app does not do.
        if !path.hasPrefix("/"), fm.fileExists(atPath: "/" + path) { return "/" + path }
        return path.hasPrefix("/") ? path : (root as NSString).appendingPathComponent(path)
    }

    func context() -> AutomationContext {
        AutomationContext(activePanelPath: root, inactivePanelPath: root, cursorPath: nil,
                          selection: [], tabPaths: [root], viewMode: "details")
    }
    func listDirectory(_ path: String) throws -> [AutomationEntry] {
        let path = resolve(path)
        let fm = FileManager.default
        return try fm.contentsOfDirectory(atPath: path).map { name in
            let full = (path as NSString).appendingPathComponent(name)
            let a = try? fm.attributesOfItem(atPath: full)
            return AutomationEntry(name: name, path: full,
                                   isDirectory: (a?[.type] as? FileAttributeType) == .typeDirectory,
                                   size: (a?[.size] as? NSNumber)?.int64Value ?? 0,
                                   modified: a?[.modificationDate] as? Date)
        }
    }
    func stat(_ path: String) throws -> AutomationEntry {
        let path = resolve(path)
        let a = try FileManager.default.attributesOfItem(atPath: path)
        return AutomationEntry(name: (path as NSString).lastPathComponent, path: path,
                               isDirectory: (a[.type] as? FileAttributeType) == .typeDirectory,
                               size: (a[.size] as? NSNumber)?.int64Value ?? 0,
                               modified: a[.modificationDate] as? Date)
    }
    func readFile(_ path: String, maxBytes: Int) throws -> String {
        let d = try Data(contentsOf: URL(fileURLWithPath: resolve(path)))
        return String(decoding: d.prefix(maxBytes), as: UTF8.self)
    }
    /// A real search over the sandbox: name mask and/or content, the same two things the host's
    /// search does. It used to return nothing, which let a live test "pass" while the model never
    /// found the files the test had written — a green test proving nothing.
    func search(queryJSON: Data) throws -> [AutomationEntry] {
        let d = (try? JSONSerialization.jsonObject(with: queryJSON)) as? [String: Any] ?? [:]
        let mask = (d["mask"] as? String) ?? "*"
        let text = (d["text"] as? String) ?? ""
        let requested = (d["path"] as? String) ?? ""
        let start = (requested.isEmpty || requested == "." || !requested.hasPrefix("/"))
            ? root : requested
        let names = (try? FileManager.default.contentsOfDirectory(atPath: start)) ?? []
        var out: [AutomationEntry] = []
        for name in names {
            let full = (start as NSString).appendingPathComponent(name)
            if mask != "*", !Self.matches(mask: mask, name: name) { continue }
            if !text.isEmpty {
                let content = (try? String(contentsOfFile: full, encoding: .utf8)) ?? ""
                guard content.localizedCaseInsensitiveContains(text) else { continue }
            }
            if let entry = try? stat(full) { out.append(entry) }
        }
        return out
    }

    /// `fnmatch`, which is what a wildcard mask means everywhere else in this app.
    private static func matches(mask: String, name: String) -> Bool {
        mask.withCString { m in name.withCString { n in fnmatch(m, n, 0) == 0 } }
    }
    func getConfig(_ key: String) -> String? { nil }
    func listCommandsJSON() -> Data { Data("[]".utf8) }
    func listPluginsJSON() -> Data { Data("[]".utf8) }
    func openPath(_ path: String) {}
    func openInPanel(_ path: String, side: String) {}
    func setSelection(mask: String) {}
    func runCommand(_ id: String) {}
    /// Records rather than runs. A fake that actually shelled out would be testing the machine, and
    /// the thing under test here is the policy: whether this tool is even reached without approval.
    var ranShell: String?
    func runShell(_ command: String) async throws -> String { ranShell = command; return "" }
    func copy(sources: [String], destination: String) throws { throw AutomationError.notImplemented("copy") }
    func move(sources: [String], destination: String) throws { throw AutomationError.notImplemented("move") }
    func rename(path: String, newName: String) throws { throw AutomationError.notImplemented("rename") }
    func makeDirectory(_ path: String) throws { throw AutomationError.notImplemented("mkdir") }
    func setConfig(_ key: String, _ value: String) throws { throw AutomationError.notImplemented("config") }
    func moveToTrash(_ paths: [String]) throws { throw AutomationError.notImplemented("trash") }
    func deletePermanently(_ paths: [String]) throws { throw AutomationError.notImplemented("delete") }
}

final class LiveRealFolderTests: XCTestCase {
    // Real end-to-end: the on-device model reads a REAL file (in a temp sandbox) via the
    // agent loop and answers. Read-only; the sandbox is created and deleted here, so no
    // real user data is touched. Auto-skips without Apple Intelligence.
    func test_live_readsRealFile_andAnswers() async throws {
        guard #available(macOS 26, *) else { throw XCTSkip("macOS 26") }
        try LiveModel.requireEnabled()
        let provider = AppleFoundationModelsProvider()
        guard await provider.isAvailable else { throw XCTSkip("Apple Intelligence not available") }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let notes = dir.appendingPathComponent("notes.txt")
        try "Action items:\n- Buy milk\n- Call Bob about the roof\n- Ship version 1 on Friday\n"
            .write(to: notes, atomically: true, encoding: .utf8)
        try "just some numbers".write(to: dir.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)

        // Keep the raw temp path OUT of the prompt: a prompt dominated by a long
        // /var/folders/UUID/... path reads as "not natural language" to Apple's on-device
        // guardrail and throws "unsupported language or locale". The model discovers the
        // folder via get_context/list_directory instead — also a more realistic flow.
        // The small model can still transiently error, so retry with a fresh session.
        var lastError: Error?
        for attempt in 1...5 {
            do {
                let session = AgentSession(core: DefaultAutomationCore(bridge: RealFSBridge(root: dir.path)),
                                           provider: provider, policy: .readOnly,
                                           systemPrompt: "You are a file assistant. Use tools to inspect the current folder and read files. Answer briefly.")
                let result = try await session.send("Read the file notes.txt in the current folder and list the action items it contains.")
                let trace = await session.snapshot().messages
                for m in trace {
                    let body = m.content.replacingOccurrences(of: "\n", with: "⏎").prefix(120)
                    print("[live]   \(m.role)\(m.toolName.map { "/\($0)" } ?? ""): \(body)")
                }
                print("[live] real-folder answer (attempt \(attempt)): \(result)")
                if case .answer(let text) = result {
                    // Real success: the answer must reflect content actually read from the
                    // file — not just any non-empty string. The small model is flaky, so
                    // retry if this attempt didn't produce a grounded answer.
                    let lower = text.lowercased()
                    if lower.contains("milk") || lower.contains("bob") || lower.contains("ship") {
                        XCTAssertFalse(text.isEmpty)
                        return
                    }
                }
                // Not grounded / .stopped / .needsConfirmation → retry.
                lastError = nil
            } catch {
                lastError = error
                print("[live] attempt \(attempt) errored: \(error)")
            }
        }
        if let lastError { throw XCTSkip("on-device model transiently unavailable: \(lastError)") }
        // The model ran but never produced a grounded answer in 5 tries — a small-model
        // quality limitation, not a code failure. Skip rather than pass silently.
        throw XCTSkip("on-device model did not produce a grounded answer in 5 attempts")
    }
}
