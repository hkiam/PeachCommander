// SPDX-License-Identifier: Apache-2.0
// PermissionPolicy.swift - the capability/autonomy model shared by every consumer
// of the Automation Core (the in-app AI agent, the MCP server, the future Python
// plugin). Permissions and auditing live here, in one place, so no consumer can
// exceed what a session is allowed to do. See docs/analysis/ai-agent-plugin-plan.md.

import Foundation

/// A coarse capability an automation action needs. The permission policy grants or
/// withholds these per session/provider.
public enum Capability: String, Codable, Sendable, CaseIterable {
    case read        // list/stat/read file content, read context
    case navigate    // change panel/tab/current folder, selection
    case write       // copy/move/mkdir/rename/pack/extract/setAttributes
    case delete      // move to Trash or delete permanently
    case config      // read/write the file-manager configuration
    case runCommand  // invoke an arbitrary cm_* command
    case network     // network access (remote FS, downloads, cloud model, MCP)
}

/// How much an automation session may do without asking the user first.
public enum Autonomy: String, Codable, Sendable, CaseIterable {
    case readOnly       // may only read/analyze; never mutates
    case confirmWrites  // reads freely; write/delete/config present a plan to approve
    case autonomous     // may perform writes without confirmation (explicit opt-in)
}

/// The effective permissions for one automation session.
public struct PermissionPolicy: Sendable, Equatable, Codable {
    public var autonomy: Autonomy
    /// Capabilities the session is allowed to use at all (a hard allow-list).
    public var allowed: Set<Capability>

    public init(autonomy: Autonomy = .confirmWrites,
                allowed: Set<Capability> = Set(Capability.allCases)) {
        self.autonomy = autonomy
        self.allowed = allowed
    }

    /// The recommended default: read/navigate/run freely, but writes need approval.
    public static let standard = PermissionPolicy(autonomy: .confirmWrites)

    /// A safe read-only policy (analysis/suggestions only).
    public static let readOnly = PermissionPolicy(
        autonomy: .readOnly, allowed: [.read, .navigate, .runCommand, .network])

    /// Is this capability permitted at all for the session?
    public func permits(_ cap: Capability) -> Bool { allowed.contains(cap) }

    /// The mutating capabilities.
    static let mutating: Set<Capability> = [.write, .delete, .config]

    /// Whether an action needing `cap` must be confirmed by the user before running.
    /// (Under `.readOnly`, mutating actions are not confirmed — they are refused; use
    /// `decision(for:)` for the full outcome.)
    public func requiresConfirmation(_ cap: Capability) -> Bool {
        autonomy == .confirmWrites && Self.mutating.contains(cap)
    }

    /// The outcome for an action requiring `cap`.
    public enum Decision: String, Sendable, Equatable { case allow, confirm, refuse }

    public func decision(for cap: Capability) -> Decision {
        guard permits(cap) else { return .refuse }
        if Self.mutating.contains(cap) {
            switch autonomy {
            case .readOnly:      return .refuse
            case .confirmWrites: return .confirm
            case .autonomous:    return .allow
            }
        }
        return .allow
    }
}
