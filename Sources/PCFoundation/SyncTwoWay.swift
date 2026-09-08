// SPDX-License-Identifier: Apache-2.0
// SyncTwoWay.swift - Deciding what to do when there is a record of the last run.
//
// The two stateless modes cannot tell "new here" from "deleted there", so symmetric mode copies a
// one-sided file back — delete something on the laptop, synchronise, and it returns from the backup —
// and mirror mode deletes but only in one direction, so whatever was done on the target is lost.
//
// With a record both questions are answerable, and one new answer becomes possible: **delete it here,
// because it was deleted there.** That is the payoff and the danger of the whole feature, so the
// decision is written out as a complete table over two independent classifications — how each side
// stands against its own record — rather than as a chain of `if`s over the pair. Sixteen cases, all
// of them named, because the ones that get skipped in a chain are exactly the ones that lose data.
//
// Two rules run through it:
//
//   * A deletion is only propagated when the *other* side's walk can prove the path is gone. Absence
//     is not evidence on its own — the walk may never have started. Where it cannot be proved the row
//     becomes a conflict, so the user sees it, rather than nothing, so the user does not.
//   * "Changed on one side, deleted on the other" is a question, never a deletion. It is the case
//     other tools get wrong.

import Foundation

public enum SyncTwoWay {

    /// How one side stands against the record, reduced to what the decision needs.
    enum SideState: Equatable {
        /// Not in the record and not there now.
        case absent
        /// In the record, gone now — the only state a deletion may be propagated from.
        case gone
        /// There now, and either not in the record or different from it. Both mean "this side has
        /// something the record does not", which is what decides a direction.
        case newer
        /// There now and exactly as recorded.
        case same
    }

    static func sideState(recorded: SyncStateSide?, now: SyncStateSide?,
                          toleranceSeconds: TimeInterval) -> SideState {
        switch SyncState.change(recorded: recorded, now: now, toleranceSeconds: toleranceSeconds) {
        case .neverThere: return .absent
        case .disappeared: return .gone
        case .appeared, .changed: return .newer
        case .unchanged: return .same
        }
    }

    /// What the two sides and the record say, together.
    ///
    /// - Parameters:
    ///   - state: The previous run's entries, keyed by normalised relative path.
    ///   - stateKnown: Whether there is a usable record at all. False falls back to the stateless
    ///     rules and **never deletes** — the first run of a pair cannot know whether a one-sided file
    ///     is new or deleted, so it copies and records, and the mode works from the second run.
    ///   - leftScope, rightScope: What each walk was able to see. A deletion is only propagated when
    ///     the side it is derived from can prove the path is gone.
    public static func classify(_ items: [SyncItem], options: SyncOptions,
                                state: [String: SyncStateEntry], stateKnown: Bool,
                                leftScope: SyncSideScope,
                                rightScope: SyncSideScope) -> [SyncResult] {
        guard stateKnown else {
            // Deliberately the existing behaviour, not a weaker version of the new one.
            return SyncModel.classify(items, options: options)
        }
        // The record's own tolerance, never `effectiveTolerance`: the daylight-hour widening is for
        // two sides' clocks against each other, and applying it to a side against its own past turns
        // a recent edit into "untouched" — see `SyncState.unchanged`.
        let tolerance = options.toleranceSeconds
        return items.map { item in
            let key = SyncState.normalise(item.relativePath, caseSensitive: options.caseSensitive)
            let recorded = state[key]
            // `SyncItem.isDirectory` is the two sides' kinds already merged (`l || r`), so a
            // per-side disagreement cannot be expressed here. Recording is per side; deciding is not,
            // because the item this comes from cannot say which side was the folder.
            let nowLeft = item.leftSize.map {
                SyncStateSide(size: $0, modified: item.leftModified ?? Date(timeIntervalSince1970: 0),
                              isDirectory: item.isDirectory)
            }
            let nowRight = item.rightSize.map {
                SyncStateSide(size: $0, modified: item.rightModified ?? Date(timeIntervalSince1970: 0),
                              isDirectory: item.isDirectory)
            }
            let left = sideState(recorded: recorded?.left, now: nowLeft, toleranceSeconds: tolerance)
            let right = sideState(recorded: recorded?.right, now: nowRight, toleranceSeconds: tolerance)
            return decide(item: item, left: left, right: right, options: options,
                          leftScope: leftScope, rightScope: rightScope)
        }
    }

