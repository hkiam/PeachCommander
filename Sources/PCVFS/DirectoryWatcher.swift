// SPDX-License-Identifier: Apache-2.0
// DirectoryWatcher.swift - Notice changes in a directory as they happen (F-361).
//
// What was here before was named FSEventsWatcher, polled the directory's mtime every two seconds,
// logged "Directory X was modified" — and told nobody. There was no callback, no stream, no way for the
// panel to hear it. `DirectoryModel.startAutoRefresh()` dutifully started one on every directory load
// and never stopped it, so navigating built up polling loops that could not have refreshed anything.
// The panels therefore never noticed a file another program created; the help even documented a
// two-second delay that did not exist.
//
// This is the real thing: an FSEvents stream, which is what macOS offers for exactly this question.
//
// Three decisions worth stating:
//
//   * **Immediate for one change, throttled for a burst.** `noDefer` makes the *first* change arrive at
//     once, so a saved file appears without delay. FSEvents' own `latency` is not a rate limit, though:
//     measured, unpacking 200 files still produced fifteen batches, i.e. fifteen re-listings. So the
//     callback is throttled on the leading edge — fire now, then at most once per `cooldown` while
//     changes keep coming, and once more at the end so the final state is never missed.
//   * **This directory only, which needs `FileEvents`.** An FSEvents stream is inherently recursive and
//     a build running in a subfolder must not reload the panel on every compiled file. Without
//     `kFSEventStreamCreateFlagFileEvents` the granularity is *directories*, and measurement showed the
//     filter then cannot work in either direction: a file modified in the watched folder is reported as
//     an event for the folder (indistinguishable from a change deeper down, which also reports the
//     folder), while a write into `sub/deeper` reports `sub/` — a direct child. With `FileEvents` each
//     item is named: `<dir>/file.txt` for anything in the listing, `<dir>/sub/deeper/x.txt` for the deep
//     case, and no ancestor events at all. So the path decides, exactly as one would hope.
//   * **An event for the watched directory itself is only believed when its mtime moved.** Its own
//     creation arrives right after `start()` — FSEvents' "since now" is coarse — and would otherwise
//     refresh a folder once just for being opened. When it is really gone or replaced, the mtime differs
//     (or `stat` fails) and the refresh happens.
//   * **The watched path is canonicalised with realpath(3), not with Foundation.** FSEvents reports
//     fully resolved paths: register /tmp/x and the events arrive as /private/tmp/x, so an unresolved
//     comparison filters every one of them away — the watcher looks simply dead. The trap is that
//     `URL.resolvingSymlinksInPath()` does the *opposite* for exactly these paths: it documents that it
//     *strips* a leading /private, so it turned /private/var/… back into /var/… and the first version
//     of this file received every event and discarded it. Measured against a standalone probe, not
//     assumed — and the filter's unit test agreed with the bug because it used the same wrong function.

import Foundation

/// Watches one directory and calls back when its contents change.
///
/// Not an actor: `FSEventStream` wants a dispatch queue and a C callback, and the owner is the main
/// actor. The callback arrives on `queue`; the owner hops to the main actor itself.
public final class DirectoryWatcher: @unchecked Sendable {
    /// How long FSEvents may collect further changes before reporting. Long enough that a copy of many
    /// files is one refresh; short enough that a refresh still feels immediate.
    public static let defaultLatency: CFTimeInterval = 0.35

    /// The shortest gap between two refreshes while changes keep arriving.
    public static let defaultCooldown: TimeInterval = 0.4

    private let watchedPath: String
    private let latency: CFTimeInterval
    private let cooldown: TimeInterval
    private let onChange: @Sendable () -> Void
    private let queue = DispatchQueue(label: "com.peachcommander.directory-watcher")
    private var stream: FSEventStreamRef?
    /// The watched directory's mtime as of the last check. Touched only from `queue`.
    private var lastKnownMTime: Date?
    /// Leading-edge throttle state, both touched only from `queue`.
    private var cooling = false
    private var missedWhileCooling = false

    /// - Parameters:
    ///   - path: the directory to watch. Resolved for symlinks, because that is what FSEvents reports.
    ///   - latency: coalescing window, see ``defaultLatency``.
    ///   - onChange: called on a private queue whenever this directory's contents changed.
    public init(path: String, latency: CFTimeInterval = DirectoryWatcher.defaultLatency,
                cooldown: TimeInterval = DirectoryWatcher.defaultCooldown,
                onChange: @escaping @Sendable () -> Void) {
        self.watchedPath = Self.canonical(path)
        self.latency = latency
        self.cooldown = cooldown
        self.onChange = onChange
    }

