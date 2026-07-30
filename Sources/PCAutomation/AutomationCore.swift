// AutomationCore.swift - the seam every automation consumer talks to.
//
// PCApp implements this (it owns the panels, op engine, command registry and
// config); the AI agent plugin, the MCP server, and the future Python plugin all
// consume it. All mutating calls are expected to be checked against a
// PermissionPolicy and, under `.confirmWrites`, to surface a plan the user approves
// before executing — enforcement is the Core implementation's responsibility, not the
// caller's. Results are Codable so they map onto LLM tool results / MCP responses.

import Foundation

/// A single entry returned by a listing/stat operation.
public struct AutomationEntry: Codable, Sendable, Equatable {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modified: Date?
    public init(name: String, path: String, isDirectory: Bool, size: Int64, modified: Date?) {
        self.name = name; self.path = path; self.isDirectory = isDirectory
        self.size = size; self.modified = modified
    }
}

/// A snapshot of the live UI context handed to an automation session.
public struct AutomationContext: Codable, Sendable, Equatable {
    public var activePanelPath: String
    public var inactivePanelPath: String
    public var cursorPath: String?
    public var selection: [String]
    public var tabPaths: [String]
    public var viewMode: String
    public init(activePanelPath: String, inactivePanelPath: String, cursorPath: String?,
                selection: [String], tabPaths: [String], viewMode: String) {
        self.activePanelPath = activePanelPath; self.inactivePanelPath = inactivePanelPath
        self.cursorPath = cursorPath; self.selection = selection
        self.tabPaths = tabPaths; self.viewMode = viewMode
    }
}

/// The result of invoking a tool: success with a JSON-encodable payload, a request
/// for confirmation (a human-readable plan), or a refusal.
public enum AutomationOutcome: Sendable, Equatable {
    /// The action ran; `payload` is a JSON result (nil for pure side-effects).
    case ok(payload: Data?)
    /// A write/delete/config action under `.confirmWrites`: `plan` is a
    /// human-readable description; call `confirm(token:)` to execute it.
    case needsConfirmation(plan: String, token: String)
    /// The policy forbids this capability (or the autonomy level refuses it).
    case refused(reason: String)
    /// The action was attempted and failed.
    case failed(error: String)
}

/// Errors the Core may throw for malformed requests.
public enum AutomationError: Error, Sendable, Equatable {
    case unknownTool(String)
    case missingArgument(String)
    case notImplemented(String)
}

/// The automation seam. A concrete implementation lives in PCApp; consumers hold
/// this protocol. Every method is async and main-actor-free at the protocol level
/// (the implementation hops to the main actor as needed).
public protocol AutomationCore: Sendable {
    /// The catalogue of tools this core advertises (defaults to the shared catalogue).
    var tools: [ToolDefinition] { get }

    /// A snapshot of the current UI context.
    func context() async throws -> AutomationContext

    /// Invoke a tool by name with JSON arguments, under `policy`. The implementation
    /// enforces the policy: it returns `.needsConfirmation` for gated writes, or
    /// `.refused` when the policy forbids the capability.
    func invoke(tool name: String, arguments: Data?, policy: PermissionPolicy) async throws -> AutomationOutcome

    /// Confirm a previously returned plan (its `token`) and execute it.
    func confirm(token: String) async throws -> AutomationOutcome

    /// The host event stream (panel/selection/operation/config/search).
    func events() -> AsyncStream<HostEvent>
}

public extension AutomationCore {
    var tools: [ToolDefinition] { AutomationCatalog.tools }
}
