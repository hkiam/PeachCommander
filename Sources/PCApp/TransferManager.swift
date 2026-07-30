// TransferManager.swift - App-wide background transfer queue (TODOS #135).
//
// Total-Commander-style background transfer manager: file operations (copy/move/
// delete) run detached via TransferQueue while the main UI stays interactive. Each
// enqueued operation becomes a Job the user can pause/resume/cancel from the
// manager window. Jobs run concurrently (each owns its TransferQueue + control);
// the manager just tracks their live state and notifies observers on every change.

import AppKit
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
        /// Serializes pause/resume/cancel calls onto `control` in click order so a
        /// quick Pause→Resume can't reach the control actor out of order.
        var controlChain: Task<Void, Never>?
        /// For a `.queued` (download-list) job: the prepared queue, run on start (F-215).
        var pendingQueue: TransferQueue?

        init(title: String, kind: OperationKind, control: OperationControl,
             onComplete: (@MainActor ([String]) -> Void)?) {
            self.title = title
            self.kind = kind
            self.control = control
            self.onComplete = onComplete
        }
    }

    private(set) var jobs: [Job] = []
    /// Called on any change to the job list or a job's state (window observes this).
    var onChange: (() -> Void)?

    var hasActiveJobs: Bool { jobs.contains { !$0.status.isFinished } }
    /// Whether any job is waiting in the download list to be started (F-215).
    var hasQueuedJobs: Bool { jobs.contains { $0.status == .queued } }

    /// Queue a background operation. `onComplete` receives the processed source
    /// paths on success (e.g. to unmark + reload the originating panel).
    /// With `startHeld: true` the job is added to the download list in a `.queued`
    /// state and only runs when the user starts it (F-215).
    func enqueue(_ kind: OperationKind, title: String, startHeld: Bool = false,
                 onComplete: (@MainActor ([String]) -> Void)? = nil) {
        let queue = TransferQueue()
        let job = Job(title: title, kind: kind, control: queue.control, onComplete: onComplete)
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

    /// Start every held download-list job (F-215).
    func startAllQueued() {
        for job in jobs where job.status == .queued { startJob(job) }
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
