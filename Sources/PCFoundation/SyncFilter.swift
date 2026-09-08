// SPDX-License-Identifier: Apache-2.0
// SyncFilter.swift - Which files are part of a synchronisation at all.
//
// The sync window has always filtered with one include mask over the leaf name plus "ignore hidden".
// That cannot say `node_modules/`, cannot say "nothing over 2 GB", and cannot say "only what changed
// this month" — and an include list cannot express an exclusion at all.
//
// This is the decision layer for that, and it is pure on purpose: "does this file belong to this
// comparison" is a question about a path, a size and a date, and it is worth being able to answer it
// in a test rather than through a window.
//
// Two rules run in two different places, and the difference is not a detail:
//
//   * Name and path rules act per side, inside the walk. They depend only on the relative path, which
//     is the same on both sides, so both sides drop the same entries and the two halves stay
//     consistent.
//   * Size and date rules act on the *pair*, after pairing. Per side they are worse than useless: a
//     file that is 3 GB on the left and 1 KB on the right, under "nothing over 2 GB", would vanish
//     from the left walk only — the pair would then read as "only on the right" and be copied to the
//     left, overwriting the 3 GB file with the small one. An exclusion that acts per side turns into
//     a copy.

import Foundation

/// The criteria that say which entries a synchronisation includes.
///
/// Everything is optional and an all-default filter is inert (`isActive == false`), so a preset that
/// carries no filter behaves exactly as one written before filters existed.
public struct SyncFilter: Codable, Equatable, Sendable {
    /// Patterns whose match is *excluded*, separated by `;` or `|`.
    ///
    /// `;` because that is what the file mask uses. `|` as well, because the mask gives a single bar
    /// the meaning "everything after this is excluded" — so somebody who has learned that will paste
    /// `*.bak|*.tmp` in here, and a field that silently excluded nothing in return would be worse
    /// than one that had refused the text.
    ///
    /// The language is the file mask's: `*` and `?` are the only special characters, everything else
    /// is literal, and matching ignores case. Three shapes:
    ///
    ///   * `*.tmp`, `node_modules` — no separator: matches any single path *component*, at any depth.
    ///   * `build/` — trailing separator: only a folder of that name, never a file.
    ///   * `src/*/generated` — contains a separator: matches the relative path, and `*` stops at a
    ///     separator, so this does not reach into `src/a/b/generated`.
    ///
    /// An entry is excluded when a pattern matches the entry itself or any folder above it. That is
    /// what makes pruning the descent an optimisation rather than the mechanism — see `Exclusions`.
    public var excludePatterns: String
    /// Smallest size to include, in bytes, inclusive.
    public var minSize: Int64?
    /// Largest size to include, in bytes, inclusive.
    public var maxSize: Int64?
    /// Include only what was modified within this many days of the run.
    ///
    /// Stored relative and resolved at scan time, unlike the search window — which collapses its
    /// "within the last N days" field to an absolute date when the query is built and does not save
    /// it at all. A saved search is a question asked once; a sync preset is a job run again and
    /// again, and there "the last 30 days" has to mean thirty days before *this* run.
    public var modifiedWithinDays: Int?
    /// Include only what was modified at or after this date.
    public var modifiedAfter: Date?
    /// Include only what was modified at or before this date.
    public var modifiedBefore: Date?
    /// A plugin content field criterion, in `ContentFieldPredicate` text form (`fileinfo.width > 800`).
    ///
    /// Text rather than a parsed predicate because that type lives in PCVFS and this one must not
    /// depend on it. It is applied by PCOperations, after classification and only on the side a row
    /// is copied *from* — a plugin needs a real file, and a one-sided row has none on the other side.
    public var pluginPredicate: String?

    public init(excludePatterns: String = "", minSize: Int64? = nil, maxSize: Int64? = nil,
                modifiedWithinDays: Int? = nil, modifiedAfter: Date? = nil,
                modifiedBefore: Date? = nil, pluginPredicate: String? = nil) {
        self.excludePatterns = excludePatterns
        self.minSize = minSize
        self.maxSize = maxSize
        self.modifiedWithinDays = modifiedWithinDays
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.pluginPredicate = pluginPredicate
    }

