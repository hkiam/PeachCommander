// SPDX-License-Identifier: Apache-2.0
// MemberStage.swift - A real file for something that is not one yet (F-479).
//
// Quick Look, "Open with", a double-click and the Share sheet all need a path the rest of macOS can
// open. Inside an archive — or on FTP, SFTP, S3 or a plugin mount — there is no such path, which is
// why those gestures did nothing there: the panel handed `/xl/sheet.xlsx` to `NSWorkspace`, which is
// not a file, and Cmd+Y refused outright.
//
// Extracting one member was already possible (`localFileIfAvailable`, used by F3 and the hex editor).
// What was missing is everything around it, and each piece of it is a defect in its own right:
//
//   * **A cache.** `ArchiveFS.localFileIfAvailable` decompresses the whole member into memory and
//     writes it out on *every* call. Arrowing back and forth between two files paid twice per move.
//   * **Two lifetimes.** A preview's copy should die with the mount; a copy handed to Excel must not,
//     because Excel still has it open. `ArchiveFS` deletes its temp root in `deinit`, which is right
//     for the first and data loss for the second.
//   * **A ceiling.** Nothing stopped a 4 GB member from being read into memory as one `Data`.
//   * **A measurement.** Somebody has to time these reads, or `ImplicitWorkBudget` never learns how
//     fast the mount is and judges every preview by the conservative fallback forever.
//
// Layout: `<tmp>/PCStage-<pid>-<uuid>/<n>/<original name>`. One directory per member, because two
// members may share a name and the extracted file has to keep its own — Quick Look, `NSWorkspace`
// and every "open with" downstream decide the file's type from its extension.

import Foundation
import PCFoundation

/// How long a staged file has to live.
public enum StagePurpose: Sendable, Equatable {
    /// Shown in a preview. Dies with the mount, and may be evicted under pressure.
    case preview
    /// Handed to another application. Outlives the mount, is never evicted, and is written
    /// read-only — so a user editing it is told by that application rather than discovering later
    /// that the archive never changed.
    case handoff
}

/// Where a staged file came from, so a caller knows whether it may delete it.
public struct StagedFile: Sendable, Equatable {
    public let url: URL
    /// False when the filesystem handed back the real file (LocalFS, a branch view) rather than a
    /// copy. Nothing may delete or chmod that.
    public let isCopy: Bool

    public init(url: URL, isCopy: Bool) {
        self.url = url
        self.isCopy = isCopy
    }
}

public enum MemberStageError: Error, Equatable {
    /// The member is larger than the caller allowed.
    case tooLarge(bytes: Int64, limit: Int64)
    /// The filesystem could not produce the bytes (an encrypted member without a password, a
    /// connection that dropped).
    case unreadable
    /// The member's name would put the staged file outside the staging root.
    case refusedName(String)
}

