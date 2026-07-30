// SPDX-License-Identifier: Apache-2.0
// FileAssociations.swift - Per-extension viewer/editor associations (F-273).
//
// A tiny, human-editable INI with two sections mapping a lowercased file
// extension to the application that should open it (an .app path or a bundle id).
// The host consults this before falling back to the built-in Lister / editor, so
// e.g. `.psd` can open in an external tool while `.txt` stays internal.
//
//   [Viewer]
//   psd = /Applications/Preview.app
//   [Editor]
//   swift = /Applications/Visual Studio Code.app
//
// An empty value or the literal `internal` means "use the built-in view/edit".

import Foundation

public struct FileAssociations: Equatable, Sendable {
    /// lowercased extension -> application (path or bundle id) for viewing.
    public private(set) var viewers: [String: String]
    /// lowercased extension -> application for editing.
    public private(set) var editors: [String: String]

    public init(viewers: [String: String] = [:], editors: [String: String] = [:]) {
        self.viewers = viewers
        self.editors = editors
    }

    /// The external application to VIEW `ext` with, or nil to use the built-in Lister.
    public func viewerApp(forExtension ext: String) -> String? { Self.resolve(viewers, ext) }
    /// The external application to EDIT `ext` with, or nil to use the built-in editor.
    public func editorApp(forExtension ext: String) -> String? { Self.resolve(editors, ext) }

    public mutating func setViewer(_ app: String?, forExtension ext: String) {
        Self.set(&viewers, app, ext)
    }
    public mutating func setEditor(_ app: String?, forExtension ext: String) {
        Self.set(&editors, app, ext)
    }

    private static func resolve(_ map: [String: String], _ ext: String) -> String? {
        let value = map[ext.lowercased()]?.trimmingCharacters(in: .whitespaces)
        guard let value, !value.isEmpty, value.lowercased() != "internal" else { return nil }
        return value
    }

    private static func set(_ map: inout [String: String], _ app: String?, _ ext: String) {
        let key = ext.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }
        if let app, !app.trimmingCharacters(in: .whitespaces).isEmpty { map[key] = app }
        else { map.removeValue(forKey: key) }
    }

    // MARK: - Row model (for the Options grid editor, F-273)

    /// One editor-grid row: an extension with its optional viewer/editor apps.
    /// Empty `viewer`/`editor` mean "use the built-in".
    public struct Row: Equatable, Sendable, Identifiable {
        public var ext: String
        public var viewer: String
        public var editor: String
        public var id: String { ext.lowercased() }
        public init(ext: String, viewer: String = "", editor: String = "") {
            self.ext = ext; self.viewer = viewer; self.editor = editor
        }
    }

    /// The union of viewer/editor extensions as grid rows, sorted by extension.
    public var rows: [Row] {
        Set(viewers.keys).union(editors.keys).sorted().map {
            Row(ext: $0, viewer: viewers[$0] ?? "", editor: editors[$0] ?? "")
        }
    }

    /// Rebuild from grid rows: blank extensions are dropped; blank viewer/editor
    /// values simply omit that mapping; a later row wins on a duplicate extension.
    public init(rows: [Row]) {
        var viewers: [String: String] = [:]
        var editors: [String: String] = [:]
        for row in rows {
            let key = row.ext.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let v = row.viewer.trimmingCharacters(in: .whitespaces)
            let e = row.editor.trimmingCharacters(in: .whitespaces)
            if v.isEmpty { viewers.removeValue(forKey: key) } else { viewers[key] = v }
            if e.isEmpty { editors.removeValue(forKey: key) } else { editors[key] = e }
        }
        self.init(viewers: viewers, editors: editors)
    }

    // MARK: - INI

    /// Parse the two-section INI. Unknown sections/keys are ignored.
    public static func parse(_ text: String) -> FileAssociations {
        var viewers: [String: String] = [:]
        var editors: [String: String] = [:]
        var section = ""
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).lowercased()
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            switch section {
            case "viewer": viewers[key] = value
            case "editor": editors[key] = value
            default: break
            }
        }
        return FileAssociations(viewers: viewers, editors: editors)
    }

    /// Serialize back to the INI form (sorted keys for stable diffs).
    public func serialized() -> String {
        var out = "[Viewer]\n"
        for k in viewers.keys.sorted() { out += "\(k) = \(viewers[k]!)\n" }
        out += "\n[Editor]\n"
        for k in editors.keys.sorted() { out += "\(k) = \(editors[k]!)\n" }
        return out
    }
}
