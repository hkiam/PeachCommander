// SPDX-License-Identifier: Apache-2.0
// TransferSchedule.swift - Which held transfer starts next (F-085).
//
// "Start all" on a download list used to start every held job at once, because `startAllQueued` looped
// over them and called `startJob` on each. Each job owns its own queue and control, so twenty queued
// downloads became twenty concurrent transfers — over FTP that is worse than useless, and it is not
// what a background transfer manager is for. Total Commander runs them one after another.
//
// The decision lives here rather than in the manager because the manager is an AppKit object no test
// bundle can reach, and "one at a time" is a rule about a list of statuses, not about windows. Whether
// the transfers *overlap* cannot be observed from outside without timing them — and on APFS a
// same-volume copy can finish instantly, so sequential and concurrent would look identical. The rule
// itself can be checked exactly.

import Foundation

/// What a transfer job is doing, as far as scheduling is concerned.
public enum TransferJobStatus: String, Sendable, Equatable {
    case queued      // held, waiting for its turn
    case running
    case paused      // started, still occupying the slot
    case done
    case failed
    case cancelled
}

public enum TransferSchedule {

    /// The index of the held job to start next, or nil if none should start yet.
    ///
    /// A paused job counts as occupying the slot: it was started and the user may resume it, so
    /// beginning another transfer underneath it would be the concurrency this exists to avoid.
    /// Finished jobs — done, failed or cancelled — do not hold anything up; a failure must not stop
    /// the rest of the list.
    public static func nextToStart(_ statuses: [TransferJobStatus]) -> Int? {
        if statuses.contains(where: { $0 == .running || $0 == .paused }) { return nil }
        return statuses.firstIndex(of: .queued)
    }

    /// Whether the job at `index` can be moved in the queue at all.
    ///
    /// Only one that has not started. A running or paused job has a partially written destination
    /// and a live control; moving it would reorder nothing that matters — `nextToStart` never looks
    /// past it — while suggesting it did. A finished one is history.
    public static func canReorder(_ statuses: [TransferJobStatus], at index: Int) -> Bool {
        statuses.indices.contains(index) && statuses[index] == .queued
    }

    /// Where a queued job lands when nudged by `delta` (-1 = earlier, +1 = later), or nil when the
    /// move is impossible.
    ///
    /// The move is over *queued* jobs only: it steps to the neighbouring queued position, skipping
    /// anything finished, and never crosses a running or paused job. Crossing one would look like a
    /// promotion and change nothing — the transfer in flight still has to end first — which is the
    /// kind of control that teaches people the buttons do not work.
    public static func moveTarget(_ statuses: [TransferJobStatus], from index: Int,
                                  delta: Int) -> Int? {
        guard canReorder(statuses, at: index), delta != 0 else { return nil }
        let step = delta < 0 ? -1 : 1
        var i = index + step
        while statuses.indices.contains(i) {
            switch statuses[i] {
            case .queued: return i
            case .running, .paused: return nil      // the barrier: nothing useful lies beyond it
            case .done, .failed, .cancelled: i += step   // history, step over it
            }
        }
        return nil
    }
}
