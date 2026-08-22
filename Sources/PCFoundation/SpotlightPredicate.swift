// SPDX-License-Identifier: Apache-2.0
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

/// A structured file query, the shape the assistant's natural language is translated *into* (F-446).
///
/// The split is deliberate: the model turns "that PDF contract from last month" into these fields, and
/// Spotlight does the finding. Nothing here is a guess about language — the fields are inspectable, so
/// "nothing found" can be read as "it looked for a PDF named *contract* modified in the last 30 days"
/// rather than being a shrug.
public struct SpotlightQuery: Equatable, Sendable {
    /// Words or wildcards to match against the file NAME. A bare word becomes a substring match.
    public var nameMask: String
    /// Words to find INSIDE files, through Spotlight's content index.
    public var contentText: String?
    /// The kind of file, as a conformance class rather than an extension.
    public var kind: Kind?
    /// Modified within the last N days. Relative on purpose: it needs no knowledge of today's date,
    /// which is the one thing a language model reliably does not have.
    public var modifiedWithinDays: Int?
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    public var largerThanBytes: Int64?
    public var smallerThanBytes: Int64?

    public init(nameMask: String = "", contentText: String? = nil, kind: Kind? = nil,
                modifiedWithinDays: Int? = nil, modifiedAfter: Date? = nil, modifiedBefore: Date? = nil,
                largerThanBytes: Int64? = nil, smallerThanBytes: Int64? = nil) {
        self.nameMask = nameMask; self.contentText = contentText; self.kind = kind
        self.modifiedWithinDays = modifiedWithinDays
        self.modifiedAfter = modifiedAfter; self.modifiedBefore = modifiedBefore
        self.largerThanBytes = largerThanBytes; self.smallerThanBytes = smallerThanBytes
    }

    /// Whether this query says anything at all. An empty one would match the whole volume, which is
    /// not an answer to any question a user asked — the caller reports that rather than returning
    /// a hundred thousand paths.
    public var isEmpty: Bool {
        let name = nameMask.trimmingCharacters(in: .whitespaces)
        let namesAnything = name.isEmpty || name == "*" || name == "*.*"
        return namesAnything && (contentText ?? "").isEmpty && kind == nil
            && modifiedWithinDays == nil && modifiedAfter == nil && modifiedBefore == nil
            && largerThanBytes == nil && smallerThanBytes == nil
    }

    /// A file class, expressed as the UTI its type conforms to.
    ///
    /// Conformance, not extension: `kMDItemContentTypeTree` carries the whole chain, so `.image`
    /// matches a JPEG, a PNG and a HEIC without naming any of them. The list is short and every entry
    /// is a real system UTI — a longer guessed list would silently match nothing.
    public enum Kind: String, CaseIterable, Sendable {
        case pdf, image, movie, audio, text, source, archive, folder, application

        public var uti: String {
            switch self {
            case .pdf:         return "com.adobe.pdf"
            case .image:       return "public.image"
            case .movie:       return "public.movie"
            case .audio:       return "public.audio"
            case .text:        return "public.text"
            case .source:      return "public.source-code"
            case .archive:     return "public.archive"
            case .folder:      return "public.folder"
            case .application: return "com.apple.application"
            }
        }

        /// Tolerant parsing, because this arrives from a language model: "PDF", "pdfs", "images",
        /// "photo", "video" and "folders" all have to land somewhere sensible or the feature fails on
        /// wording rather than on substance.
        public init?(loose text: String) {
            let s = text.lowercased().trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { return nil }
            switch s {
            case "pdf", "pdfs":                                  self = .pdf
            case "image", "images", "picture", "pictures", "photo", "photos": self = .image
            case "movie", "movies", "video", "videos", "film":    self = .movie
            case "audio", "music", "sound", "sounds", "song", "songs": self = .audio
            case "text", "document", "documents", "doc", "docs":  self = .text
            case "source", "code", "sourcecode", "source-code":   self = .source
            case "archive", "archives", "zip", "zips":            self = .archive
            case "folder", "folders", "directory", "directories", "dir": self = .folder
            case "app", "apps", "application", "applications":    self = .application
            default:
                // Also accept the raw case name, so the documented values always work.
                guard let exact = Kind(rawValue: s) else { return nil }
                self = exact
            }
        }
    }
}

extension SpotlightPredicate {
    /// Build a predicate for a structured query, or nil when it says nothing.
    ///
    /// `now` is a parameter rather than a call so the relative window can be tested; every caller in
    /// the app passes the real clock.
    public static func build(_ query: SpotlightQuery, now: Date = Date()) -> NSPredicate? {
        guard !query.isEmpty else { return nil }
        var subs: [NSPredicate] = []

        // The name and content halves are exactly what the older builder already does, so it stays
        // the single place that knows how a mask becomes a pattern.
        let name = query.nameMask.trimmingCharacters(in: .whitespaces)
        let namesAnything = name.isEmpty || name == "*" || name == "*.*"
        if !namesAnything || !(query.contentText ?? "").isEmpty {
            subs.append(build(nameMask: namesAnything ? "*" : name, contentText: query.contentText))
        }

        if let kind = query.kind {
            subs.append(NSPredicate(format: "kMDItemContentTypeTree == %@", kind.uti))
        }
        // The relative window is resolved here, once, so "within 30 days" and an explicit range cannot
        // disagree about which end is inclusive.
        if let days = query.modifiedWithinDays, days > 0 {
            let from = now.addingTimeInterval(-Double(days) * 86_400)
            subs.append(NSPredicate(format: "kMDItemContentModificationDate >= %@", from as NSDate))
        }
        if let after = query.modifiedAfter {
            subs.append(NSPredicate(format: "kMDItemContentModificationDate >= %@", after as NSDate))
        }
        if let before = query.modifiedBefore {
            subs.append(NSPredicate(format: "kMDItemContentModificationDate <= %@", before as NSDate))
        }
        if let bytes = query.largerThanBytes {
            subs.append(NSPredicate(format: "kMDItemFSSize >= %@", NSNumber(value: bytes)))
        }
        if let bytes = query.smallerThanBytes {
            subs.append(NSPredicate(format: "kMDItemFSSize <= %@", NSNumber(value: bytes)))
        }

        guard !subs.isEmpty else { return nil }
        return subs.count == 1 ? subs[0] : NSCompoundPredicate(andPredicateWithSubpredicates: subs)
    }
}
