// SPDX-License-Identifier: Apache-2.0
// MenuFile.swift - Total Commander-style `.mnu` main-menu format, parser + writer.
//
// TC main menus are a Windows-resource-like grammar of nested POPUP blocks:
//
//   POPUP "&Files"
//     MENUITEM "&View\tF3", cm_List
//     MENUITEM "&Copy\tF5", 40000
//     MENUITEM SEPARATOR
//     POPUP "&More"
//       MENUITEM "&Pack…", cm_PackFiles
//     END_POPUP
//   END_POPUP
//
// A MENUITEM carries a quoted caption and a command token that is either a TC
// numeric command id (which equals PCCommand.id where a 1:1 command exists) or a
// cm_/em_ name; the caller resolves it against the CommandRegistry (cm_) or the
// user's commands (em_, from usercmd.ini — that is how TC gets a `%P`-style
// parameter into a menu entry) when building the live NSMenu. Captions keep their
// raw form (with `&` mnemonic markers and a `\t<accel>` display hint);
// `displayCaption(_:)` strips both for presentation — the accelerator hint is
// deliberately not honoured, because the active keymap is this app's single source
// for shortcuts and a label from the file would state a key that may not be bound.
//
// The grammar is line-oriented and lenient: an unrecognized line is ignored so a
// hand-edited file never fails to load. Lenient is not the same as silent, though —
// `parse(_:)` returns a diagnostic per ignored or malformed line so the caller can
// report what it skipped instead of leaving the user with a menu entry that is
// simply missing. Modeled on ButtonBar.swift (pure, Sendable, round-trippable,
// testable).

import Foundation

/// One node in a `.mnu` menu tree.
public indirect enum MenuNode: Sendable, Equatable {
    case separator
    /// A command item: `caption` is raw (may contain `&`/`\t`); `command` is the raw
    /// token (numeric id string or cm_/em_ name).
    case command(caption: String, command: String)
    /// A submenu with a raw caption and ordered children.
    case popup(caption: String, children: [MenuNode])
}

/// Something the parser could not make sense of, with the 1-based line it is on.
public struct MenuDiagnostic: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        /// A line whose leading keyword is not part of the format.
        case unknownLine
        /// `MENUITEM "caption",` with no command token — nothing to invoke.
        case itemWithoutCommand
        /// An item outside any POPUP: the macOS menu bar has no place for it, so it
        /// is parsed but cannot be shown.
        case itemOutsideMenu
        /// `END_POPUP` with no POPUP open.
        case strayEndPopup
        /// A POPUP still open at end of file (closed implicitly).
        case unclosedPopup
    }

    public let line: Int
    public let kind: Kind
    /// The offending line (or the popup's caption, for `unclosedPopup`).
    public let text: String

    public init(line: Int, kind: Kind, text: String) {
        self.line = line
        self.kind = kind
        self.text = text
    }
}

public struct MenuFile: Sendable, Equatable {
    /// Top-level menus (each a `.popup`); stray top-level items are tolerated.
    public var roots: [MenuNode]

    public init(roots: [MenuNode] = []) { self.roots = roots }

    // MARK: - Parsing

    public init(parsing text: String) {
        self = Self.parse(text).menu
    }

    /// Parse `.mnu` text into a menu tree plus the list of lines that were skipped or
    /// repaired. The tree is exactly what `init(parsing:)` produces; the diagnostics
    /// exist so a caller can tell the user *why* an entry they wrote is not there.
    public static func parse(_ text: String) -> (menu: MenuFile, diagnostics: [MenuDiagnostic]) {
        // A stack of (line, caption, children) frames; index 0 is a synthetic root
        // holding the top-level popups. The line is kept to report an unclosed POPUP
        // where it was opened rather than at end of file.
        var stack: [(line: Int, caption: String?, children: [MenuNode])] = [(0, nil, [])]
        var diagnostics: [MenuDiagnostic] = []

        // Split on *newlines*, not on the character "\n": in Swift "\r\n" is a single
        // Character, so `split(separator: "\n")` does not split a CRLF file at all — and a
        // `.mnu` that came from Total Commander has CRLF line endings. The whole file
        // arrived here as one line, whose leading keyword was POPUP and whose caption was
        // the first quoted string in it: one empty menu, every item gone. `isNewline`
        // treats CRLF as the one line break it is (the same trap INIDocument documents).
        for (index, rawLine) in text.split(omittingEmptySubsequences: false,
                                           whereSeparator: { $0.isNewline }).enumerated() {
            let lineNumber = index + 1
            let trimmed = String(rawLine).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix(";") || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") { continue }

            let (keyword, rest) = splitKeyword(trimmed)
            switch keyword.uppercased() {
            case "POPUP":
                stack.append((lineNumber, firstQuoted(rest) ?? rest, []))
            case "END_POPUP", "ENDPOPUP":
                guard stack.count > 1 else {
                    diagnostics.append(MenuDiagnostic(line: lineNumber, kind: .strayEndPopup, text: trimmed))
                    continue
                }
                let frame = stack.removeLast()
                stack[stack.count - 1].children.append(.popup(caption: frame.caption ?? "", children: frame.children))
            case "MENUITEM":
                if stack.count == 1 {
                    diagnostics.append(MenuDiagnostic(line: lineNumber, kind: .itemOutsideMenu, text: trimmed))
                }
                if rest.uppercased() == "SEPARATOR" {
                    stack[stack.count - 1].children.append(.separator)
                } else if let (caption, command) = parseMenuItem(rest), !command.isEmpty {
                    stack[stack.count - 1].children.append(.command(caption: caption, command: command))
                } else {
                    diagnostics.append(MenuDiagnostic(line: lineNumber, kind: .itemWithoutCommand, text: trimmed))
                }
            default:
                diagnostics.append(MenuDiagnostic(line: lineNumber, kind: .unknownLine, text: trimmed))
            }
        }

        // Close any popups left open by a malformed file.
        while stack.count > 1 {
            let frame = stack.removeLast()
            diagnostics.append(MenuDiagnostic(line: frame.line, kind: .unclosedPopup, text: frame.caption ?? ""))
            stack[stack.count - 1].children.append(.popup(caption: frame.caption ?? "", children: frame.children))
        }
        // Diagnostics in file order: the implicit closes above are appended last but
        // belong where their POPUP was opened.
        diagnostics.sort { $0.line < $1.line }
        return (MenuFile(roots: stack[0].children), diagnostics)
    }

