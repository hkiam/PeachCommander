// SPDX-License-Identifier: Apache-2.0
// SemanticVersion.swift - A comparable major.minor.patch version, and the host's own (F-482).
//
// Two things needed a version at runtime and neither had one. A plugin's
// `PCPluginMinHostVersion` was parsed and then compared against nothing, because there was no
// host version to compare it *to*: the number lives in `project.yml` and reaches the built app
// only as a string in Info.plist. And a plugin's own version was never read at all, so an
// install could not tell an upgrade from a downgrade from a reinstall.
//
// `Tools/check-version.sh` stays the release gate — it is what enforces that the tag, the
// marketing version and the build number agree. This is the other half: the same notion of a
// version, available while the app runs.
//
// Pure and deterministic. `HostVersion.current` reads Info.plist once and can be overridden, so
// tests are not at the mercy of whatever version the bundle they run in happens to carry.

import Foundation

/// A `major.minor.patch` version that sorts the way people expect (2.10.0 > 2.9.0).
///
/// Deliberately narrow: no pre-release tags, no build metadata. Everything this project
/// versions — the app, a plugin bundle — is a plain triple, and a parser that accepts more than
/// it can order is a parser that sorts something wrongly later.
public struct SemanticVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(_ major: Int, _ minor: Int = 0, _ patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parse "1", "1.2" or "1.2.3". Missing components are zero.
    ///
    /// Returns nil for anything else — including "1.2.3.4" and "1.2.3-beta". A version that is
    /// not understood must not silently become 0.0.0: that would read as "older than everything"
    /// and turn a misprint into a downgrade nobody was warned about.
    public init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let n = Int(part) else { return nil }
            numbers.append(n)
        }
        self.major = numbers[0]
        self.minor = numbers.count > 1 ? numbers[1] : 0
        self.patch = numbers.count > 2 ? numbers[2] : 0
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}

/// The running application's marketing version.
public enum HostVersion {
    /// Set by tests (and by nothing else) to make the comparison deterministic.
    nonisolated(unsafe) public static var override: SemanticVersion?

    /// `CFBundleShortVersionString` of the main bundle, or 0.0.0 when there isn't one.
    ///
    /// 0.0.0 is the honest answer for a process with no app bundle — a test runner, a command
    /// line tool — and it is deliberately the *lowest* version rather than the highest: a plugin
    /// that demands a newer host than we can prove we are is refused there, not admitted.
    public static var current: SemanticVersion {
        if let override { return override }
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return raw.flatMap(SemanticVersion.init) ?? SemanticVersion(0, 0, 0)
    }
}
