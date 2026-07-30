// RemoteAutomationCore.swift — an AutomationCore backed by the host's contrib C-ABI.
//
// The AI assistant runs inside a removable plugin bundle; it does NOT own the file
// manager. Instead it drives the host's automation engine over the PcHostServices
// automation* callbacks (contrib.h). AgentSession / AppleNativeToolSession are written
// against the `AutomationCore` protocol, so swapping the in-process DefaultAutomationCore
// for this remote one is the only change needed — plan-then-confirm still flows through
// the host (it applies the policy and returns a token; we call confirm with it).
//
// The host callbacks BLOCK (they run the async core on the main actor and wait), so we
// always call them off the main thread to avoid deadlocking the UI.

import Foundation
import PCAutomation

final class RemoteAutomationCore: AutomationCore, @unchecked Sendable {
    // A by-value copy of the services table: the `host` token + function pointers stay
    // valid for the plugin/view lifetime (the host bridge is long-lived).
    private let services: PcHostServices
    // Tools from an external MCP server (KI-01), merged into the catalogue and routed
    // to the client. Text-convention providers (cloud) can call them; the native Apple
    // path uses static @Generable tools and so can't (documented limitation).
    private let mcp: MCPClient?
    private let mcpTools: [ToolDefinition]

    init(services: PcHostServices, mcp: MCPClient? = nil, mcpTools: [ToolDefinition] = []) {
        self.services = services
        self.mcp = mcp
        self.mcpTools = mcpTools
    }

    var tools: [ToolDefinition] { AutomationCatalog.tools + mcpTools }

    func context() async throws -> AutomationContext {
        guard let json = await call({ s in s.automationContextJson?(s.host) }),
              let data = json.data(using: .utf8),
              let ctx = try? JSONDecoder().decode(AutomationContext.self, from: data) else {
            throw AutomationError.notImplemented("context")
        }
        return ctx
    }

    func invoke(tool name: String, arguments: Data?, policy: PermissionPolicy) async throws -> AutomationOutcome {
        // Route external MCP tools to the MCP server instead of the host core.
        if let mcp, mcpTools.contains(where: { $0.name == name }) {
            let args = (arguments.flatMap { try? JSONSerialization.jsonObject(with: $0) }) as? [String: Any] ?? [:]
            let inner = (args["arguments"] as? [String: Any]) ?? args
            let text = (try? await mcp.callTool(name: name, arguments: inner)) ?? "(MCP call failed)"
            return .ok(payload: try? JSONSerialization.data(withJSONObject: ["result": text]))
        }
        let argsStr = arguments.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let json = await call { s in
            name.withCString { np in argsStr.withCString { ap in s.automationInvoke?(s.host, np, ap) } }
        }
        return Self.decodeOutcome(json)
    }

    func confirm(token: String) async throws -> AutomationOutcome {
        let json = await call { s in token.withCString { tp in s.automationConfirm?(s.host, tp) } }
        return Self.decodeOutcome(json)
    }

    func events() -> AsyncStream<HostEvent> { AsyncStream { $0.finish() } }

    // MARK: - Off-main C call + string ownership

    /// Run `body` (a blocking host callback returning a malloc'd C string) on a
    /// background thread, copy the result to a Swift String, and free it via the host.
    private func call(_ body: @escaping @Sendable (PcHostServices) -> UnsafeMutablePointer<CChar>?) async -> String? {
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            DispatchQueue.global().async { [self] in
                let ptr = body(self.services)
                let str = ptr.map { String(cString: $0) }
                if let ptr { self.services.automationFree?(self.services.host, ptr) }
                cont.resume(returning: str)
            }
        }
    }

    static func decodeOutcome(_ json: String?) -> AutomationOutcome {
        guard let json, let d = json.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let status = o["status"] as? String else {
            return .failed(error: "no response from host")
        }
        switch status {
        case "ok":
            return .ok(payload: (o["payloadB64"] as? String).flatMap { Data(base64Encoded: $0) })
        case "needsConfirmation":
            return .needsConfirmation(plan: o["plan"] as? String ?? "", token: o["token"] as? String ?? "")
        case "refused":
            return .refused(reason: o["reason"] as? String ?? "refused")
        default:
            return .failed(error: o["error"] as? String ?? "failed")
        }
    }
}
