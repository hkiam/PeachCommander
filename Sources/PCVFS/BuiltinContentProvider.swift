// BuiltinContentProvider.swift - Standard file columns as content fields (I16 T04).
//
// Exposes the everyday file attributes (name, size, extension, modification date)
// through the exact same ContentFieldProvider interface a PDX plugin uses, so the
// built-in columns and plugin columns are fully symmetric — custom-column sets,
// search, and multi-rename treat "builtin.size" and "somePlugin.width" alike.

import Foundation

/// Built-in provider exposing the standard file columns as content fields.
public struct BuiltinContentProvider: ContentFieldProvider {
    public let providerName = "builtin"
    public let fields = [
        ContentField(id: "name", title: "Name"),
        ContentField(id: "size", title: "Size", unit: "bytes"),
        ContentField(id: "extension", title: "Extension"),
        ContentField(id: "modified", title: "Modified")
    ]

    public init() {}

    public func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
        switch fieldID {
        case "name":
            return .string(url.lastPathComponent)
        case "extension":
            let ext = url.pathExtension
            return ext.isEmpty ? .none : .string(ext)
        case "size":
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true, let size = values.fileSize else { return .none }
            return .integer(Int64(size))
        case "modified":
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let date = values.contentModificationDate else { return .none }
            return .string(Self.dateFormatter.string(from: date))
        default:
            return .none
        }
    }

    /// Stable, sortable, locale-independent timestamp text (also comparable as a string).
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
