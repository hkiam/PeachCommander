// SPDX-License-Identifier: Apache-2.0
// MkDirEngine.swift - Create directories: nested `a/b/c` and multi `d1|d2`
// (SPEC-004 §8).

import Foundation
import PCFoundation

public enum MkDirEngine {
    /// The relative directory names `spec` asks for, validated but not created.
    ///
    /// Split out of `create` so that a caller which does not create through `FileManager` — a network
    /// or plugin mount, which creates through its own file system — asks the same question and gets
    /// the same refusals. The rules below are why that matters: they are not formatting, they are the
    /// reason a folder cannot be talked into appearing outside the directory the panel is showing.
    ///
    /// "." and ".." as whole components are refused rather than resolved. ".." put the new folder
    /// outside the directory the panel is showing — so it was created where the user could not
    /// see it, the listing did not change, and nothing said why. "." merely reported the parent
    /// back as freshly created. A leading "/" is *not* rejected: it is what anyone used to a
    /// shell types for "here", and `appendingPathComponent` already keeps it inside the parent.
    /// A name that merely contains dots (".config", "a..b") is untouched.
    public static func parse(spec: String) throws -> [String] {
        let groups = spec.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
        guard !groups.isEmpty else { throw OperationError.invalidName(spec) }
        var names: [String] = []
        for group in groups {
            let trimmed = group.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.contains("\0") { throw OperationError.invalidName(trimmed) }
            let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
            if parts.contains(where: { $0 == ".." || $0 == "." }) {
                throw OperationError.invalidName(trimmed)
            }
            names.append(trimmed)
        }
        // A spec that asked for nothing — "   ", or "|" on its own — used to report success while
        // creating no folder at all, so the dialog closed and the panel was unchanged.
        guard !names.isEmpty else { throw OperationError.invalidName(spec) }
        return names
    }

    /// Create one or more directories described by `spec` inside `parent`.
    /// `spec` may contain `|`-separated groups; each group may be a nested path
    /// (`a/b/c`). Returns the leaf paths created (or already present).
    /// On macOS only `/` (separator) and NUL are invalid in names.
    @discardableResult
    public static func create(spec: String, in parent: String) throws -> [String] {
        var created: [String] = []
        for trimmed in try parse(spec: spec) {
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
        // `parse` already refuses a spec that names nothing, so this is a post-condition rather than
        // the check it used to be: it holds the promise that a success means a folder exists.
        guard !created.isEmpty else { throw OperationError.invalidName(spec) }
        return created
    }
}
