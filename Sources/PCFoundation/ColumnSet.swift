// ColumnSet.swift - Custom column-set model + INI persistence (SPEC-002 §3, F-024).
//
// A named, ordered set of columns the user can show in a panel. Each column binds
// to a content-field id ("builtin.name", "fileinfo.width", "somePlugin.bitrate"),
// with a display title, pixel width, and alignment — the same qualified-id scheme
// the ContentFieldRegistry resolves, so built-in and plugin fields are interchangeable.
// Sets round-trip through an INIDocument so they survive hand-editing.

import Foundation

/// Horizontal alignment of a column's cells.
public enum ColumnAlignment: String, Sendable, CaseIterable {
    case left, right, center
}

/// One column in a set.
public struct ColumnSpec: Equatable, Sendable {
    public let fieldID: String        // qualified content-field id, e.g. "fileinfo.width"
    public let title: String          // column header text
    public let width: Int             // pixel width
    public let alignment: ColumnAlignment

    public init(fieldID: String, title: String, width: Int, alignment: ColumnAlignment = .left) {
        self.fieldID = fieldID
        self.title = title
        self.width = width
        self.alignment = alignment
    }
}

/// A named, ordered set of columns.
public struct ColumnSet: Equatable, Sendable {
    public let name: String
    public let columns: [ColumnSpec]

    public init(name: String, columns: [ColumnSpec]) {
        self.name = name
        self.columns = columns
    }
}

/// Reads/writes column sets in an INIDocument. Each set lives in its own
/// `[ColumnSet.<name>]` section with a `Count` and indexed `N.Field/Title/Width/Align`
/// keys, so unrelated INI content is preserved on save.
public enum ColumnSetStore {
    static let sectionPrefix = "ColumnSet."

    /// Parse all column sets from `doc`, in first-appearance order.
    public static func load(from doc: INIDocument) -> [ColumnSet] {
        var sets: [ColumnSet] = []
        for section in doc.sections() where section.hasPrefix(sectionPrefix) {
            let name = String(section.dropFirst(sectionPrefix.count))
            guard let countStr = doc.value(section: section, key: "Count"),
                  let count = Int(countStr) else { continue }
            var columns: [ColumnSpec] = []
            for i in stride(from: 1, through: count, by: 1) {
                guard let field = doc.value(section: section, key: "\(i).Field"), !field.isEmpty else { continue }
                let title = doc.value(section: section, key: "\(i).Title") ?? field
                let width = doc.value(section: section, key: "\(i).Width").flatMap(Int.init) ?? 100
                let align = doc.value(section: section, key: "\(i).Align")
                    .flatMap(ColumnAlignment.init(rawValue:)) ?? .left
                columns.append(ColumnSpec(fieldID: field, title: title, width: width, alignment: align))
            }
            sets.append(ColumnSet(name: name, columns: columns))
        }
        return sets
    }

    /// Write `sets` into `doc`, replacing any sections for the same names.
    public static func save(_ sets: [ColumnSet], into doc: inout INIDocument) {
        for set in sets {
            let section = sectionPrefix + set.name
            // Clear any stale indexed keys (a set may have shrunk) before rewriting.
            for key in doc.keys(inSection: section) {
                doc.remove(section: section, key: key)
            }
            doc.set(String(set.columns.count), section: section, key: "Count")
            for (index, col) in set.columns.enumerated() {
                let n = index + 1
                doc.set(col.fieldID, section: section, key: "\(n).Field")
                doc.set(col.title, section: section, key: "\(n).Title")
                doc.set(String(col.width), section: section, key: "\(n).Width")
                doc.set(col.alignment.rawValue, section: section, key: "\(n).Align")
            }
        }
    }

    /// Convenience: serialize `sets` to standalone INI text.
    public static func serialize(_ sets: [ColumnSet]) -> String {
        var doc = INIDocument()
        save(sets, into: &doc)
        return doc.serialized()
    }
}
