// DefaultAutomationCore.swift - the executable Automation Core.
//
// Enforces the PermissionPolicy (refuse / confirm / allow), implements
// plan-then-confirm for gated write/delete/config actions, dispatches tool calls
// to the AutomationHostBridge, and vends the host event stream. AppKit-free and
// unit-tested against a fake bridge; PCApp supplies the real bridge.

import Foundation

public actor DefaultAutomationCore: AutomationCore {
    /// Executes a plugin-contributed tool by name + JSON args (KI-06). Returns nil if
    /// the plugin can't handle it.
    public typealias ExternalToolRouter = @Sendable (_ name: String, _ arguments: Data?) async -> AutomationOutcome?

    private let bridge: AutomationHostBridge
    private let bus: HostEventBus
    private let externalTools: [ToolDefinition]
    private let externalRouter: ExternalToolRouter?
    private var pending: [String: (tool: String, args: Data?)] = [:]

    /// - Parameters:
    ///   - externalTools: extra tools contributed by plugins (merged into the catalogue,
    ///     policy-gated by their declared capability).
    ///   - externalRouter: executes a contributed tool by name; the host routes to the
    ///     owning plugin.
    public init(bridge: AutomationHostBridge, bus: HostEventBus = HostEventBus(),
                externalTools: [ToolDefinition] = [], externalRouter: ExternalToolRouter? = nil) {
        self.bridge = bridge
        self.bus = bus
        self.externalTools = externalTools
        self.externalRouter = externalRouter
    }

    /// Emit a host event to subscribers (the host calls this via `eventBus`).
    public nonisolated var eventBus: HostEventBus { bus }
    public nonisolated func events() -> AsyncStream<HostEvent> { bus.stream() }
    public nonisolated var tools: [ToolDefinition] { AutomationCatalog.tools + externalTools }
    private nonisolated func toolDefinition(named name: String) -> ToolDefinition? {
        AutomationCatalog.tool(named: name) ?? externalTools.first { $0.name == name }
    }

    public func context() async throws -> AutomationContext { try await bridge.context() }

    public func invoke(tool name: String, arguments: Data?, policy: PermissionPolicy) async throws -> AutomationOutcome {
        guard let tool = toolDefinition(named: name) else { throw AutomationError.unknownTool(name) }
        switch policy.decision(for: tool.capability) {
        case .refuse:
            return .refused(reason: "The current permissions do not allow '\(tool.capability.rawValue)' actions.")
        case .confirm:
            let token = UUID().uuidString
            pending[token] = (name, arguments)
            return .needsConfirmation(plan: planText(tool: name, arguments: arguments), token: token)
        case .allow:
            return await execute(name, arguments)
        }
    }

    public func confirm(token: String) async throws -> AutomationOutcome {
        guard let p = pending.removeValue(forKey: token) else {
            return .failed(error: "Unknown or already-used confirmation token.")
        }
        return await execute(p.tool, p.args)
    }

    /// Number of plans awaiting confirmation (tests/diagnostics).
    public var pendingCount: Int { pending.count }

    // MARK: - Dispatch

    private func execute(_ name: String, _ arguments: Data?) async -> AutomationOutcome {
        // Plugin-contributed tools route to their owning plugin (KI-06).
        if externalTools.contains(where: { $0.name == name }) {
            return await externalRouter?(name, arguments) ?? .failed(error: "No handler for '\(name)'.")
        }
        do {
            let a = Args(arguments)
            switch name {
            case "get_context":   return .ok(payload: try encode(try await bridge.context()))
            case "list_directory": return .ok(payload: try encode(try await bridge.listDirectory(try a.string("path"))))
            case "stat_path":     return .ok(payload: try encode(try await bridge.stat(try a.string("path"))))
            case "read_file":
                let text = try await bridge.readFile(try a.string("path"), maxBytes: a.int("max_bytes", default: 65536))
                return .ok(payload: try json(["content": text]))
            case "search":        return .ok(payload: try encode(try await bridge.search(queryJSON: try a.object("query"))))
            case "hash_file":
                let h = try await bridge.hashFile(try a.string("path"), algorithm: (try? a.string("algorithm")) ?? "sha256")
                return .ok(payload: try json(["hash": h.hash, "algorithm": h.algorithm]))
            case "write_file":
                try await bridge.writeFile(try a.string("path"), content: try a.string("content"))
                return .ok(payload: nil)
            case "merge_files":
                let r = try await bridge.mergeFiles(sources: (try? a.strings("sources")) ?? [],
                                                    destination: try a.string("destination"))
                return .ok(payload: try json(["destination": r.destination,
                                              "files_merged": r.count, "rows": r.rows]))
            case "semantic_search":
                return .ok(payload: try encode(try await bridge.semanticSearch(query: try a.string("query"),
                                                                               path: try? a.string("path"),
                                                                               limit: a.int("limit", default: 10))))
            case "get_config":
                let v = try await bridge.getConfig(try a.string("key"))
                return .ok(payload: try json(["value": v ?? ""]))
            case "remember":
                try await bridge.remember(try a.string("text")); return .ok(payload: try json(["ok": true]))
            case "recall":
                let notes = try await bridge.recall((try? a.string("query")) ?? "", limit: a.int("limit", default: 10))
                return .ok(payload: try json(["notes": notes]))
            case "list_commands": return .ok(payload: try await bridge.listCommandsJSON())
            case "list_plugins":  return .ok(payload: try await bridge.listPluginsJSON())
            case "open_path":     try await bridge.openPath(try a.string("path")); return .ok(payload: nil)
            case "open_in_panel": try await bridge.openInPanel(try a.string("path"), side: try a.string("side")); return .ok(payload: nil)
            case "set_selection": try await bridge.setSelection(mask: try a.string("mask")); return .ok(payload: nil)
            case "run_command":   try await bridge.runCommand(try a.string("command_id")); return .ok(payload: nil)
            case "copy":          try await bridge.copy(sources: try a.strings("sources"), destination: try a.string("destination")); return .ok(payload: nil)
            case "move":          try await bridge.move(sources: try a.strings("sources"), destination: try a.string("destination")); return .ok(payload: nil)
            case "rename":        try await bridge.rename(path: try a.string("path"), newName: try a.string("new_name")); return .ok(payload: nil)
            case "make_directory": try await bridge.makeDirectory(try a.string("path")); return .ok(payload: nil)
            case "set_config":    try await bridge.setConfig(try a.string("key"), try a.string("value")); return .ok(payload: nil)
            case "move_to_trash": try await bridge.moveToTrash(try a.strings("paths")); return .ok(payload: nil)
            case "delete_permanently": try await bridge.deletePermanently(try a.strings("paths")); return .ok(payload: nil)
            default: throw AutomationError.notImplemented(name)
            }
        } catch let e as AutomationError {
            return .failed(error: String(describing: e))
        } catch {
            return .failed(error: error.localizedDescription)
        }
    }

    /// A human-readable description of what a gated action will do (best-effort).
    private func planText(tool: String, arguments: Data?) -> String {
        let a = Args(arguments)
        switch tool {
        case "copy":  return "Copy \((try? a.strings("sources").count) ?? 0) item(s) to \((try? a.string("destination")) ?? "?")."
        case "move":  return "Move \((try? a.strings("sources").count) ?? 0) item(s) to \((try? a.string("destination")) ?? "?")."
        case "rename": return "Rename \((try? a.string("path")) ?? "?") to \((try? a.string("new_name")) ?? "?")."
        case "make_directory": return "Create folder \((try? a.string("path")) ?? "?")."
        case "write_file":
            let p = (try? a.string("path")) ?? "?"
            let n = (try? a.string("content"))?.count ?? 0
            return "Write \(n) characters to \(p)."
        case "merge_files":
            let n = (try? a.strings("sources"))?.count
            let dst = (try? a.string("destination")) ?? "?"
            return "Merge \(n.map { "\($0)" } ?? "the selected") file(s) into \(dst)."
        case "set_config": return "Set \((try? a.string("key")) ?? "?") = \((try? a.string("value")) ?? "?")."
        case "move_to_trash": return "Move \((try? a.strings("paths").count) ?? 0) item(s) to the Trash."
        case "delete_permanently": return "Permanently delete \((try? a.strings("paths").count) ?? 0) item(s). This cannot be undone."
        default: return "Run \(tool)."
        }
    }

    private func encode<T: Encodable>(_ v: T) throws -> Data { try JSONEncoder().encode(v) }
    private func json(_ dict: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: dict) }
}

/// Minimal typed accessor over a tool's JSON arguments.
private struct Args {
    private let dict: [String: Any]
    init(_ data: Data?) {
        dict = (try? JSONSerialization.jsonObject(with: data ?? Data())) as? [String: Any] ?? [:]
    }
    func string(_ k: String) throws -> String {
        guard let v = dict[k] as? String else { throw AutomationError.missingArgument(k) }
        return v
    }
    func strings(_ k: String) throws -> [String] {
        guard let v = dict[k] as? [String] else { throw AutomationError.missingArgument(k) }
        return v
    }
    func int(_ k: String, default d: Int) -> Int { (dict[k] as? Int) ?? d }
    func object(_ k: String) throws -> Data {
        guard let v = dict[k] else { throw AutomationError.missingArgument(k) }
        return try JSONSerialization.data(withJSONObject: v)
    }
}