    deinit { stop() }

    /// Begin watching. Calling it twice is a no-op rather than a second stream.
    public func start() {
        guard stream == nil else { return }
        let info = Unmanaged.passRetained(self).toOpaque()
        var context = FSEventStreamContext(
            version: 0, info: info, retain: nil,
            release: { pointer in
                guard let pointer else { return }
                Unmanaged<DirectoryWatcher>.fromOpaque(pointer).release()
            },
            copyDescription: nil)

        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let cPaths = paths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
            let batch = (0..<count).compactMap { cPaths[$0].map { String(cString: $0) } }
            // One callback per batch is all the panel needs: it re-lists the whole directory.
            if watcher.batchChangesTheListing(batch) { watcher.notifyThrottled() }
        }

        guard let created = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [watchedPath] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            // UseCFTypes is deliberately *not* set: the callback reads the paths as C strings above.
            // FileEvents is what makes the "this directory only" filter possible — see the header.
            UInt32(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents))
        else {
            // Releases the retain taken for the context, which the stream never took ownership of.
            Unmanaged<DirectoryWatcher>.fromOpaque(info).release()
            return
        }
        stream = created
        // Remembered before the stream can report anything: FSEvents' "since now" is coarse enough that
        // directories created moments ago still arrive, and an unset baseline would turn each of those
        // into a refresh right after opening a folder.
        lastKnownMTime = directoryMTime()
        FSEventStreamSetDispatchQueue(created, queue)
        FSEventStreamStart(created)
    }

    /// Stop watching and release the stream. Safe to call more than once, and from `deinit`.
    public func stop() {
        guard let stream else { return }
        self.stream = nil
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    /// Call `onChange` now, or once the cooldown expires if one just went out.
    ///
    /// Always on `queue`, so the flags need no lock.
    private func notifyThrottled() {
        if cooling {
            missedWhileCooling = true
            return
        }
        cooling = true
        onChange()
        queue.asyncAfter(deadline: .now() + cooldown) { [weak self] in
            guard let self else { return }
            self.cooling = false
            if self.missedWhileCooling {
                self.missedWhileCooling = false
                // The tail matters: the last change of a copy must not be the one that is dropped.
                self.notifyThrottled()
            }
        }
    }

    /// The path as the kernel sees it: /tmp → /private/tmp, and every symlink on the way resolved.
    ///
    /// Falls back to the input when realpath fails, which for a directory that no longer exists is the
    /// harmless case — the stream reports nothing for it either.
    static func canonical(_ path: String) -> String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// Whether this batch of event paths means the panel's listing is out of date.
    ///
    /// See the header: with `FileEvents` a direct child is a change to the listing and is enough on its
    /// own, while an event for the watched directory itself is only believed when its mtime moved — the
    /// folder's own creation arrives right after `start()` and must not refresh it.
    func batchChangesTheListing(_ eventPaths: [String]) -> Bool {
        var namesTheDirectory = false
        for eventPath in eventPaths {
            switch classify(eventPath) {
            case .directChild: return true
            case .theDirectory: namesTheDirectory = true
            case .elsewhere: continue
            }
        }
        guard namesTheDirectory else { return false }
        let current = directoryMTime()
        guard current != lastKnownMTime else { return false }
        lastKnownMTime = current
        return true
    }

    enum EventScope: Equatable { case theDirectory, directChild, elsewhere }

    /// Where `eventPath` sits relative to the watched directory.
    func classify(_ eventPath: String) -> EventScope {
        let path = eventPath.hasSuffix("/") ? String(eventPath.dropLast()) : eventPath
        if path == watchedPath { return .theDirectory }
        let prefix = watchedPath.hasSuffix("/") ? watchedPath : watchedPath + "/"
        guard path.hasPrefix(prefix) else { return .elsewhere }
        return path.dropFirst(prefix.count).contains("/") ? .elsewhere : .directChild
    }

    /// The watched directory's modification time, or nil if it is gone.
    private func directoryMTime() -> Date? {
        var info = stat()
        guard stat(watchedPath, &info) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec)
                    + TimeInterval(info.st_mtimespec.tv_nsec) / 1_000_000_000)
    }
}
