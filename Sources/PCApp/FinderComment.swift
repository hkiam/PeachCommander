// FinderComment.swift - Read/write the macOS Finder comment (F-023).
//
// The Finder comment is stored in the `com.apple.metadata:kMDItemFinderComment`
// extended attribute as a binary property list wrapping the string. Reading and
// writing it directly through xattr needs no Spotlight query or TCC prompt, so we
// can keep it in sync with our descript.ion comments at the point of editing.

import Foundation

enum FinderComment {
    private static let attribute = "com.apple.metadata:kMDItemFinderComment"

    /// The Finder comment for `path`, or nil when absent/undecodable.
    static func read(_ path: String) -> String? {
        let size = path.withCString { getxattr($0, attribute, nil, 0, 0, 0) }
        guard size > 0 else { return nil }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buf in
            path.withCString { getxattr($0, attribute, buf.baseAddress, size, 0, 0) }
        }
        guard read > 0 else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? String
    }

    /// Set (or clear, when nil/empty) the Finder comment for `path`. Returns true
    /// on success. A cleared comment removes the attribute.
    @discardableResult
    static func write(_ comment: String?, to path: String) -> Bool {
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            let rc = path.withCString { removexattr($0, attribute, 0) }
            return rc == 0 || errno == ENOATTR
        }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: trimmed,
                                                             format: .binary, options: 0) else { return false }
        let rc = data.withUnsafeBytes { buf in
            path.withCString { getPath in setxattr(getPath, attribute, buf.baseAddress, buf.count, 0, 0) }
        }
        return rc == 0
    }
}
