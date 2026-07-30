// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class ToolCallProtocolTests: XCTestCase {

    func test_instructions_listTools() {
        let s = ToolCallProtocol.instructions(for: AutomationCatalog.tools)
        XCTAssertTrue(s.contains("TOOL:"))
        XCTAssertTrue(s.contains("list_directory"))
        XCTAssertTrue(s.contains("read_file"))
    }

    func test_parse_toolCall_withJSON() {
        let reply = ToolCallProtocol.parse(#"TOOL: list_directory {"path": "/a"}"#)
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        XCTAssertEqual(call.name, "list_directory")
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertEqual((obj?["path"] as? String), "/a")
    }

    func test_parse_toolCall_amidProse_picksTheDirective() {
        let reply = ToolCallProtocol.parse("Sure, let me look.\nTOOL: get_context {}\n")
        guard case .toolCalls(let calls) = reply else { return XCTFail() }
        XCTAssertEqual(calls.first?.name, "get_context")
    }

    func test_parse_plainText_isAnswer() {
        let reply = ToolCallProtocol.parse("There are 5 files in that folder.")
        XCTAssertEqual(reply, .text("There are 5 files in that folder."))
    }

    func test_parse_invalidJSON_fallsBackToEmptyArgs() {
        let reply = ToolCallProtocol.parse("TOOL: search not-json-here")
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        XCTAssertEqual(call.name, "search")
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertNotNil(obj)   // valid empty object
    }

    func test_parse_nameOnly() {
        let reply = ToolCallProtocol.parse("TOOL: list_plugins")
        guard case .toolCalls(let calls) = reply else { return XCTFail() }
        XCTAssertEqual(calls.first?.name, "list_plugins")
    }

    // Regression: the on-device model emitted `TOOL: search(query: "notes")` and the old
    // parser took "search(query:" as the tool name → unknownTool. The name must be just
    // the identifier, and the keyword args must coerce into a JSON object.
    func test_parse_functionCallSyntax_stringArg() {
        let reply = ToolCallProtocol.parse(#"TOOL: search(query: "notes")"#)
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        XCTAssertEqual(call.name, "search")
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertEqual(obj?["query"] as? String, "notes")
    }

    func test_parse_functionCallSyntax_multipleTypedArgs() {
        let reply = ToolCallProtocol.parse(#"TOOL: read_file(path: "/a/b.txt", maxBytes: 100)"#)
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        XCTAssertEqual(call.name, "read_file")
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertEqual(obj?["path"] as? String, "/a/b.txt")
        XCTAssertEqual((obj?["maxBytes"] as? NSNumber)?.intValue, 100)
    }

    func test_parse_parenthesizedJSON() {
        let reply = ToolCallProtocol.parse(#"TOOL: list_directory({"path": "/a"})"#)
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        XCTAssertEqual(call.name, "list_directory")
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertEqual(obj?["path"] as? String, "/a")
    }

    // Regression: after a tool result the on-device model sometimes fabricates extra
    // "USER:/ASSISTANT:" turns; keep only its own reply.
    func test_parse_dropsFabricatedConversationTurns() {
        let raw = "Action items:\n- Buy milk\n- Call Bob\nUSER: now sort them\nASSISTANT: ok"
        let reply = ToolCallProtocol.parse(raw)
        XCTAssertEqual(reply, .text("Action items:\n- Buy milk\n- Call Bob"))
    }

    func test_sanitizeAnswer_keepsCleanReply() {
        XCTAssertEqual(ToolCallProtocol.sanitizeAnswer("There are 3 files."), "There are 3 files.")
    }

    func test_parse_keywordArg_withCommaInsideQuotes() {
        let reply = ToolCallProtocol.parse(#"TOOL: search(query: "a, b", scope: "here")"#)
        guard case .toolCalls(let calls) = reply, let call = calls.first else { return XCTFail() }
        let obj = try? JSONSerialization.jsonObject(with: call.argumentsJSON) as? [String: Any]
        XCTAssertEqual(obj?["query"] as? String, "a, b")   // comma inside quotes not split
        XCTAssertEqual(obj?["scope"] as? String, "here")
    }
}
