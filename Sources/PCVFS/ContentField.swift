// SPDX-License-Identifier: Apache-2.0
// ContentField.swift - Generic content-field interface (SPEC-012 §5, I16).
//
// A uniform way to expose extra, computed columns for a file — the internal
// analogue of a WDX content plugin. Built-in providers (e.g. image dimensions)
// and, later, real PDX plugins implement `ContentFieldProvider`; a registry
// resolves a qualified field id ("provider.field") to a typed value. Consumed by
// custom columns, search, and multi-rename.

import Foundation

/// A typed field value.
public enum ContentValue: Equatable, Sendable {
    case string(String)
    case integer(Int64)
    case none

    /// A human-readable display string ("" for `.none`).
    public var display: String {
        switch self {
        case .string(let s): return s
        case .integer(let i): return "\(i)"
        case .none: return ""
        }
    }
}

/// Metadata describing one field a provider can compute.
public struct ContentField: Equatable, Sendable {
    public let id: String       // unqualified within its provider, e.g. "width"
    public let title: String    // column header, e.g. "Width"
    public let unit: String?    // e.g. "px"
    /// A whole searchable document rather than a value to put in a column (PC_FT_FULLTEXT).
    ///
    /// The distinction matters in both directions: a decompiled class is useless as a column and
    /// essential to a content search, so this is what keeps megabytes of source out of a table cell
    /// and lets the search find it (F-351).
    public let isFullText: Bool
    public init(id: String, title: String, unit: String? = nil, isFullText: Bool = false) {
        self.id = id
        self.title = title
        self.unit = unit
        self.isFullText = isFullText
    }
}

/// Something that computes content fields for local files.
public protocol ContentFieldProvider: Sendable {
    /// Unique provider namespace, e.g. "fileinfo".
    var providerName: String { get }
    /// Fields this provider offers.
    var fields: [ContentField] { get }
    /// Compute one field's value for a local file (`.none` if unavailable).
    func value(fieldID: String, forFileAt url: URL) async -> ContentValue
    /// Search a full-text field *inside the provider*, if it can, returning the 1-based line and its
    /// text. Default nil: the caller then fetches the text and searches it itself.
    ///
    /// Worth having because fetching means copying a whole document across the plugin boundary, and
    /// whatever buffer that uses becomes the limit on how much of it is searchable.
    func searchFullText(fieldID: String, forFileAt url: URL, needle: String,
                        matchCase: Bool) async -> (line: Int, preview: String)?
}

public extension ContentFieldProvider {
    func searchFullText(fieldID: String, forFileAt url: URL, needle: String,
                        matchCase: Bool) async -> (line: Int, preview: String)? { nil }
}

/// Holds the registered providers and resolves qualified field ids.
public final class ContentFieldRegistry: @unchecked Sendable {
    private var providers: [String: ContentFieldProvider] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(_ provider: ContentFieldProvider) {
        lock.lock(); defer { lock.unlock() }
        providers[provider.providerName] = provider
    }

    /// All fields across providers, each as a qualified id "provider.field".
    public func allQualifiedFields() -> [(qualifiedID: String, field: ContentField)] {
        lock.lock(); defer { lock.unlock() }
        return providers.values
            .sorted { $0.providerName < $1.providerName }
            .flatMap { provider in provider.fields.map { ("\(provider.providerName).\($0.id)", $0) } }
    }

    /// The text every full-text provider can produce for `url`, concatenated.
    ///
    /// This is what lets a content search look at something other than the file's own bytes: a
    /// decompiled class, and later any other format a plugin can turn into text. Providers that offer
    /// no full-text field, or none for this file, contribute nothing — so a file nobody claims costs
    /// one dictionary lookup per provider and is then searched normally (F-351).
    public func fullText(forFileAt url: URL) async -> String? {
        lock.lock()
        let candidates = providers.values
            .flatMap { provider in provider.fields.filter(\.isFullText).map { (provider, $0.id) } }
        lock.unlock()
        var parts: [String] = []
        for (provider, fieldID) in candidates {
            let text = await provider.value(fieldID: fieldID, forFileAt: url).display
            if !text.isEmpty { parts.append(text) }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    /// Search every full-text provider for `needle`, preferring providers that can search themselves.
    ///
    /// Returns the first match as a line number and that line's text. A provider that cannot search
    /// gets asked for its text instead, so the two kinds coexist and only the capable ones avoid the
    /// copy.
    public func searchFullText(forFileAt url: URL, needle: String,
                               matchCase: Bool) async -> (line: Int, preview: String)? {
        lock.lock()
        let candidates = providers.values
            .flatMap { provider in provider.fields.filter(\.isFullText).map { (provider, $0.id) } }
        lock.unlock()
        for (provider, fieldID) in candidates {
            if let hit = await provider.searchFullText(fieldID: fieldID, forFileAt: url,
                                                      needle: needle, matchCase: matchCase) {
                return hit
            }
        }
        return nil
    }

    /// Whether any provider offers full text at all, so a caller can skip the work entirely.
    public var hasFullTextProvider: Bool {
        lock.lock(); defer { lock.unlock() }
        return providers.values.contains { $0.fields.contains(where: \.isFullText) }
    }

    /// Resolve a qualified field id ("provider.field") to a value for a file.
    public func value(qualifiedID: String, forFileAt url: URL) async -> ContentValue {
        let parts = qualifiedID.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return .none }
        lock.lock(); let provider = providers[parts[0]]; lock.unlock()
        guard let provider else { return .none }
        return await provider.value(fieldID: parts[1], forFileAt: url)
    }
}

/// Built-in provider exposing image dimensions/metadata via ImageInfoProvider.
public struct ImageInfoContentProvider: ContentFieldProvider {
    public let providerName = "fileinfo"
    public let fields = [
        ContentField(id: "width", title: "Width", unit: "px"),
        ContentField(id: "height", title: "Height", unit: "px"),
        ContentField(id: "dimensions", title: "Dimensions"),
        ContentField(id: "colormodel", title: "Color Model")
    ]

    public init() {}

    public func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
        guard let info = ImageInfoProvider.info(at: url) else { return .none }
        switch fieldID {
        case "width": return .integer(Int64(info.pixelWidth))
        case "height": return .integer(Int64(info.pixelHeight))
        case "dimensions": return .string(info.dimensionsText)
        case "colormodel": return info.colorModel.map(ContentValue.string) ?? .none
        default: return .none
        }
    }
}
