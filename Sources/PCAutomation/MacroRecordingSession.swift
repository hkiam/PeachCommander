// SPDX-License-Identifier: Apache-2.0
// MacroRecordingSession.swift — an explicit recording, with a start and an end (F-478).
//
// The other way into a macro reads what already happened (`MacroRecorder.candidates`), and it has one
// question it cannot answer: *where does it begin*. A list of the last thirty things is a list the user
// then has to edit down, and the two boundaries — the first step and the last — are exactly what they
// know and the list does not. So this is the second way in: arm it, do the work, stop, and the steps
// are the ones that happened in between. Nothing else is offered.
//
// **It does not read the history.** That is the point and it is also a bug fix: the "recent actions"
// path reads the app's operation history, which the user can switch off in Settings — and with
// `History.Enabled=0` the recorder was silently blind, reporting "nothing has happened yet" to somebody
// who had just created three folders and copied a file. A deliberate recording must not depend on an
// unrelated privacy setting, so what is recorded here is pushed in by the panels as it happens.
//
// Pure and IO-free, so the boundaries — what falls inside the window, what a stop returns, what the cap
// drops — are testable without a window. The app owns one of these and feeds it.

import Foundation

/// One recording: armed at a moment, collecting what happens until it is stopped.
///
/// `Codable` so the host can put it down and pick it up again across a quit — see `resumable`.
public struct MacroRecordingSession: Sendable, Equatable, Codable {

    /// When the recording was armed, or nil when nothing is being recorded.
    public private(set) var startedAt: Date?

    /// What has happened since, oldest first — the order they arrived, which is the order a macro has
    /// to replay them in.
    public private(set) var actions: [RecordedAction] = []

    /// The most a single recording keeps.
    ///
    /// A bound rather than a promise about how anybody works: a recording left armed over a copy of ten
    /// thousand files would otherwise grow without limit, and a macro of ten thousand steps is not a
    /// macro. The *oldest* go first, because a recording that has run away from its owner is one whose
    /// end they still mean.
    public static let cap = 500

    public init() {}

    public var isRecording: Bool { startedAt != nil }

    /// How many steps have been caught so far — what the indicator counts up.
    public var count: Int { actions.count }

    /// Arm the recording, discarding anything a previous one left.
    public mutating func start(at moment: Date = Date()) {
        startedAt = moment
        actions = []
    }

    /// Add what just happened. Does nothing when no recording is armed — the callers are choke points
    /// that run whether or not anybody is recording, and a check at each of them would be a check that
    /// one day is missing at one of them.
    public mutating func record(_ action: RecordedAction) {
        guard isRecording else { return }
        actions.append(action)
        if actions.count > Self.cap { actions.removeFirst(actions.count - Self.cap) }
    }

    /// Stop, and hand back everything that happened — including the automation actions out of `audit`
    /// that fall inside the recording's window.
    ///
    /// The audit log is merged here rather than pushed in like the panel operations, because the
    /// Automation Core already writes it and a second feed would record the same action twice. Only the
    /// entries inside the window: the log is a running one, and everything before the start belongs to
    /// whatever the user was doing before they decided to record.
    public mutating func stop(mergingAudit audit: [AuditEntry] = []) -> [RecordedAction] {
        let inWindow = automationActions(from: audit)
        let out = actions + inWindow
        startedAt = nil
        actions = []
        return out
    }

    /// Give up the recording without producing anything.
    public mutating func cancel() {
        startedAt = nil
        actions = []
    }

    /// This recording as something worth writing to disk, or nil when there is nothing to keep.
    ///
    /// A recording is armed by hand and then the user goes off and works; quitting the app in the
    /// middle of that is not a decision to throw it away, and a crash certainly is not. So it is put
    /// down at every save point and picked up at the next launch, where the indicator says it is still
    /// running and the user can stop it or discard it. An *armed but empty* recording is still worth
    /// keeping: the arming is itself the decision, and coming back to no indicator at all would read
    /// as the feature having forgotten.
    public var resumable: MacroRecordingSession? { isRecording ? self : nil }

    /// The audit entries that fall inside this recording's window, as candidate actions.
    ///
    /// Exposed for the caller that wants to *count* what a stop would yield without stopping — the
    /// indicator's number would otherwise be short by whatever the assistant did.
    public func automationActions(from audit: [AuditEntry]) -> [RecordedAction] {
        guard let startedAt else { return [] }
        // Half-open at the start and inclusive of everything after, so an action logged in the same
        // second as the start is kept: the audit log's timestamps are seconds, and dropping the first
        // one loses exactly the action somebody armed the recorder *for*.
        let from = startedAt.timeIntervalSince1970 - 1
        return audit.filter { $0.at >= from }.map(RecordedAction.init)
    }
}
