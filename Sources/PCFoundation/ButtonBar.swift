// ButtonBar.swift - Total Commander `.bar` (button bar) format, parser + writer.
//
// TC button bars are INI files with a single [Buttonbar] section:
//
//   [Buttonbar]
//   Buttoncount=3
//   button1=wcmicons.dll,5
//   cmd1=cm_Copy
//   param1=
//   path1=
//   menu1=Copy files
//   iconic1=1
//   ...
//
// Each button `i` (1-based) is described by six keys: button<i> (icon spec),
// cmd<i> (command: cm_*/em_*/program path/*.bar subbar/directory), param<i>,
// path<i> (start dir), menu<i> (tooltip/title) and iconic<i> (0/1). A button
// whose icon and command are both empty renders as a visual separator in TC;
// we keep it in the list (as a BarButton with empty fields) so indices and
// round-trips stay stable.
//
// Parsing is built on top of INIDocument, which already gives us
// case-insensitive section/key lookup and consistent value trimming
// (trailing "\r" stripped, leading/trailing spaces trimmed, inner spaces
// preserved).

import Foundation

/// A single button (or separator) in a TC button bar.
public struct BarButton: Sendable, Equatable {
    /// button<i> - icon spec, e.g. "wcmicons.dll,5" or an .app/.ico path.
    public var icon: String
    /// cmd<i> - command: cm_*/em_* internal command, program path, *.bar subbar, or directory.
    public var cmd: String
    /// param<i> - parameters passed to cmd.
    public var param: String
    /// path<i> - start directory for cmd.
    public var path: String
    /// menu<i> - tooltip / menu title shown for the button.
    public var menu: String
    /// iconic<i> - whether the button is shown without its caption (icon-only).
    public var iconic: Bool

    public init(
        icon: String = "",
        cmd: String = "",
        param: String = "",
        path: String = "",
        menu: String = "",
        iconic: Bool = false
    ) {
        self.icon = icon
        self.cmd = cmd
        self.param = param
        self.path = path
        self.menu = menu
        self.iconic = iconic
    }

    /// True when this is a visual separator (no icon and no command).
    public var isSeparator: Bool {
        icon.isEmpty && cmd.isEmpty
    }
}

/// A TC button bar: an ordered list of buttons (and separators).
public struct ButtonBar: Sendable, Equatable {
    public var buttons: [BarButton]

    public init(buttons: [BarButton] = []) {
        self.buttons = buttons
    }

    /// Parse a TC `.bar` file body. Returns an empty bar (no buttons) if there
    /// is no `[Buttonbar]` section. Reads `Buttoncount` then `button1..buttonN`
    /// etc.; tolerates missing keys and a `Buttoncount` larger/smaller than the
    /// actually-present keys (iterates `1...Buttoncount`, filling absent keys
    /// with defaults).
    public init(parsing text: String) {
        let ini = INIDocument(parsing: text)

        // Section lookup in INIDocument.value() is already case-insensitive,
        // so if [Buttonbar] is absent entirely, Buttoncount simply reads as
        // missing and we naturally fall through to zero buttons.
        let section = "Buttonbar"
        let count = Int(ini.value(section: section, key: "Buttoncount") ?? "") ?? 0

        var result: [BarButton] = []
        result.reserveCapacity(max(0, count))
        if count > 0 {
            for i in 1...count {
                let icon = ini.value(section: section, key: "button\(i)") ?? ""
                let cmd = ini.value(section: section, key: "cmd\(i)") ?? ""
                let param = ini.value(section: section, key: "param\(i)") ?? ""
                let path = ini.value(section: section, key: "path\(i)") ?? ""
                let menu = ini.value(section: section, key: "menu\(i)") ?? ""
                let iconic = (ini.value(section: section, key: "iconic\(i)") ?? "0") == "1"
                result.append(BarButton(icon: icon, cmd: cmd, param: param, path: path, menu: menu, iconic: iconic))
            }
        }
        self.buttons = result
    }

    /// Serialize back to TC-compatible `.bar` text: `[Buttonbar]` header,
    /// `Buttoncount=N`, then for each i (1-based) the keys button<i>, cmd<i>,
    /// param<i>, path<i>, menu<i>, iconic<i>. A key line is omitted when its
    /// value is empty, except `iconic<i>` which is always written as 0/1.
    public func serialize() -> String {
        var lines: [String] = ["[Buttonbar]", "Buttoncount=\(buttons.count)"]
        lines.reserveCapacity(2 + buttons.count * 6)

        for (offset, button) in buttons.enumerated() {
            let i = offset + 1
            if !button.icon.isEmpty {
                lines.append("button\(i)=\(button.icon)")
            }
            if !button.cmd.isEmpty {
                lines.append("cmd\(i)=\(button.cmd)")
            }
            if !button.param.isEmpty {
                lines.append("param\(i)=\(button.param)")
            }
            if !button.path.isEmpty {
                lines.append("path\(i)=\(button.path)")
            }
            if !button.menu.isEmpty {
                lines.append("menu\(i)=\(button.menu)")
            }
            lines.append("iconic\(i)=\(button.iconic ? "1" : "0")")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
