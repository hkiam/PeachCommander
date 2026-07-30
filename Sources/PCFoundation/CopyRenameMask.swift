// CopyRenameMask.swift - Wildcard rename mask for copy/move targets (F-080).
//
// Total Commander lets the F5/F6 target field end in a wildcard mask (e.g.
// "*.bak", "backup_*.*", "??.dat") so each copied/moved file is renamed on the
// fly. `*` inserts the remaining source characters, `?` copies exactly one, any
// other character is literal. Name and extension are masked independently, split
// at the last dot on both the mask and the source name.

import Foundation

public enum CopyRenameMask {
    /// True if `component` looks like a rename mask (contains `*` or `?`). The
    /// caller uses this on a target's last path component to decide mask mode.
    public static func isMask(_ component: String) -> Bool {
        component.contains("*") || component.contains("?")
    }

    /// Apply `mask` to `sourceName`, returning the new file name. Name and
    /// extension are expanded separately; a mask without a dot keeps the source
    /// extension. A trailing "." in the mask (e.g. "*.") strips the extension.
    public static func apply(_ mask: String, to sourceName: String) -> String {
        let (sBase, sExt) = splitBaseExt(sourceName)
        guard let dot = mask.lastIndex(of: ".") else {
            // No dot in the mask: expand the name part, keep the source extension.
            let base = expand(String(mask), source: sBase)
            return sExt.isEmpty ? base : base + "." + sExt
        }
        let maskName = String(mask[..<dot])
        let maskExt = String(mask[mask.index(after: dot)...])
        let base = expand(maskName, source: sBase)
        let ext = expand(maskExt, source: sExt)
        return ext.isEmpty ? base : base + "." + ext
    }

    /// Expand one mask segment against a source segment: `*` = rest of source,
    /// `?` = one source char (skipped if source is exhausted), else literal.
    private static func expand(_ mask: String, source: String) -> String {
        let src = Array(source)
        var i = 0
        var out = ""
        for ch in mask {
            switch ch {
            case "*":
                if i < src.count { out += String(src[i...]); i = src.count }
            case "?":
                if i < src.count { out.append(src[i]); i += 1 }
            default:
                out.append(ch)
            }
        }
        return out
    }

    /// Split a name into (base, ext) at the last dot, treating a leading dot as
    /// part of the base (so ".gitignore" has no extension) — the TC/Finder rule.
    private static func splitBaseExt(_ name: String) -> (base: String, ext: String) {
        let ns = name as NSString
        let dot = ns.range(of: ".", options: .backwards)
        if dot.location == NSNotFound || dot.location == 0 { return (name, "") }
        return (ns.substring(to: dot.location), ns.substring(from: dot.location + 1))
    }
}
