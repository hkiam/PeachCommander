// SPDX-License-Identifier: Apache-2.0
// ContentFieldValues.swift - Reading structure back out of a plugin content field (F-379).
//
// A content field hands the host one display string, because that is all the ABI carries. When the host
// wants more than something to put in a table cell — the Notes plugin's "Note lines" is a *list*, and
// the viewer has to scroll to each of them — the string has to be read back apart, and that reading is
// the host's business, not the plugin's.
//
// Deliberately forgiving in one direction only: anything that is not a line number is dropped, and
// nothing is invented. A plugin that answers "3, 12" and one that answers "3,12" mean the same thing,
// but a plugin that answers "soon" means no lines at all — not line 0.

import Foundation

public enum ContentFieldValues {

    /// Line numbers from a field whose display value lists them separated by commas.
    ///
    /// Duplicates are dropped and the result is ascending, so a caller can use it as positions in a
    /// document without sorting again. Numbers below 1 are discarded: lines are 1-based everywhere in
    /// this app, and a 0 arriving from a plugin would silently address the line above the first one.
    public static func lineNumbers(_ display: String) -> [Int] {
        var seen = Set<Int>()
        var result: [Int] = []
        for part in display.split(separator: ",") {
            guard let n = Int(part.trimmingCharacters(in: .whitespaces)), n >= 1,
                  seen.insert(n).inserted else { continue }
            result.append(n)
        }
        return result.sorted()
    }
}
