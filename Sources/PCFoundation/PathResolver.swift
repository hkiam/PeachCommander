// SPDX-License-Identifier: Apache-2.0
// PathResolver.swift - Resolve a user-typed path for direct navigation (TODOS #13).
//
// Expands a leading ~, resolves a relative path against the panel's current
// directory, and normalises "." / ".." lexically (without touching the disk or
// following symlinks). Existence/kind checks are left to the caller. Pure and
// unit-testable.
//
// A network address is NOT a local path and is refused here rather than mangled. It used to be
// mangled: `\\srv\ablage\dir` starts with no "/", so it went down the relative branch and came
// back as `<current folder>/\\srv\ablage\dir`, and `//srv/ablage` was worse — `standardizingPath`
// collapses the double slash, so it returned `/srv/ablage`, a plausible-looking local path that
// was never what the user typed. Returning nil hands the input back to the caller, which routes
// it through `NetworkShare` instead.

import Foundation

public enum PathResolver {
    /// Resolve `input` to an absolute, lexically-standardised path, or nil if it is empty or
    /// names a network location (see `NetworkShare.isNetworkLocation`).
    public static func resolve(_ input: String, base: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !NetworkShare.isNetworkLocation(s) else { return nil }

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
