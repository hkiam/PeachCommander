// SPDX-License-Identifier: Apache-2.0
// HistoryOperation.swift — the payload of a recorded file operation, encoded into one string (F-402).
//
// Its own file, away from `HistoryService`, because it is pure: no AppKit, no store, no main actor —
// which is what lets it be compiled into a test bundle and held to its one safety rule directly. That
// rule is `decode`, and it is the whole reason the type exists in this shape; see below.

import Foundation

/// The payload of a repeatable operation, encoded into one string.
///
/// Only copy and move are repeatable, and that is a decision rather than an omission: repeating a
/// *delete* would be a destructive action offered from a list of things the user is browsing, and
/// repeating a rename has no meaning once the name has changed. Both still appear in the history — Enter
/// on one shows it in the panel instead of doing anything to it.
enum HistoryOperation {
    static let kindCopy = "copy"
    static let kindMove = "move"
    /// The kinds the *macro recorder* can read and the history palette deliberately cannot (F-478).
    ///
    /// The palette's rule stands and is enforced where it always was — in `decode`, which still answers
    /// only for copy and move. The distinction it rests on is not the operation but the act: pressing
    /// Enter on a row of a list somebody is browsing must never delete anything, while building a macro
    /// is a deliberate act that is then shown as a plan and confirmed before every single run. So a
    /// trash or a rename can carry what it would take to repeat it, and only `decodeAny` will look.
    static let kindTrash = "trash"
    static let kindDelete = "delete"
    static let kindRename = "rename"
    static let kindMakeDirectory = "mkdir"

    private static let separator = "\u{3}"

    static func encode(kind: String, items: [String], mask: String?) -> String {
        ([kind, mask ?? ""] + items).joined(separator: separator)
    }

    /// A batch of renames, as `[old, new, old, new, …]` leaf names within the entry's directory.
    ///
    /// Pairs interleaved rather than two fields, because the payload is one flat list by construction
    /// and a second list would need a second separator that a file name could contain. U+0003 cannot
    /// appear in a macOS file name; nothing else here is safe to assume.
    static func encodeRenames(_ pairs: [(old: String, new: String)]) -> String {
        encode(kind: kindRename, items: pairs.flatMap { [$0.old, $0.new] }, mask: nil)
    }

    /// The rename pairs out of a `kindRename` payload, or nil when it is not one or is malformed.
    static func decodeRenames(_ payload: String) -> [(old: String, new: String)]? {
        guard let decoded = decodeAny(payload), decoded.kind == kindRename,
              decoded.items.count % 2 == 0, !decoded.items.isEmpty else { return nil }
        return stride(from: 0, to: decoded.items.count, by: 2).map {
            (old: decoded.items[$0], new: decoded.items[$0 + 1])
        }
    }

    /// Returns nil when the payload is empty or not one of the repeatable kinds.
    ///
    /// "Repeatable" here means *from the history palette*, where a row is one Enter away — so this
    /// answers only for copy and move, and adding a kind above cannot change that.
    static func decode(_ payload: String) -> (kind: String, items: [String], mask: String?)? {
        guard let decoded = decodeAny(payload),
              decoded.kind == kindCopy || decoded.kind == kindMove else { return nil }
        return decoded
    }

    /// Every kind, for the macro recorder.
    static func decodeAny(_ payload: String) -> (kind: String, items: [String], mask: String?)? {
        guard !payload.isEmpty else { return nil }
        let fields = payload.components(separatedBy: separator)
        guard fields.count >= 3 else { return nil }
        let items = Array(fields.dropFirst(2)).filter { !$0.isEmpty }
        guard !items.isEmpty else { return nil }
        return (fields[0], items, fields[1].isEmpty ? nil : fields[1])
    }
}
