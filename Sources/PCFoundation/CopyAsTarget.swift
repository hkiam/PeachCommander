// SPDX-License-Identifier: Apache-2.0
// CopyAsTarget.swift - Reading what the user typed into the "copy as" target field (F-399).
//
// Shift+F5 copies within the current directory under a new name, so the field is offered pre-filled
// with the source's own path and the user edits the last part of it. That makes the last component
// ambiguous in a way the ordinary F5 field is not: `/photos/holiday.jpg` can mean "into a folder
// called holiday.jpg" or "as a file called holiday.jpg", and only the context says which.
//
// The rules, in the order they are applied:
//
//   * A trailing separator means a directory. `/photos/backup/` is a place, never a name — this is
//     the one way the user can say so explicitly, and it is the same convention every shell uses.
//   * A last component containing `*` or `?` is a rename mask (F-080), whatever else is true. That is
//     what makes `*.bak` work for a whole selection.
//   * Otherwise, with exactly one item selected, the last component is the new **name**. With several
//     it cannot be — they would all land on top of each other — so it is a directory.
//
// A literal name is handed onwards as a `CopyRenameMask` with no wildcards in it, which expands to
// exactly itself. No second mechanism, and nothing in the engine has to learn about this dialog.

import Foundation

public enum CopyAsTarget {

    /// What the target field means: where to copy, and under what name.
    ///
    /// `mask` is nil when the whole string was a directory and the sources keep their own names.
    public struct Resolved: Equatable {
        public let directory: String
        public let mask: String?
        public init(directory: String, mask: String?) {
            self.directory = directory
            self.mask = mask
        }
    }

    /// Resolve `typed` against `baseDir` (the panel's own directory).
    ///
    /// Returns nil for an empty entry — the caller treats that as "no target given" rather than as
    /// the current directory, because silently copying onto the sources is exactly what this whole
    /// feature has to avoid.
    public static func resolve(_ typed: String, baseDir: String, singleItem: Bool) -> Resolved? {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Asked *before* expanding: `expandingTildeInPath` also standardises away a trailing
        // separator, so a check afterwards never sees the one thing it is looking for. Found by the
        // test for it, which is the only reason this is a comment rather than a bug.
        let saysDirectory = trimmed.hasSuffix("/")
        let expanded = (trimmed as NSString).expandingTildeInPath

        if saysDirectory {
            return Resolved(directory: absolute(expanded, baseDir: baseDir), mask: nil)
        }

        let last = (expanded as NSString).lastPathComponent
        let head = (expanded as NSString).deletingLastPathComponent
        let isName = CopyRenameMask.isMask(last) || singleItem
        guard isName, !last.isEmpty else {
            return Resolved(directory: absolute(expanded, baseDir: baseDir), mask: nil)
        }
        return Resolved(directory: absolute(head, baseDir: baseDir), mask: last)
    }

    /// Whether the copy would land exactly where the source already is.
    ///
    /// Answered on the strings, deliberately: this runs before anything is created, so there is no
    /// target on disk to compare identities with. It catches the case that matters — the offered
    /// value confirmed unchanged — and the engine's own `isSameFile` check, which asks the
    /// filesystem, is what catches the rest.
    public static func wouldLandOnSource(_ source: String, directory: String, mask: String) -> Bool {
        let landed = (directory as NSString)
            .appendingPathComponent(CopyRenameMask.apply(mask, to: (source as NSString).lastPathComponent))
        return (landed as NSString).standardizingPath == (source as NSString).standardizingPath
    }

    /// A path the engine can use: absolute as given, or relative to the panel's directory.
    private static func absolute(_ path: String, baseDir: String) -> String {
        var p = path
        while p.count > 1, p.hasSuffix("/") { p.removeLast() }
        if p.isEmpty { return baseDir }
        if (p as NSString).isAbsolutePath { return (p as NSString).standardizingPath }
        return ((baseDir as NSString).appendingPathComponent(p) as NSString).standardizingPath
    }
}
