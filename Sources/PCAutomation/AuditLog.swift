// SPDX-License-Identifier: Apache-2.0
// AuditLog.swift — what the assistant actually did, and how to take it back.
//
// The Automation Core was described as an audited seam and audited nothing: there was no
// record of which tools ran, with which arguments, on whose behalf. For a feature that
// moves and renames a user's files that record is not a nicety — it is the thing that makes
// the autonomy levels above "read-only" defensible, and the thing a user needs when an
// assistant did something they did not follow.
//
// Append-only JSONL under the config root, written by DefaultAutomationCore at the single
// point where a tool executes, so every consumer (the in-app chat, the MCP server, a
// plugin-contributed tool) is covered by construction rather than by remembering to log.
//
// Undo is deliberately narrow and honest: an entry carries an inverse only where one really
// exists — a rename can be renamed back, a move can be moved back. A file that was
// overwritten cannot be restored without a copy that was never made, and macOS offers no
// public way to put an item back from the Trash. Those entries say so instead of offering a
// button that would lie.

import Foundation

/// One executed automation action.
public struct AuditEntry: Codable, Sendable, Equatable {
    public var at: Double
    public var tool: String
    public var capability: String
    /// The arguments as JSON text, bounded — a `write_file` carries a whole document.
    public var arguments: String
    /// "ok", "refused" or "failed".
    public var outcome: String
    /// The failure or refusal reason, when there is one.
    public var detail: String?
    /// The tool and arguments that would take this action back, when such a thing exists.
    public var undoTool: String?
    public var undoArguments: String?
    /// Why this action cannot be undone (shown instead of an offer to undo it).
    public var undoUnavailable: String?

    public var isUndoable: Bool { undoTool != nil && undoArguments != nil && outcome == "ok" }

    /// A one-line description for a log view.
    public var summary: String {
        let arguments = self.arguments.count > 120
            ? String(self.arguments.prefix(120)) + "…" : self.arguments
        let mark = outcome == "ok" ? "" : " — \(outcome)\(detail.map { ": \($0)" } ?? "")"
        return "\(tool) \(arguments)\(mark)"
    }
}

/// The log file. Reads and writes are whole-file operations: the log is capped, one line per
/// action, and an assistant produces actions at human speed.
public struct AuditLog: Sendable {
    public let url: URL
    public let cap: Int

    public init(url: URL, cap: Int = 2000) {
        self.url = url
        self.cap = cap
    }

    public func append(_ entry: AuditEntry) {
        var entries = load()
        entries.append(entry)
        if entries.count > cap { entries.removeFirst(entries.count - cap) }
        write(entries)
    }

    /// Newest first.
    public func recent(limit: Int = 50) -> [AuditEntry] {
        Array(load().suffix(max(0, limit)).reversed())
    }

    /// The newest action that can still be taken back.
    public func lastUndoable() -> AuditEntry? {
        load().last { $0.isUndoable }
    }

    /// Mark an entry as taken back, so the same action is not undone twice. Matched on time
    /// and tool: two actions cannot share a timestamp from the same writer.
    public func markUndone(_ entry: AuditEntry) {
        var entries = load()
        guard let index = entries.lastIndex(where: { $0.at == entry.at && $0.tool == entry.tool }) else { return }
        entries[index].undoTool = nil
        entries[index].undoArguments = nil
        entries[index].undoUnavailable = "already undone"
        write(entries)
    }

    public func load() -> [AuditEntry] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return text.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(AuditEntry.self, from: data)
        }
    }

    private func write(_ entries: [AuditEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let lines = entries.compactMap { entry -> String? in
            guard let data = try? encoder.encode(entry) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? Data((lines.joined(separator: "\n") + "\n").utf8).write(to: url, options: .atomic)
    }
}

/// Builds the inverse of an action, where one exists. Separate from the log so the rules are
/// in one readable place and can be tested without touching a file.
public enum AuditInverse {

    /// The tool and arguments that undo `tool(arguments)`, or the reason none can.
    /// `context` supplies what the arguments alone do not say — for a move, where the files
    /// came from.
    public static func of(tool: String, arguments: [String: Any])
        -> (tool: String, arguments: [String: Any])? {
        switch tool {
        case "rename":
            // Rename back: the new name sits in the old name's directory.
            guard let path = arguments["path"] as? String,
                  let newName = arguments["new_name"] as? String else { return nil }
            let directory = (path as NSString).deletingLastPathComponent
            let renamed = (directory as NSString).appendingPathComponent(newName)
            return ("rename", ["path": renamed, "new_name": (path as NSString).lastPathComponent])
        case "move":
            // Move back: each file returns to the directory it came from. Only sound when they
            // all came from the same one, which is the case the panels produce.
            guard let sources = arguments["sources"] as? [String],
                  let destination = arguments["destination"] as? String,
                  let first = sources.first else { return nil }
            let origins = Set(sources.map { ($0 as NSString).deletingLastPathComponent })
            guard origins.count == 1 else { return nil }
            let moved = sources.map {
                (destination as NSString).appendingPathComponent(($0 as NSString).lastPathComponent)
            }
            return ("move", ["sources": moved,
                             "destination": (first as NSString).deletingLastPathComponent])
        case "rename_batch":
            // The same batch with the lists swapped. Sound for the whole batch precisely because the
            // batch is all-or-nothing: every pair either happened or none did, so swapping them cannot
            // describe a state the folder was never in.
            guard let old = arguments["old_names"] as? [String],
                  let new = arguments["new_names"] as? [String], old.count == new.count else { return nil }
            var swapped: [String: Any] = ["old_names": new, "new_names": old]
            if let directory = arguments["directory"] as? String { swapped["directory"] = directory }
            return ("rename_batch", swapped)
        case "set_comment":
            // The previous comment is not in the arguments; the caller records it if it wants
            // this undoable. Nothing to build here.
            return nil
        default:
            return nil
        }
    }

    /// Why an action of this kind cannot be taken back. `nil` when it can.
    public static func unavailableReason(tool: String) -> String? {
        switch tool {
        case "rename", "move", "rename_batch":
            return nil
        case "write_file":
            return "the previous contents were not kept"
        case "move_to_trash":
            return "items can be restored from the Trash in the Finder"
        case "delete_permanently":
            return "a permanent deletion cannot be undone"
        case "make_directory":
            return "the folder was created; remove it yourself if it is not wanted"
        case "copy", "merge_files":
            return "the copy can be deleted; the originals are untouched"
        case "set_config":
            return "the previous value was not kept"
        case "run_shell", "run_command":
            return "what a command did is not known here"
        default:
            return "this action has no inverse"
        }
    }
}
