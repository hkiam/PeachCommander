// SPDX-License-Identifier: Apache-2.0
// SyncState.swift - What the two sides looked like when they last agreed.
//
// Both existing comparison modes are stateless, and that costs one thing: a file present on one side
// only is either **new here** or **deleted there**, and without a record of the last run those two
// are indistinguishable. Symmetric mode therefore copies it back — delete something on the laptop,
// synchronise, and it returns from the backup — and mirror mode deletes but only in one direction.
//
// This is the record that tells them apart. Everything in here is a pure value; reading and writing
// it is `SyncStateStore`'s job, and deciding what to do with it is the decision layer's.
//
// Three things live here on purpose, in exactly one place each, because the repo has a scar from
// each of them being computed twice:
//
//   * `unchanged` — the one definition of "this side has not moved since the record".
//   * `normalise` — the one definition of what a path key is.
//   * `key` — the one definition of which file a pair's record lives in.
//
// `FileFactStore` records what happens otherwise: the writer, a panel column and the rename mask each
// worked out the same fingerprint independently, "disagreed on both the epoch and the rounding, so
// the column was empty for every file". The epochs in this project genuinely differ — `SummaryStore`
// counts from the reference date, `ThumbnailCache` from 1970, `FileStamp` from `st_mtimespec`. So the
// field here is called `modifiedUnix` and is seconds since 1970 as a `Double`, and that is the whole
// convention.

import Foundation

/// One side of one path, as it was at the end of the last run.
public struct SyncStateSide: Codable, Equatable, Sendable {
    public var size: Int64
    /// Seconds since 1970. Named for its epoch because this project has three of them in use, and a
    /// `Double` rather than a `Date` because `JSONEncoder`'s `.iso8601` strategy truncates to whole
    /// seconds — which does not matter at the default two-second tolerance and does as soon as
    /// somebody types a smaller one into the window's tolerance field.
    public var modifiedUnix: Double
    public var isDirectory: Bool

    public init(size: Int64, modifiedUnix: Double, isDirectory: Bool) {
        self.size = size
        self.modifiedUnix = modifiedUnix
        self.isDirectory = isDirectory
    }

    public init(size: Int64, modified: Date, isDirectory: Bool) {
        self.init(size: size, modifiedUnix: modified.timeIntervalSince1970,
                  isDirectory: isDirectory)
    }

    public var modified: Date { Date(timeIntervalSince1970: modifiedUnix) }

    /// Field by field with defaults, for the reason `SyncOptions.init(from:)` records: the
    /// synthesized decoder throws on a missing key instead of using the default, and one line of a
    /// state file that will not decode must cost that line and not the pair's whole history.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        size = try c.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        modifiedUnix = try c.decodeIfPresent(Double.self, forKey: .modifiedUnix) ?? 0
        isDirectory = try c.decodeIfPresent(Bool.self, forKey: .isDirectory) ?? false
    }
}

/// One path, as both sides had it.
///
/// Both sides optional, and not because it is convenient: a run records what was *there*, and a row
/// the user unticked leaves a path on one side only. A record that could not say "this was on the
/// left and never on the right" would make the next run read that as a deletion.
public struct SyncStateEntry: Codable, Equatable, Sendable {
    public var relativePath: String
    public var left: SyncStateSide?
    public var right: SyncStateSide?

    public init(relativePath: String, left: SyncStateSide?, right: SyncStateSide?) {
        self.relativePath = relativePath
        self.left = left
        self.right = right
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relativePath = try c.decodeIfPresent(String.self, forKey: .relativePath) ?? ""
        left = try c.decodeIfPresent(SyncStateSide.self, forKey: .left)
        right = try c.decodeIfPresent(SyncStateSide.self, forKey: .right)
    }

    /// The same entry with its two sides exchanged — for a record written before the user pressed
    /// "Swap sides".
    public var swapped: SyncStateEntry {
        SyncStateEntry(relativePath: relativePath, left: right, right: left)
    }
}

