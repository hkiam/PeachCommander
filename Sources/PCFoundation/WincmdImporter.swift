// WincmdImporter.swift - Import a subset of Total Commander's wincmd.ini (F-276).
//
// TC users migrating to Peach Commander can bring over two things that map cleanly
// onto existing PC models:
//
//   * the directory hotlist  ([DirMenu] menu<i>/cmd<i>)  → [HotlistEntry]
//   * the button bar          ([Buttonbar] inline, or a referenced .bar file) → ButtonBar
//
// This type is pure (text in, model out) so it is fully unit-testable; only the
// button-bar *reference* form touches the filesystem (to read the adjacent .bar),
// and that goes through an injectable FileManager. Colors ([Colors] BGR ints) have
// no configurable-palette destination in PC yet and are only *detected* here for
// the caller's summary; FTP sites live in a separate file (wcx_ftp.ini) and are
// handled by WincmdFtpImporter in PCNet.

import Foundation

public struct WincmdImportResult: Sendable, Equatable {
    /// Directory bookmarks flattened out of TC's [DirMenu].
    public var hotlistEntries: [HotlistEntry]
    /// The button bar, resolved either inline from [Buttonbar] or from a referenced .bar.
    public var buttonBar: ButtonBar?
    /// The raw `Buttonbar=` reference value, when the bar is stored in a separate file
    /// (kept for the summary — e.g. so the caller can report an unresolved reference).
    public var buttonBarReference: String?
    /// Whether a [Colors] section was present (reported as "not imported").
    public var colorsPresent: Bool

    public init(hotlistEntries: [HotlistEntry] = [], buttonBar: ButtonBar? = nil,
                buttonBarReference: String? = nil, colorsPresent: Bool = false) {
        self.hotlistEntries = hotlistEntries
        self.buttonBar = buttonBar
        self.buttonBarReference = buttonBarReference
        self.colorsPresent = colorsPresent
    }
}

public enum WincmdImporter {

    /// Parse TC's `[DirMenu]` directory hotlist into a flat list of title→path
    /// bookmarks. TC stores parallel `menu<i>` (caption) / `cmd<i>` (command) keys.
    /// Only `cd <path>` commands become bookmarks; separators (`menu=-`), submenu
    /// openers (empty `cmd`), submenu closers (`menu=--`) and any non-`cd` commands
    /// are skipped, so nested menus are flattened to their directory leaves.
    public static func parseHotlist(_ ini: INIDocument) -> [HotlistEntry] {
        var out: [HotlistEntry] = []
        var i = 1
        var consecutiveMisses = 0
        // TC numbers entries contiguously from 1; tolerate a tiny gap then stop.
        while consecutiveMisses < 3 {
            let menu = ini.value(section: "DirMenu", key: "menu\(i)")
            let cmd = ini.value(section: "DirMenu", key: "cmd\(i)")
            if menu == nil && cmd == nil {
                consecutiveMisses += 1
                i += 1
                continue
            }
            consecutiveMisses = 0
            if let cmd, let path = directoryPath(fromCommand: cmd) {
                let caption = cleanCaption(menu ?? "")
                let title = caption.isEmpty ? (path as NSString).lastPathComponent : caption
                out.append(HotlistEntry(title: title, path: path))
            }
            i += 1
        }
        return out
    }

    /// Extract the target directory from a TC menu command, or nil if it isn't a
    /// `cd` command. Handles `cd <path>` (the hotlist form); other commands are
    /// ignored (they have no bookmark meaning).
    static func directoryPath(fromCommand cmd: String) -> String? {
        let trimmed = cmd.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("cd ") else { return nil }
        let path = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return path.isEmpty ? nil : path
    }

    /// Strip a Windows menu mnemonic marker: a single `&` is removed, `&&` becomes a
    /// literal `&`.
    static func cleanCaption(_ s: String) -> String {
        s.replacingOccurrences(of: "&&", with: "\u{0001}")
         .replacingOccurrences(of: "&", with: "")
         .replacingOccurrences(of: "\u{0001}", with: "&")
         .trimmingCharacters(in: .whitespaces)
    }

    /// Resolve the button bar: prefer an inline `[Buttonbar]` (older wincmd.ini kept
    /// buttons there); otherwise follow a `Buttonbar=<path>` reference to an adjacent
    /// `.bar` file in `sourceDirectory` (matched by filename, case-insensitively).
    /// Returns the parsed bar (nil if empty/unresolved) and the raw reference string.
    public static func resolveButtonBar(iniText: String, sourceDirectory: URL,
                                        fileManager: FileManager = .default) -> (bar: ButtonBar?, reference: String?) {
        let inline = ButtonBar(parsing: iniText)
        if !inline.buttons.isEmpty { return (inline, nil) }

        let ini = INIDocument(parsing: iniText)
        guard let ref = ini.value(section: "Buttonbar", key: "Buttonbar"), !ref.isEmpty else {
            return (nil, nil)
        }
        // The reference is a Windows path (possibly with unresolved %env% vars); we
        // only use its filename and look for it next to the wincmd.ini.
        let fileName = ref.split(whereSeparator: { $0 == "\\" || $0 == "/" }).last.map(String.init) ?? ref
        if let url = locate(fileName: fileName, in: sourceDirectory, fileManager: fileManager),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            let bar = ButtonBar(parsing: text)
            return (bar.buttons.isEmpty ? nil : bar, ref)
        }
        return (nil, ref)
    }

    private static func locate(fileName: String, in dir: URL, fileManager: FileManager) -> URL? {
        let direct = dir.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: direct.path) { return direct }
        let lower = fileName.lowercased()
        let contents = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return contents.first { $0.lastPathComponent.lowercased() == lower }
    }

    /// Import everything importable from a wincmd.ini at `sourceURL`.
    public static func importAll(iniText: String, sourceURL: URL,
                                 fileManager: FileManager = .default) -> WincmdImportResult {
        let ini = INIDocument(parsing: iniText)
        let hotlist = parseHotlist(ini)
        let (bar, ref) = resolveButtonBar(iniText: iniText,
                                          sourceDirectory: sourceURL.deletingLastPathComponent(),
                                          fileManager: fileManager)
        let colorsPresent = ini.sections().contains { $0.lowercased() == "colors" }
        return WincmdImportResult(hotlistEntries: hotlist, buttonBar: bar,
                                  buttonBarReference: ref, colorsPresent: colorsPresent)
    }
}
