// SPDX-License-Identifier: Apache-2.0
// ThemeFile.swift — user-supplied colour themes, one .ini per theme (F-337).
//
// A theme file lives in <config>/themes/<id>.ini and looks like this:
//
//     [Theme]
//     Name = Midnight
//     Base = dark
//
//     [Colors]
//     ListBackground = #101020
//     ListText       = #C0C0D0
//
// The id is the filename stem; the display name comes from `Name` (falling back to the stem).
// `Base` picks which built-in palette supplies everything the file does not mention, so a
// three-line theme is a legitimate theme — you override what you care about and inherit the
// rest. Keys are the `Theme.Colors` property names, matched case-insensitively.
//
// Parsing is deliberately separate from disk access: `parse` is a pure String -> Palette so the
// whole format is testable without a filesystem, and it never throws — a malformed file yields
// warnings and whatever was still usable, because a typo in one colour must not cost the user
// their theme. Only a file with no usable colour at all is rejected.

import AppKit
import Foundation
import os

enum ThemeFile {
    /// The extension a theme file must have.
    static let fileExtension = "ini"

    /// os.Logger, not NSLog: NSLog output from this app does not reach the unified log, so
    /// diagnostics written with it are invisible — which is exactly what made an unreadable
    /// themes folder look like an empty one. `import os` keeps this file free of PCFoundation
    /// so the test target can compile it on its own.
    private static let log = Logger(subsystem: "com.peachcommander", category: "Theme")

    // MARK: - Parsing

    struct ParseResult {
        var palette: Theme.Palette?
        /// Human-readable problems: unknown keys, unparsable colours, a bad `Base`. Reported to
        /// the log rather than a dialog — a broken theme should not block startup.
        var warnings: [String] = []
    }

    /// Parse a theme file's contents. `id` is the filename stem.
    ///
    /// Returns `palette == nil` only when the file contributes nothing: no recognised colour at
    /// all. In every other case the result is usable and `warnings` explains what was skipped.
    static func parse(_ text: String, id: String) -> ParseResult {
        var result = ParseResult()
        var name: String?
        var baseIsDark: Bool?
        var section = ""
        var applied = 0
        var overrides: [(String, NSColor)] = []

        for (lineNumber, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            // Strip comments before anything else. `;` and `#` both start one — but only at the
            // start of a value's *line*, never mid-value, or every "#RRGGBB" would be a comment.
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if let semi = line.firstIndex(of: ";") {
                line = String(line[line.startIndex..<semi]).trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
            }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces).lowercased()
                continue
            }

            guard let eq = line.firstIndex(of: "=") else {
                result.warnings.append("line \(lineNumber + 1): not a key = value pair, ignored")
                continue
            }
            let key = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if key.isEmpty { continue }

