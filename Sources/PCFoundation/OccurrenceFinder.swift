// OccurrenceFinder.swift - Find all (non-overlapping) occurrences of a term in a
// string as NSRanges. Pure + testable; used by the editor's "mark all" feature.

import Foundation

public enum OccurrenceFinder {
    /// All non-overlapping ranges of `term` in `string`. Empty term → none.
    public static func ranges(of term: String, in string: String,
                              caseInsensitive: Bool = true) -> [NSRange] {
        guard !term.isEmpty else { return [] }
        let ns = string as NSString
        let options: NSString.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
        var result: [NSRange] = []
        var start = 0
        while start < ns.length {
            let r = ns.range(of: term, options: options,
                             range: NSRange(location: start, length: ns.length - start))
            if r.location == NSNotFound { break }
            result.append(r)
            start = r.location + max(1, r.length)
        }
        return result
    }
}
