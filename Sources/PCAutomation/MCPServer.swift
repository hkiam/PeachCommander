// SPDX-License-Identifier: Apache-2.0
// MCPServer.swift - a Model Context Protocol adapter over the Automation Core.
//
// Exposes the file manager's automation tools to external agents (Claude Code,
// Codex) as MCP tools. This type is the transport-agnostic protocol engine: it
// turns a JSON-RPC 2.0 request into a response by driving an AutomationCore. The
// socket/stdio transport and the settings toggle are wired separately (so this
// layer stays pure and unit-testable). Off by default; the host decides the policy.
//
// Supported methods: `initialize`, `tools/list`, `tools/call`. Because writes are
// gated (plan-then-confirm), a gated `tools/call` returns the plan plus a token and
// a synthetic `pc_confirm` tool executes it — the external client stays in control.

import Foundation

public struct MCPServer: Sendable {
    public static let protocolVersion = "2024-11-05"
    public static let serverName = "peach-commander"

    private let core: AutomationCore
    private let policy: PermissionPolicy

    public init(core: AutomationCore, policy: PermissionPolicy = .standard) {
        self.core = core
        // The withheld capabilities are taken out of the *allow-list*, not only out of the listing.
        //
        // Hiding the tool and refusing it by name is a check on the name, and a name is not the only
        // way to reach a capability: a macro is one tool call (`run_macro`, declared `.write`, so
        // offered) whose steps go straight back through the Core. A macro holding a `run_shell` step
        // was therefore reachable from a socket on any installation that had switched the shell on —
        // past a rule whose whole point is that a remote client cannot get there. Withholding the
        // capability closes the class rather than the spelling: whatever route reaches the step, the
        // step is refused.
        self.policy = PermissionPolicy(autonomy: policy.autonomy,
                                       allowed: policy.allowed.subtracting(Self.notOfferedRemotely))
    }

    /// Capabilities that are not offered over MCP at all, whatever the policy says.
    ///
    /// The gate here is *plan then confirm*, and the thing that confirms is the external client —
    /// that is what "the external client stays in control" means, and it is the right shape for the
    /// file operations an agent was connected to perform. It is the wrong shape for running a program
    /// of the agent's choosing, where the same arrangement reads as the agent approving itself.
    ///
    /// In the app, `run_shell` puts a dialog in front of a person with the command quoted in full.
    /// There is no equivalent over a socket, so the tool is simply not there. Refusing it at
    /// `tools/list` as well as at the call means a client never sees a capability it cannot have.
    ///
    /// `.script` is here for the same reason and one more: an AppleScript can send Apple events to
    /// *other* applications, so a remote client running one reaches past this app entirely — past
    /// the catalogue, past the audit log, past anything the policy could hold it to.
    static let notOfferedRemotely: Set<Capability> = [.shell, .script]

    static func offered(_ tools: [ToolDefinition]) -> [ToolDefinition] {
        tools.filter { !notOfferedRemotely.contains($0.capability) }
    }

    /// The confirm pseudo-tool exposed alongside the catalogue.
    static let confirmTool = ToolDefinition(
        "pc_confirm", .runCommand, "Confirm and execute a previously returned plan.",
        [.init("token", .string, "The confirmation token from a gated tool call.")])

    /// Handle one JSON-RPC message. Returns the response bytes, or nil for a
    /// notification (no `id`).
    public func handle(_ request: Data) async -> Data? {
        guard let obj = (try? JSONSerialization.jsonObject(with: request)) as? [String: Any] else {
            return Self.errorResponse(id: nil, code: -32700, message: "Parse error")
        }
        let id = obj["id"]                      // may be Int, String, or absent (notification)
        guard let method = obj["method"] as? String else {
            return id == nil ? nil : Self.errorResponse(id: id, code: -32600, message: "Invalid request")
        }
        let params = obj["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            return Self.result(id: id, [
                "protocolVersion": Self.protocolVersion,
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": Self.serverName, "version": String(PCAutomationVersion)],
            ])
        case "notifications/initialized":
            return nil   // notification
        case "tools/list":
            let tools = (Self.offered(core.tools) + [Self.confirmTool]).map { $0.schemaObject() }
            return Self.result(id: id, ["tools": tools])
        case "tools/call":
            return await handleToolsCall(id: id, params: params)
        default:
            return Self.errorResponse(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    private func handleToolsCall(id: Any?, params: [String: Any]) async -> Data? {
        guard let name = params["name"] as? String else {
            return Self.errorResponse(id: id, code: -32602, message: "Missing tool name")
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let argsData = try? JSONSerialization.data(withJSONObject: arguments)

        do {
            let outcome: AutomationOutcome
            if name == Self.confirmTool.name {
                let token = arguments["token"] as? String ?? ""
                outcome = try await core.confirm(token: token)
            } else if let tool = core.tools.first(where: { $0.name == name }),
                      Self.notOfferedRemotely.contains(tool.capability) {
                // Not listed, and refused if asked for anyway: a client that guessed the name — or
                // one written against a future version — must not get it because the listing was the
                // only thing standing in the way.
                return Self.errorResponse(id: id, code: -32601,
                                          message: "\(name) is not available over MCP")
            } else {
                outcome = try await core.invoke(tool: name, arguments: argsData, policy: policy)
            }
            switch outcome {
            case .ok(let payload):
                let text = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "OK"
                return Self.toolResult(id: id, text: text, isError: false)
            case .needsConfirmation(let plan, let token):
                return Self.toolResult(id: id,
                    text: "Confirmation required: \(plan)\nCall the `pc_confirm` tool with token \"\(token)\" to proceed.",
                    isError: false)
            case .refused(let reason):
                return Self.toolResult(id: id, text: "Refused: \(reason)", isError: true)
            case .failed(let error):
                return Self.toolResult(id: id, text: "Failed: \(error)", isError: true)
            }
        } catch let e as AutomationError {
            // The same readable form the in-app agent gets: an external agent has to recover from
            // this too, and it cannot act on a printed Swift enum either.
            return Self.toolResult(id: id, text: DefaultAutomationCore.readableError(e, tool: name),
                                   isError: true)
        } catch {
            return Self.toolResult(id: id, text: "Error: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - JSON-RPC framing

    private static func envelope(id: Any?, _ body: [String: Any]) -> Data? {
        var msg: [String: Any] = ["jsonrpc": "2.0"]
        msg["id"] = id ?? NSNull()
        for (k, v) in body { msg[k] = v }
        return try? JSONSerialization.data(withJSONObject: msg, options: [.sortedKeys])
    }
    private static func result(id: Any?, _ result: [String: Any]) -> Data? {
        envelope(id: id, ["result": result])
    }
    private static func errorResponse(id: Any?, code: Int, message: String) -> Data? {
        envelope(id: id, ["error": ["code": code, "message": message]])
    }
    private static func toolResult(id: Any?, text: String, isError: Bool) -> Data? {
        result(id: id, ["content": [["type": "text", "text": text]], "isError": isError])
    }
}
