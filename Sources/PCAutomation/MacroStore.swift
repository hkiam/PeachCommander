// SPDX-License-Identifier: Apache-2.0
// MacroStore.swift — the user's macros on disk (F-478).
//
// `<configRoot>/macros.json`, a JSON array. Same shape and same rules as the other preset stores
// (`rename-presets.json`, `sync-presets.json`) and the same hard rule as `SkillStore`: this is a file
// a person edits, so nothing in here may trap or throw on bad content. A malformed file yields no
// macros and says so in the diagnostics — it never stops the application.

import Foundation

public struct MacroStore: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    /// The macros on disk, in file order, with unusable entries dropped.
    ///
    /// Returns the problems alongside, because dropping an entry silently is how a user ends up
    /// staring at a button that does nothing. The caller logs them; the editor shows them.
    public func load() -> (macros: [Macro], problems: [String]) {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return ([], []) }
        guard let decoded = try? JSONDecoder().decode([Macro].self, from: data) else {
            return ([], ["\(url.lastPathComponent): not a readable list of macros"])
        }
        var problems: [String] = []
        var seen = Set<String>()
        var out: [Macro] = []
        for macro in decoded {
            let id = Self.sanitize(macro.id)
            guard !id.isEmpty else {
                problems.append("a macro with an unusable id (“\(macro.id)”) was skipped"); continue
            }
            guard seen.insert(id).inserted else {
                // Not "last one wins" as in SkillStore: there the duplicate replaces a *built-in*
                // whose id is known, and the later entry is what an editor means. Here both entries
                // are the user's, both would claim the command name `mc_<id>`, and quietly picking
                // one means a button that runs the macro the user was not looking at.
                problems.append("two macros share the id “\(id)”; the second was skipped"); continue
            }
            guard !macro.steps.isEmpty else {
                // A macro with no steps would register as a command that does nothing, which is worse
                // than absent: it appears in the Command Browser and on a key. The seeded file's
                // explanatory entry is one of these, and this is what keeps it out of the command table.
                continue
            }
            if id != macro.id { problems.append("macro id “\(macro.id)” was read as “\(id)”") }
            out.append(Macro(id: id,
                             title: macro.title.isEmpty ? id : macro.title,
                             icon: macro.icon,
                             steps: macro.steps))
        }
        return (out, problems)
    }

    /// Just the macros, for the callers that have nowhere to put a diagnostic.
    public func macros() -> [Macro] { load().macros }

    public func macro(id: String) -> Macro? {
        let wanted = Self.sanitize(id)
        return macros().first { $0.id == wanted }
    }

    /// Write `macros`, replacing the file. Sorted keys and pretty-printed: this file is meant to be
    /// opened, diffed and put in a dotfiles repo.
    public func save(_ macros: [Macro]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(macros).write(to: url, options: .atomic)
    }

    /// Add or replace one macro by id, keeping the order of the rest.
    public func upsert(_ macro: Macro) throws {
        var all = macros()
        if let index = all.firstIndex(where: { $0.id == macro.id }) { all[index] = macro }
        else { all.append(macro) }
        try save(all)
    }

    public func remove(id: String) throws {
        try save(macros().filter { $0.id != Self.sanitize(id) })
    }

    /// An id reduced to what a command name may hold.
    ///
    /// The id becomes `mc_<id>`, which is typed into `usercmd.ini`, parsed out of `.mnu` files and
    /// matched against keymap entries — all of which are whitespace- and separator-sensitive INI
    /// formats. Letting a space or a `=` through would produce a command name that some of those
    /// files can express and others cannot.
    public static func sanitize(_ id: String) -> String {
        String(id.unicodeScalars.map { scalar -> Character in
            let c = Character(scalar)
            if c.isASCII, c.isLetter || c.isNumber || c == "-" || c == "_" { return c }
            return "-"
        }).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// An id derived from a title, unique against `existing`.
    public static func proposedID(for title: String, existing: [String]) -> String {
        let base = sanitize(title.lowercased()).isEmpty ? "macro" : sanitize(title.lowercased())
        guard existing.contains(base) else { return base }
        var n = 2
        while existing.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}
