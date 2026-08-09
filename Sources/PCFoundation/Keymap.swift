// SPDX-License-Identifier: Apache-2.0
// Keymap.swift - Keyboard-remapping engine (TC key-scheme model, F-254).
//
// Models Total Commander's key-scheme system with layered precedence:
//   user overrides  >  the active scheme  >  the builtin defaults.
//
// A `KeyChord` is a normalized key combination (modifiers + a canonical key token).
// A `KeymapScheme` is one layer of chord->command bindings, parsed from / serialized
// to an INI `[Shortcuts]` section. A `Keymap` merges three layers into an effective
// map and answers both directions: chord -> command (dispatch) and command -> chord
// (menu display).
//
// Pure, deterministic, Sendable. No IO, no Date()/random - PCFoundation, Foundation only.

import Foundation

// MARK: - KeyChord

/// A single normalized key combination: zero or more modifiers plus one key token.
public struct KeyChord: Hashable, Sendable {
    public let ctrl: Bool
    public let alt: Bool
    public let shift: Bool
    public let cmd: Bool
    /// Canonical UPPERCASE key token, e.g. "F5", "A", "NUM+", "ENTER".
    public let key: String

    public init(ctrl: Bool = false, alt: Bool = false, shift: Bool = false, cmd: Bool = false, key: String) {
        self.ctrl = ctrl
        self.alt = alt
        self.shift = shift
        self.cmd = cmd
        // Store the key in canonical form so equivalent chords compare equal even
        // when constructed directly (e.g. "f5" == "F5", "del" == "DELETE").
        self.key = KeyChord.canonicalKeyToken(key)
    }

    /// Parse a spec string like "C+S+F5", "A+F7", "F5", "C+Num+".
    /// Returns nil if the key token is empty/invalid or a modifier token is unknown.
    public init?(parsing spec: String) {
        let trimmed = spec.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var parts = trimmed.components(separatedBy: "+")
        // A trailing "+" is the numpad-plus key token, not an empty separator:
        // "C+Num+" -> ["C","Num",""] -> ["C","Num+"];  "Num+" -> ["Num",""] -> ["Num+"].
        if parts.count >= 2, parts.last == "" {
            parts.removeLast()
            parts[parts.count - 1] += "+"
        }

        // The last remaining token is the key; everything before it is modifiers.
        guard !parts.isEmpty else { return nil }
        let rawKey = parts.removeLast()
        guard let validKey = KeyChord.validatedKeyToken(rawKey) else { return nil }

        var c = false, a = false, s = false, w = false
        for token in parts {
            switch KeyChord.modifier(from: token) {
            case .ctrl: c = true
            case .alt: a = true
            case .shift: s = true
            case .cmd: w = true
            case nil: return nil // unknown modifier token
            }
        }

        self.ctrl = c
        self.alt = a
        self.shift = s
        self.cmd = w
        self.key = validKey
    }

    /// Canonical spec string. Modifiers in order C, A, S, W each followed by "+",
    /// then the key. E.g. ctrl+shift+F5 -> "C+S+F5"; no mods + "F5" -> "F5".
    public var spec: String {
        var result = ""
        if ctrl { result += "C+" }
        if alt { result += "A+" }
        if shift { result += "S+" }
        if cmd { result += "W+" }
        result += key
        return result
    }

    // MARK: Normalization helpers

    private enum Modifier { case ctrl, alt, shift, cmd }

    /// Map a modifier token (case-insensitive, with aliases) to a modifier, or nil.
    private static func modifier(from token: String) -> Modifier? {
        switch token.uppercased() {
        case "C", "CTRL": return .ctrl
        case "A", "ALT", "OPT": return .alt
        case "S", "SHIFT": return .shift
        case "W", "CMD", "WIN": return .cmd
        default: return nil
        }
    }

    /// Uppercase a key token and apply spelling aliases, without validating it.
    private static func canonicalKeyToken(_ raw: String) -> String {
        let upper = raw.uppercased()
        switch upper {
        case "DEL": return "DELETE"
        case "ESCAPE": return "ESC"
        default: return upper
        }
    }

    /// Canonicalize a key token and return it only if it is in the allowed set.
    private static func validatedKeyToken(_ raw: String) -> String? {
        let token = canonicalKeyToken(raw)
        return allowedKeys.contains(token) ? token : nil
    }

