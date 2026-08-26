// SPDX-License-Identifier: Apache-2.0
// AutomationHostBridge.swift - the minimal host capability surface the Automation
// Core needs. PCApp conforms to this (it owns the panels, op engine, config and
// command registry); DefaultAutomationCore drives it. Keeping the bridge in terms
// of Core vocabulary (paths, AutomationEntry, JSON) decouples the core logic from
// AppKit and makes it unit-testable against a fake bridge.

import Foundation
import PCFoundation

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

/// What Vision could make of a picture. Text first, because a scan or a screenshot is a document
/// that happens to be stored as pixels, and its words are what a file manager can act on; the
/// labels are the fallback for a photograph, which has none.
public struct ImageDescription: Codable, Sendable, Equatable {
    /// The text found on the image, in reading order.
    public var text: String
    /// What the image appears to show, most confident first — "beach", "document", "cat".
    public var labels: [String]
    public init(text: String = "", labels: [String] = []) {
        self.text = text
        self.labels = labels
    }
    public var isEmpty: Bool { text.isEmpty && labels.isEmpty }
}

public protocol AutomationHostBridge: Sendable {
    // Context / reads
    func context() async throws -> AutomationContext
    func listDirectory(_ path: String) async throws -> [AutomationEntry]
    func stat(_ path: String) async throws -> AutomationEntry
    func readFile(_ path: String, maxBytes: Int) async throws -> String
    /// Read a bounded slice starting at `offset` bytes. A file too large for the model's
    /// context window is read in slices, so this is what makes a long document readable
    /// at all. Defaulted below, so an existing bridge keeps working.
    func readFile(_ path: String, maxBytes: Int, offset: Int) async throws -> String
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

    /// Find files through the system's own file index, anywhere it reaches (F-446).
    ///
    /// The counterpart to `search`, which walks a directory tree: this asks macOS's index instead, so
    /// it can answer about the whole disk without a walk and can match words *inside* files. The
    /// arguments are the structured form of a description — kind, name, a modification window, a size
    /// range — because the translation from language belongs to the model and the finding does not.
    /// Returns the matches and a description of where it looked, for a caller that has to explain an
    /// empty result.
    func findFiles(nameMask: String, contentText: String?, kind: String?, withinDays: Int?,
                   largerThanBytes: Int64?, smallerThanBytes: Int64?,
                   scope: String, limit: Int) async throws -> (entries: [AutomationEntry], scope: String)

    /// Rename many files in one folder as one all-or-nothing step (F-447).
    ///
    /// Returns the refusals instead of applying part of the batch: a model-proposed table with one bad
    /// row is usually a systematic mistake, and half of it applied is a folder to untangle by hand.
    func renameBatch(directory: String, oldNames: [String], newNames: [String])
        async throws -> (renamed: Int, directory: String, problems: [RenameBatchPlan.Problem])

    /// The same checks without doing anything, so the Core can refuse a batch before proposing it.
    func renameBatchProblems(directory: String, oldNames: [String],
                             newNames: [String]) async -> [RenameBatchPlan.Problem]

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
    /// The macOS Finder tags on `path`.
    func getTags(_ path: String) async throws -> [String]
    /// What is in a picture: the text on it, and what it appears to show. Vision, on-device.
    func describeImage(_ path: String) async throws -> ImageDescription
    /// Replace the Finder tags on `path`. An empty list removes them.
    func setTags(_ path: String, tags: [String]) async throws
}

public extension AutomationHostBridge {
    /// Reads from the start and drops the prefix. Correct for any bridge, and cheap at the
    /// sizes a context window allows; a bridge that can seek should override it.
    func readFile(_ path: String, maxBytes: Int, offset: Int) async throws -> String {
        guard offset > 0 else { return try await readFile(path, maxBytes: maxBytes) }
        let bytes = Array(try await readFile(path, maxBytes: offset + maxBytes).utf8)
        guard offset < bytes.count else { return "" }
        return String(decoding: bytes[offset..<min(bytes.count, offset + maxBytes)], as: UTF8.self)
    }
    func semanticSearch(query: String, path: String?, limit: Int) async throws -> [AutomationEntry] { [] }
    /// A bridge with no system index answers "nothing, and here is where I did not look" rather than
    /// throwing: the tool is optional, and a caller must be able to fall back to `search`.
    func findFiles(nameMask: String, contentText: String?, kind: String?, withinDays: Int?,
                   largerThanBytes: Int64?, smallerThanBytes: Int64?,
                   scope: String, limit: Int) async throws -> (entries: [AutomationEntry], scope: String) {
        ([], "no system file index on this host")
    }
    func renameBatch(directory: String, oldNames: [String], newNames: [String])
        async throws -> (renamed: Int, directory: String, problems: [RenameBatchPlan.Problem]) {
        (0, directory, [RenameBatchPlan.Problem(name: "(the batch)",
                                                reason: "this host cannot rename files")])
    }
    /// No opinion by default: a host that cannot rename says so when asked to, not when asked about it.
    func renameBatchProblems(directory: String, oldNames: [String],
                             newNames: [String]) async -> [RenameBatchPlan.Problem] { [] }
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
    func getTags(_ path: String) async throws -> [String] { throw AutomationError.notImplemented("get_tags") }
    func describeImage(_ path: String) async throws -> ImageDescription { throw AutomationError.notImplemented("describe_image") }
    func setTags(_ path: String, tags: [String]) async throws { throw AutomationError.notImplemented("set_tags") }
}

public extension AutomationHostBridge {
    /// Hosts that do not classify their commands get the safe answer for all of them.
    func commandInfo(_ id: String) async -> AutomationCommandInfo { .unknown }
}