public actor MemberStage {

    /// Shared by every consumer: two surfaces asking for the same member must get one extraction.
    public static let shared = MemberStage()

    /// Directory-name prefix, also swept at launch by `ArchiveTempSweeper`.
    public static let prefix = "PCStage-"

    /// Budgets, in the shape `docs/architecture/performance.md` states the others.
    private let maxEntries = 64
    private let maxRetainedBytes: Int64 = 256 * 1024 * 1024

    private struct Key: Hashable {
        let mount: String
        let member: String
        let bytes: Int64
    }

    private struct Entry {
        let url: URL
        let bytes: Int64
        var purpose: StagePurpose
        var usedAt: Date
        /// Non-zero while something is showing this file and it must not be swept away underneath.
        var pins: Int
    }

    private var entries: [Key: Entry] = [:]
    private var retained: Int64 = 0
    private var counter = 0
    private var root: URL?
    /// Extractions in flight, so two surfaces following one cursor do the work once.
    private var inFlight: [Key: Task<URL, Error>] = [:]

    private var pressureSource: DispatchSourceMemoryPressure?

    public init() {
        // Caches give way under pressure rather than compete with the app that filled them
        // (performance.md); `ArchiveDirectoryCache` hooks the same source for the same reason.
        // Previews only — a copy another application is holding open is not this actor's to reclaim.
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            Task { await self?.dropEvictablePreviews() }
        }
        source.resume()
        pressureSource = source
    }

    /// Everything a preview staged that nothing is currently showing.
    public func dropEvictablePreviews() {
        for (key, entry) in entries where entry.purpose == .preview && entry.pins == 0 {
            remove(key)
        }
    }

    // MARK: - Staging

    /// A real local file for `path` on `fs`.
    ///
    /// - Parameters:
    ///   - mountKey: identifies the mount for caching and for the throughput estimate. Include
    ///     whatever makes the mount's *content* identity — `FileStamp` for an archive file — so a
    ///     rewritten archive does not serve yesterday's member.
    ///   - bytes: the member's size from the listing, for the ceiling and the cache key.
    ///   - limitBytes: refuse above this. 0 = no limit.
    public func stage(_ path: VFSPath, on fs: VirtualFileSystem, mountKey: String,
                      bytes: Int64, purpose: StagePurpose,
                      limitBytes: Int64 = 0) async throws -> StagedFile {
        // The filesystems whose "extraction" is the file itself: nothing to copy, nothing to own,
        // and nothing to measure. A branch view is one of them — `ResultsFS` hands back the path it
        // was given — except for its hits inside archives, which it resolves to a real extraction
        // that this stage did not make and so must not delete either.
        if fs is LocalFS || fs is ResultsFS {
            guard let url = try await fs.localFileIfAvailable(path) else { throw MemberStageError.unreadable }
            return StagedFile(url: url, isCopy: false)
        }

        if limitBytes > 0, bytes > limitBytes {
            throw MemberStageError.tooLarge(bytes: bytes, limit: limitBytes)
        }

        let key = Key(mount: mountKey, member: path.path, bytes: bytes)
        if var hit = entries[key], FileManager.default.fileExists(atPath: hit.url.path) {
            hit.usedAt = Date()
            // A file first staged for a preview and then handed to an application is promoted, never
            // demoted: the copy Excel is holding must not become evictable because a preview reused it.
            if purpose == .handoff, hit.purpose == .preview {
                hit.purpose = .handoff
                Self.makeReadOnly(hit.url)
            }
            entries[key] = hit
            return StagedFile(url: hit.url, isCopy: true)
        }

        if let running = inFlight[key] {
            return StagedFile(url: try await running.value, isCopy: true)
        }

        let task = Task<URL, Error> { [weak self] in
            guard let self else { throw MemberStageError.unreadable }
            return try await self.extract(path, on: fs, key: key, mountKey: mountKey, purpose: purpose)
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return StagedFile(url: try await task.value, isCopy: true)
    }

    private func extract(_ path: VFSPath, on fs: VirtualFileSystem, key: Key,
                         mountKey: String, purpose: StagePurpose) async throws -> URL {
        let name = (path.path as NSString).lastPathComponent
        let directory = try makeDirectory()
        guard let destination = PathContainment.childURL(name, under: directory, root: directory) else {
            // A member called `../../evil` is the oldest trick in the format; the same rule the
            // extractor applies, applied to a directory nobody chose.
            try? FileManager.default.removeItem(at: directory)
            throw MemberStageError.refusedName(name)
        }

        let started = Date()
        let written: Int64
        do {
            if let resumable = fs as? ResumableFileDownloading {
                // Straight to the destination, the way the panel's own extract walk does it: the
                // generic path below would hold the whole file in memory first.
                written = try await resumable.downloadFile(path, to: destination, resume: false).written
            } else {
                written = try await Self.streamToFile(fs: fs, path: path, destination: destination)
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error is CancellationError ? error : MemberStageError.unreadable
        }

        if !mountKey.isEmpty {
            TransferRateEstimator.shared.record(key: mountKey, bytes: written,
                                                seconds: Date().timeIntervalSince(started))
        }
        if purpose == .handoff { Self.makeReadOnly(destination) }

        entries[key] = Entry(url: destination, bytes: written, purpose: purpose, usedAt: Date(), pins: 0)
        retained += written
        evictIfNeeded()
        return destination
    }

    /// Chunk by chunk into a real file, checking for cancellation between chunks.
    ///
    /// The reason this is not `localFileIfAvailable`: that reads the whole member into one `Data`
    /// and writes it out, so a 2 GB member costs 2 GB of memory twice over, and it cannot be
    /// interrupted — which is what makes cancelling a preview the cursor has moved on from possible.
    private static func streamToFile(fs: VirtualFileSystem, path: VFSPath, destination: URL) async throws -> Int64 {
        let stream = try await fs.openRead(path)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: destination) else {
            try? await stream.close()
            throw MemberStageError.unreadable
        }
        defer { try? handle.close() }
        var total: Int64 = 0
        for try await element in stream {
            if Task.isCancelled {
                try? await stream.close()
                throw CancellationError()
            }
            guard let chunk = element as? Data else { continue }
            try handle.write(contentsOf: chunk)
            total += Int64(chunk.count)
        }
        try? await stream.close()
        return total
    }

    // MARK: - Lifetime

    /// Hold `url` against eviction while something is showing it.
    public func pin(_ url: URL) {
        guard let key = key(for: url) else { return }
        entries[key]?.pins += 1
    }

    public func unpin(_ url: URL) {
        guard let key = key(for: url), let entry = entries[key], entry.pins > 0 else { return }
        entries[key]?.pins = entry.pins - 1
    }

    /// Drop everything this mount staged for a preview. Called when a panel leaves the mount: the
    /// copies handed to other applications stay, because those applications still have them open.
    public func releasePreviews(mountKey: String) {
        for (key, entry) in entries
        where key.mount == mountKey && entry.purpose == .preview && entry.pins == 0 {
            remove(key)
        }
    }

    /// Everything the session staged, except what somebody may still be editing.
    ///
    /// A handoff copy whose modification date has moved is a document the user has saved into, and
    /// deleting it here would be the one way this feature could lose work. It is left for
    /// `ArchiveTempSweeper`, which takes it once the process it belonged to is gone.
    public func purgeAtExit() {
        for (key, entry) in entries {
            if entry.purpose == .handoff, Self.wasModified(entry.url) { continue }
            remove(key)
        }
        if let root, entries.isEmpty { try? FileManager.default.removeItem(at: root) }
    }

    /// For tests and for the memory-pressure handler: everything, unconditionally.
    public func removeAll() {
        for key in entries.keys { remove(key) }
        if let root { try? FileManager.default.removeItem(at: root) }
        root = nil
    }

    /// What the stage is holding, for the harness and the tests.
    public func report() -> (files: Int, bytes: Int64) { (entries.count, retained) }

    // MARK: - Internals

    private func key(for url: URL) -> Key? {
        entries.first(where: { $0.value.url == url })?.key
    }

    private func remove(_ key: Key) {
        guard let entry = entries.removeValue(forKey: key) else { return }
        retained -= entry.bytes
        // The member's own directory, not just the file: one directory per member is what keeps two
        // members of the same name apart.
        try? FileManager.default.removeItem(at: entry.url.deletingLastPathComponent())
    }

    /// Least recently used first, skipping anything pinned or handed to another application.
    private func evictIfNeeded() {
        guard entries.count > maxEntries || retained > maxRetainedBytes else { return }
        let evictable = entries
            .filter { $0.value.pins == 0 && $0.value.purpose == .preview }
            .sorted { $0.value.usedAt < $1.value.usedAt }
        for (key, _) in evictable {
            guard entries.count > maxEntries || retained > maxRetainedBytes else { return }
            remove(key)
        }
    }

    private func makeDirectory() throws -> URL {
        let root: URL
        if let existing = self.root, FileManager.default.fileExists(atPath: existing.path) {
            root = existing
        } else {
            // The pid is in the name so a later launch can tell a leftover from a live session's
            // files, rather than waiting a day to be sure (see `ArchiveTempSweeper`).
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Self.prefix)\(getpid())-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            self.root = root
        }
        counter += 1
        let directory = root.appendingPathComponent("\(counter)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 0444, and the modification date remembered with it.
    ///
    /// Read-only is the honest state: nothing writes an edited copy back into an archive yet, and a
    /// user who spends an afternoon in a document that silently cannot be saved anywhere has been
    /// failed worse than one whose application says "read only" at the top.
    private static func makeReadOnly(_ url: URL) {
        try? FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        if let modified = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date {
            stampedDates.set(url.path, modified)
        }
    }

    private static func wasModified(_ url: URL) -> Bool {
        guard let stamped = stampedDates.get(url.path),
              let now = try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        else { return false }
        return now > stamped
    }

    /// Modification dates as staged, so "the user saved into this" can be told from "nothing
    /// happened". Outside the actor because `makeReadOnly` is called from its static context.
    private static let stampedDates = StampedDates()

    final class StampedDates: @unchecked Sendable {
        private let lock = NSLock()
        private var dates: [String: Date] = [:]
        func set(_ path: String, _ date: Date) {
            lock.lock(); defer { lock.unlock() }
            dates[path] = date
        }
        func get(_ path: String) -> Date? {
            lock.lock(); defer { lock.unlock() }
            return dates[path]
        }
    }
}
