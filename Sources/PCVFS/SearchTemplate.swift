// SPDX-License-Identifier: Apache-2.0
// SearchTemplate.swift - Named, reusable "Find Files" criteria, persisted as JSON.
//
// A template captures the *reusable* part of a search (masks, content, options) but
// not the per-search context (start directory, selection scope). `makeQuery` fills
// those in at search time. The store round-trips a list of templates to a file.

import Foundation
import PCFoundation

/// A named set of reusable search criteria.
public struct SearchTemplate: Codable, Equatable, Sendable {
    public var name: String
    public var nameMask: String
    public var contentText: String?
    public var caseSensitive: Bool
    public var useRegex: Bool
    public var wholeWord: Bool
    /// Hex byte sequence as a "48 65" style string, or nil when not a hex search.
    public var hexContent: String?
    public var minSize: Int64?
    public var maxSize: Int64?
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    public var includeDirectories: Bool
    public var contentEncodingAware: Bool
    public var maxDepth: Int
    /// Attribute filters (F-152): nil = don't care, true/false = must be / must not be.
    public var requireHidden: Bool?
    public var requireReadOnly: Bool?
    /// Report empty folders instead of files. See `SearchQuery.emptyDirectoriesOnly`.
    public var emptyDirectoriesOnly: Bool = false

    public init(name: String, nameMask: String = "*.*", contentText: String? = nil,
                caseSensitive: Bool = false, useRegex: Bool = false, wholeWord: Bool = false,
                hexContent: String? = nil, minSize: Int64? = nil, maxSize: Int64? = nil,
                modifiedAfter: Date? = nil, modifiedBefore: Date? = nil,
                includeDirectories: Bool = false, contentEncodingAware: Bool = false, maxDepth: Int = 0,
                requireHidden: Bool? = nil, requireReadOnly: Bool? = nil,
                emptyDirectoriesOnly: Bool = false) {
        self.name = name
        self.nameMask = nameMask
        self.contentText = contentText
        self.caseSensitive = caseSensitive
        self.useRegex = useRegex
        self.wholeWord = wholeWord
        self.hexContent = hexContent
        self.minSize = minSize
        self.maxSize = maxSize
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.includeDirectories = includeDirectories
        self.contentEncodingAware = contentEncodingAware
        self.maxDepth = maxDepth
        self.requireHidden = requireHidden
        self.requireReadOnly = requireReadOnly
        self.emptyDirectoriesOnly = emptyDirectoriesOnly
    }

    /// Decode field by field, treating every one as optional.
    ///
    /// Written out rather than synthesized because the synthesized version does *not* fall back to
    /// a property's default value — it throws on a missing key. Templates are saved to disk and
    /// outlive the version that wrote them, so adding a single option to this struct would have
    /// made every previously saved search fail to load, silently: `SearchTemplateStore.load`
    /// answers `[]` for anything it cannot decode. Now a template written by an older build keeps
    /// working, and so will one written by this build when the next option arrives.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        nameMask = try c.decodeIfPresent(String.self, forKey: .nameMask) ?? "*.*"
        contentText = try c.decodeIfPresent(String.self, forKey: .contentText)
        caseSensitive = try c.decodeIfPresent(Bool.self, forKey: .caseSensitive) ?? false
        useRegex = try c.decodeIfPresent(Bool.self, forKey: .useRegex) ?? false
        wholeWord = try c.decodeIfPresent(Bool.self, forKey: .wholeWord) ?? false
        hexContent = try c.decodeIfPresent(String.self, forKey: .hexContent)
        minSize = try c.decodeIfPresent(Int64.self, forKey: .minSize)
        maxSize = try c.decodeIfPresent(Int64.self, forKey: .maxSize)
        modifiedAfter = try c.decodeIfPresent(Date.self, forKey: .modifiedAfter)
        modifiedBefore = try c.decodeIfPresent(Date.self, forKey: .modifiedBefore)
        includeDirectories = try c.decodeIfPresent(Bool.self, forKey: .includeDirectories) ?? false
        contentEncodingAware = try c.decodeIfPresent(Bool.self, forKey: .contentEncodingAware) ?? false
        maxDepth = try c.decodeIfPresent(Int.self, forKey: .maxDepth) ?? 0
        requireHidden = try c.decodeIfPresent(Bool.self, forKey: .requireHidden)
        requireReadOnly = try c.decodeIfPresent(Bool.self, forKey: .requireReadOnly)
        emptyDirectoriesOnly = try c.decodeIfPresent(Bool.self, forKey: .emptyDirectoriesOnly) ?? false
    }

    /// Build a runnable query, supplying the per-search directory/scope.
    public func makeQuery(startDirectory: String, scopePaths: [String]? = nil) -> SearchQuery {
        var query = SearchQuery(nameMask: nameMask, startDirectory: startDirectory, maxDepth: maxDepth,
                    contentText: contentText, caseSensitive: caseSensitive, minSize: minSize, maxSize: maxSize,
                    useRegex: useRegex, scopePaths: scopePaths, wholeWord: wholeWord,
                    hexContent: hexContent.flatMap { ByteSearch.parseHex($0) },
                    modifiedAfter: modifiedAfter, modifiedBefore: modifiedBefore,
                    includeDirectories: includeDirectories, contentEncodingAware: contentEncodingAware,
                    requireHidden: requireHidden, requireReadOnly: requireReadOnly)
        query.emptyDirectoriesOnly = emptyDirectoriesOnly
        return query
    }
}

/// Persists a list of `SearchTemplate`s as JSON at a fixed file URL.
public final class SearchTemplateStore {
    private let url: URL

    public init(url: URL) { self.url = url }

    /// Load the saved templates (empty on a missing/unreadable/invalid file).
    public func load() -> [SearchTemplate] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SearchTemplate].self, from: data)) ?? []
    }

    /// Overwrite the stored templates. Returns true on success.
    @discardableResult
    public func save(_ templates: [SearchTemplate]) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(templates) else { return false }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    /// Add or replace a template (matched by name, case-insensitively); returns the
    /// resulting list, sorted by name.
    @discardableResult
    public func upsert(_ template: SearchTemplate) -> [SearchTemplate] {
        var all = load().filter { $0.name.caseInsensitiveCompare(template.name) != .orderedSame }
        all.append(template)
        all.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save(all)
        return all
    }

    /// Remove the template with the given name; returns the resulting list.
    @discardableResult
    public func remove(named name: String) -> [SearchTemplate] {
        let all = load().filter { $0.name.caseInsensitiveCompare(name) != .orderedSame }
        save(all)
        return all
    }
}
