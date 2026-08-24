// SPDX-License-Identifier: Apache-2.0
// SearchNotice.swift - What a search could not look at, and why (F-463).
//
// A search that quietly declines to open a file reads exactly like "the term is
// not in there". The dialog already refuses to make that mistake for an invalid
// regular expression (F-154); an archive it could not open deserves the same
// courtesy. Every skip a search makes produces one of these, and the dialog
// turns them into a sentence next to the hit count.

import Foundation

/// One place a search did not look, and the reason it did not.
public struct SearchNotice: Sendable, Equatable {
    /// Why a file or member was not searched.
    ///
    /// The cases are deliberately specific rather than a single `.failed(String)`:
    /// the dialog groups them ("2 need a password, 1 could not be opened"), and a
    /// grouped count cannot be recovered from prose. Localisation needs whole
    /// clauses too — assembling them from fragments at run time does not survive
    /// Hungarian or Korean.
    public enum Reason: Sendable, Equatable {
        /// A name we recognised, and then could not parse.
        case unreadable
        /// Encrypted, and no password was available. The names still matched — a zip
        /// stores them in clear — so only the *content* went unsearched.
        case needsPassword
        /// Larger than a search is willing to open. Carries the size and the ceiling,
        /// so the message can say how far over it was rather than only that it was.
        case tooLarge(Int64, limit: Int64)
        /// Nested deeper than `maxArchiveDepth` (the zip-bomb guard).
        case tooDeep

        // Deliberately no `noHandler`, `timedOut`, `memberTooLarge` or `skippedBinary`.
        // Each was written down first and emitted by nothing, and a case nobody raises is
        // a promise the dialog cannot keep — this type exists to stop the search claiming
        // more than it did.
    }

    /// The archive or member, as the user would recognise it (display path).
    public let path: String
    public let reason: Reason

    public init(path: String, reason: Reason) {
        self.path = path
        self.reason = reason
    }
}
