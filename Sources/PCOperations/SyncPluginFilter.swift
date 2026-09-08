// SPDX-License-Identifier: Apache-2.0
// SyncPluginFilter.swift - The advanced sync filter's plugin criterion.
//
// A content-field plugin can answer things about a file that no stat can: an image's dimensions, a
// document's page count, a media file's duration. `SyncFilter.pluginPredicate` carries one such
// condition as text, and this is where it is applied.
//
// Where it is applied is the whole design, and two obvious places are both wrong.
//
// Not inside the walk, and not on the pair: resolving a field can run a decompiler — `ContentField`
// has an `isFullText` flag precisely because a plugin value can be megabytes — so asking about both
// sides of every entry is 2 × N plugin invocations across the whole tree. On a large tree with a
// heavy provider that is not slow, it is a hang.
//
// And `ContentValue.none` does not satisfy a predicate, by the same rule the search window uses. A
// one-sided row has no file at all on the side that is missing, so a naive "either side fails and the
// pair is out" would exclude *every* file that exists on only one side the moment a plugin criterion
// is set — the feature would ship by copying nothing, and the reason would be invisible.
//
// So: after classification, on the rows that are actually going to do something, files only, and only
// the side the action reads from. Then each file is asked about once, and there is always a file to
// ask about. This mirrors how Find Files does it — the predicate is resolved per hit, after the
// engine — rather than inventing a second shape for the same problem.

import Foundation
import PCFoundation
import PCVFS

public enum SyncPluginFilter {

    /// Drop the rows whose source file does not satisfy `predicate`.
    ///
    /// - Returns: The rows that stay, and how many were held back.
    ///
    /// Rows that are left alone regardless:
    ///
    ///   * a directory — a folder has no content for a plugin to read, and excluding one would take
    ///     everything under it;
    ///   * `.equal` and `.none` — nothing is going to happen to them either way, so a plugin call
    ///     would buy nothing;
    ///   * anything whose source side is not a local folder. The registry's API takes a file `URL`,
    ///     so a server or an archive would have to be materialised first; answering "does not
    ///     satisfy" for a side that simply cannot be asked would silently drop the whole comparison.
    ///     The window disables the criterion for such a side and says so, and this is the same
    ///     decision made where it cannot be skipped.
    ///
    /// A predicate that does not parse holds nothing back. The sheet refuses to close on one, so this
    /// is the case of a preset written by hand or by a later version; excluding everything because a
    /// line of text was malformed is the one outcome nobody could diagnose from the result.
    public static func apply(to results: [SyncResult], predicate text: String,
                             left: SyncSide, right: SyncSide,
                             registry: ContentFieldRegistry) async -> (kept: [SyncResult], heldBack: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let predicate = ContentFieldPredicate.parse(trimmed) else {
            return (results, 0)
        }
        // Both sides or neither. With one local side and one archive, the rows copying *out* of the
        // local side could be judged and the rows copying into it could not — a filter applied to
        // half a comparison, which is harder to explain than one not applied at all.
        guard canEvaluate(left: left, right: right) else { return (results, 0) }

        var kept: [SyncResult] = []
        var heldBack = 0
        for result in results {
            guard let url = sourceFile(for: result, left: left, right: right) else {
                kept.append(result); continue
            }
            // A half-applied filter is a plan nobody asked for: a cancelled pass hands back the
            // rows as they were, and the caller checks `Task.isCancelled` before believing any of it.
            if Task.isCancelled { return (results, 0) }
            let value = await registry.value(qualifiedID: predicate.qualifiedID, forFileAt: url)
            if predicate.evaluate(value) { kept.append(result) } else { heldBack += 1 }
        }
        return (kept, heldBack)
    }

    /// The local file this row's action reads from, or nil when there is nothing to ask about.
    ///
    /// "Reads from" rather than "is named after": a copy to the right reads the left file, a delete
    /// on the right acts on the right one. A conflict has no direction yet, and is judged on the left
    /// — the row carries the left side's spelling of the name, and a pair present on both sides is
    /// one file as far as the user is concerned.
    private static func sourceFile(for result: SyncResult,
                                   left: SyncSide, right: SyncSide) -> URL? {
        guard !result.item.isDirectory else { return nil }
        let takeLeft: Bool
        switch result.action {
        case .copyToRight, .deleteLeft, .conflict: takeLeft = true
        case .copyToLeft, .deleteRight: takeLeft = false
        case .equal, .none: return nil
        }
        let side = takeLeft ? left : right
        guard case .localDir(let dir) = side else { return nil }
        // The side that must exist for that action is the side being read; if it is not there the
        // row is not one this criterion can judge.
        guard takeLeft ? (result.item.leftSize != nil) : (result.item.rightSize != nil) else { return nil }
        // The row carries one spelling of the name — the left side's when it is there. Under
        // case-insensitive matching the other side may spell it differently, which a case-insensitive
        // volume resolves anyway; the scanner keeps both spellings for the reads that cannot rely on
        // that, and if this ever has to, it takes them the same way.
        return URL(fileURLWithPath: (dir as NSString).appendingPathComponent(result.item.relativePath))
    }

    /// Whether a plugin criterion can be evaluated for this pair of sides at all.
    ///
    /// The window asks this to disable the criterion with a visible reason rather than offering one
    /// that would quietly do nothing.
    public static func canEvaluate(left: SyncSide, right: SyncSide) -> Bool {
        if case .localDir = left, case .localDir = right { return true }
        return false
    }
}
