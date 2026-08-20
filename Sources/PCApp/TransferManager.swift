// SPDX-License-Identifier: Apache-2.0
// TransferManager.swift - App-wide background transfer queue (TODOS #135).
//
// Total-Commander-style background transfer manager: file operations (copy/move/
// delete) run detached via TransferQueue while the main UI stays interactive. Each
// enqueued operation becomes a Job the user can pause/resume/cancel from the
// manager window. Jobs run concurrently (each owns its TransferQueue + control);
// the manager just tracks their live state and notifies observers on every change.

import AppKit
import PCAutomation
import PCOperations

@MainActor
final class TransferManager {
    static let shared = TransferManager()

    enum Status: String {
        case queued, running, paused, done, failed, cancelled
        var isFinished: Bool { self == .done || self == .failed || self == .cancelled }
    }

    final class Job {
        let id = UUID()
        let title: String
        let kind: OperationKind
        let control: OperationControl
        var progress = OpProgress()
        var status: Status = .running
        var errorText: String?
        let onComplete: (@MainActor ([String]) -> Void)?
        let onFinish: (@MainActor (Bool) -> Void)?
        /// Serializes pause/resume/cancel calls onto `control` in click order so a
        /// quick Pause→Resume can't reach the control actor out of order.
        var controlChain: Task<Void, Never>?
        /// For a `.queued` (download-list) job: the prepared queue, run on start (F-215).
        var pendingQueue: TransferQueue?
        /// Bytes per second this job may use, or nil for the configured default. Kept here as well
        /// as on the control so the row can show what it is set to without asking an actor.
        var speedLimit: Int64?

        init(title: String, kind: OperationKind, control: OperationControl,
             onComplete: (@MainActor ([String]) -> Void)?,
             onFinish: (@MainActor (Bool) -> Void)? = nil) {
            self.title = title
            self.kind = kind
            self.control = control
            self.onComplete = onComplete
            self.onFinish = onFinish
        }
    }

    private(set) var jobs: [Job] = []
    /// Called on any change to the job list or a job's state (window observes this).
    var onChange: (() -> Void)?
    /// Background operations as typed host events, for the Automation Core's event bus. Set by
    /// the window controller, which owns the bus; nil in any context that has none.
    var onOperationEvent: ((HostEvent) -> Void)?

    var hasActiveJobs: Bool { jobs.contains { !$0.status.isFinished } }
    /// Whether any job is waiting in the download list to be started (F-215).
    var hasQueuedJobs: Bool { jobs.contains { $0.status == .queued } }

    /// Queue a background operation. `onComplete` receives the processed source
    /// paths on success (e.g. to unmark + reload the originating panel).
    /// With `startHeld: true` the job is added to the download list in a `.queued`
    /// state and only runs when the user starts it (F-215).
    /// - Parameter onFinish: called once the job reaches a terminal state, with whether it
    ///   succeeded. `onComplete` fires only on success, so a caller that has to *wait* for the
    ///   operation — the automation tools do, or the assistant reports a copy that has not
    ///   happened yet — would wait forever on a failure or a cancellation.
    func enqueue(_ kind: OperationKind, title: String, startHeld: Bool = false,
                 onComplete: (@MainActor ([String]) -> Void)? = nil,
                 onFinish: (@MainActor (Bool) -> Void)? = nil) {
        let queue = TransferQueue()
        let job = Job(title: title, kind: kind, control: queue.control, onComplete: onComplete,
                      onFinish: onFinish)
        if startHeld {
            job.status = .queued
            job.pendingQueue = queue
            jobs.append(job)
            onChange?()
            return
        }
        jobs.append(job)
        onChange?()
        Task { await run(job, queue: queue) }
    }

    /// Start a single held (`.queued`) download-list job (F-215).
    func startJob(_ job: Job) {
        guard job.status == .queued, let queue = job.pendingQueue else { return }
        job.status = .running
        job.pendingQueue = nil
        onChange?()
        Task { await run(job, queue: queue) }
    }

    /// Start the held download-list jobs, one after another (F-215, F-085).
    ///
    /// This used to call `startJob` on every one of them, and each job owns its own queue and control
    /// — so twenty queued downloads became twenty concurrent transfers. Over FTP that is worse than
    /// useless, and it is not what a background transfer manager is for; Total Commander runs them in
    /// turn. The next one starts when the previous ends, whether it succeeded or not: one failure must
    /// not strand the rest of the list.
    func startAllQueued() {
        drainingQueue = true
        startNextQueuedJob()
    }

    /// True while "start all" is working through the list.
    private var drainingQueue = false

    /// Start the next held job, unless one is still occupying the slot.
    ///
    /// The rule is in `TransferSchedule` because the manager is an AppKit object no test bundle can
    /// reach, while "one at a time" is a statement about a list of statuses.
    private func startNextQueuedJob() {
        guard drainingQueue else { return }
        let statuses = jobs.map { TransferJobStatus(rawValue: $0.status.rawValue) ?? .done }
        guard let index = TransferSchedule.nextToStart(statuses) else {
            if !statuses.contains(.queued) { drainingQueue = false }
            return
        }
        startJob(jobs[index])
    }

