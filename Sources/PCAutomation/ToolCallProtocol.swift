// ToolCallProtocol.swift - a text convention that makes any text model tool-capable.
//
// On-device / small models (and plain cloud text endpoints) don't all expose native
// tool-calling, so we teach the model a tiny protocol: to use a tool it replies with
// exactly one line `TOOL: <name> <json-args>`; otherwise it answers normally. The
// provider parses that into a ModelReply, and the existing AgentSession loop executes
// the call under the permission policy and feeds the result back. This is uniform
// across providers and fully unit-testable. (Native FoundationModels `Tool` calling
// is a future enhancement — see docs/analysis/ai-agent-enhancements.md.)

import Foundation

public enum ToolCallProtocol {
    public static let directive = "TOOL:"

    /// Instructions describing the available tools and how to call them, appended to
    /// a provider's system prompt.
    public static func instructions(for tools: [ToolDefinition]) -> String {
        var s = """
        You can use tools to inspect and act on the file manager. To call a tool, reply \
        with EXACTLY one line and nothing else:
        \(directive) <tool_name> <json-arguments>
        The tool name comes first, then a space, then a SINGLE JSON object of arguments \
        (use {} when there are none). For example:
        \(directive) list_directory {"path": "/Users/me/Documents"}
        \(directive) get_context {}
        Only call a tool when you need it; when you have the final answer, reply normally \
        (no \(directive) line). After a tool runs you will see its result and can continue.
        Give ONLY your own reply. Never write lines that begin with "USER:", "ASSISTANT:" \
        or "SYSTEM:", and never invent extra conversation turns or additional questions — \
        after a tool result, either call another tool or state your final answer directly.

        Available tools (name — description; arguments follow):

        """
        for t in tools {
            let params = t.parameters.map { "\($0.name)\($0.required ? "" : "?")" }
                .joined(separator: ", ")
            let args = params.isEmpty ? "no arguments" : "arguments: \(params)"
            s += "- \(t.name) — \(t.summary) [\(args)]\n"
        }
        return s
    }

    /// Parse a model's raw text into either a tool call or a final text answer.
    ///
    /// Small models don't always follow the exact `TOOL: name {json}` convention — they
    /// frequently emit function-call syntax like `TOOL: search(query: "notes")` or
    /// `TOOL: read_file(path: "/a", maxBytes: 100)`. We parse the tool name as the leading
    /// identifier and coerce whatever follows (a JSON object, parenthesized JSON, or
    /// Swift-ish `key: value` pairs) into a JSON arguments object.
    public static func parse(_ text: String) -> ModelReply {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(directive) else { continue }
            let rest = line.dropFirst(directive.count).trimmingCharacters(in: .whitespaces)
            guard !rest.isEmpty else { continue }
            // Tool name = leading identifier (letters/digits/underscore); stop at the
            // first space, '(' or '{'. This rejects the old bug where "search(query:"
            // became the tool name.
            let name = String(rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
            guard !name.isEmpty else { continue }
            var argRegion = String(rest.dropFirst(name.count)).trimmingCharacters(in: .whitespaces)
            // Unwrap one layer of surrounding parentheses: name(...) → ...
            if argRegion.hasPrefix("("), argRegion.hasSuffix(")") {
                argRegion = String(argRegion.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            }
            return .toolCalls([ModelToolCall(id: UUID().uuidString, name: name,
                                             argumentsJSON: coerceArgs(argRegion))])
        }
        return .text(sanitizeAnswer(text))
    }

    /// Small text-convention models sometimes keep going after their answer and fabricate
    /// further conversation turns ("USER: …", "ASSISTANT: …"). Keep only the model's own
    /// reply: drop everything from the first fabricated role marker onward.
    static func sanitizeAnswer(_ text: String) -> String {
        var kept: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()
            if trimmed.hasPrefix("USER:") || trimmed.hasPrefix("ASSISTANT:") || trimmed.hasPrefix("SYSTEM:") {
                break
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Argument coercion

    /// Turn a tool call's argument text into a JSON object, tolerating the shapes small
    /// models actually produce: a JSON object, or `key: value, key2: "v2"` keyword args.
    static func coerceArgs(_ raw: String) -> Data {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return Data("{}".utf8) }
        if s.hasPrefix("{"), let d = s.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: d)) is [String: Any] {
            return d
        }
        if let obj = parseKeywordArgs(s) { return obj }
        return Data("{}".utf8)
    }

    private static func parseKeywordArgs(_ s: String) -> Data? {
        var dict: [String: Any] = [:]
        for piece in splitTopLevel(s, on: ",") {
            guard let colon = piece.firstIndex(of: ":") else { return nil }
            let key = piece[..<colon].trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
            let val = String(piece[piece.index(after: colon)...])
            guard !key.isEmpty else { return nil }
            dict[key] = jsonValue(val)
        }
        guard !dict.isEmpty, let d = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return d
    }

    /// Interpret a single argument value token: real JSON if it parses (numbers, bools,
    /// quoted strings, arrays, objects), otherwise a bare/unquoted string.
    private static func jsonValue(_ token: String) -> Any {
        let t = token.trimmingCharacters(in: .whitespaces)
        if let d = t.data(using: .utf8),
           let v = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) {
            return v
        }
        if t.count >= 2,
           (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
            return String(t.dropFirst().dropLast())
        }
        return t
    }

    /// Split on `sep` at the top level only — not inside quotes or {}/[] brackets.
    private static func splitTopLevel(_ s: String, on sep: Character) -> [String] {
        var parts: [String] = []
        var depth = 0
        var inString: Character?
        var current = ""
        for ch in s {
            if let quote = inString {
                current.append(ch)
                if ch == quote { inString = nil }
                continue
            }
            switch ch {
            case "\"", "'": inString = ch; current.append(ch)
            case "{", "[": depth += 1; current.append(ch)
            case "}", "]": depth = max(0, depth - 1); current.append(ch)
            case sep where depth == 0: parts.append(current); current = ""
            default: current.append(ch)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(current) }
        return parts
    }
}
