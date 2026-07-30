// RenameByEditor.swift - Edit selected names in a text editor (F-174).
//
// The multi-rename "edit in editor" round-trip: export one `old<TAB>new` line per
// selected file (the new column seeded equal to old), let the user edit the new
// column in any editor, then re-import and pair positionally. Pure and unit-
// tested; the app layer handles the temp file, the editor window and the actual
// renames.

import Foundation

public struct RenamePair: Equatable, Sendable {
    public let old: String
    public let new: String
    public init(old: String, new: String) { self.old = old; self.new = new }
}

public enum RenameByEditor {
    public enum PlanError: Error, Equatable {
        /// The edited file has a different number of lines than files exported.
        case countMismatch(expected: Int, got: Int)
        /// Line `line` (1-based) has an empty new name.
        case emptyName(line: Int)
        /// Two files would end up with the same name.
        case duplicate(String)
    }

    /// Tab-separated export text: `old<TAB>old` per name (edit the right column).
    public static func exportText(_ names: [String]) -> String {
        names.map { "\($0)\t\($0)" }.joined(separator: "\n") + "\n"
    }

    /// Pair `originals` with the edited text positionally and return the rename
    /// pairs whose name actually changed. Each edited line is `old<TAB>new` (or
    /// just `new`); only the part after the first tab is taken as the new name.
    public static func plan(originals: [String], editedText: String) -> Result<[RenamePair], PlanError> {
        var lines = editedText.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }   // editors add a trailing newline
        guard lines.count == originals.count else {
            return .failure(.countMismatch(expected: originals.count, got: lines.count))
        }
        var pairs: [RenamePair] = []
        var seen = Set<String>()
        for (i, line) in lines.enumerated() {
            let newName: String
            if let tab = line.firstIndex(of: "\t") {
                newName = String(line[line.index(after: tab)...]).trimmingCharacters(in: .whitespaces)
            } else {
                newName = line.trimmingCharacters(in: .whitespaces)
            }
            if newName.isEmpty { return .failure(.emptyName(line: i + 1)) }
            if !seen.insert(newName).inserted { return .failure(.duplicate(newName)) }
            if newName != originals[i] { pairs.append(RenamePair(old: originals[i], new: newName)) }
        }
        return .success(pairs)
    }
}