/// What a record says about the run that wrote it.
public struct SyncStateHeader: Codable, Equatable, Sendable {
    /// Bumped when a later version means something a reader of this one would get *wrong*. A
    /// tolerant decoder handles fields being added; the version handles meanings changing, which it
    /// cannot. `SyncStateStore` refuses to read a higher one rather than misreading it — the one
    /// thing a tolerant decoder cannot do for itself.
    public static let currentVersion = 1

    public var version: Int
    /// Both roots as written, normalised. Redundant with the filename's hash except as the check
    /// that matters: a hash collision, or a file copied by hand into the state directory, would
    /// otherwise attach one pair's history to another.
    public var leftRoot: String
    public var rightRoot: String
    public var runAt: Date
    /// The options, mask and filter the run used.
    ///
    /// Diagnostic, and it is worth being blunt about that, because the obvious use for them is
    /// unsound: comparing this run's filter against the record's does **not** establish that a
    /// missing path was in scope last time. `SyncFilter.modifiedWithinDays` is stored relative and
    /// resolved at scan time, so the same filter text covers a different set on every run, and
    /// `keepsPair` drops a pair before a `SyncItem` exists at all. Scope is established the other way
    /// round, per path, by `SyncSideScope.provesAbsence(of:)`.
    public var options: SyncOptions
    public var fileMask: String
    public var withSubdirs: Bool
    public var ignoreHidden: Bool
    public var filter: SyncFilter?
    /// The roots' inode numbers when the record was written. Advisory only: `st_dev` is not stable
    /// across mounts, so a difference cannot be a refusal on its own — but a changed root inode
    /// together with a large share of deletions is a much stronger signal than either alone.
    public var leftRootInode: UInt64?
    public var rightRootInode: UInt64?
    public var entryCount: Int

    public init(version: Int = SyncStateHeader.currentVersion,
                leftRoot: String, rightRoot: String, runAt: Date,
                options: SyncOptions, fileMask: String, withSubdirs: Bool, ignoreHidden: Bool,
                filter: SyncFilter? = nil,
                leftRootInode: UInt64? = nil, rightRootInode: UInt64? = nil,
                entryCount: Int = 0) {
        self.version = version
        self.leftRoot = leftRoot
        self.rightRoot = rightRoot
        self.runAt = runAt
        self.options = options
        self.fileMask = fileMask
        self.withSubdirs = withSubdirs
        self.ignoreHidden = ignoreHidden
        self.filter = filter
        self.leftRootInode = leftRootInode
        self.rightRootInode = rightRootInode
        self.entryCount = entryCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // No default for the version: a line that does not say which version it is cannot be read as
        // the current one. Zero is not a valid version, so it falls out as unreadable.
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        leftRoot = try c.decodeIfPresent(String.self, forKey: .leftRoot) ?? ""
        rightRoot = try c.decodeIfPresent(String.self, forKey: .rightRoot) ?? ""
        runAt = try c.decodeIfPresent(Date.self, forKey: .runAt) ?? Date(timeIntervalSince1970: 0)
        options = try c.decodeIfPresent(SyncOptions.self, forKey: .options) ?? SyncOptions()
        fileMask = try c.decodeIfPresent(String.self, forKey: .fileMask) ?? "*.*"
        withSubdirs = try c.decodeIfPresent(Bool.self, forKey: .withSubdirs) ?? true
        ignoreHidden = try c.decodeIfPresent(Bool.self, forKey: .ignoreHidden) ?? false
        filter = try c.decodeIfPresent(SyncFilter.self, forKey: .filter)
        leftRootInode = try c.decodeIfPresent(UInt64.self, forKey: .leftRootInode)
        rightRootInode = try c.decodeIfPresent(UInt64.self, forKey: .rightRootInode)
        entryCount = try c.decodeIfPresent(Int.self, forKey: .entryCount) ?? 0
    }
}

public enum SyncState {

    // MARK: - What a path key is

