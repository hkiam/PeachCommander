// SPDX-License-Identifier: Apache-2.0
// AppleNativeToolSession.swift - native FoundationModels tool-calling for the on-device
// Apple model, replacing the fragile text convention for that provider.
//
// The on-device model is small: with the text convention it emits malformed calls
// (`search(query: …)`) and fabricates conversation turns. Native tool-calling uses
// guided generation (constrained decoding), so the model's tool choice and arguments
// are ALWAYS structurally valid, and FoundationModels drives the tool loop internally.
//
// We keep the safety model: every native tool routes through the same AutomationCore,
// so PermissionPolicy still gates writes/deletes and plan-then-confirm still applies —
// a gated tool suspends inside its `call`, asks the ConfirmationBroker (the UI), and
// only proceeds after the user confirms. Reads run immediately.
//
// macOS 26 + Apple Intelligence only; everything is availability- and canImport-gated,
// so older systems and non-Apple providers are unaffected (they use ToolCallProtocol).

import Foundation

/// Asked mid-turn to confirm a gated plan (write/delete/config). Returns the user's
/// decision. Implemented by the UI; a headless caller may auto-decide.
public protocol ConfirmationBroker: Sendable {
    func confirmPlan(_ plan: String) async -> Bool
}

#if canImport(FoundationModels)
import FoundationModels

/// Shared execution context for the native tools: runs a tool through the core under
/// the current policy, resolving plan-then-confirm via the broker. A reference type so
/// the policy can be updated between turns while the tool instances stay fixed.
@available(macOS 26, *)
final class NativeToolContext: @unchecked Sendable {
    let core: AutomationCore
    var policy: PermissionPolicy
    let broker: ConfirmationBroker?
    let onProgress: (@Sendable (String) async -> Void)?

    init(core: AutomationCore, policy: PermissionPolicy,
         broker: ConfirmationBroker?, onProgress: (@Sendable (String) async -> Void)?) {
        self.core = core; self.policy = policy; self.broker = broker; self.onProgress = onProgress
    }

    /// Execute tool `name` with JSON `args`, returning a string the model can read.
    /// Gated tools wait for the broker; a decline is reported back to the model.
    func run(_ name: String, _ args: [String: Any]) async -> String {
        #if DEBUG
        NSLog("[native] tool: %@", name)
        #endif
        await onProgress?(name)
        let json = (try? JSONSerialization.data(withJSONObject: args)) ?? Data("{}".utf8)
        do {
            let outcome = try await core.invoke(tool: name, arguments: json, policy: policy)
            switch outcome {
            case .ok(let payload):
                let text = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "OK"
                // Nudge the small model to chain search/list → read_file for CONTENTS
                // (it otherwise answers from names alone or fabricates).
                if name == "search" || name == "list_directory" {
                    return text + "\n\n[Note: this lists file names/paths only, NOT their "
                        + "contents. To read what is inside a file, call read_file with its path.]"
                }
                return text
            case .refused(let reason):
                return "Refused: \(reason)"
            case .failed(let error):
                return "Failed: \(error)"
            case .needsConfirmation(let plan, let token):
                guard await (broker?.confirmPlan(plan) ?? false) else {
                    return "The user declined this action. Do NOT attempt any other or "
                        + "alternative action; simply acknowledge that you will not make "
                        + "changes, and stop."
                }
                let done = try await core.confirm(token: token)
                if case .ok(let p) = done { return p.flatMap { String(data: $0, encoding: .utf8) } ?? "Done." }
                if case .failed(let e) = done { return "Failed: \(e)" }
                return "Done."
            }
        } catch {
            return "Failed: \(error)"
        }
    }
}

/// Build a JSON dict, dropping empty-string values so optional args are simply omitted.
@available(macOS 26, *)
private func ntArgs(_ pairs: [String: Any]) -> [String: Any] {
    pairs.filter { !(($0.value as? String)?.isEmpty ?? false) }
}

// MARK: - Native tool definitions (one per catalogue entry)

@available(macOS 26, *)
struct NTGetContext: Tool {
    let ctx: NativeToolContext
    var name: String { "get_context" }
    var description: String { "Get the current UI context: active folder, selection, cursor, tabs and view." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("get_context", [:]) }
}

@available(macOS 26, *)
struct NTListDirectory: Tool {
    let ctx: NativeToolContext
    var name: String { "list_directory" }
    var description: String { "List the entries of a folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path or VFS path to list") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("list_directory", ["path": a.path])
    }
}

