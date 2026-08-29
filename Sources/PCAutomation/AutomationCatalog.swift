// SPDX-License-Identifier: Apache-2.0
// AutomationCatalog.swift - the versioned catalogue of automation tools.
//
// Each tool is a named, typed operation the file manager can perform. The catalogue
// is the single source that maps 1:1 onto LLM tool definitions and MCP tools, so
// the agent, the MCP server, and the Python plugin all advertise exactly the same
// capabilities. Tools are declared here even before every one is implemented by the
// host, so the surface is stable and discoverable.

import Foundation

/// The Automation Core contract version. Bumped on incompatible changes.
public let PCAutomationVersion = 1

/// One parameter of a tool.
public struct ToolParameter: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case string, integer, boolean, array, object }
    public let name: String
    public let type: Kind
    public let description: String
    public let required: Bool
    public init(_ name: String, _ type: Kind, _ description: String, required: Bool = true) {
        self.name = name; self.type = type; self.description = description; self.required = required
    }
}

/// A tool the automation surface exposes.
public struct ToolDefinition: Codable, Sendable, Equatable {
    public let name: String
    public let summary: String
    public let capability: Capability
    public let parameters: [ToolParameter]
    public init(_ name: String, _ capability: Capability, _ summary: String,
                _ parameters: [ToolParameter] = []) {
        self.name = name; self.capability = capability; self.summary = summary
        self.parameters = parameters
    }

    /// This tool rendered as a JSON-Schema "tool" object (the shape LLM tool-calling
    /// and MCP both use): {name, description, inputSchema:{type:object, properties, required}}.
    public func schemaObject() -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        for p in parameters {
            properties[p.name] = ["type": p.type.rawValue, "description": p.description]
            if p.required { required.append(p.name) }
        }
        return ["name": name, "description": summary,
                "inputSchema": ["type": "object", "properties": properties, "required": required]]
    }
}

