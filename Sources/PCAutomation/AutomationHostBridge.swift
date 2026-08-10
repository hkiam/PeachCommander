// SPDX-License-Identifier: Apache-2.0
// AutomationHostBridge.swift - the minimal host capability surface the Automation
// Core needs. PCApp conforms to this (it owns the panels, op engine, config and
// command registry); DefaultAutomationCore drives it. Keeping the bridge in terms
// of Core vocabulary (paths, AutomationEntry, JSON) decouples the core logic from
// AppKit and makes it unit-testable against a fake bridge.

import Foundation

/// What a `cm_*` command does, from the policy's point of view.
///
/// `run_command` can invoke any command the app has, and several of them are the very actions the
/// dedicated tools gate: `cm_DeleteReal` deletes exactly what `delete_permanently` deletes. Its
/// capability was `.runCommand`, which is not one of the mutating ones, so under the default
/// "confirm writes" policy `delete_permanently` presented a plan and `run_command("cm_DeleteReal")`
/// simply ran. Measured before it was changed — the outcome was `ok`, with nothing to approve.
///
/// So the decision is made about the *command*, not about the tool that names it.
public struct AutomationCommandInfo: Sendable, Equatable {
    /// The capability invoking this command really needs.
    public var capability: Capability
    /// A human phrase for the confirmation ("Delete selection permanently"), when the host has one.
    /// Without it the user would be asked to approve "Run run_command", which is not a decision
    /// anybody can make.
    public var label: String?

    public init(capability: Capability, label: String? = nil) {
        self.capability = capability
        self.label = label
    }

    /// What an unrecognised command is assumed to be: something that changes things.
    ///
    /// Fails closed on purpose. A command missing from the host's classification then costs one
    /// confirmation; the other default would let the next destructive command added to the app
    /// through unannounced, which is how this defect existed in the first place.
    public static let unknown = AutomationCommandInfo(capability: .write)
}

public protocol AutomationHostBridge: Sendable {
    // Context / reads
    func context() async throws -> AutomationContext
    func listDirectory(_ path: String) async throws -> [AutomationEntry]
    func stat(_ path: String) async throws -> AutomationEntry
    func readFile(_ path: String, maxBytes: Int) async throws -> String
    func search(queryJSON: Data) async throws -> [AutomationEntry]
    func getConfig(_ key: String) async throws -> String?
    func listCommandsJSON() async throws -> Data
    func listPluginsJSON() async throws -> Data

    // Navigate
    func openPath(_ path: String) async throws
    func openInPanel(_ path: String, side: String) async throws
    func setSelection(mask: String) async throws
    func runCommand(_ id: String) async throws
    /// Run `command` in a terminal tab the user can see, and return what it printed.
    func runShell(_ command: String) async throws -> String

    /// What invoking `id` amounts to, so `run_command` is held to the same policy as the tool that
    /// does the same thing directly. See `AutomationCommandInfo`.
    func commandInfo(_ id: String) async -> AutomationCommandInfo

    // Write / delete / config (only reached after the policy allows/confirms)
    func copy(sources: [String], destination: String) async throws
    func move(sources: [String], destination: String) async throws
    func rename(path: String, newName: String) async throws
    func makeDirectory(_ path: String) async throws
    func setConfig(_ key: String, _ value: String) async throws
    func moveToTrash(_ paths: [String]) async throws
    func deletePermanently(_ paths: [String]) async throws

    /// Rank files in `path` (or the active folder) by semantic similarity of their
    /// names to `query`, best first. Default: unsupported (empty).
    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry]

    /// Long-term memory (persists across chats). Defaults: no-op / empty.
    func remember(_ text: String) async throws
    func recall(_ query: String, limit: Int) async throws -> [String]

    /// Compute a file's hash (algorithm: sha256|sha1|md5). Write UTF-8 text to a file.
    func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String)
    func writeFile(_ path: String, content: String) async throws

    /// Merge `sources` (or the current selection when empty) into a single new file at
    /// `destination`, keeping a CSV header only once. Returns the resolved destination
    /// path, how many files were merged, and how many data rows were written.
    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int)

    /// The comment attached to a path, or nil when it has none. Set or clear it (empty clears).
    ///
    /// A capability of the *host*, not of the file: where the comment lives (descript.ion beside the
    /// file, the Finder comment, both) is the host's business, and a core that knew would have to know
    /// about all of them.
    func getComment(_ path: String) async throws -> String?
    func setComment(_ path: String, comment: String?) async throws
}

public extension AutomationHostBridge {
    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] { [] }
    func remember(_ text: String) async throws {}
    func recall(_ query: String, limit: Int) async throws -> [String] { [] }
    func hashFile(_ path: String, algorithm: String) async throws -> (hash: String, algorithm: String) {
        throw AutomationError.notImplemented("hash_file")
    }
    func writeFile(_ path: String, content: String) async throws { throw AutomationError.notImplemented("write_file") }
    func mergeFiles(sources: [String], destination: String) async throws -> (destination: String, count: Int, rows: Int) {
        throw AutomationError.notImplemented("merge_files")
    }
    func getComment(_ path: String) async throws -> String? { throw AutomationError.notImplemented("get_comment") }
    func setComment(_ path: String, comment: String?) async throws { throw AutomationError.notImplemented("set_comment") }
}

public extension AutomationHostBridge {
    /// Hosts that do not classify their commands get the safe answer for all of them.
    func commandInfo(_ id: String) async -> AutomationCommandInfo { .unknown }
}
