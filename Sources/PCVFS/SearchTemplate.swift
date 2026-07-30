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

    public init(name: String, nameMask: String = "*.*", contentText: String? = nil,
                caseSensitive: Bool = false, useRegex: Bool = false, wholeWord: Bool = false,
                hexContent: String? = nil, minSize: Int64? = nil, maxSize: Int64? = nil,
                modifiedAfter: Date? = nil, modifiedBefore: Date? = nil,
                includeDirectories: Bool = false, contentEncodingAware: Bool = false, maxDepth: Int = 0,
                requireHidden: Bool? = nil, requireReadOnly: Bool? = nil) {
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
    }

    /// Build a runnable query, supplying the per-search directory/scope.
    public func makeQuery(startDirectory: String, scopePaths: [String]? = nil) -> SearchQuery {
        SearchQuery(nameMask: nameMask, startDirectory: startDirectory, maxDepth: maxDepth,
                    contentText: contentText, caseSensitive: caseSensitive, minSize: minSize, maxSize: maxSize,
                    useRegex: useRegex, scopePaths: scopePaths, wholeWord: wholeWord,
                    hexContent: hexContent.flatMap { ByteSearch.parseHex($0) },
                    modifiedAfter: modifiedAfter, modifiedBefore: modifiedBefore,
                    includeDirectories: includeDirectories, contentEncodingAware: contentEncodingAware,
                    requireHidden: requireHidden, requireReadOnly: requireReadOnly)
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
