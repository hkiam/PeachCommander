// SPDX-License-Identifier: Apache-2.0
// PathResolver.swift - Resolve a user-typed path for direct navigation (TODOS #13).
//
// Expands a leading ~, resolves a relative path against the panel's current
// directory, and normalises "." / ".." lexically (without touching the disk or
// following symlinks). Existence/kind checks are left to the caller. Pure and
// unit-testable.

import Foundation

public enum PathResolver {
    /// Resolve `input` to an absolute, lexically-standardised path, or nil if empty.
    public static func resolve(_ input: String, base: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        if s == "~" {
            s = NSHomeDirectory()
        } else if s.hasPrefix("~/") {
            s = NSHomeDirectory() + String(s.dropFirst(1))
        }

        let combined: String
        if s.hasPrefix("/") {
            combined = s
        } else {
            combined = (base as NSString).appendingPathComponent(s)
        }
        return (combined as NSString).standardizingPath
    }
}
