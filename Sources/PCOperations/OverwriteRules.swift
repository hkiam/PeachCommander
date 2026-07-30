// SPDX-License-Identifier: Apache-2.0
// OverwriteRules.swift - Pure decision rules for the overwrite dialog (F-086).
//
// The conditional "…All Older / …All Larger" blanket choices and Auto-Rename
// naming are pure functions of the two files, factored here so they can be
// unit-tested without the GUI resolver.

import Foundation

public enum OverwriteRules {
    /// Overwrite the target only when the source is strictly newer (a missing
    /// source date never overwrites; a missing target date does).
    public static func overwriteIfSourceNewer(source: FileFacts, target: FileFacts) -> OverwriteDecision {
        guard let s = source.modified else { return .skip }
        return (target.modified == nil || s > target.modified!) ? .overwrite : .skip
    }

    /// Overwrite the target only when the source is strictly larger.
    public static func overwriteIfSourceLarger(source: FileFacts, target: FileFacts) -> OverwriteDecision {
        source.size > target.size ? .overwrite : .skip
    }

    /// A non-colliding-ish rename: append " (2)" before the extension, or bump an
    /// existing " (N)" suffix. A further conflict simply re-prompts.
    public static func autoRenameName(_ name: String) -> String {
        let ns = name as NSString
        let ext = ns.pathExtension
        var stem = ns.deletingPathExtension
        var n = 2
        if let open = stem.range(of: " (", options: .backwards), stem.hasSuffix(")") {
            let inner = stem[open.upperBound..<stem.index(before: stem.endIndex)]
            if let num = Int(inner) {
                n = num + 1
                stem = String(stem[stem.startIndex..<open.lowerBound])
            }
        }
        let renamed = "\(stem) (\(n))"
        return ext.isEmpty ? renamed : "\(renamed).\(ext)"
    }
}
