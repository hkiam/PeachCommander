// MkDirEngine.swift - Create directories: nested `a/b/c` and multi `d1|d2`
// (SPEC-004 §8).

import Foundation
import PCFoundation

public enum MkDirEngine {
    /// Create one or more directories described by `spec` inside `parent`.
    /// `spec` may contain `|`-separated groups; each group may be a nested path
    /// (`a/b/c`). Returns the leaf paths created (or already present).
    /// On macOS only `/` (separator) and NUL are invalid in names.
    @discardableResult
    public static func create(spec: String, in parent: String) throws -> [String] {
        let groups = spec.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
        guard !groups.isEmpty else { throw OperationError.invalidName(spec) }
        var created: [String] = []
        for group in groups {
            let trimmed = group.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("\0") { throw OperationError.invalidName(trimmed) }
            let full = (parent as NSString).appendingPathComponent(trimmed)
            do {
                try FileManager.default.createDirectory(atPath: full,
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
                created.append(full)
            } catch {
                throw OperationError.cannotCreateDirectory(full)
            }
        }
        return created
    }
}
