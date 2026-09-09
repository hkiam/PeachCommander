// SPDX-License-Identifier: Apache-2.0
// SyncRunRecord.swift - What one synchronisation run did, in a form that outlives it.
//
// The executor answers `SyncRunReport`: one outcome per planned row, saying whether the bytes
// arrived, where a deleted file went, what was refused and why. All of it was thrown away when the
// window re-compared, and the user was left with a status line the next run overwrites.
//
// That mattered most for the one sentence the help file is honest about: a deleted file is in the
// Trash and can be put back from the Finder. Which is true and unusable, because nobody can say
// *which* of several hundred items in there this run put down. A run that is written down answers
// exactly that, and — since `SyncStatus.deleted` now carries the path the move reported — it can
// point at the item instead of describing it.
//
// Two shape decisions, both taken from what is already here:
//
//   * **Flat and tolerantly decoded**, like `AuditEntry`. Every optional is additive, so a record
//     written before a field existed still reads. A payload-carrying enum would not survive that.
//   * **Times as `Double` seconds since 1970**, like `SyncStateSide.modifiedUnix` and for the same
//     reason plus one: `JSONEncoder`'s `.iso8601` truncates to whole seconds, and a guard that
//     compares a destination's timestamp for equality would then fail on every file it looked at.

import Foundation

/// The one line at the top of a run's file: what the run was, and what became of it as a whole.
public struct SyncRunHeader: Codable, Equatable, Sendable {
    /// Bumped when a later version means something a reader of this one would get *wrong*. The
    /// tolerant decoder below handles fields being added; it cannot handle meanings changing, so
    /// `SyncRunStore` refuses to read a higher version rather than misreading it.
    public static let currentVersion = 1

    public var version: Int
    /// Seconds since 1970 — see the file header on why this is not a `Date`.
    public var runAt: Double
    /// Both roots as the run held them, standardised and precomposed. The filename carries only a
    /// digest of the pair, so this is where a reader learns which folders a run was about.
    public var leftRoot: String
    public var rightRoot: String
    /// The roots' inode numbers at the time of the run.
    ///
    /// The reason they are here is the one thing that makes an absolute path in a file safe to act
    /// on later: `/Volumes/Backup` can be a different disk next week, and hourly runs mean a record
    /// is often about a folder that has since moved. Advisory in `SyncStateHeader`'s sense — `st_dev`
    /// is not stable across mounts — but advisory in the *refusing* direction costs nothing.
    public var leftRootInode: UInt64?
    public var rightRootInode: UInt64?
    /// `"symmetric"`, `"mirror"` or `"twoWay"`, as a string on purpose.
    ///
    /// `SyncPreset` records the reason: a stored enum case that a later version does not know about
    /// decodes to an undefined third state, and this file is read by versions that were written
    /// before the mode existed.
    public var mode: String
    public var fileMask: String
    public var withSubdirs: Bool
    public var ignoreHidden: Bool
    /// The filter in words, for a reader — not for a decision. `SyncStateHeader.options` carries the
    /// same warning and the same reason: a relative date filter covers a different set on every run,
    /// so comparing two runs' filters establishes nothing about scope.
    public var filterSummary: String?
    public var stopped: Bool

    public var planned: Int
    /// How many rows copied. `created` and `overwritten` are a breakdown of this one and do
    /// not have to add up to it: a copy into an archive or onto a server cannot say which it was.
    public var copied: Int
    public var created: Int
    public var overwritten: Int
    public var deleted: Int
    public var refused: Int
    public var failed: Int
    public var notAttempted: Int
    public var noOp: Int

    /// Whether the file holds a line for every planned item.
    ///
    /// False above `SyncRunStore.maximumItems`, where only the items that did *not* run smoothly are
    /// kept. Recorded rather than inferred from the line count, because "this run had no problems"
    /// and "this run's rows were left out" are the two things a reader must never confuse.
    public var itemsListed: Bool
    /// Why nothing from this run can be put back, when that is already decidable from the header
    /// alone. `AuditEntry.undoUnavailable`'s job, in its voice.
    public var undoUnavailable: String?

    public init(version: Int = SyncRunHeader.currentVersion,
                runAt: Double, leftRoot: String, rightRoot: String,
                leftRootInode: UInt64? = nil, rightRootInode: UInt64? = nil,
                mode: String, fileMask: String = "", withSubdirs: Bool = true,
                ignoreHidden: Bool = false, filterSummary: String? = nil, stopped: Bool = false,
                planned: Int = 0, copied: Int = 0, created: Int = 0, overwritten: Int = 0, deleted: Int = 0,
                refused: Int = 0, failed: Int = 0, notAttempted: Int = 0, noOp: Int = 0,
                itemsListed: Bool = true, undoUnavailable: String? = nil) {
        self.version = version
        self.runAt = runAt
        self.leftRoot = leftRoot
        self.rightRoot = rightRoot
        self.leftRootInode = leftRootInode
        self.rightRootInode = rightRootInode
        self.mode = mode
        self.fileMask = fileMask
        self.withSubdirs = withSubdirs
        self.ignoreHidden = ignoreHidden
        self.filterSummary = filterSummary
        self.stopped = stopped
        self.planned = planned
        self.copied = copied
        self.created = created
        self.overwritten = overwritten
        self.deleted = deleted
        self.refused = refused
        self.failed = failed
        self.notAttempted = notAttempted
        self.noOp = noOp
        self.itemsListed = itemsListed
        self.undoUnavailable = undoUnavailable
    }

