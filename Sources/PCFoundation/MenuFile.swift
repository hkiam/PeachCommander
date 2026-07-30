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
// numeric command id (which equals PCCommand.id) or a cm_/em_ name; the caller
// resolves it against the CommandRegistry when building the live NSMenu. Captions
// keep their raw form (with `&` mnemonic markers and a `\t<accel>` display hint);
// `displayCaption(_:)` strips both for presentation. The grammar is line-oriented
// and lenient: unrecognized lines are ignored so a hand-edited file never fails to
// load. Modeled on ButtonBar.swift (pure, Sendable, round-trippable, testable).

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

public struct MenuFile: Sendable, Equatable {
    /// Top-level menus (each a `.popup`); stray top-level items are tolerated.
    public var roots: [MenuNode]

    public init(roots: [MenuNode] = []) { self.roots = roots }

    // MARK: - Parsing

    public init(parsing text: String) {
        // A stack of (caption, children) frames; index 0 is a synthetic root holding
        // the top-level popups.
        var stack: [(caption: String?, children: [MenuNode])] = [(nil, [])]

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var line = String(rawLine)
            if line.hasSuffix("\r") { line.removeLast() }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix(";") || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") { continue }

            let (keyword, rest) = Self.splitKeyword(trimmed)
            switch keyword.uppercased() {
            case "POPUP":
                stack.append((Self.firstQuoted(rest) ?? rest, []))
            case "END_POPUP", "ENDPOPUP":
                guard stack.count > 1 else { continue }
                let frame = stack.removeLast()
                stack[stack.count - 1].children.append(.popup(caption: frame.caption ?? "", children: frame.children))
            case "MENUITEM":
                if rest.uppercased() == "SEPARATOR" {
                    stack[stack.count - 1].children.append(.separator)
                } else if let (caption, command) = Self.parseMenuItem(rest), !command.isEmpty {
                    stack[stack.count - 1].children.append(.command(caption: caption, command: command))
                }
            default:
                continue   // unknown line — ignore
            }
        }

        // Close any popups left open by a malformed file.
        while stack.count > 1 {
            let frame = stack.removeLast()
            stack[stack.count - 1].children.append(.popup(caption: frame.caption ?? "", children: frame.children))
        }
        self.roots = stack[0].children
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
        guard let open = s.firstIndex(of: "\""),
              let close = s[s.index(after: open)...].firstIndex(of: "\"") else { return nil }
        return String(s[s.index(after: open)..<close])
    }

    /// Parse `"caption", command` → (caption, command). The command is everything
    /// after the caption's closing quote and the following comma.
    private static func parseMenuItem(_ s: String) -> (caption: String, command: String)? {
        guard let open = s.firstIndex(of: "\""),
              let close = s[s.index(after: open)...].firstIndex(of: "\"") else { return nil }
        let caption = String(s[s.index(after: open)..<close])
        var tail = String(s[s.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        if tail.hasPrefix(",") { tail.removeFirst() }
        // Drop any trailing comment / extra params after the command token.
        let command = tail.trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }).first.map(String.init) ?? ""
        return (caption, command)
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
        func emit(_ node: MenuNode, indent: Int) {
            let pad = String(repeating: "  ", count: indent)
            switch node {
            case .separator:
                lines.append("\(pad)MENUITEM SEPARATOR")
            case .command(let caption, let command):
                lines.append("\(pad)MENUITEM \"\(caption)\", \(command)")
            case .popup(let caption, let children):
                lines.append("\(pad)POPUP \"\(caption)\"")
                for child in children { emit(child, indent: indent + 1) }
                lines.append("\(pad)END_POPUP")
            }
        }
        for root in roots { emit(root, indent: 0) }
        return lines.joined(separator: "\n") + "\n"
    }
}
