// SPDX-License-Identifier: Apache-2.0
// FinderTagColor.swift - Reading and writing macOS Finder tags (F-291).
//
// Split out of PanelCells so it can be tested on its own: the cell drawing around it pulls in the
// theme and the icon cache, and none of that has anything to do with what a tag is.
//
// The whole point of this type is one asymmetry. A Finder tag is stored as "Name" or "Name\n<index>",
// and the *name* is localized — a file tagged red on a German system carries "Rot" — while the trailing
// colour index is not. So everything here works from the index, and the names are only ever a label.

import AppKit

/// Finder tag colors, resolved from the raw `_kMDItemUserTags` xattr so the
/// mapping is locale-independent (the tag *names* are localized; the trailing
/// color index 0…7 is not).
enum FinderTagColor {
    /// Index → color, matching Finder's label palette. Index 0 = "no color".
    static let palette: [NSColor] = [
        .clear,          // 0 none
        .systemGray,     // 1 gray
        .systemGreen,    // 2 green
        .systemPurple,   // 3 purple
        .systemBlue,     // 4 blue
        .systemYellow,   // 5 yellow
        .systemRed,      // 6 red
        .systemOrange,   // 7 orange
    ]

    /// Dot colors for the file's Finder tags, in stored order. Colored tags map
    /// to their palette color; a named tag without a color shows a neutral dot.
    static func colors(forPath path: String) -> [NSColor] {
        tagColorIndices(forPath: path).map { idx in
            (idx > 0 && idx < palette.count) ? palette[idx] : .tertiaryLabelColor
        }
    }

    /// Color indices (0…7) for the file's Finder tags, one per tag, in stored
    /// order. Index 0 means the tag has no assigned color. Empty when untagged.
    static func tagColorIndices(forPath path: String) -> [Int] {
        guard let tags = readUserTags(path) else { return [] }
        return tags.map { tag in
            let parts = tag.components(separatedBy: "\n")
            if parts.count > 1, let idx = Int(parts[1]), idx >= 0, idx < palette.count { return idx }
            return 0
        }
    }

    /// Maps a color name (English or German) to its Finder color index, or nil.
    static func colorIndex(forName name: String) -> Int? {
        switch name.lowercased() {
        case "gray", "grey", "grau": return 1
        case "green", "grün", "gruen": return 2
        case "purple", "lila", "violett", "violet": return 3
        case "blue", "blau": return 4
        case "yellow", "gelb": return 5
        case "red", "rot": return 6
        case "orange": return 7
        default: return nil
        }
    }

    /// The raw tag entries on a file ("Name" or "Name\n<index>"), in stored order.
    static func rawTags(forPath path: String) -> [String] { readUserTags(path) ?? [] }

    /// Write raw tag entries back, or remove the attribute entirely when there are none.
    ///
    /// Written as a binary plist through `setxattr`, the same shape `readUserTags` expects — and
    /// deliberately *not* through `URLResourceValues.tagNames`, which drops the colour: setting
    /// ["Red"] that way stores "Red\n0", index 0 meaning "no colour". A tag applied from this app
    /// therefore appeared grey in its own column and as a colourless custom tag in the Finder, and on a
    /// non-English system it did not merge with the localized label already on the file (F-291).
    @discardableResult
    static func writeRawTags(_ tags: [String], toPath path: String) -> Bool {
        let name = "com.apple.metadata:_kMDItemUserTags"
        guard !tags.isEmpty else { return removexattr(path, name, 0) == 0 || errno == ENOATTR }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: tags,
                                                             format: .binary, options: 0) else { return false }
        return data.withUnsafeBytes { setxattr(path, name, $0.baseAddress, data.count, 0, 0) } == 0
    }

    /// Reads the `com.apple.metadata:_kMDItemUserTags` xattr (a plist array of
    /// "Name" / "Name\n<index>" strings). Returns nil when absent.
    private static func readUserTags(_ path: String) -> [String]? {
        let name = "com.apple.metadata:_kMDItemUserTags"
        let size = getxattr(path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
        guard read > 0 else { return nil }
        if read < size { data.removeSubrange(read..<size) }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String]
    }
}
