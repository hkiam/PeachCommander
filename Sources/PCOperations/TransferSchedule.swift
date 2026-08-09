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
}