    /// A relative path reduced to the form the record uses.
    ///
    /// The composition half is **not** what keeps a lookup working, and it is worth saying so before
    /// somebody relies on it: Swift's `String` compares and hashes by canonical equivalence, so a
    /// decomposed name off an APFS listing and a composed one off an FTP listing already find each
    /// other in a dictionary. Measured, both ways round. What it does buy is stable *bytes* — the
    /// same path always writes the same line — which matters where the bytes are what is compared,
    /// and that is `key` below.
    ///
    /// Case folding is the half that is load-bearing here: it follows the comparison's own setting,
    /// so the record agrees with the pairing that produced it.
    public static func normalise(_ path: String, caseSensitive: Bool) -> String {
        let composed = path.precomposedStringWithCanonicalMapping
        return caseSensitive ? composed : composed.lowercased()
    }

    /// Which file a pair's record lives in.
    ///
    /// Over the **sorted** pair, so that pressing "Swap sides" finds the same record rather than
    /// silently starting a new history. Which root was on the left when it was written is in the
    /// header, and `SyncStateStore` exchanges the sides on the way in when they no longer match.
    ///
    /// A digest rather than the paths themselves: a path can be longer than a filename may be, and
    /// contains separators. And this is where composition genuinely matters — a digest is over
    /// bytes, and `Data("Bücher".utf8)` differs between the two spellings even though the two
    /// strings compare equal. Without precomposing here, one folder reached two ways would keep two
    /// separate histories and neither would ever see the other's deletions.
    public static func key(leftRoot: String, rightRoot: String) -> String {
        let a = (leftRoot as NSString).standardizingPath.precomposedStringWithCanonicalMapping
        let b = (rightRoot as NSString).standardizingPath.precomposedStringWithCanonicalMapping
        let joined = [a, b].sorted().joined(separator: "\u{0}")
        return String(ChecksumAlgorithm.sha256.hex(of: Data(joined.utf8)).prefix(32))
    }

    // MARK: - Has this side moved?

    /// Is `side` still as the record has it?
    ///
    /// The single definition, and two things about it are deliberate.
    ///
    /// **A directory is compared by existence and kind only.** A folder's timestamp changes whenever
    /// a child changes, so comparing it would make every folder in the tree read as "changed", and a
    /// changed folder on one side against a deleted one on the other is a conflict — the whole tree
    /// would come back as conflicts.
    ///
    /// **`ignoreDaylightHour` does not apply here**, whatever the comparison's own options say. It
    /// widens the tolerance to at least an hour, and a file edited within the last hour whose size
    /// happens to be unchanged would then read as untouched — which turns "changed here, deleted
    /// there" into a silent deletion, exactly the case the conflict exists to catch. The DST widening
    /// is for comparing *two sides' clocks* against each other, not a side against its own past.
    public static func unchanged(_ recorded: SyncStateSide, size: Int64, modified: Date,
                                 isDirectory: Bool, toleranceSeconds: TimeInterval) -> Bool {
        guard recorded.isDirectory == isDirectory else { return false }
        if isDirectory { return true }
        guard recorded.size == size else { return false }
        return abs(modified.timeIntervalSince1970 - recorded.modifiedUnix) <= toleranceSeconds
    }

    /// How one side stands against its own record.
    public enum SideChange: Sendable, Equatable {
        /// Absent in the record and absent now — nothing to say.
        case neverThere
        /// Absent in the record, there now.
        case appeared
        /// In the record, gone now.
        case disappeared
        case unchanged
        case changed
    }

    /// Classify one side against the record.
    ///
    /// - Parameter now: The side as it is, or nil when it is not there.
    public static func change(recorded: SyncStateSide?, now: SyncStateSide?,
                              toleranceSeconds: TimeInterval) -> SideChange {
        switch (recorded, now) {
        case (nil, nil): return .neverThere
        case (nil, _?): return .appeared
        case (_?, nil): return .disappeared
        case (let r?, let n?):
            return unchanged(r, size: n.size, modified: n.modified, isDirectory: n.isDirectory,
                             toleranceSeconds: toleranceSeconds) ? .unchanged : .changed
        }
    }
}
