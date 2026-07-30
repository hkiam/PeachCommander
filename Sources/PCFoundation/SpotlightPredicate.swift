// SpotlightPredicate.swift - Build an NSMetadataQuery predicate from a name mask
// (+ optional content text). Split out of the app target so the predicate string
// is unit-testable without a live Spotlight index.

import Foundation

public enum SpotlightPredicate {
    /// Any of the (OR'd) space-separated name masks, AND an optional content
    /// clause. A bare "*"/"*.*"/empty mask matches all names; a token without a
    /// wildcard becomes a substring match.
    public static func build(nameMask: String, contentText: String?) -> NSPredicate {
        var subs: [NSPredicate] = []

        let tokens = nameMask.split(separator: " ").map(String.init)
        let matchesAll = tokens.isEmpty || tokens.contains { $0 == "*" || $0 == "*.*" }
        if !matchesAll {
            let namePreds = tokens.map { token -> NSPredicate in
                let pattern = (token.contains("*") || token.contains("?")) ? token : "*\(token)*"
                return NSPredicate(format: "kMDItemFSName LIKE[cd] %@", pattern)
            }
            subs.append(namePreds.count == 1 ? namePreds[0]
                        : NSCompoundPredicate(orPredicateWithSubpredicates: namePreds))
        }

        if let text = contentText, !text.isEmpty {
            subs.append(NSPredicate(format: "kMDItemTextContent CONTAINS[cd] %@", text))
        }

        guard !subs.isEmpty else { return NSPredicate(format: "kMDItemFSName LIKE[cd] %@", "*") }
        return subs.count == 1 ? subs[0] : NSCompoundPredicate(andPredicateWithSubpredicates: subs)
    }
}
