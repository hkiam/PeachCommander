// SPDX-License-Identifier: Apache-2.0
// MacroStore.swift — the user's macros on disk (F-478).
//
// `<configRoot>/macros/<id>.json`, **one file per macro**. It was one `macros.json` holding all of
// them, which followed the other preset stores (`rename-presets.json`, `sync-presets.json`) — and a
// macro is not a preset. It is a thing people hand to each other: "here, this is how I file invoices."
// Getting one out of a JSON array meant editing by hand, and getting one in meant editing by hand
// again. The project already draws this distinction elsewhere and says why — `scripts/` keeps one file
// per script because a script is something a person opens in Script Editor, `themes/` one per theme,
// `menus/` one per `.mnu`. A macro belongs with those, not with the presets.
//
// It also cost robustness. A single file is a single point of failure: one entry with `"steps"`
// written as a string, and *nothing* loaded — every macro gone, every button and key pointing at one
// silently doing nothing. Per-entry decoding fixed that inside the array; separate files make it
// structural, because a file that will not parse cannot take its neighbours with it.
//
// **Order** is the one thing a directory does not give you, and it is not decoration: the order the
// macros are in is the order the Command Browser and the button-bar picker list them in. So each file
// carries an `order`, assigned on save. A file dropped in by hand has none and lands at the end, which
// is where a new thing belongs.
//
// The same hard rule as `SkillStore` still holds: these are files a person edits, so nothing here may
// trap or throw on bad content. A malformed file costs that macro and says so in the diagnostics.

import Foundation

public struct MacroStore: Sendable {

    /// The directory holding one `<id>.json` per macro.
    public let directory: URL

    /// The single-file store this replaced, for the one-time move. Nil when there is nothing to move.
    private let legacyFile: URL?

    /// - Parameter legacyFile: `macros.json` as it used to be. When it is there and `directory` is
    ///   not, ``migrateIfNeeded()`` moves its contents across.
    public init(directory: URL, legacyFile: URL? = nil) {
        self.directory = directory
        self.legacyFile = legacyFile
    }

    // MARK: - Reading

    /// The macros on disk, in their saved order, with unusable ones dropped.
    ///
    /// Returns the problems alongside, because dropping one silently is how a user ends up staring at
    /// a button that does nothing. The caller logs them; the manager and the editor show them.
    public func load() -> (macros: [Macro], problems: [String]) {
        var problems: [String] = []
        var decoded: [(macro: Macro, order: Int?, file: String)] = []
        for file in files() {
            guard let data = try? Data(contentsOf: file), !data.isEmpty else { continue }
            guard let macro = try? JSONDecoder().decode(Macro.self, from: data) else {
                problems.append("\(file.lastPathComponent) could not be read and was skipped")
                continue
            }
            decoded.append((macro, order(in: data), file.lastPathComponent))
        }
        // By saved order, then by file name so that two files without one — or with the same one —
        // still come out in the same sequence on every launch. A list that reshuffles itself between
        // launches would make the button-bar picker and the Command Browser unreadable.
        decoded.sort {
            ($0.order ?? Int.max, $0.file) < ($1.order ?? Int.max, $1.file)
        }

        var seen = Set<String>()
        var out: [Macro] = []
        for entry in decoded {
            let macro = entry.macro
            let id = Self.sanitize(macro.id.isEmpty ? (entry.file as NSString).deletingPathExtension
                                                    : macro.id)
            guard !id.isEmpty else {
                problems.append("\(entry.file) has an unusable id (“\(macro.id)”) and was skipped")
                continue
            }
            guard seen.insert(id).inserted else {
                // Both entries are the user's and both would claim the command name `mc_<id>`, so
                // quietly picking one means a button that runs the macro they were not looking at.
                problems.append("two macros share the id “\(id)”; \(entry.file) was skipped")
                continue
            }
            guard !macro.steps.isEmpty else {
                // A macro with no steps would register as a command that does nothing, which is worse
                // than absent: it appears in the Command Browser and on a key.
                continue
            }
            if id != macro.id, !macro.id.isEmpty {
                problems.append("macro id “\(macro.id)” was read as “\(id)”")
            }
            out.append(Macro(id: id, title: macro.title.isEmpty ? id : macro.title,
                             icon: macro.icon, steps: macro.steps))
        }
        return (out, problems)
    }

