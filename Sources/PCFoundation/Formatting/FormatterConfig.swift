// SPDX-License-Identifier: Apache-2.0
// FormatterConfig.swift - User-defined formatters, one per file extension.
//
// Read from `formatters.ini` in the config directory, in the project's existing INI format
// (INIDocument), so it sits next to the other configuration rather than introducing a
// second file format:
//
//     [swift]
//     tool = swiftformat
//     args = --quiet stdin
//
//     [sql]
//     tool = /opt/homebrew/bin/sqlfluff
//     args = format -
//
//     [go]
//     tool = gofmt
//
// Section name = the extension (without the dot). `args` is split on spaces; quote a value
// containing spaces. `name` optionally overrides what the status line shows.
//
// These win over everything else — a configured tool is an explicit instruction.

import Foundation

public enum FormatterConfig {
    /// File name inside the configuration directory.
    public static let fileName = "formatters.ini"

    /// Parse `text` into formatters. Sections without a `tool` are skipped rather than
    /// failing the whole file, so one bad entry cannot disable the others.
    public static func parse(_ text: String) -> [ExternalToolFormatter] {
        let ini = INIDocument(parsing: text)
        return ini.sections().compactMap { section in
            let ext = section.trimmingCharacters(in: .whitespaces).lowercased()
            guard !ext.isEmpty,
                  let tool = ini.value(section: section, key: "tool")?.trimmingCharacters(in: .whitespaces),
                  !tool.isEmpty else { return nil }
            let args = splitArguments(ini.value(section: section, key: "args") ?? "")
            let name = ini.value(section: section, key: "name")?.trimmingCharacters(in: .whitespaces)
            return ExternalToolFormatter(tool: tool, arguments: args, extensions: [ext],
                                         name: (name?.isEmpty == false) ? name : nil)
        }
    }

    /// Load from `directory`, returning [] when the file is absent — an optional feature must
    /// not need a config file to exist.
    public static func load(from directory: URL) -> [ExternalToolFormatter] {
        let url = directory.appendingPathComponent(fileName)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    /// A commented template, written on demand so the format is discoverable without docs.
    public static func template() -> String {
        """
        ; formatters.ini — one section per file extension, overriding the built-in
        ; formatters and any detected command-line tool.
        ;
        ;   tool = executable name (found on PATH) or an absolute path
        ;   args = arguments, split on spaces; the file's text is piped in on stdin
        ;          and the formatted text is read from stdout
        ;   name = optional label for the status line
        ;
        ; Examples — uncomment and adjust:
        ;
        ; [swift]
        ; tool = swiftformat
        ; args = --quiet stdin
        ;
        ; [sql]
        ; tool = sqlfluff
        ; args = format -
        ;
        ; [go]
        ; tool = gofmt

        """
    }

    /// Split an argument string on spaces, honouring "double" and 'single' quotes so a path
    /// with a space can be passed. Not a shell: no expansion, no escapes beyond the quotes.
    static func splitArguments(_ line: String) -> [String] {
        var args: [String] = []
        var current = ""
        var quote: Character?
        for char in line {
            if let q = quote {
                if char == q { quote = nil } else { current.append(char) }
            } else if char == "\"" || char == "'" {
                quote = char
            } else if char == " " || char == "\t" {
                if !current.isEmpty { args.append(current); current = "" }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { args.append(current) }
        return args
    }
}