            switch section {
            case "theme":
                switch key.lowercased() {
                case "name":
                    if !value.isEmpty { name = value }
                case "base":
                    switch value.lowercased() {
                    case "dark": baseIsDark = true
                    case "light": baseIsDark = false
                    default:
                        result.warnings.append(
                            "line \(lineNumber + 1): Base must be \"light\" or \"dark\", not \(value.debugDescription) — using dark")
                    }
                default:
                    result.warnings.append("line \(lineNumber + 1): unknown [Theme] key \(key.debugDescription), ignored")
                }
            case "colors":
                // Key first, then the value. When both are wrong — the usual case for a line
                // copied from some other app's theme — the unknown key is the cause and the
                // unparsable value is the symptom, so naming the key is the useful message.
                var probe = Theme.light
                guard probe.setColor(named: key, to: .black) else {
                    result.warnings.append("line \(lineNumber + 1): unknown colour \(key.debugDescription), ignored")
                    continue
                }
                guard let color = NSColor(hexString: value) else {
                    result.warnings.append(
                        "line \(lineNumber + 1): \(key) = \(value.debugDescription) is not a #RRGGBB colour, ignored")
                    continue
                }
                overrides.append((key, color))
                applied += 1
            case "":
                result.warnings.append("line \(lineNumber + 1): \(key) appears before any [section], ignored")
            default:
                result.warnings.append("line \(lineNumber + 1): unknown section [\(section)], ignored")
            }
        }

        guard applied > 0 else {
            result.warnings.append("no usable colour in [Colors] — theme not loaded")
            return result
        }

        // Default to dark: a partial theme is far more often a dark one, and a dark base with a
        // light palette is merely unusual, whereas the reverse (light chrome, dark panels) is
        // what actually looks broken.
        let isDark = baseIsDark ?? true
        var colors = isDark ? Theme.dark : Theme.light
        for (key, color) in overrides { _ = colors.setColor(named: key, to: color) }

        result.palette = Theme.Palette(
            id: id,
            name: name ?? id,
            isDark: isDark,
            colors: colors,
            syntax: isDark ? Theme.darkSyntax : Theme.lightSyntax)
        return result
    }

    // MARK: - Loading

    /// Read every `*.ini` in `directory` and return the palettes, sorted by display name.
    ///
    /// A missing directory is normal, not an error — most users never create one. Files whose
    /// stem collides with a built-in id are skipped: `Theme.palette(id:)` returns the first
    /// match, so allowing it would make which palette you get depend on ordering, and the
    /// golden tests on the shipped palettes would no longer describe what the app renders.
    static func loadPalettes(from directory: URL) -> (palettes: [Theme.Palette], warnings: [String]) {
        var warnings: [String] = []
        let fm = FileManager.default
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            // "No themes folder" is the normal case and must stay silent. "There is a folder but I
            // cannot read it" is a real problem the user needs told — permissions, a broken
            // symlink, a file where a directory should be. Collapsing both into a silent empty
            // result made a failure indistinguishable from success, which cost real time to
            // diagnose once already.
            if fm.fileExists(atPath: directory.path) {
                warnings.append("themes folder exists but could not be read: \(error.localizedDescription)")
            }
            return ([], warnings)
        }
        var loaded: [Theme.Palette] = []
        var seen = Set<String>()
        for url in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.pathExtension.lowercased() == fileExtension else { continue }
            let id = url.deletingPathExtension().lastPathComponent
            let file = url.lastPathComponent

            guard !id.isEmpty else { continue }
            if Theme.reservedPaletteIds.contains(id.lowercased()) {
                warnings.append("\(file): \"\(id)\" is a built-in theme name — rename the file")
                continue
            }
            guard seen.insert(id.lowercased()).inserted else {
                warnings.append("\(file): another file already defines \"\(id)\" — skipped")
                continue
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                warnings.append("\(file): could not be read as UTF-8")
                continue
            }
            let result = parse(text, id: id)
            warnings.append(contentsOf: result.warnings.map { "\(file): \($0)" })
            if let palette = result.palette { loaded.append(palette) }
        }
        return (loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, warnings)
    }

    /// Load `directory` into `Theme.userPalettes` and log what was skipped.
    ///
    /// Warnings go to the log deliberately: a theme is cosmetic, and interrupting startup with a
    /// dialog about a stray key would be worse than the typo.
    @MainActor
    static func loadUserPalettes(from directory: URL) {
        let (palettes, warnings) = loadPalettes(from: directory)
        Theme.userPalettes = palettes
        for w in warnings { log.warning("\(w, privacy: .public)") }
        if palettes.isEmpty {
            log.info("no user themes in \(directory.path, privacy: .public)")
        } else {
            log.info("loaded \(palettes.count) user theme(s): \(palettes.map(\.id).joined(separator: ", "), privacy: .public)")
        }
    }

    // MARK: - The example file

    /// A commented example, written into the themes directory when the user first opens it so
    /// there is something to copy rather than a format to guess. Reproduces the built-in Norton
    /// palette, which doubles as a working reference for every key.
    static let exampleFileName = "example-norton.ini"

    static func exampleFileContents() -> String {
        var lines = [
            "; Peach Commander theme — copy this file, rename it, and edit.",
            ";",
            "; The file name (without .ini) is the theme's id; Name is what the Theme menu shows.",
            "; Base picks the built-in palette that supplies every colour you do not list here,",
            "; so a theme can be three lines long. Colours are #RRGGBB.",
            ";",
            "; This example reproduces the built-in Norton Commander theme, so it also serves as",
            "; the complete list of colours you can set. Built-in names (light, dark, norton,",
            "; system) are reserved — a file using one is skipped.",
            ";",
            "; CursorRowText is optional and special: the cursor row is drawn as a filled bar while",
            "; the text keeps its normal colour. Set it if your bar colour is close to your text",
            "; colour, or the cursor row will be unreadable. Omit it to leave the text alone.",
            "",
            "[Theme]",
            "Name = My Norton",
            "Base = dark",
            "",
            "[Colors]",
        ]
        // Generated from the palette rather than typed, so the example cannot fall out of date.
        let nc = Theme.norton
        let pairs: [(String, NSColor)] = [
            ("WindowBackground", nc.windowBackground), ("ListBackground", nc.listBackground),
            ("ListText", nc.listText), ("SelectedText", nc.selectedText),
            ("CursorFrame", nc.cursorFrame), ("ActiveCursorFrame", nc.activeCursorFrame),
            ("SelectionFillActive", nc.selectionFillActive), ("SelectionFillInactive", nc.selectionFillInactive),
            ("ZebraRow", nc.zebraRow), ("HeaderSeparator", nc.headerSeparator),
            ("ColumnSeparator", nc.columnSeparator),
            ("ActivePathBarBackground", nc.activePathBarBackground), ("ActivePathBarText", nc.activePathBarText),
            ("InactivePathBarBackground", nc.inactivePathBarBackground), ("InactivePathBarText", nc.inactivePathBarText),
            ("PathBarBackground", nc.pathBarBackground), ("PathBarText", nc.pathBarText),
            ("PathBarHoverBackground", nc.pathBarHoverBackground), ("PathBarSeparator", nc.pathBarSeparator),
            ("PathBarFreeSpaceText", nc.pathBarFreeSpaceText),
            ("FunctionButtonBackground", nc.functionButtonBackground),
            ("FunctionButtonPressed", nc.functionButtonPressed), ("FunctionButtonText", nc.functionButtonText),
            ("StatusBarBackground", nc.statusBarBackground), ("StatusBarText", nc.statusBarText),
            ("DriveBarBackground", nc.driveBarBackground), ("DriveBarHighlight", nc.driveBarHighlight),
            ("DriveBarText", nc.driveBarText), ("DriveBarHighlightText", nc.driveBarHighlightText),
            ("FileHandleReadText", nc.fileHandleReadText),
            ("FileHandleWriteText", nc.fileHandleWriteText),
            ("FileHandleReadWriteText", nc.fileHandleReadWriteText),
            ("TabBarBackground", nc.tabBarBackground), ("TabBarActiveChip", nc.tabBarActiveChip),
            ("TabBarInactiveChip", nc.tabBarInactiveChip), ("TabBarChipText", nc.tabBarChipText),
            ("TabBarActiveChipText", nc.tabBarActiveChipText),
        ] + (nc.cursorRowText.map { [("CursorRowText", $0)] } ?? [])
        let width = pairs.map(\.0.count).max() ?? 0
        for (key, color) in pairs {
            lines.append(key.padding(toLength: width, withPad: " ", startingAt: 0) + " = #" + color.hexString.uppercased())
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Create the themes directory (with the example inside if it is empty) and return it.
    ///
    /// Called when the user asks to open the folder, never unprompted: creating directories and
    /// writing files into someone's config on the off chance they want a theme is not our call.
    static func prepareDirectory(_ directory: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        if !existing.contains(where: { $0.pathExtension.lowercased() == fileExtension }) {
            try exampleFileContents().write(to: directory.appendingPathComponent(exampleFileName),
                                            atomically: true, encoding: .utf8)
        }
        return directory
    }
}
