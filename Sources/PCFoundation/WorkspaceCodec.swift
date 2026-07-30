// WorkspaceCodec.swift - (De)serialize a panel's tab list to a single string,
// used to persist named Workspaces (backlog item). Kept here (not in the app
// target) so the round-trip is unit-testable.

import Foundation

public enum WorkspaceCodec {
    private static let unitSeparator = "\u{1}"   // between fields of one tab
    private static let recordSeparator = "\u{2}" // between tabs

    /// Encodes tabs as `path US sort US asc US locked US cursor` records joined
    /// by a record separator. Both separators are control characters that do not
    /// occur in paths or sort keys.
    public static func encode(_ tabs: [PanelTabState]) -> String {
        tabs.map { t in
            [t.path, t.sortColumn, t.sortAscending ? "1" : "0", t.locked ? "1" : "0", t.cursorName ?? ""]
                .joined(separator: unitSeparator)
        }.joined(separator: recordSeparator)
    }

    /// Inverse of `encode`. Records with an empty path or fewer than four fields
    /// are skipped.
    public static func decode(_ string: String) -> [PanelTabState] {
        guard !string.isEmpty else { return [] }
        return string.components(separatedBy: recordSeparator).compactMap { record in
            let f = record.components(separatedBy: unitSeparator)
            guard f.count >= 4, !f[0].isEmpty else { return nil }
            return PanelTabState(path: f[0], sortColumn: f[1], sortAscending: f[2] == "1",
                                 locked: f[3] == "1", cursorName: (f.count > 4 && !f[4].isEmpty) ? f[4] : nil)
        }
    }
}
