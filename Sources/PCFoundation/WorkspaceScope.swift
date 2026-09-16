// SPDX-License-Identifier: Apache-2.0
// WorkspaceScope.swift - A workspace can be limited to a folder (F-499).
//
// A safety net for a tool that deletes. "Clean up backups" has a root of `/Volumes/Backup`, and an
// operation that would reach outside it asks first — or refuses, if that is what was asked for.
//
// **Navigation is never restricted.** A scope governs what is *written*, never what is *shown*. A file
// manager that refuses to list a folder is broken, and the moment this rule bends, people switch the
// feature off and never switch it back on. This belongs in `DECISIONS.md` because it will be
// re-litigated by somebody reasonable.
//
// **Containment is by path component, not by prefix.** `/Users/m/Backups2` is not inside
// `/Users/m/Backups`, and `hasPrefix` says it is — a warning that never fires for the folder next
// door is worse than no warning, because it is trusted.

import Foundation

public enum ScopeEnforcement: String, Codable, Sendable, CaseIterable {
    /// No check at all. What a workspace without a root has, and what "don't ask me again" sets.
    case allow
    /// Ask, with Cancel as the default button.
    case ask
    /// Refuse, and say which folder would have to change.
    case refuse
}

public struct WorkspaceScope: Codable, Sendable, Equatable {
    /// "" means no scope, and then `enforcement` is irrelevant — there is nothing to be outside of.
    ///
    /// **Anything that is not an absolute path means no scope either**, and that rule is load-bearing
    /// rather than tidy. `ScopeCheck.contains` compares normalised path *components*, so a relative
    /// root matches nothing at all — and "matches nothing" does not mean "protects nothing", it means
    /// **every** operation is outside and every one of them is refused or asked about. That is not a
    /// strict scope, it is a workspace nobody can work in, and the user cannot see why: the folder
    /// named in the refusal is one that was never a folder.
    ///
    /// It happened. An automation verb parsed `workspacescope |ask` — meant to clear the scope — as
    /// the root `"ask"`, because Swift's `split` drops empty parts, and fourteen later scenarios hung
    /// on a confirmation sheet nobody had asked for. The verb is fixed; this is the reason it could
    /// not have got that far in the first place.
    public var root: String
    public var enforcement: ScopeEnforcement

    public init(root: String = "", enforcement: ScopeEnforcement = .ask) {
        self.root = root
        self.enforcement = enforcement
    }

    /// Is there a scope to **enforce here**? Only an absolute root can be, for the reason above.
    public var isSet: Bool { root.hasPrefix("/") }

    /// Is the root one of the two shapes worth keeping — absolute, or tilde-portable?
    ///
    /// Separate from ``isSet`` because the two questions differ in exactly one place: an exported
    /// `.pcworkspace` writes its root tilde-abbreviated, so that it lands in the *receiving* user's
    /// home, and `~/Backups` is deliberately not enforceable until an import has expanded it. The
    /// codec and the exchange ask this one; everything that guards an operation asks ``isSet``.
    ///
    /// Anything else is not written down at all. It cannot be enforced, so keeping it would only
    /// preserve a value that is waiting for somebody to relax ``isSet`` and make it live again.
    public var hasRoot: Bool { root.hasPrefix("/") || root.hasPrefix("~") }

    private enum CodingKeys: String, CodingKey { case root, enforcement }

    /// Nothing is written for a workspace with no scope, which is nearly all of them.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        // `hasRoot`, not `isSet`: an exported file's root is tilde-abbreviated and would otherwise be
        // dropped on the way out — the scope would vanish between export and import.
        guard hasRoot else { return }
        try c.encode(root, forKey: .root)
        try c.encode(enforcement, forKey: .enforcement)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(root: try c.decodeIfPresent(String.self, forKey: .root) ?? "",
                  enforcement: try c.decodeIfPresent(ScopeEnforcement.self, forKey: .enforcement) ?? .ask)
    }
}

/// Which side of an operation a path was on, so the sentence can say "the destination" rather than
/// leaving somebody to work out which of the two folders it means.
public enum ScopeSide: String, Sendable, Equatable {
    case source, destination
}

public enum ScopeVerdict: Sendable, Equatable {
    case inside
    case outside(offenders: [String], side: ScopeSide)
}

public enum ScopeCheck {

    /// Is `path` inside `root` (or the root itself)?
    ///
    /// Compared as path components after normalising, which is the whole point: `/a/Backups2` shares
    /// a prefix with `/a/Backups` and is a different folder. Trailing slashes, `.` segments and
    /// repeated separators are all normalised away first, because a root typed by hand or arriving
    /// from a `.pcworkspace` may carry any of them.
    ///
    /// Symlink resolution is the caller's job (`resolve`), so this stays pure and testable: the app
    /// passes `URL(fileURLWithPath:).resolvingSymlinksInPath()`, and a test passes identity.
    public static func contains(root: String, path: String,
                                resolve: (String) -> String = { $0 }) -> Bool {
        let rootParts = components(of: resolve(root))
        let pathParts = components(of: resolve(path))
        guard !rootParts.isEmpty else { return true }   // no root: everything is inside
        guard pathParts.count >= rootParts.count else { return false }
        return Array(pathParts.prefix(rootParts.count)) == rootParts
    }

    static func components(of path: String) -> [String] {
        (path as NSString).standardizingPath.split(separator: "/").map(String.init)
    }

    /// Decide about one operation.
    ///
    /// Sources and destination are separate because they need different sentences and because most
    /// operations only care about one of them: a copy is judged by where it lands, a delete by what it
    /// takes. The destination is reported first when both are outside — it is the one the user can fix
    /// by picking a different folder.
    public static func decide(scope: WorkspaceScope,
                              sources: [String] = [],
                              destination: String? = nil,
                              resolve: (String) -> String = { $0 }) -> ScopeVerdict {
        guard scope.isSet, scope.enforcement != .allow else { return .inside }

        if let destination, !contains(root: scope.root, path: destination, resolve: resolve) {
            return .outside(offenders: [destination], side: .destination)
        }
        let strays = sources.filter { !contains(root: scope.root, path: $0, resolve: resolve) }
        return strays.isEmpty ? .inside : .outside(offenders: strays, side: .source)
    }
}