@available(macOS 26, *)
struct NTStatPath: Tool {
    let ctx: NativeToolContext
    var name: String { "stat_path" }
    var description: String { "Get metadata (size, kind, dates) for a path." }
    @Generable struct Arguments {
        @Guide(description: "Path to inspect") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("stat_path", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTReadFile: Tool {
    let ctx: NativeToolContext
    var name: String { "read_file" }
    var description: String { "Read the text content of a file." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to read") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("read_file", ["path": a.path])
    }
}

@available(macOS 26, *)
struct NTHashFile: Tool {
    let ctx: NativeToolContext
    var name: String { "hash_file" }
    var description: String { "Compute the SHA-256 hash of a file's bytes." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to hash") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("hash_file", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTWriteFile: Tool {
    let ctx: NativeToolContext
    var name: String { "write_file" }
    var description: String { "Create or overwrite a text file with the given content." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file to write") var path: String
        @Guide(description: "The full text content to write into the file") var content: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("write_file", ["path": a.path, "content": a.content])
    }
}

@available(macOS 26, *)
struct NTGetComment: Tool {
    let ctx: NativeToolContext
    var name: String { "get_comment" }
    var description: String { "Read the comment attached to a file or folder. Empty when it has none." }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file or folder") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("get_comment", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTSetComment: Tool {
    let ctx: NativeToolContext
    var name: String { "set_comment" }
    var description: String {
        "Attach a short comment to a file or folder describing what it is for, or clear it with an "
        + "empty string. Use this when the user asks you to note, label, annotate or describe a file. "
        + "The comment is stored beside the file and shown in the panel's Comment column."
    }
    @Generable struct Arguments {
        @Guide(description: "Absolute path of the file or folder") var path: String
        @Guide(description: "The comment text; empty removes the comment") var comment: String
    }
    func call(arguments a: Arguments) async throws -> String {
        // Not ntArgs: an empty comment is how a comment is *removed*, and dropping empty strings
        // would turn "clear this" into a call with no comment argument at all.
        await ctx.run("set_comment", ["path": a.path, "comment": a.comment])
    }
}

@available(macOS 26, *)
struct NTMergeFiles: Tool {
    let ctx: NativeToolContext
    var name: String { "merge_files" }
    var description: String {
        "Combine/merge/concatenate the currently selected files (e.g. CSV files) into one "
        + "new file. Use this for any 'merge/combine the selected files into a new file' "
        + "request. It operates on the current selection, so you ONLY provide the "
        + "destination file name — do not read the files yourself."
    }
    @Generable struct Arguments {
        @Guide(description: "Name of the new merged file, e.g. combined.csv") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("merge_files", ["destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTSearch: Tool {
    let ctx: NativeToolContext
    var name: String { "search" }
    var description: String { "Search for files by name mask and/or text content." }
    @Generable struct Arguments {
        @Guide(description: "Filename wildcard mask, e.g. *.txt (use * for any)") var mask: String
        @Guide(description: "Text to find inside files; empty for none") var text: String
        @Guide(description: "Absolute folder to search in; empty for the active folder") var path: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("search", ["query": ntArgs(["mask": a.mask, "text": a.text, "path": a.path])])
    }
}

@available(macOS 26, *)
struct NTGetConfig: Tool {
    let ctx: NativeToolContext
    var name: String { "get_config" }
    var description: String { "Read a configuration value by its Section.Key." }
    @Generable struct Arguments {
        @Guide(description: "Config key, e.g. Display.NaturalSort") var key: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("get_config", ["key": a.key]) }
}

@available(macOS 26, *)
struct NTListCommands: Tool {
    let ctx: NativeToolContext
    var name: String { "list_commands" }
    var description: String { "List the available commands (id, name, category)." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("list_commands", [:]) }
}

@available(macOS 26, *)
struct NTListPlugins: Tool {
    let ctx: NativeToolContext
    var name: String { "list_plugins" }
    var description: String { "List enabled plugins and their contributed commands." }
    @Generable struct Arguments {}
    func call(arguments: Arguments) async throws -> String { await ctx.run("list_plugins", [:]) }
}

@available(macOS 26, *)
struct NTOpenPath: Tool {
    let ctx: NativeToolContext
    var name: String { "open_path" }
    var description: String { "Open a folder (or reveal a file) in the active panel." }
    @Generable struct Arguments {
        @Guide(description: "Path to open") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("open_path", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTOpenInPanel: Tool {
    let ctx: NativeToolContext
    var name: String { "open_in_panel" }
    var description: String { "Open a path in a specific panel or a new tab." }
    @Generable struct Arguments {
        @Guide(description: "Path to open") var path: String
        @Guide(description: "left, right, or new-tab") var side: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("open_in_panel", ["path": a.path, "side": a.side])
    }
}

@available(macOS 26, *)
struct NTSetSelection: Tool {
    let ctx: NativeToolContext
    var name: String { "set_selection" }
    var description: String { "Select entries in the active panel by a wildcard mask." }
    @Generable struct Arguments {
        @Guide(description: "Wildcard mask, e.g. *.txt") var mask: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("set_selection", ["mask": a.mask]) }
}

@available(macOS 26, *)
struct NTCopy: Tool {
    let ctx: NativeToolContext
    var name: String { "copy" }
    var description: String { "Copy files/folders to a destination folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to copy") var sources: [String]
        @Guide(description: "Destination folder") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("copy", ["sources": a.sources, "destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTMove: Tool {
    let ctx: NativeToolContext
    var name: String { "move" }
    var description: String { "Move files/folders to a destination folder." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to move") var sources: [String]
        @Guide(description: "Destination folder") var destination: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("move", ["sources": a.sources, "destination": a.destination])
    }
}

@available(macOS 26, *)
struct NTRename: Tool {
    let ctx: NativeToolContext
    var name: String { "rename" }
    var description: String { "Rename a single entry in place." }
    @Generable struct Arguments {
        @Guide(description: "Entry to rename") var path: String
        @Guide(description: "New name (one path component)") var newName: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("rename", ["path": a.path, "new_name": a.newName])
    }
}

@available(macOS 26, *)
struct NTMakeDirectory: Tool {
    let ctx: NativeToolContext
    var name: String { "make_directory" }
    var description: String { "Create a new folder." }
    @Generable struct Arguments {
        @Guide(description: "Folder path to create") var path: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("make_directory", ["path": a.path]) }
}

@available(macOS 26, *)
struct NTSetConfig: Tool {
    let ctx: NativeToolContext
    var name: String { "set_config" }
    var description: String { "Set a configuration value by its Section.Key." }
    @Generable struct Arguments {
        @Guide(description: "Config key") var key: String
        @Guide(description: "New value") var value: String
    }
    func call(arguments a: Arguments) async throws -> String {
        await ctx.run("set_config", ["key": a.key, "value": a.value])
    }
}

@available(macOS 26, *)
struct NTMoveToTrash: Tool {
    let ctx: NativeToolContext
    var name: String { "move_to_trash" }
    var description: String { "Move files/folders to the Trash (reversible)." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to move to the Trash") var paths: [String]
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("move_to_trash", ["paths": a.paths]) }
}

@available(macOS 26, *)
struct NTDeletePermanently: Tool {
    let ctx: NativeToolContext
    var name: String { "delete_permanently" }
    var description: String { "Delete files/folders permanently (NOT reversible)." }
    @Generable struct Arguments {
        @Guide(description: "Absolute paths to delete permanently") var paths: [String]
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("delete_permanently", ["paths": a.paths]) }
}

@available(macOS 26, *)
struct NTRunCommand: Tool {
    let ctx: NativeToolContext
    var name: String { "run_command" }
    var description: String { "Invoke a named command (cm_*) by id." }
    @Generable struct Arguments {
        @Guide(description: "The command id, e.g. cm_PackFiles") var commandId: String
    }
    func call(arguments a: Arguments) async throws -> String { await ctx.run("run_command", ["command_id": a.commandId]) }
}

// Guided-generation types for reliable STRUCTURED output (KI-09): the model fills a
// typed schema (constrained decoding) instead of free text, so a table is always
// well-formed.
@available(macOS 26, *)
@Generable struct GeneratedTableRow {
    @Guide(description: "the cell values, one per column, in header order") var cells: [String]
}
@available(macOS 26, *)
@Generable struct GeneratedTable {
    @Guide(description: "the column headers") var headers: [String]
    @Guide(description: "the data rows") var rows: [GeneratedTableRow]
}

/// A conversation that drives the file manager via the on-device Apple model using
/// native tool-calling. Holds a stateful LanguageModelSession so context carries
/// across turns; the tools execute through the shared AutomationCore.
@available(macOS 26, *)
public actor AppleNativeToolSession {
    private let ctx: NativeToolContext
    private let llm: LanguageModelSession
    private let onPartial: (@Sendable (String) async -> Void)?

    public init(core: AutomationCore, policy: PermissionPolicy, instructions: String,
                broker: ConfirmationBroker? = nil,
                onProgress: (@Sendable (String) async -> Void)? = nil,
                onPartial: (@Sendable (String) async -> Void)? = nil) {
        let ctx = NativeToolContext(core: core, policy: policy, broker: broker, onProgress: onProgress)
        self.ctx = ctx
        self.onPartial = onPartial
        self.llm = LanguageModelSession(tools: Self.makeTools(ctx), instructions: instructions)
    }

    public func setPolicy(_ p: PermissionPolicy) { ctx.policy = p }

    /// Produce a well-formed Markdown table from data IN the instruction via guided
    /// generation (constrained decoding fills a typed schema — always valid). Uses a
    /// fresh tool-less session: guided generation + tool-calling don't mix reliably
    /// (the model returns prose after a tool call), so reading happens separately.
    public func generateMarkdownTable(_ instruction: String) async throws -> String {
        let session = LanguageModelSession(instructions: "You produce structured tabular data.")
        let t = try await session.respond(to: instruction, generating: GeneratedTable.self).content
        var md = "| " + t.headers.joined(separator: " | ") + " |\n"
        md += "| " + t.headers.map { _ in "---" }.joined(separator: " | ") + " |\n"
        for r in t.rows { md += "| " + r.cells.joined(separator: " | ") + " |\n" }
        return md
    }

    /// Read a file through the core, then guided-generate a Markdown table from its
    /// contents — the two reliable steps combined (used by the "Make a table" action).
    public func tabulateFile(path: String) async throws -> String {
        let raw = await ctx.run("read_file", ["path": path])
        let content: String
        if let d = raw.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let c = o["content"] as? String { content = c } else { content = raw }
        return try await generateMarkdownTable("Turn the following data into a Markdown table.\n\nData:\n\(content)")
    }

    /// Send a user message and run the whole native tool loop to a final answer,
    /// streaming the growing answer text through `onPartial` (cumulative snapshots).
    /// The small on-device model can transiently throw (e.g. the "unsupported language
    /// or locale" guardrail) or return an empty answer; retry once before giving up.
    public func send(_ text: String) async throws -> String {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                var final = ""
                var snapshots = 0
                for try await partial in llm.streamResponse(to: text) {
                    final = partial.content
                    snapshots += 1
                    await onPartial?(final)
                }
                #if DEBUG
                NSLog("[native] streamed %d snapshots (attempt %d)", snapshots, attempt + 1)
                #endif
                if !final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return final }
                // Empty answer → retry once.
            } catch {
                lastError = error
                #if DEBUG
                NSLog("[native] send attempt %d error: %@", attempt + 1, "\(error)")
                #endif
            }
        }
        // The on-device model failed even after a retry (often a tool-argument
        // deserialize error on a complex request). Surface a clean, actionable message
        // rather than a raw internal error, and don't abort the chat.
        if lastError != nil {
            return "I couldn't complete that reliably — the on-device model produced an "
                + "invalid tool call. Try rephrasing it more simply, splitting it into steps, "
                + "or switching to a cloud model in Settings ▸ AI."
        }
        return ""
    }
}

@available(macOS 26, *)
extension AppleNativeToolSession: NativeTurnRunner {
    public func runTurn(_ text: String, policy: PermissionPolicy) async throws -> String {
        #if DEBUG
        NSLog("[native] runTurn (native tool-calling path)")
        #endif
        setPolicy(policy)
        return try await send(text)
    }

    public func makeTable(fromFile path: String) async throws -> String? {
        try await tabulateFile(path: path)
    }

    static func makeTools(_ ctx: NativeToolContext) -> [any Tool] {
        [NTGetContext(ctx: ctx), NTListDirectory(ctx: ctx), NTStatPath(ctx: ctx), NTReadFile(ctx: ctx),
         NTHashFile(ctx: ctx), NTWriteFile(ctx: ctx), NTMergeFiles(ctx: ctx),
         NTGetComment(ctx: ctx), NTSetComment(ctx: ctx),
         NTSearch(ctx: ctx), NTGetConfig(ctx: ctx), NTListCommands(ctx: ctx), NTListPlugins(ctx: ctx),
         NTOpenPath(ctx: ctx), NTOpenInPanel(ctx: ctx), NTSetSelection(ctx: ctx),
         NTCopy(ctx: ctx), NTMove(ctx: ctx), NTRename(ctx: ctx), NTMakeDirectory(ctx: ctx),
         NTSetConfig(ctx: ctx), NTMoveToTrash(ctx: ctx), NTDeletePermanently(ctx: ctx), NTRunCommand(ctx: ctx)]
    }
}
#endif