    /// The table. Sixteen cases, exhaustive over the two classifications.
    static func decide(item: SyncItem, left: SideState, right: SideState, options: SyncOptions,
                       leftScope: SyncSideScope, rightScope: SyncSideScope) -> SyncResult {
        func result(_ action: SyncAction, _ basis: SyncBasis = .comparison) -> SyncResult {
            SyncResult(action: action, item: item, basis: basis)
        }
        /// A propagated deletion, but only if the side it is derived from can prove the absence.
        ///
        /// Where it cannot, the row becomes a conflict rather than nothing: the user has to be able
        /// to see that this path was not decided, and to answer it by hand. Silently doing nothing
        /// would leave the two sides different with no trace of why.
        func propagate(_ action: SyncAction, provenBy scope: SyncSideScope) -> SyncResult {
            scope.provesAbsence(of: item.relativePath)
                ? result(action, .propagatedDeletion)
                : result(.conflict, .stateConflict)
        }

        switch (left, right) {
        // Nothing anywhere, or nothing left anywhere: no action, and the record for it is dropped by
        // `SyncState.next` rather than here.
        case (.absent, .absent), (.absent, .gone), (.gone, .absent), (.gone, .gone):
            return result(SyncAction.none)

        // One side has something the other never had, or no longer has a record of. An ordinary copy.
        case (.newer, .absent), (.same, .absent):
            return result(.copyToRight)
        case (.absent, .newer), (.absent, .same):
            return result(.copyToLeft)

        // The record says this side is untouched and the other is gone. *This* is the new answer.
        case (.same, .gone):
            return propagate(.deleteLeft, provenBy: rightScope)
        case (.gone, .same):
            return propagate(.deleteRight, provenBy: leftScope)

        // One side moved, the other did not: the direction is decided by the record, not by which
        // timestamp is larger. On FAT and on shares with skewed clocks — the reason
        // `ignoreDaylightHour` and the tolerance field exist at all — that is a real gain.
        case (.newer, .same):
            return result(.copyToRight)
        case (.same, .newer):
            return result(.copyToLeft)

        // Both moved, or one moved and the other was deleted. Questions, never decisions: a change
        // against a deletion is the case other tools get wrong by deleting quietly.
        case (.newer, .newer), (.newer, .gone), (.gone, .newer):
            return result(.conflict, .stateConflict)

        // Neither moved.
        case (.same, .same):
            return result(SyncModel.classify([item], options: options).first?.action ?? .equal)
        }
    }
}

public extension SyncState {

