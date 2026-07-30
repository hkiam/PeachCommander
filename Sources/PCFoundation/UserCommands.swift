// SPDX-License-Identifier: Apache-2.0
// UserCommands.swift - User command model (Total Commander's usercmd.ini analog).
//
// usercmd.ini holds one INI section per user-defined command. The section name
// is the command's `em_` id, which doubles as the command's internal identifier
// (invokable as an `em_` command) and, by default, its Start menu title. This
// model parses/serializes that file format and preserves declaration order,
// since the order commands appear in usercmd.ini is the order they appear in
// the Start menu.
//
// A hand-rolled line scanner is used (rather than routing through INIDocument)
// so the order-preservation contract is guaranteed by construction and doesn't
// depend on unrelated behavior of a shared, more general-purpose INI model.

import Foundation

/// A single Total Commander user command (one `[em_...]` section).
public struct UserCommand: Sendable, Equatable {
    /// Section id, e.g. "em_MyBackup". Conventionally starts with "em_"; the
    /// original casing (including the "em_" prefix) is preserved verbatim.
    public var name: String
    /// Program to run, or an internal `cm_`/`path` command reference.
    public var cmd: String
    /// `%`-parameter template passed to `cmd` (e.g. "%P %N").
    public var param: String
    /// Start directory for the command; may be empty (inherit).
    public var path: String
    /// Display title shown in the Start menu; falls back to `name` when empty.
    public var menu: String
    /// Optional shortcut string, e.g. "C+S+B".
    public var key: String

    public init(name: String, cmd: String = "", param: String = "",
                path: String = "", menu: String = "", key: String = "") {
        self.name = name
        self.cmd = cmd
        self.param = param
        self.path = path
        self.menu = menu
        self.key = key
    }

    /// The title to show in the Start menu: `menu` if non-empty, else `name`.
    public var displayTitle: String {
        menu.isEmpty ? name : menu
    }
}

/// An ordered collection of ``UserCommand``s, mirroring usercmd.ini.
public struct UserCommands: Sendable, Equatable {
    /// Commands in file/menu order.
    public var commands: [UserCommand]

    public init(commands: [UserCommand] = []) {
        self.commands = commands
    }

    /// Parse usercmd.ini text. Only sections whose name starts with "em_"
    /// (case-insensitive) become user commands; any other section (or content
    /// outside of a section) is ignored. Section/key order in the source text
    /// is preserved. Missing keys default to "". Duplicate sections with the
    /// same name are kept as separate entries, each in its position in the file.
    public init(parsing text: String) {
        var result: [UserCommand] = []
        // Index into `result` for the section currently being parsed, or nil
        // when we're outside of any em_ section (or inside a non-em_ one).
        var currentIndex: Int?

        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, substring) in rawLines.enumerated() {
            // Drop a trailing empty element produced by a final "\n".
            if index == rawLines.count - 1 && substring.isEmpty {
                continue
            }

            var line = String(substring)
            if line.hasSuffix("\r") {
                line.removeLast()
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix(";") || trimmed.hasPrefix("#") {
                // Comment line; not part of the model.
                continue
            }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let sectionName = String(trimmed.dropFirst().dropLast())
                if sectionName.lowercased().hasPrefix("em_") {
                    result.append(UserCommand(name: sectionName))
                    currentIndex = result.count - 1
                } else {
                    currentIndex = nil
                }
                continue
            }

            guard let currentIndex, let equalsIndex = line.firstIndex(of: "=") else {
                // key=value line outside any em_ section, or a line that isn't
                // a recognized construct: nothing to record.
                continue
            }

            let key = String(line[line.startIndex..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

            switch key.lowercased() {
            case "cmd":
                result[currentIndex].cmd = value
            case "param":
                result[currentIndex].param = value
            case "path":
                result[currentIndex].path = value
            case "menu":
                result[currentIndex].menu = value
            case "key":
                result[currentIndex].key = value
            default:
                break // Unknown key; ignored.
            }
        }

        self.commands = result
    }

    /// Serialize back to usercmd.ini text: one `[name]` section per command in
    /// `commands` order, writing only non-empty keys, always in the order
    /// cmd, param, path, menu, key.
    public func serialize() -> String {
        var lines: [String] = []
        for command in commands {
            lines.append("[\(command.name)]")
            if !command.cmd.isEmpty {
                lines.append("cmd=\(command.cmd)")
            }
            if !command.param.isEmpty {
                lines.append("param=\(command.param)")
            }
            if !command.path.isEmpty {
                lines.append("path=\(command.path)")
            }
            if !command.menu.isEmpty {
                lines.append("menu=\(command.menu)")
            }
            if !command.key.isEmpty {
                lines.append("key=\(command.key)")
            }
        }
        if lines.isEmpty {
            return ""
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Look up a command by its `em_` name, case-insensitive. Returns the
    /// first match in file order if duplicates exist.
    public func command(named name: String) -> UserCommand? {
        let target = name.lowercased()
        return commands.first { $0.name.lowercased() == target }
    }
}