    /// Field by field with defaults, for `SyncStateSide.init(from:)`'s reason: the synthesized
    /// decoder throws on a missing key instead of taking the default, and one unreadable header
    /// must not be the difference between a listed run and an invisible file.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 0
        runAt = try c.decodeIfPresent(Double.self, forKey: .runAt) ?? 0
        leftRoot = try c.decodeIfPresent(String.self, forKey: .leftRoot) ?? ""
        rightRoot = try c.decodeIfPresent(String.self, forKey: .rightRoot) ?? ""
        leftRootInode = try c.decodeIfPresent(UInt64.self, forKey: .leftRootInode)
        rightRootInode = try c.decodeIfPresent(UInt64.self, forKey: .rightRootInode)
        mode = try c.decodeIfPresent(String.self, forKey: .mode) ?? ""
        fileMask = try c.decodeIfPresent(String.self, forKey: .fileMask) ?? ""
        withSubdirs = try c.decodeIfPresent(Bool.self, forKey: .withSubdirs) ?? true
        ignoreHidden = try c.decodeIfPresent(Bool.self, forKey: .ignoreHidden) ?? false
        filterSummary = try c.decodeIfPresent(String.self, forKey: .filterSummary)
        stopped = try c.decodeIfPresent(Bool.self, forKey: .stopped) ?? false
        planned = try c.decodeIfPresent(Int.self, forKey: .planned) ?? 0
        copied = try c.decodeIfPresent(Int.self, forKey: .copied) ?? 0
        created = try c.decodeIfPresent(Int.self, forKey: .created) ?? 0
        overwritten = try c.decodeIfPresent(Int.self, forKey: .overwritten) ?? 0
        deleted = try c.decodeIfPresent(Int.self, forKey: .deleted) ?? 0
        refused = try c.decodeIfPresent(Int.self, forKey: .refused) ?? 0
        failed = try c.decodeIfPresent(Int.self, forKey: .failed) ?? 0
        notAttempted = try c.decodeIfPresent(Int.self, forKey: .notAttempted) ?? 0
        noOp = try c.decodeIfPresent(Int.self, forKey: .noOp) ?? 0
        // Defaults to true, so a file from a version that did not have the field is read as
        // complete — which it was. The refusal it drives only ever *takes away* an offer.
        itemsListed = try c.decodeIfPresent(Bool.self, forKey: .itemsListed) ?? true
        undoUnavailable = try c.decodeIfPresent(String.self, forKey: .undoUnavailable)
    }

    public var runDate: Date { Date(timeIntervalSince1970: runAt) }
    /// Everything that happened but should not have, which is what a list wants in one column.
    public var problems: Int { refused + failed + notAttempted }
}

/// One planned row, and what became of it.
public struct SyncRunItem: Codable, Equatable, Sendable {
    /// `"copied"`, `"deleted"`, `"refused"`, `"failed"`, `"notAttempted"`, `"noOp"` — strings for
    /// `SyncRunHeader.mode`'s reason, and because `SyncStatus` carries a payload and is not
    /// `Codable`.
    public enum Outcome {
        public static let copied = "copied"
        public static let deleted = "deleted"
        public static let refused = "refused"
        public static let failed = "failed"
        public static let notAttempted = "notAttempted"
        public static let noOp = "noOp"
    }

    public var relativePath: String
    public var action: String
    /// `"comparison"`, `"propagatedDeletion"` or `"stateConflict"`.
    ///
    /// Carried separately because it cannot be recovered from `action`: a propagated deletion
    /// deliberately reuses `.deleteLeft`/`.deleteRight`, and `SyncModel` states the rule — nothing
    /// may infer "propagated" from the action value.
    public var basis: String
    public var outcome: String
    /// Why, for a refusal or a failure.
    ///
    /// **Locale-dependent** — a failure's text is `error.localizedDescription` — and therefore
    /// diagnostic only. Nothing may branch on it; a reader that needs to know *what* happened has
    /// `outcome`.
    public var reason: String?

    public var sourcePath: String?
    public var destinationPath: String?
    /// `"localDir"`, `"zip"` or `"remote"`, so a reader knows whether `destinationPath` is a path on
    /// this machine at all.
    public var destinationSide: String?
    public var isDirectory: Bool?
    /// Whether the copy replaced something. From the write itself — see `CopiedDestination.existed`
    /// for why the scan cannot answer it. Nil where the write could not: an archive, a server, a
    /// directory.
    public var created: Bool?
    public var destinationSize: Int64?
    public var destinationModifiedUnix: Double?

