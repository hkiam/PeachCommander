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
    /// Run a shell command line. Its own capability rather than folded into `.write`, because it is
    /// not a kind of writing — it is "run a program of your choosing", which can do everything the
    /// other capabilities can and several things none of them cover. Naming it separately is what
    /// lets a policy grant file operations without granting this.
    case shell
    /// Run an OSA script (AppleScript, JXA, any installed OSA language). Its own capability rather
    /// than folded into `.shell`, for two reasons: a script can drive *other applications* through
    /// Apple events, which "run a program" does not describe, and a user who wants a file-filing
    /// AppleScript must be able to have it without also granting an arbitrary shell.
    case script
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

    /// The capabilities nobody gets by default: each is switched on once, in Settings, or not at all.
    ///
    /// A set rather than a literal at each use site, because the failure mode is silent. When
    /// `.script` was added, `standardWithShell` was spelled "every capability" — so turning the
    /// shell on would have granted scripting too, unannounced, to every session that had asked for
    /// a shell before scripting existed.
    public static let optIn: Set<Capability> = [.shell, .script]

    /// The recommended default: read/navigate/run freely, but writes need approval.
    ///
    /// **Without `.shell` or `.script`.** Every other capability here is something a file manager's
    /// assistant is for; running a program of its choosing is not, and a dialog is a poor place to
    /// meet a capability for the first time. Switching one on is a decision taken once, in Settings,
    /// in the quiet — not one taken under time pressure with a command already written.
    public static let standard = PermissionPolicy(
        autonomy: .confirmWrites, allowed: Set(Capability.allCases).subtracting(optIn))

    /// `standard`, plus the shell — what the setting grants when it is switched on. The approval per
    /// command still applies; this only decides whether the tool exists for the session at all.
    public static let standardWithShell = standard.granting(.shell)

    /// `standard`, plus scripting — what `AI.AllowScript` grants when it is switched on.
    public static let standardWithScript = standard.granting(.script)

    /// This policy with `caps` added to the allow-list. Autonomy is untouched: granting a capability
    /// says the tool exists for the session, never that it may run unconfirmed.
    public func granting(_ caps: Capability...) -> PermissionPolicy {
        PermissionPolicy(autonomy: autonomy, allowed: allowed.union(caps))
    }

    /// A safe read-only policy (analysis/suggestions only).
    public static let readOnly = PermissionPolicy(
        autonomy: .readOnly, allowed: [.read, .navigate, .runCommand, .network])

    /// Is this capability permitted at all for the session?
    public func permits(_ cap: Capability) -> Bool { allowed.contains(cap) }

    /// The mutating capabilities.
    static let mutating: Set<Capability> = [.write, .delete, .config, .shell, .script]

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