    /// Just the macros, for the callers that have nowhere to put a diagnostic.
    public func macros() -> [Macro] { load().macros }

    public func macro(id: String) -> Macro? {
        let wanted = Self.sanitize(id)
        return macros().first { $0.id == wanted }
    }

    /// The file a macro lives in — what "edit this one" has to open.
    public func file(for id: String) -> URL {
        directory.appendingPathComponent(Self.sanitize(id) + ".json")
    }

    /// Every `.json` in the directory, by name.
    ///
    /// Sorted so that `files()` is deterministic before `load` re-sorts by `order`; and filtered by
    /// extension so a `README.md` or a `.DS_Store` beside them is not reported as a broken macro.
    private func files() -> [URL] {
        let found = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        return found.filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The `order` a file carries, read from the raw JSON.
    ///
    /// Out of the JSON rather than off `Macro`, because it is not part of what a macro *is* — it is
    /// where this installation happens to keep it in the list. A macro someone sends you carries
    /// whatever number it had on their machine, and importing it assigns a fresh one.
    private func order(in data: Data) -> Int? {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["order"] as? Int
    }

    // MARK: - Writing

    /// Write `macros` as the whole collection: one file each, in this order, and nothing else left over.
    ///
    /// Removing what is no longer in the list is what makes this "the collection" rather than "some
    /// files": a delete in the manager has to actually delete, and a rename that changed an id would
    /// otherwise leave the old file behind to be loaded again next launch.
    public func save(_ macros: [Macro]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = Set<String>()
        for (index, macro) in macros.enumerated() {
            let url = file(for: macro.id)
            try Self.write(macro, order: index, to: url)
            written.insert(url.lastPathComponent)
        }
        for stale in files() where !written.contains(stale.lastPathComponent) {
            // Only files that are themselves macros. A `.json` in this folder that has no steps is not
            // one — `_readme.json` from the seed is exactly that, and so is any note a user keeps
            // beside their macros. Deleting those because somebody reordered the list would be taking
            // away something nobody asked to have taken away.
            guard let data = try? Data(contentsOf: stale),
                  let macro = try? JSONDecoder().decode(Macro.self, from: data),
                  !macro.steps.isEmpty
            else { continue }
            try? FileManager.default.removeItem(at: stale)
        }
    }

    /// One macro as the bytes of its own file.
    ///
    /// Pretty-printed with sorted keys: these files are meant to be opened, diffed, kept in a dotfiles
    /// repo and sent to somebody. `order` is written alongside rather than into `Macro`, so the type
    /// stays what a macro is and a file that is imported elsewhere carries no stale position.
    public static func encoded(_ macro: Macro, order: Int? = nil) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let order else { return try encoder.encode(macro) }
        var object = (try JSONSerialization.jsonObject(with: try encoder.encode(macro))
                      as? [String: Any]) ?? [:]
        object["order"] = order
        return try JSONSerialization.data(withJSONObject: object,
                                          options: [.prettyPrinted, .sortedKeys])
    }