    /// Decode field by field, every one optional.
    ///
    /// Hand-written from the outset for the reason `SyncOptions.init(from:)` records: this rides
    /// inside a `SyncPreset` on disk, the synthesized decoder throws on a missing key rather than
    /// using the default, and `SyncPresetStore.load` answers `[]` for anything it cannot decode. A
    /// filter written before the next criterion was added must still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        excludePatterns = try c.decodeIfPresent(String.self, forKey: .excludePatterns) ?? ""
        minSize = try c.decodeIfPresent(Int64.self, forKey: .minSize)
        maxSize = try c.decodeIfPresent(Int64.self, forKey: .maxSize)
        modifiedWithinDays = try c.decodeIfPresent(Int.self, forKey: .modifiedWithinDays)
        modifiedAfter = try c.decodeIfPresent(Date.self, forKey: .modifiedAfter)
        modifiedBefore = try c.decodeIfPresent(Date.self, forKey: .modifiedBefore)
        pluginPredicate = try c.decodeIfPresent(String.self, forKey: .pluginPredicate)
    }

    // MARK: - What the window has to be able to say about it

    /// How many criteria are set. The window puts this in the button that opens the filter, because a
    /// filter nobody can see is the dangerous kind: a forgotten search finds too little and you
    /// search again, a forgotten sync filter leaves a backup incomplete and reports success.
    public var activeCriteriaCount: Int {
        var n = 0
        if !Self.split(excludePatterns).isEmpty { n += 1 }
        if minSize != nil { n += 1 }
        if maxSize != nil { n += 1 }
        if let days = modifiedWithinDays, days > 0 { n += 1 }
        if modifiedAfter != nil { n += 1 }
        if modifiedBefore != nil { n += 1 }
        if let p = pluginPredicate, !p.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        return n
    }

    public var isActive: Bool { activeCriteriaCount > 0 }

    /// Whether anything here has to be asked of the *pair* rather than of the walk.
    public var hasPairCriteria: Bool {
        minSize != nil || maxSize != nil || modifiedBefore != nil || effectiveAfter(now: Date()) != nil
    }

    // MARK: - Name and path rules

    /// Turn the patterns into something worth asking per entry.
    ///
    /// A `WildcardMask` compiles its regular expression inside every `matches` call, which is
    /// affordable for one mask per file and is not for k patterns across every component of every
    /// entry in a tree. Build one of these before a walk and keep it.
    public func exclusions() -> Exclusions { Exclusions(patterns: Self.split(excludePatterns)) }

    /// The exclusion patterns, translated once.
    public struct Exclusions: Sendable {
        private struct Compiled: Sendable {
            let regex: NSRegularExpression?
            /// The pattern as typed, for the fallback when it will not compile.
            let literal: String
            let matchesWholePath: Bool
            let directoriesOnly: Bool
        }
        private let compiled: [Compiled]

        public var isEmpty: Bool { compiled.isEmpty }

        init(patterns: [String]) {
            compiled = patterns.map { raw in
                var pattern = raw
                let directoriesOnly = pattern.hasSuffix("/")
                while pattern.hasSuffix("/") { pattern.removeLast() }
                let matchesWholePath = pattern.contains("/")
                // `[^/]*` and not `.*`: a path pattern that reaches across a separator would make
                // `src/*/generated` match `src/a/b/generated`, and `src/*` swallow a whole tree.
                let body = WildcardMask.regexPattern(for: pattern,
                                                     anySequence: "[^/]*", anyCharacter: "[^/]")
                return Compiled(regex: try? NSRegularExpression(pattern: body, options: [.caseInsensitive]),
                                literal: pattern,
                                matchesWholePath: matchesWholePath,
                                directoriesOnly: directoriesOnly)
            }
        }

        /// Is this entry outside the comparison?
        ///
        /// True when a pattern matches the entry itself *or any folder above it*. Checking the
        /// ancestors is what lets the walks treat cutting off the descent as a pure speed-up: a walk
        /// that forgets to prune still drops every entry under an excluded folder, so forgetting is
        /// slow rather than wrong. It also covers the case that has no folder to prune — a zip
        /// legitimately contains `a/b.txt` with no entry for `a/` at all, and a rule that worked by
        /// pruning would do nothing there.
        public func excludes(relativePath: String, isDirectory: Bool) -> Bool {
            guard !compiled.isEmpty else { return false }
            let parts = relativePath.split(separator: "/", omittingEmptySubsequences: true)
            guard !parts.isEmpty else { return false }
            // Every folder above the entry, shortest first. Each of those is a directory by
            // construction — something lives inside it.
            var prefix = ""
            for part in parts.dropLast() {
                prefix = prefix.isEmpty ? String(part) : prefix + "/" + part
                if matches(path: prefix, leaf: String(part), isDirectory: true) { return true }
            }
            return matches(path: relativePath, leaf: String(parts[parts.count - 1]),
                           isDirectory: isDirectory)
        }

        /// Is the whole subtree below this folder excluded? Purely an optimisation for the walks.
        public func prunes(directory relativePath: String) -> Bool {
            excludes(relativePath: relativePath, isDirectory: true)
        }

        private func matches(path: String, leaf: String, isDirectory: Bool) -> Bool {
            for p in compiled {
                if p.directoriesOnly, !isDirectory { continue }
                let subject = p.matchesWholePath ? path : leaf
                guard let regex = p.regex else {
                    // Same fallback `WildcardMask` takes: a pattern that will not compile is compared
                    // literally rather than quietly matching everything or nothing.
                    if subject.compare(p.literal, options: .caseInsensitive) == .orderedSame { return true }
                    continue
                }
                let range = NSRange(location: 0, length: subject.utf16.count)
                if regex.firstMatch(in: subject, options: [], range: range) != nil { return true }
            }
            return false
        }
    }

    // MARK: - Size and date rules

    /// Does this pair stay in the comparison?
    ///
    /// Every side that is *there* has to pass. A pair present on both sides where one side fails is
    /// dropped whole — the alternative, keeping it, means reconciling a pair one half of which the
    /// user excluded, and a copy would then overwrite the side that failed. Dropping it is the
    /// conservative reading, and the count of held-back entries is what keeps it from being silent.
    ///
    /// A one-sided entry is judged on the side that exists, which is the only side there is to judge.
    ///
    /// Directories are never filtered by size or date: a folder's own size and timestamp say nothing
    /// about what is in it, and excluding a folder for its date would take its contents with it.
    /// Folders leave the comparison through `Exclusions` or not at all.
    public func keepsPair(leftSize: Int64?, leftModified: Date?,
                          rightSize: Int64?, rightModified: Date?,
                          isDirectory: Bool, now: Date) -> Bool {
        guard !isDirectory else { return true }
        if let size = leftSize, !keeps(size: size, modified: leftModified, now: now) { return false }
        if let size = rightSize, !keeps(size: size, modified: rightModified, now: now) { return false }
        return true
    }

    /// One side, on its own terms.
    public func keeps(size: Int64, modified: Date?, now: Date) -> Bool {
        if let minSize, size < minSize { return false }
        if let maxSize, size > maxSize { return false }
        if let after = effectiveAfter(now: now) {
            guard let modified, modified >= after else { return false }
        }
        if let modifiedBefore {
            guard let modified, modified <= modifiedBefore else { return false }
        }
        return true
    }

    /// The lower date bound actually in force.
    ///
    /// Both bounds apply when both are set, as `SpotlightQuery.build` does with the same pair — which
    /// for two lower bounds means the later of the two. The relative one is resolved against `now`
    /// the same way, `now - days × 86400` rather than a calendar day boundary, so that the app has
    /// one convention for "within the last N days" instead of two.
    public func effectiveAfter(now: Date) -> Date? {
        var bound = modifiedAfter
        if let days = modifiedWithinDays, days > 0 {
            let relative = now.addingTimeInterval(-Double(days) * 86_400)
            bound = bound.map { max($0, relative) } ?? relative
        }
        return bound
    }

    /// Split a pattern list on both separators, dropping blanks.
    static func split(_ list: String) -> [String] {
        list.split(whereSeparator: { $0 == ";" || $0 == "|" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
