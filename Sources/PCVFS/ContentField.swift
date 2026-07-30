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
    public init(id: String, title: String, unit: String? = nil) {
        self.id = id
        self.title = title
        self.unit = unit
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