/// The catalogue of automation tools. Grouped by capability; the `capability` on
/// each tool is what the `PermissionPolicy` gates.
public enum AutomationCatalog {
    public static let tools: [ToolDefinition] = [
        // read / context
        .init("get_context", .read, "Get the current UI context: active panel path, selection, cursor, tabs, view and sort."),
        .init("list_directory", .read, "List the entries of a folder (works for local, archive and remote paths).",
              [.init("path", .string, "Absolute path or VFS path to list.")]),
        .init("stat_path", .read, "Get metadata (size, kind, dates, attributes) for a path.",
              [.init("path", .string, "Path to inspect.")]),
        .init("read_file", .read, "Read a bounded slice of a file's text content, with encoding detection. The result reports whether more of the file remains, so a long file can be read in slices.",
              [.init("path", .string, "File to read."),
               .init("max_bytes", .integer, "Maximum bytes to read.", required: false),
               .init("offset", .integer, "Byte offset to start at (default 0).", required: false)]),
        .init("describe_image", .read, "Read what is IN a picture: the text on it and what it appears to show. Use this for a photo, a scan or a screenshot — read_file returns bytes for those, not meaning.",
              [.init("path", .string, "Absolute path of the image.")]),
        .init("hash_file", .read, "Compute a cryptographic hash of a file's bytes (default SHA-256).",
              [.init("path", .string, "File to hash."),
               .init("algorithm", .string, "\"sha256\" (default), \"sha1\", or \"md5\".", required: false)]),
        .init("search", .read, "Find files by a NAME pattern, or by exact words inside them. The mask matches file names only; put words to find inside files in \"text\". For \"which file is about X\", prefer semantic_search.",
              [.init("query", .object, "Search query: masks, text, regex, size/date filters, start folders.")]),
        .init("semantic_search", .read, "Find files in a folder that are about something, ranked by on-device similarity over their names AND the beginning of their contents. Use this for fuzzy 'find the file about X' requests; use read_file or summarize_file on a match.",
              [.init("query", .string, "Natural-language description of what to find."),
               .init("path", .string, "Folder to search (default: active folder).", required: false),
               .init("limit", .integer, "Max results (default 10).", required: false)]),
        .init("find_files", .read, "Find files ANYWHERE through the system file index — the whole disk or your home folder, without walking it. THE tool for \"that PDF from last month\" or \"all my node_modules folders\". Combine the fields; each one narrows the result. Prefer this over search when the folder is unknown, and over semantic_search when the description is concrete (a kind, a word in the name, a time).",
              [.init("name", .string, "Words or wildcards to match in the FILE NAME. A bare word matches as a substring.", required: false),
               .init("text", .string, "Words to find INSIDE files, through the content index.", required: false),
               .init("kind", .string, "One of: pdf, image, movie, audio, text, source, archive, folder, application.", required: false),
               .init("within_days", .integer, "Only files modified in the last N days. Use this for \"recently\", \"last week\", \"last month\" — it needs no date arithmetic.", required: false),
               .init("larger_than_bytes", .integer, "Only files at least this large.", required: false),
               .init("smaller_than_bytes", .integer, "Only files at most this large.", required: false),
               .init("scope", .string, "Where to look: \"home\" (default), \"disk\" for the whole computer, \"here\" for the active folder, or an absolute path.", required: false),
               .init("limit", .integer, "Max results (default 50).", required: false)]),
        .init("get_config", .config, "Read a configuration value by its Section.Key.",
              [.init("key", .string, "Config key, e.g. \"Display.NaturalSort\".")]),
        .init("remember", .read, "Save a short note to long-term memory (persists across chats). Use for durable facts/preferences the user asks you to remember.",
              [.init("text", .string, "The note to remember.")]),
        .init("recall", .read, "Recall notes from long-term memory matching a query (empty = most recent).",
              [.init("query", .string, "Text to match (optional).", required: false),
               .init("limit", .integer, "Max notes (default 10).", required: false)]),
        .init("get_comment", .read, "Read the comment attached to a file or folder (the descript.ion comment the Comment column shows, or the macOS Finder comment when there is none). Empty when the item has no comment.",
              [.init("path", .string, "Absolute path of the file or folder.")]),
        .init("list_recent_actions", .read, "List what the assistant has recently done (tool, arguments, outcome), newest first, and whether each can still be undone.",
              [.init("limit", .integer, "How many entries (default 20).", required: false)]),
        .init("list_commands", .read, "List the available commands (id, name, category, help)."),
        .init("list_plugins", .read, "List enabled plugins and their contributed commands and columns."),
        // navigate
        .init("open_path", .navigate, "Open a folder (or reveal a file) in the active panel.",
              [.init("path", .string, "Path to open.")]),
        .init("open_in_panel", .navigate, "Open a path in a specific panel or a new tab.",
              [.init("path", .string, "Path to open."),
               .init("side", .string, "\"left\", \"right\", or \"new-tab\".")]),
        .init("set_selection", .navigate, "Select entries in the active panel by a wildcard mask, replacing whatever was selected before. Fails when the mask matches nothing, rather than leaving the previous selection standing.",
              [.init("mask", .string, "Wildcard mask, e.g. \"*.txt\".")]),
        // Not a `.write`: nothing on disk changes, and what it replaces is a scratch buffer, not
        // data. Gating it like a rename would mean a confirmation sheet for the thing the user just
        // asked for in words — and a read-only session could then read a folder but not hand the
        // answer over, which is most of what asking was for.
        .init("copy_to_clipboard", .navigate, "Put text on the clipboard, ready to paste somewhere else. Use it whenever the user asks to copy an answer — a list of names, a table, a path. Replaces whatever was on the clipboard. To put the FILES themselves on the clipboard rather than text about them, select them and run the cm_CopyToClipboard command instead.",
              [.init("text", .string, "The exact text to place on the clipboard.")]),
        // write (gated / confirmed)
        .init("copy", .write, "Copy files/folders to a destination folder.",
              [.init("sources", .array, "Absolute paths to copy."),
               .init("destination", .string, "Destination folder.")]),
        .init("move", .write, "Move files/folders to a destination folder.",
              [.init("sources", .array, "Absolute paths to move."),
               .init("destination", .string, "Destination folder.")]),
        .init("rename", .write, "Rename a single entry in place.",
              [.init("path", .string, "Entry to rename."),
               .init("new_name", .string, "New name (one path component).")]),
        .init("rename_batch", .write, "Rename MANY files in one step: you build the new names, this shows them as a table, renames them all at once and can take the whole batch back with undo_last_action. STRONGLY prefer this over calling rename repeatedly — it asks once instead of once per file. The two lists must line up one to one, and nothing is renamed if any name is unusable.",
              [.init("old_names", .array, "The current file names, without a folder."),
               .init("new_names", .array, "The new names, in the same order."),
               .init("directory", .string, "Folder the files are in (default: active folder).", required: false)]),
        .init("make_directory", .write, "Create a new folder (intermediate folders allowed).",
              [.init("path", .string, "Folder path to create.")]),
        .init("create_file", .write, "Create a new, empty file. Does nothing if a file of that name is already there — it never overwrites. Use this for “make me an empty file”; use write_file when there is content to put in it.",
              [.init("path", .string, "Absolute path of the file to create.")]),
        .init("write_file", .write, "Create or overwrite a text file with the given UTF-8 content.",
              [.init("path", .string, "Absolute path of the file to write."),
               .init("content", .string, "The full text content to write.")]),
        .init("merge_files", .write, "Combine several files into one new file in a single step. For CSV files it keeps the header only once. Use this whenever the user asks to merge/combine/concatenate files into a new one — do NOT read and rewrite them by hand.",
              [.init("destination", .string, "Output file name or path for the merged result."),
               .init("sources", .array, "Absolute paths to merge, in order. Omit to use the current selection.", required: false)]),
        .init("get_tags", .read, "Read the macOS Finder tags on a file or folder.",
              [.init("path", .string, "Path to read.")]),
        .init("set_tags", .write, "Replace the macOS Finder tags on a file or folder — the coloured labels the panel shows and Spotlight searches. An empty list removes them. Pass the current tags as previous_tags so the change can be undone.",
              [.init("path", .string, "Path to tag."),
               .init("tags", .array, "The tags the file should have afterwards."),
               .init("previous_tags", .array, "The tags it has now, so undo can restore them.", required: false)]),
        .init("set_comment", .write, "Attach a comment to a file or folder, or clear it with an empty string. Use this to describe what a file is for — it is stored in descript.ion beside the file and mirrored into the macOS Finder comment, so it survives copying and is searchable.",
              [.init("path", .string, "Absolute path of the file or folder."),
               .init("comment", .string, "The comment text; an empty string removes the comment.")]),
        .init("set_config", .config, "Set a configuration value by its Section.Key.",
              [.init("key", .string, "Config key."), .init("value", .string, "New value.")]),
        // delete (gated / confirmed)
        .init("move_to_trash", .delete, "Move files/folders to the Trash (reversible).",
              [.init("paths", .array, "Absolute paths to trash.")]),
        .init("delete_permanently", .delete, "Delete files/folders permanently (not reversible).",
              [.init("paths", .array, "Absolute paths to delete.")]),
        // Undoing is a write: it changes the file system back, and it is gated like any other
        // change. Declared as a tool rather than hidden in the UI so the assistant can be asked
        // to do it, and an external agent over MCP has the same way back.
        .init("undo_last_action", .write, "Undo the most recent action that can be undone (a rename or a move). Says why if the last action has no inverse.")
        ,
        // commands
        .init("run_command", .runCommand, "Invoke a named command (cm_*) by id.",
              [.init("command_id", .string, "The command id, e.g. \"cm_PackFiles\".")]),
        // Runs where the user can watch it. A hidden shell would be the same capability with the
        // evidence removed, and the point of putting it in a terminal tab is that what ran is on
        // screen afterwards, in the user's own scrollback, next to everything else they ran.
        .init("run_shell", .shell,
              "Run a shell command in a visible terminal tab and return what it printed.",
              [.init("command", .string, "The command line, exactly as it should be run.")]),
        // The declared capability is the floor, not the answer. What invoking a macro really needs is
        // the most demanding of its steps, and the Core substitutes that at call time — the same
        // arrangement `run_command` needs, and for the same reason: otherwise a macro whose last step
        // is `delete_permanently` would be gated as a write.
        .init("run_macro", .write,
              "Run one of the user's saved macros — a named sequence of these same tools. Use list_macros to see what exists; the steps and their arguments are the user's, not yours to change.",
              [.init("macro_id", .string, "The macro's id, as listed by list_macros."),
               .init("skip_steps", .array, "Step ids to leave out. Filled in by the confirmation sheet when the user strikes rows out; you do not normally set this.", required: false)]),
        .init("list_macros", .read, "List the user's saved macros (id, title, and what each step does)."),
    ]

    /// The whole catalogue as a JSON array of tool-schema objects (LLM/MCP shape).
    public static func toolsJSONData() throws -> Data {
        try JSONSerialization.data(withJSONObject: tools.map { $0.schemaObject() },
                                   options: [.prettyPrinted, .sortedKeys])
    }

    /// Look a tool up by name.
    public static func tool(named name: String) -> ToolDefinition? {
        tools.first { $0.name == name }
    }
}