    /// The full set of accepted canonical key tokens.
    private static let allowedKeys: Set<String> = {
        var keys = Set<String>()
        // Letters A..Z
        for scalar in UnicodeScalar("A").value...UnicodeScalar("Z").value {
            keys.insert(String(UnicodeScalar(scalar)!))
        }
        // Digits 0..9
        for digit in 0...9 { keys.insert(String(digit)) }
        // Function keys F1..F12
        for n in 1...12 { keys.insert("F\(n)") }
        // Named keys
        keys.formUnion([
            "ENTER", "TAB", "SPACE", "ESC", "BACKSPACE", "INSERT", "DELETE",
            "LEFT", "RIGHT", "UP", "DOWN", "PGUP", "PGDN", "HOME", "END",
            // The key left of the "1", identified by *position* rather than by the character it
            // produces (F-381). Every other token here is layout-independent because the character
            // is: an "A" is an "A" everywhere. This one is not — the same physical key is ` on a US
            // layout, ^ on a German one, @ on a French one — so binding the character would make the
            // shortcut mean a different key on every keyboard, and on a German layout the backtick
            // additionally lives behind Shift on a dead key. The dispatcher resolves this token from
            // the hardware key code instead; see KeymapMenu.keyToken(from:).
            "BACKQUOTE",
        ])
        // Numpad operator keys
        keys.formUnion(["NUM+", "NUM-", "NUM*", "NUM/"])
        return keys
    }()
}

// MARK: - KeymapScheme

/// One layer of chord->command bindings, parsed from an INI `[Shortcuts]` section.
public struct KeymapScheme: Sendable, Equatable {
    /// chord -> command name (e.g. "cm_Copy"). An empty command string represents an
    /// explicit suppression (meaningful only in the user layer).
    public var bindings: [KeyChord: String]

    public init(bindings: [KeyChord: String] = [:]) {
        self.bindings = bindings
    }

    /// Parse an INI whose `[Shortcuts]` section holds `spec=command` lines.
    /// Lines whose key fails to parse are skipped; a blank command removes the binding.
    public init(parsing ini: String) {
        var result: [KeyChord: String] = [:]
        var inShortcuts = false

        for rawLine in ini.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            // Comments.
            if line.hasPrefix(";") || line.hasPrefix("#") { continue }
            // Section header.
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                inShortcuts = name.caseInsensitiveCompare("Shortcuts") == .orderedSame
                continue
            }
            guard inShortcuts else { continue }
            // key=command (split on the first "=").
            guard let eq = line.firstIndex(of: "=") else { continue }
            let keyPart = String(line[line.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            let cmdPart = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard let chord = KeyChord(parsing: keyPart) else { continue }
            if cmdPart.isEmpty {
                result.removeValue(forKey: chord)
            } else {
                result[chord] = cmdPart
            }
        }
        self.bindings = result
    }

    /// Serialize to a `[Shortcuts]` INI block, one `spec=command` per binding,
    /// sorted by spec for deterministic output.
    public func serialized() -> String {
        var lines = ["[Shortcuts]"]
        let sorted = bindings.sorted { $0.key.spec < $1.key.spec }
        for (chord, command) in sorted {
            lines.append("\(chord.spec)=\(command)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Keymap

/// A layered effective keymap. User overrides win over the active scheme, which wins
/// over the builtin defaults.
public struct Keymap: Sendable {
    private let builtin: KeymapScheme
    private let scheme: KeymapScheme
    private var user: KeymapScheme

    public init(builtin: KeymapScheme, scheme: KeymapScheme = KeymapScheme(), user: KeymapScheme = KeymapScheme()) {
        self.builtin = builtin
        self.scheme = scheme
        self.user = user
    }

    /// Effective command for a chord (user > scheme > builtin). A user binding to ""
    /// explicitly suppresses lower layers and yields nil.
    public func command(for chord: KeyChord) -> String? {
        if let userCmd = user.bindings[chord] {
            return userCmd.isEmpty ? nil : userCmd
        }
        if let schemeCmd = scheme.bindings[chord] {
            return schemeCmd.isEmpty ? nil : schemeCmd
        }
        if let builtinCmd = builtin.bindings[chord] {
            return builtinCmd.isEmpty ? nil : builtinCmd
        }
        return nil
    }

    /// The highest-precedence chord currently bound to `command` (for menu display).
    /// Search order: user, then scheme, then builtin; within a layer pick the smallest
    /// spec (lexicographic) as a deterministic tie-break.
    public func chord(for command: String) -> KeyChord? {
        for layer in [user, scheme, builtin] {
            let matches = layer.bindings.filter { $0.value == command }.map { $0.key }
            if let best = matches.min(by: { $0.spec < $1.spec }) {
                return best
            }
        }
        return nil
    }

    /// The fully merged effective bindings (user over scheme over builtin), with any
    /// chord whose final value is "" (a suppression) removed.
    public var effective: [KeyChord: String] {
        var result = builtin.bindings
        for (chord, command) in scheme.bindings { result[chord] = command }
        for (chord, command) in user.bindings { result[chord] = command }
        return result.filter { !$0.value.isEmpty }
    }

    /// Add/replace a user override. `command == nil` removes the user entry entirely;
    /// `command == ""` installs an explicit suppression of lower layers.
    public mutating func setUserBinding(_ chord: KeyChord, to command: String?) {
        if let command {
            user.bindings[chord] = command
        } else {
            user.bindings.removeValue(forKey: chord)
        }
    }

    /// The user-override layer (for persistence).
    public var userScheme: KeymapScheme { user }
}
