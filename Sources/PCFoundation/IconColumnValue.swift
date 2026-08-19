// SPDX-License-Identifier: Apache-2.0
// IconColumnValue.swift — the `symbolName\ttext` value of an icon column, split once (F-428, F-430).
//
// A content field that declares units "icon" returns `symbolName\ttext`: the SF Symbol the panel draws and
// the words beside it. The first version of that split the value where it was *drawn*, and the raw string
// stayed in the value cache — so sorting the column ordered rows by symbol name, "copy column value" put
// `pencil.circle.fill<TAB>Modified` on the clipboard, an unaimed filter for "circle" matched every row in a
// repository, and the harness dump gained a third field. The wire format has to be undone once, on the way
// in, and this is that one place.

import Foundation

public enum IconColumnValue {
    /// Split a raw icon-column value. A value with no tab has no symbol and is text throughout, which is
    /// what a plugin sends for a row it has no icon for.
    public static func split(_ raw: String) -> (symbol: String?, text: String) {
        guard let tab = raw.firstIndex(of: "\t") else { return (nil, raw) }
        let symbol = String(raw[raw.startIndex..<tab])
        // Only the first tab separates; anything after it belongs to the text, and an empty symbol field
        // means "no icon" rather than a symbol whose name is the empty string.
        return (symbol.isEmpty ? nil : symbol, String(raw[raw.index(after: tab)...]))
    }
}