    /// Write one macro's file, keeping any keys the file already had that this does not own.
    ///
    /// `_comment` is why. JSON has no comments, so the shipped examples — and any note a user has
    /// written next to their own macro — live in a key the decoder ignores. Encoding straight from
    /// `Macro` drops every unknown key, which means the first reorder in the manager would silently
    /// delete the explanations the file exists to carry. So the object on disk is the base and the
    /// macro is merged over it.
    private static func write(_ macro: Macro, order: Int?, to url: URL) throws {
        let fresh = (try JSONSerialization.jsonObject(with: try encoded(macro, order: order))
                     as? [String: Any]) ?? [:]
        var object = ((try? Data(contentsOf: url))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        for (key, value) in fresh { object[key] = value }
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            .write(to: url, options: .atomic)
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

    // MARK: - Exchange

    /// One or more macros read out of a file somebody sent.
    ///
    /// Accepts both shapes on purpose: a single macro object, which is what ``encoded(_:order:)``
    /// writes, and an array of them — which is what the old `macros.json` was, so a file from before
    /// this change, or from somebody who has not updated, imports without being edited first.
    public static func decodeForImport(_ data: Data) -> [Macro] {
        let decoder = JSONDecoder()
        if let one = try? decoder.decode(Macro.self, from: data) { return [one] }
        guard let elements = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else { return [] }
        return elements.compactMap { element in
            guard let bytes = try? JSONSerialization.data(withJSONObject: element) else { return nil }
            return try? decoder.decode(Macro.self, from: bytes)
        }
    }

    /// Add `incoming` to the collection, giving anything whose id is taken a free one.
    ///
    /// Never replaces: an import is somebody else's macro arriving, and silently overwriting the one
    /// you wrote under the same obvious name ("backup") is the one outcome that cannot be undone from
    /// here. Returns what was actually added, with the ids they ended up with.
    @discardableResult
    public func importing(_ incoming: [Macro]) throws -> [Macro] {
        var all = macros()
        var added: [Macro] = []
        for macro in incoming where !macro.steps.isEmpty {
            let id = Self.proposedID(for: Self.sanitize(macro.id).isEmpty ? macro.title : macro.id,
                                     existing: all.map(\.id))
            let placed = Macro(id: id, title: macro.title.isEmpty ? id : macro.title,
                               icon: macro.icon, steps: macro.steps)
            all.append(placed)
            added.append(placed)
        }
        guard !added.isEmpty else { return [] }
        try save(all)
        return added
    }

    // MARK: - The move from one file to a directory

    /// Move a `macros.json` across, once, and put the old file out of the way.
    ///
    /// Only when there is no directory yet: a user who already has one has answered this question, and
    /// a `macros.json` sitting beside it is theirs to do with as they like.
    ///
    /// The old file is renamed rather than deleted. It is the user's data and the move is the kind of
    /// thing that has to be reversible by hand — and a file called `macros.json.migrated` says what
    /// happened without anybody having to read a release note.
    ///
    /// Returns whether anything was moved.
    @discardableResult
    public func migrateIfNeeded() -> Bool {
        guard let legacyFile,
              !FileManager.default.fileExists(atPath: directory.path),
              let data = try? Data(contentsOf: legacyFile), !data.isEmpty
        else { return false }
        guard let elements = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return false }
        // The *raw* objects are what gets written, not `Macro` values re-encoded. JSON has no comments,
        // so an explanation next to a macro lives in a `_comment` the decoder ignores — and a migration
        // that quietly deleted the notes a user wrote about their own macros would be a poor trade for
        // a tidier layout. Each object is validated by decoding it, and then written as it stands.
        var seen = Set<String>()
        var written = 0
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for element in elements {
                guard let bytes = try? JSONSerialization.data(withJSONObject: element),
                      let macro = try? JSONDecoder().decode(Macro.self, from: bytes),
                      !macro.steps.isEmpty
                else { continue }
                // Through the same sanitising the loader does, so a legacy id that was only ever
                // tolerated becomes the id its file is named after rather than a name nothing finds.
                let id = Self.sanitize(macro.id)
                guard !id.isEmpty, seen.insert(id).inserted else { continue }
                var object = element
                object["id"] = id
                object["order"] = written
                try JSONSerialization.data(withJSONObject: object,
                                           options: [.prettyPrinted, .sortedKeys])
                    .write(to: file(for: id), options: .atomic)
                written += 1
            }
        } catch { return false }
        guard written > 0 else { return false }
        try? FileManager.default.moveItem(
            at: legacyFile,
            to: legacyFile.deletingLastPathComponent()
                .appendingPathComponent(legacyFile.lastPathComponent + ".migrated"))
        return true
    }

    // MARK: - Ids

    /// An id reduced to what a command name may hold.
    ///
    /// The id becomes `mc_<id>`, which is typed into `usercmd.ini`, parsed out of `.mnu` files and
    /// matched against keymap entries — all of which are whitespace- and separator-sensitive INI
    /// formats. Letting a space or a `=` through would produce a command name that some of those
    /// files can express and others cannot. It is now also a *file name*, which rules out the same
    /// characters for a second reason.
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