    public var toTrash: Bool?
    /// Where a deleted item went, when it went anywhere recoverable. The field this whole record
    /// exists to be able to write down.
    public var trashedPath: String?
    /// Where the version this copy displaced went. Set only for an overwrite onto a side with a
    /// Trash; nil for a fresh copy, and nil for an overwrite that was permanent — which the record
    /// then has no way to soften, and does not pretend to.
    public var replacedTrashedPath: String?

    /// Set once this row has been acted on, so nothing is put back twice.
    ///
    /// `AuditLog.markUndone`'s semantics exactly: the row is never removed, it loses its offer and
    /// gains its reason. The history of what a run did must survive undoing it.
    public var undoneAt: Double?
    public var undoUnavailable: String?

    public init(relativePath: String, action: String, basis: String, outcome: String,
                reason: String? = nil, sourcePath: String? = nil, destinationPath: String? = nil,
                destinationSide: String? = nil, isDirectory: Bool? = nil, created: Bool? = nil,
                destinationSize: Int64? = nil, destinationModifiedUnix: Double? = nil,
                toTrash: Bool? = nil, trashedPath: String? = nil,
                replacedTrashedPath: String? = nil,
                undoneAt: Double? = nil, undoUnavailable: String? = nil) {
        self.relativePath = relativePath
        self.action = action
        self.basis = basis
        self.outcome = outcome
        self.reason = reason
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.destinationSide = destinationSide
        self.isDirectory = isDirectory
        self.created = created
        self.destinationSize = destinationSize
        self.destinationModifiedUnix = destinationModifiedUnix
        self.toTrash = toTrash
        self.trashedPath = trashedPath
        self.replacedTrashedPath = replacedTrashedPath
        self.undoneAt = undoneAt
        self.undoUnavailable = undoUnavailable
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        relativePath = try c.decodeIfPresent(String.self, forKey: .relativePath) ?? ""
        action = try c.decodeIfPresent(String.self, forKey: .action) ?? ""
        basis = try c.decodeIfPresent(String.self, forKey: .basis) ?? "comparison"
        outcome = try c.decodeIfPresent(String.self, forKey: .outcome) ?? ""
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        sourcePath = try c.decodeIfPresent(String.self, forKey: .sourcePath)
        destinationPath = try c.decodeIfPresent(String.self, forKey: .destinationPath)
        destinationSide = try c.decodeIfPresent(String.self, forKey: .destinationSide)
        isDirectory = try c.decodeIfPresent(Bool.self, forKey: .isDirectory)
        created = try c.decodeIfPresent(Bool.self, forKey: .created)
        destinationSize = try c.decodeIfPresent(Int64.self, forKey: .destinationSize)
        destinationModifiedUnix = try c.decodeIfPresent(Double.self, forKey: .destinationModifiedUnix)
        toTrash = try c.decodeIfPresent(Bool.self, forKey: .toTrash)
        trashedPath = try c.decodeIfPresent(String.self, forKey: .trashedPath)
        replacedTrashedPath = try c.decodeIfPresent(String.self, forKey: .replacedTrashedPath)
        undoneAt = try c.decodeIfPresent(Double.self, forKey: .undoneAt)
        undoUnavailable = try c.decodeIfPresent(String.self, forKey: .undoUnavailable)
    }

    /// Did this row run smoothly? Above the item cap only rows for which this is false are kept.
    ///
    /// A **deletion is never smooth** in that sense, whatever its outcome: it is the row a person
    /// comes to this record looking for, and it is the only one that can be put back.
    public var isPlainSuccess: Bool {
        (outcome == Outcome.copied || outcome == Outcome.noOp) && trashedPath == nil
    }
}

public enum SyncRunRecord {

    /// Which file a run's record lives in.
    ///
    /// `<yyyyMMdd'T'HHmmss'Z'>-<pair key, 8>`, and each half earns its place. The timestamp first so
    /// that sorting the filenames sorts the runs, which is what lets a listing and a trim work
    /// without reading anything. The pair digest second, over `SyncState.key` — the same function,
    /// so a run can be matched to the state record of the same two folders, and so the filename
    /// carries no path. Which is also why it is a digest and not the paths: a name may not hold
    /// separators, and a digest over bytes is where composition genuinely matters.
    public static func identifier(runAt: Date, leftRoot: String, rightRoot: String) -> String {
        let key = SyncState.key(leftRoot: leftRoot, rightRoot: rightRoot)
        return "\(stampFormatter.string(from: runAt))-\(key.prefix(8))"
    }

    /// UTC, fixed-width, and `POSIX` — a run listed in a different order than it happened would be
    /// a listing nobody can read, and this string is also the sort key and the trim order.
    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f
    }()
}
