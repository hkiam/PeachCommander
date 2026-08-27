// SPDX-License-Identifier: Apache-2.0
// ScriptStore.swift — the user's OSA scripts on disk (F-477).
//
// `<configRoot>/scripts/` holds one file per script, and `scripts.json` beside them holds only what a
// script file cannot carry: its title, how it should be run, and its timeout. Two stores rather than
// one blob, because a script is something a person edits in Script Editor and a `.applescript` on disk
// is what Script Editor can open. Dropping a file into the folder is enough to add a script.
//
// This lives in PCAutomation rather than in the plugin for the reason `DirectActionPlan` gives about
// itself: nothing under `Plugins/` is compiled into a test target, so logic put there cannot be tested
// at all. The plugin keeps the OSAKit and subprocess machinery, which needs a machine anyway; the
// decisions about what a script *is* are here.

import Foundation

/// How a script is run. See `Plugins/Scripting/ScriptRunner.swift` for why the default is a subprocess.
public enum ScriptRunMode: String, Codable, Sendable, CaseIterable {
    /// `osascript` as a child process: a hard timeout, a cancel, and a kill.
    case subprocess
    /// OSAKit inside the app: a structured return value and a compiled script cached between runs, at
    /// the price of no timeout — a script that loops holds the app.
    case inProcess = "in-process"
}

public struct ScriptDefinition: Codable, Sendable, Equatable {
    /// The file's base name, and the suffix of the command id `plugin.script.run.<id>`.
    public let id: String
    /// The file name as it is on disk, extension included.
    public var fileName: String
    public var title: String
    /// An OSA language name as `OSALanguage` knows it — "AppleScript", "JavaScript", or anything else
    /// installed on the machine. A string rather than an enum on purpose: the set is a property of the
    /// machine, not of this build, and a machine with another OSA component should be able to use it.
    public var language: String
    public var mode: ScriptRunMode
    /// Seconds before a subprocess script is killed. Ignored for `.inProcess`, which cannot be timed
    /// out — stated in the editor rather than silently dropped.
    public var timeoutSeconds: Int

    public init(id: String, fileName: String, title: String, language: String,
                mode: ScriptRunMode = .subprocess, timeoutSeconds: Int = 30) {
        self.id = id; self.fileName = fileName; self.title = title
        self.language = language; self.mode = mode; self.timeoutSeconds = timeoutSeconds
    }

    public var commandName: String { "plugin.script.run." + id }
}

public struct ScriptStore: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    private var metadataURL: URL { directory.appendingPathComponent("scripts.json") }

    /// Which file extensions are scripts, and what language each implies.
    ///
    /// `.scpt` is a compiled AppleScript, which `osascript` runs directly and OSAKit loads; it is listed
    /// so a script saved from Script Editor in its default format is found without being renamed.
    public static let languagesByExtension: [String: String] = [
        "applescript": "AppleScript",
        "scpt": "AppleScript",
        "scptd": "AppleScript",
        "jxa": "JavaScript",
        "js": "JavaScript",
    ]

    /// The scripts in the folder, in name order, each with whatever metadata `scripts.json` holds.
    ///
    /// The *folder* is the source of truth for which scripts exist. A metadata entry for a file that is
    /// gone is ignored rather than reported: dragging a script out of the folder is how it is removed,
    /// and complaining about it afterwards would make a normal act look like an error.
    public func scripts() -> [ScriptDefinition] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let metadata = self.metadata()
        return names
            .filter { Self.languagesByExtension[($0 as NSString).pathExtension.lowercased()] != nil }
            .sorted()
            .map { fileName in
                let id = MacroStore.sanitize((fileName as NSString).deletingPathExtension)
                let language = Self.languagesByExtension[
                    (fileName as NSString).pathExtension.lowercased()] ?? "AppleScript"
                guard var stored = metadata[id] else {
                    return ScriptDefinition(id: id, fileName: fileName,
                                            title: (fileName as NSString).deletingPathExtension,
                                            language: language)
                }
                // The file name and the language come from the file, always. A metadata entry that
                // disagreed with the extension would decide how a `.applescript` is run by what somebody
                // typed in a JSON file, which is the wrong way round.
                stored.fileName = fileName
                stored.language = language
                return stored
            }
    }

    public func script(id: String) -> ScriptDefinition? {
        let wanted = MacroStore.sanitize(id)
        return scripts().first { $0.id == wanted }
    }

    /// The absolute path of a script's file.
    public func url(of script: ScriptDefinition) -> URL {
        directory.appendingPathComponent(script.fileName)
    }

    /// `scripts.json` as a dictionary by id. Never throws: a file a person edits must not be able to
    /// stop the application, so unreadable content yields no metadata and every script gets defaults.
    func metadata() -> [String: ScriptDefinition] {
        guard let data = try? Data(contentsOf: metadataURL),
              let list = try? JSONDecoder().decode([ScriptDefinition].self, from: data)
        else { return [:] }
        return Dictionary(list.map { (MacroStore.sanitize($0.id), $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Write metadata for `scripts`, keeping only what differs from the defaults.
    ///
    /// Only the entries that say something: a file whose title is its name, run as a subprocess with the
    /// default timeout, needs no entry at all, and writing one for every script would turn the folder
    /// into something that has to be kept in sync by hand.
    public func saveMetadata(_ scripts: [ScriptDefinition]) throws {
        let interesting = scripts.filter { !Self.isDefault($0) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !interesting.isEmpty else {
            try? FileManager.default.removeItem(at: metadataURL)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(interesting).write(to: metadataURL, options: .atomic)
    }

    static func isDefault(_ script: ScriptDefinition) -> Bool {
        script.title == (script.fileName as NSString).deletingPathExtension
            && script.mode == .subprocess && script.timeoutSeconds == 30
    }

    /// Create the folder and, if it is empty, put one working example in it.
    ///
    /// An example rather than an empty folder, because the useful thing to know about this feature is
    /// not that it exists but how a script reaches the panels — and that is four lines.
    public func seedIfEmpty() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard scripts().isEmpty else { return }
        try Self.exampleScript.write(to: directory.appendingPathComponent("Example.applescript"),
                                     atomically: true, encoding: .utf8)
    }

    static let exampleScript = """
        -- An example Peach Commander script. Edit it, or delete it and add your own.
        --
        -- The panel state arrives in the environment, so the common case needs no Apple events and
        -- no permission prompt:
        --
        --   PC_ACTIVE_DIR      the active panel's folder
        --   PC_TARGET_DIR      the other panel's folder
        --   PC_CURSOR_NAME     the file under the cursor
        --   PC_SELECTION_FILE  a text file with one selected path per line
        --
        -- Anything beyond that goes through the application itself, which is scriptable:
        --
        --   tell application "Peach Commander"
        --       select "*.pdf"
        --       copy items to "~/Documents/PDFs"
        --   end tell

        set activeDir to system attribute "PC_ACTIVE_DIR"
        return "The active panel is showing " & activeDir

        """
}