    private func run(_ job: Job, queue: TransferQueue) async {
        // Background transfers can't pop interactive conflict dialogs, so resolve
        // target-exists by overwriting; a per-file ERROR is skipped (continue on
        // error) and recorded, then surfaced in an error log when the job finishes
        // (F-089).
        let resolver = BackgroundSkipResolver()
        for await event in queue.run(job.kind, resolver: resolver) {
            switch event {
            case .progress(let p):
                if job.status == .running || job.status == .paused { job.progress = p }
                onChange?()
                // A fraction, because that is what a consumer of the event stream can use; the
                // window shows the byte and file counts from the same OpProgress.
                let fraction = p.bytesTotal > 0
                    ? Double(p.bytesDone) / Double(p.bytesTotal)
                    : (p.filesTotal > 0 ? Double(p.filesDone) / Double(p.filesTotal) : 0)
                onOperationEvent?(.operationProgress(id: job.id.uuidString, fraction: fraction))
            case .completed(let done):
                job.status = .done
                onChange?()
                job.onComplete?(done)
            case .failed(let error):
                job.status = .failed
                job.errorText = "\(error)"
                onChange?()
            case .cancelled:
                job.status = .cancelled
                onChange?()
            case .log:
                break
            }
        }
        if !job.status.isFinished { job.status = .done }
        onChange?()
        job.onFinish?(job.status == .done)
        onOperationEvent?(.operationFinished(id: job.id.uuidString, ok: job.status == .done))
        // Whatever the outcome, the slot is free: let the next held job have it.
        startNextQueuedJob()
        // Continue-on-error summary for the background job (F-089).
        let problems = resolver.problems()
        if !problems.isEmpty {
            await MainActor.run {
                let summary = String(localized: "\(job.title): \(problems.count) item(s) were skipped due to errors.")
                ErrorLogWindowController.present(over: nil, summary: summary,
                                                 entries: problems.map { ($0.path, $0.message) })
            }
        }
    }

    func pause(_ job: Job) {
        guard job.status == .running else { return }
        job.status = .paused
        onChange?()
        runControl(job) { await $0.pause() }
    }

    func resume(_ job: Job) {
        guard job.status == .paused else { return }
        job.status = .running
        onChange?()
        runControl(job) { await $0.resume() }
    }

    func cancel(_ job: Job) {
        guard !job.status.isFinished else { return }
        // The event stream will report .cancelled once the engine unwinds.
        runControl(job) { await $0.cancel() }
    }

    /// Cap this job's throughput, or with nil hand it back to the configured default.
    ///
    /// Goes through the same chain as pause/resume, so a quick change followed by a pause cannot
    /// reach the control actor out of order. Takes effect within one chunk — the engine asks the
    /// control per chunk rather than reading a value copied in when it started.
    func setSpeedLimit(_ job: Job, bytesPerSecond: Int64?) {
        guard !job.status.isFinished else { return }
        job.speedLimit = bytesPerSecond
        onChange?()
        runControl(job) { await $0.setSpeedLimit(bytesPerSecond) }
    }

    /// Move a waiting job one place earlier or later in the queue.
    ///
    /// Which moves are possible is `TransferSchedule`'s to say, not this window's: a queued job may
    /// step over finished ones but never past the transfer in flight, because promoting it there
    /// would change nothing and look like it had.
    @discardableResult
    func move(_ job: Job, by delta: Int) -> Bool {
        guard let from = jobs.firstIndex(where: { $0 === job }) else { return false }
        let statuses = jobs.map { TransferJobStatus(rawValue: $0.status.rawValue) ?? .queued }
        guard let to = TransferSchedule.moveTarget(statuses, from: from, delta: delta) else { return false }
        let moved = jobs.remove(at: from)
        jobs.insert(moved, at: to)
        onChange?()
        return true
    }

    /// Whether this job can be moved at all — the gate the ▲▼ buttons are drawn from.
    func canMove(_ job: Job, by delta: Int) -> Bool {
        guard let from = jobs.firstIndex(where: { $0 === job }) else { return false }
        let statuses = jobs.map { TransferJobStatus(rawValue: $0.status.rawValue) ?? .queued }
        return TransferSchedule.moveTarget(statuses, from: from, delta: delta) != nil
    }

    /// Run a control operation for `job`, chained after any previous one so their
    /// order on the `control` actor matches the order the user triggered them.
    private func runControl(_ job: Job, _ op: @escaping @Sendable (OperationControl) async -> Void) {
        let previous = job.controlChain
        let control = job.control
        job.controlChain = Task {
            await previous?.value
            await op(control)
        }
    }

    func clearFinished() {
        jobs.removeAll { $0.status.isFinished }
        onChange?()
    }
}

/// A non-interactive resolver for background transfers (F-089): overwrite on a
/// target-exists conflict, and skip a per-file error while recording it so the
/// manager can show an error log when the job finishes.
final class BackgroundSkipResolver: OperationResolver, @unchecked Sendable {
    struct Problem: Sendable { let path: String; let message: String }
    private let lock = NSLock()
    private var log: [Problem] = []

    func problems() -> [Problem] { lock.lock(); defer { lock.unlock() }; return log }

    func resolveOverwrite(source: FileFacts, target: FileFacts) async -> OverwriteDecision { .overwrite }

    func resolveError(_ error: OperationError, path: String) async -> ErrorDecision {
        lock.lock(); log.append(Problem(path: path, message: "\(error)")); lock.unlock()
        return .skip
    }
}
