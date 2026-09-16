// SPDX-License-Identifier: Apache-2.0
// WorkspaceStore.swift - The user's workspaces on disk (F-499).
//
// `<configRoot>/workspaces/<id>.json`, **one file per workspace**, for the reason `MacroStore` gives
// about macros: a workspace is a thing people hand to each other — `.pcworkspace` is this exact file,
// not an export of it — and a file that will not parse cannot take its neighbours with it.
//
// That second half matters more here than it does for macros. A macro that fails to load is a button
// that does nothing; a workspace that fails to load may be the one holding the session, so "one bad
// entry loses everything" would mean opening the app to two empty panels and no way back.
//
// A `struct` with synchronous file access rather than an actor, matching `MacroStore`: there is
// nothing to keep between calls, one owner writes these files, and being free of actor hops is what
// lets the whole thing be tested from a temporary directory without a window or a run loop. Callers
// that write during a switch do it off the main actor; the payload is a few kilobytes.
//
// The same hard rule `MacroStore` states applies: these are files a person edits, so nothing here may
// trap or throw on bad content. A malformed file costs that workspace and says so in `problems`.

import Foundation

public struct WorkspaceStore: Sendable {

    /// The directory holding one `<id>.json` per workspace.
    public let directory: URL

    /// The single-file store this replaced, for the one-time move. Nil when there is nothing to move.
    public let legacyFile: URL?

    /// - Parameter legacyFile: `workspaces.ini` as it used to be. When it is there and `directory` is
    ///   not, ``migrate(sessionWorkspace:now:)`` moves its contents across.
    public init(directory: URL, legacyFile: URL? = nil) {
        self.directory = directory
        self.legacyFile = legacyFile
    }

    // MARK: - Reading

    /// The workspaces on disk, in their stored order, with unusable ones dropped.
    ///
    /// Returns the problems alongside for the reason `MacroStore` spells out: dropping one silently is
    /// how somebody ends up staring at a chip that is not there any more. The caller logs them; the
    /// manager window shows them.
    public func load() -> (workspaces: [Workspace], problems: [String]) {
        var problems: [String] = []
        var decoded: [Workspace] = []
        for file in files() {
            guard let data = try? Data(contentsOf: file), !data.isEmpty else { continue }
            guard let workspace = try? Self.decoder.decode(Workspace.self, from: data) else {
                problems.append("\(file.lastPathComponent) could not be read and was skipped")
                continue
            }
            guard workspace.formatVersion <= Workspace.currentFormatVersion else {
                // Refused rather than half-read: a newer file may carry fields this build would drop
                // on the next save, which is how a workspace loses its stash to an older version.
                problems.append("\(file.lastPathComponent) was written by a newer version and was skipped")
                continue
            }
            decoded.append(workspace)
        }
        // By stored order, then by id, so that two files with the same order — or none — still come
        // out in the same sequence on every launch. A chip strip that reshuffles itself between
        // launches would make ⌃1…⌃9 mean something different every morning.
        decoded.sort { ($0.order, $0.id) < ($1.order, $1.id) }
        return (decoded, problems)
    }

    private func files() -> [URL] {
        let found = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        // `<id>.journal.json` sits in the same directory and is also a `.json`; without this it would
        // be read as a workspace, fail to decode, and be reported as a problem on every launch.
        return found.filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".journal.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Writing

    /// Write one workspace, creating the directory if needed. Returns false when it could not be
    /// written — the caller decides whether that is worth saying out loud.
    @discardableResult
    public func save(_ workspace: Workspace) -> Bool {
        guard var data = try? Self.encoder.encode(workspace) else { return false }
        // A trailing newline, because these files are edited by hand and land in version control,
        // where a file without one shows up as "No newline at end of file" on every single change.
        if data.last != 0x0A { data.append(0x0A) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(workspace.id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func saveAll(_ workspaces: [Workspace]) -> Bool {
        var ok = true
        for workspace in workspaces where !save(workspace) { ok = false }
        return ok
    }

    public func delete(id: String) {
        try? FileManager.default.removeItem(at: url(id))
        // The journal goes with its workspace. This is the whole reason it is a file per workspace
        // rather than rows in a shared list: deleting it is `rm`, not a filtering pass with a class of
        // orphan bug behind it (F-499).
        try? FileManager.default.removeItem(at: journalURL(id))
    }

    // MARK: - The journal, in a file of its own

    /// `<id>.journal.json`, beside the workspace rather than inside it.
    ///
    /// The workspace file is rewritten on every navigation — it is where the live panel state lives —
    /// and a thousand journal entries riding along would mean writing a hundred kilobytes every time
    /// somebody presses Return on a folder. The journal is appended to far less often and read only
    /// when its window opens, so it pays for itself by being separate.
    public func journalURL(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).journal.json")
    }

    public func loadJournal(id: String) -> WorkspaceJournal {
        guard let data = try? Data(contentsOf: journalURL(id)), !data.isEmpty,
              let journal = try? Self.decoder.decode(WorkspaceJournal.self, from: data)
        else { return WorkspaceJournal() }
        return journal
    }

    @discardableResult
    public func saveJournal(_ journal: WorkspaceJournal, for id: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if journal.isEmpty {
                // Nothing to say, so nothing on disk — and an empty file left behind would be read
                // back on every launch for no reason.
                try? FileManager.default.removeItem(at: journalURL(id))
                return true
            }
            var data = try Self.encoder.encode(journal)
            if data.last != 0x0A { data.append(0x0A) }
            try data.write(to: journalURL(id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func url(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    // MARK: - The move from one INI file to a directory

    /// Move a `workspaces.ini` across, once, and put the old file out of the way.
    ///
    /// Only when there is no directory yet: somebody who already has one has answered this question.
    ///
    /// `sessionWorkspace` is what makes this safe for the overwhelming majority who never saved a
    /// layout at all — it is their *current* session, turned into a workspace and put first, so they
    /// open the new build and find the app exactly as they left it, now with a chip behind it. Without
    /// it, a user with no saved layouts would get an empty list and a panel pointing at home.
    ///
    /// The old file is renamed rather than deleted, for the reason `MacroStore` gives: it is the
    /// user's data, and `workspaces.ini.migrated` says what happened without anybody reading a
    /// release note.
    ///
    /// Returns the workspaces written, or nil when there was nothing to do.
    @discardableResult
    public func migrateIfNeeded(sessionWorkspace: Workspace, now: Date = Date()) -> [Workspace]? {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return nil }

        let legacyText = legacyFile.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let migrated = WorkspaceMigration.workspaces(legacyINI: legacyText,
                                                     session: sessionWorkspace,
                                                     now: now)
        guard saveAll(migrated) else { return nil }

        if let legacyFile, FileManager.default.fileExists(atPath: legacyFile.path) {
            let aside = legacyFile.appendingPathExtension("migrated")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: legacyFile, to: aside)
        }
        return migrated
    }

    // MARK: - Coders

    /// Pretty-printed with sorted keys and ISO-8601 dates, because these files are read and edited by
    /// people and diffed by version control. A workspace under `git` should show one changed line when
    /// one thing changed.
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