    /// Split a line into its leading keyword and the remainder.
    private static func splitKeyword(_ line: String) -> (String, String) {
        guard let space = line.firstIndex(where: { $0 == " " || $0 == "\t" }) else { return (line, "") }
        let keyword = String(line[..<space])
        let rest = String(line[line.index(after: space)...]).trimmingCharacters(in: .whitespaces)
        return (keyword, rest)
    }

    /// The contents of the first `"..."` in `s`, or nil.
    private static func firstQuoted(_ s: String) -> String? {
        quotedString(in: s)?.value
    }

    /// The first quoted string in `s`, and the index just past its closing quote.
    ///
    /// A doubled `""` inside the string is one literal quote. TC's format has no
    /// documented escape for that character, and the naive "up to the next quote"
    /// scan this replaced cut such a caption in half and lost the command with it —
    /// which is reachable from here, because the starter file is generated from the
    /// live menu and a plugin may contribute any title it likes. `serialize()` writes
    /// the same doubling, so a caption containing a quote round-trips.
    private static func quotedString(in s: String) -> (value: String, end: String.Index)? {
        guard let open = s.firstIndex(of: "\"") else { return nil }
        var value = ""
        var index = s.index(after: open)
        while index < s.endIndex {
            let character = s[index]
            if character == "\"" {
                let next = s.index(after: index)
                if next < s.endIndex, s[next] == "\"" {   // "" → a literal quote
                    value.append("\"")
                    index = s.index(after: next)
                    continue
                }
                return (value, next)
            }
            value.append(character)
            index = s.index(after: index)
        }
        return nil   // unterminated
    }

    /// Parse `"caption", command` → (caption, command). The command is everything
    /// after the caption's closing quote and the following comma.
    private static func parseMenuItem(_ s: String) -> (caption: String, command: String)? {
        guard let quoted = quotedString(in: s) else { return nil }
        var tail = String(s[quoted.end...]).trimmingCharacters(in: .whitespaces)
        if tail.hasPrefix(",") { tail.removeFirst() }
        // Drop any trailing comment / extra params after the command token.
        let command = tail.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }).first.map(String.init) ?? ""
        return (quoted.value, command)
    }

    // MARK: - Presentation

    /// Strip the accelerator display hint (an actual tab or a literal `\t`) and `&`
    /// mnemonic markers (`&&` → `&`).
    public static func displayCaption(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "\\t", with: "\t")   // literal "\t" → tab
        if let tab = s.firstIndex(of: "\t") { s = String(s[..<tab]) }
        return s.replacingOccurrences(of: "&&", with: "\u{0001}")
                .replacingOccurrences(of: "&", with: "")
                .replacingOccurrences(of: "\u{0001}", with: "&")
                .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Serialize

    public func serialize() -> String {
        var lines: [String] = []
        func quote(_ caption: String) -> String {
            "\"" + caption.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        func emit(_ node: MenuNode, indent: Int) {
            let pad = String(repeating: "  ", count: indent)
            switch node {
            case .separator:
                lines.append("\(pad)MENUITEM SEPARATOR")
            case .command(let caption, let command):
                lines.append("\(pad)MENUITEM \(quote(caption)), \(command)")
            case .popup(let caption, let children):
                lines.append("\(pad)POPUP \(quote(caption))")
                for child in children { emit(child, indent: indent + 1) }
                lines.append("\(pad)END_POPUP")
            }
        }
        for root in roots { emit(root, indent: 0) }
        return lines.joined(separator: "\n") + "\n"
    }
}