    /// The record to write after a run, from what the run actually did.
    ///
    /// The whole point is that this is built from **observed outcomes**, not from the plan. Taking
    /// the plan as truth breaks in a way that undoes the feature: a propagated deletion that failed
    /// would be recorded as "gone on both sides", and the next run would then see the file present on
    /// one side with no record of it and copy it back — resurrecting exactly what the user deleted.
    ///
    /// So the rule is: start from what the scan **saw**, which is accurate for every path it looked
    /// at, and then move only the sides a *successful* outcome actually changed. A failure, a refusal
    /// or a cancellation leaves the scan's observation in place, which is still true — nothing
    /// happened — so the same decision is proposed again next time.
    ///
    /// - Parameters:
    ///   - outcomes: What the run did. A `.copied` whose destination was not observed
    ///     (`observeDestinations` off) cannot be recorded: the source's timestamp is not the
    ///     destination's — `upload` sets the remote one with `try?` because plain FTP has no way to,
    ///     and `copyLocalToLocal` sets none at all. Such a path keeps only its source side, so the
    ///     next run proposes the copy again. Repeating a copy is harmless; recording a time that is
    ///     not there would make the whole tree read as changed on every run.
    ///   - previous: The record being replaced. Consulted for paths this run did not look at.
    ///   - inScope: Whether both sides' walks could account for a path — only then may its record be
    ///     dropped when it is absent everywhere.
    static func next(items: [SyncItem], outcomes: [SyncItemOutcomeSummary],
                     previous: [String: SyncStateEntry], caseSensitive: Bool,
                     inScope: (String) -> Bool) -> [SyncStateEntry] {

        /// What the scan saw of this path, which is the truth for every path it looked at.
        func scanned(_ item: SyncItem) -> SyncStateEntry {
            SyncStateEntry(
                relativePath: normalise(item.relativePath, caseSensitive: caseSensitive),
                left: item.leftSize.map {
                    SyncStateSide(size: $0,
                                  modified: item.leftModified ?? Date(timeIntervalSince1970: 0),
                                  isDirectory: item.isDirectory)
                },
                right: item.rightSize.map {
                    SyncStateSide(size: $0,
                                  modified: item.rightModified ?? Date(timeIntervalSince1970: 0),
                                  isDirectory: item.isDirectory)
                })
        }

        var out: [String: SyncStateEntry] = [:]
        let byKey = Dictionary(items.map { (normalise($0.relativePath, caseSensitive: caseSensitive), $0) },
                               uniquingKeysWith: { a, _ in a })
        let planned = Set(outcomes.map { normalise($0.relativePath, caseSensitive: caseSensitive) })

        // A path the plan never touched: the scan looked at both sides and nothing moved, so what it
        // saw *is* the new record. This is what builds a record on the very first run, where every
        // row is either equal or was left alone.
        for (key, item) in byKey where !planned.contains(key) {
            out[key] = scanned(item)
        }

        // A path the plan did touch. The distinction is whether the action actually happened, and it
        // is the whole reason the record is written from outcomes rather than from the plan.
        for outcome in outcomes {
            let key = normalise(outcome.relativePath, caseSensitive: caseSensitive)
            let item = byKey[key]
            switch outcome.change {
            case .copiedToRight(let landed):
                var entry = item.map(scanned) ?? previous[key]
                    ?? SyncStateEntry(relativePath: key, left: nil, right: nil)
                entry.right = landed          // nil when the run was not asked to observe it
                out[key] = entry
            case .copiedToLeft(let landed):
                var entry = item.map(scanned) ?? previous[key]
                    ?? SyncStateEntry(relativePath: key, left: nil, right: nil)
                entry.left = landed
                out[key] = entry
            case .deletedRight:
                var entry = item.map(scanned) ?? previous[key]
                    ?? SyncStateEntry(relativePath: key, left: nil, right: nil)
                entry.right = nil
                out[key] = entry
            case .deletedLeft:
                var entry = item.map(scanned) ?? previous[key]
                    ?? SyncStateEntry(relativePath: key, left: nil, right: nil)
                entry.left = nil
                out[key] = entry
            case .nothingHappened:
                // The decision has to survive, and this is the case that undoes the whole feature if
                // it is got wrong. A propagated deletion that failed leaves the scan seeing one side
                // gone — and recording *that* erases the evidence that the other side ever had the
                // file, so the next run reads it as "new over there" and copies it straight back,
                // resurrecting exactly what the user deleted. Measured. The previous record stands,
                // so the same deletion is proposed again; the scan's view is used only when there is
                // no previous record, which is a first run and therefore never a deletion.
                out[key] = previous[key] ?? item.map(scanned)
            }
        }

        // A path that is now absent everywhere loses its record — but only when both walks could
        // account for it. Keeping it would be worse than useless: create the file again a month
        // later on one side, and the stale record says "both sides had it", so the run reads the new
        // file as a deletion on the other side and removes it.
        for (key, entry) in out where entry.left == nil && entry.right == nil {
            if inScope(key) { out.removeValue(forKey: key) }
            else { out[key] = previous[key] ?? entry }
        }

        // And everything the scan did not look at keeps whatever the record already said. A run with
        // a narrower mask must not erase the history of the files it did not consider.
        for (key, entry) in previous where out[key] == nil && !inScope(key) {
            out[key] = entry
        }
        return out.values.sorted { $0.relativePath < $1.relativePath }
    }
}

/// What a run did to one path, in the terms the record needs.
///
/// A small translation of `SyncItemOutcome` rather than a use of it directly, so that PCFoundation —
/// where the record lives — does not have to know the executor's type, which is in PCOperations.
public struct SyncItemOutcomeSummary: Sendable, Equatable {
    public enum Change: Sendable, Equatable {
        /// The right side now holds this, with the destination as it was observed — or nil when the
        /// run was not asked to observe it, which means the copy cannot be recorded.
        case copiedToRight(SyncStateSide?)
        case copiedToLeft(SyncStateSide?)
        case deletedRight
        case deletedLeft
        /// Refused, failed, not attempted, or nothing to do: the scan's observation stands.
        case nothingHappened
    }

    public let relativePath: String
    public let change: Change

    public init(relativePath: String, change: Change) {
        self.relativePath = relativePath
        self.change = change
    }
}
