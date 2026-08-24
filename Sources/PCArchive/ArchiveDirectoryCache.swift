// SPDX-License-Identifier: Apache-2.0
// ArchiveDirectoryCache.swift - Reuse an opened archive instead of parsing it again (F-463).
//
// SPEC-007 §2 says an archive's headers are read ONCE, and performance.md budgets the
// cache at 32 archives keyed by path+mtime. Neither existed: entering an archive, leaving
// it and entering it again re-read the whole central directory every time, and so did
// unpacking it afterwards.
//
// Two rules keep this from turning a passing cost into a permanent one:
//
//   * A byte budget beside the entry count. "32 archives" says nothing about memory when
//     one of them is a tar.gz the reader had to inflate whole — 32 of those could pin
//     gigabytes for the rest of the session, which is worse than the re-parse it saves.
//     Backends report what they retain; mapped zips report zero and are effectively free.
//   * The key is size, mtime *and* inode (`FileStamp`). mtime alone is not enough: the
//     usual way a program rewrites an archive is to write a temporary file and rename it
//     over the old one, and a rename carries the source's mtime across.

import Foundation
import PCVFS

/// Open archives, keyed by the identity of the file they were read from.
public final class ArchiveDirectoryCache: @unchecked Sendable {
    /// Shared by every consumer of the archive registry.
    public static let shared = ArchiveDirectoryCache()

    private struct Key: Hashable {
        let path: String
        let stamp: FileStamp
    }

    private let lock = NSLock()
    private var entries: [Key: ArchiveFS] = [:]
    /// Least-recently-used first.
    private var order: [Key] = []
    private var retained: Int64 = 0
    private var pressureSource: DispatchSourceMemoryPressure?

    /// Budgets from performance.md, plus the byte ceiling that table does not name.
    private let maxEntries = 32
    private let maxRetainedBytes: Int64 = 64 * 1024 * 1024

    public init() {
        // Caches must give way under pressure rather than compete with the app that
        // filled them (performance.md). This is the first such hookup in the codebase.
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.removeAll() }
        source.resume()
        pressureSource = source
    }

    /// The archive already open for `url`, if it is still the same file.
    public func archive(for url: URL) -> ArchiveFS? {
        guard let stamp = FileStamp.of(url.path) else { return nil }
        let key = Key(path: url.path, stamp: stamp)
        lock.lock()
        defer { lock.unlock() }
        guard let hit = entries[key] else { return nil }
        touch(key)
        return hit
    }

    /// Remember `fs` as the archive for `url`.
    ///
    /// Declines silently in the two cases where remembering would be wrong rather than
    /// merely useless: an extraction in the temp directory, whose path is unique per
    /// call and whose file is about to be deleted, and an archive with encrypted members,
    /// where a password typed in one place would silently carry into another.
    public func store(_ fs: ArchiveFS, for url: URL) {
        guard !Self.isTemporary(url), !fs.hasEncryptedEntries,
              let stamp = FileStamp.of(url.path) else { return }
        let cost = fs.retainedBytes
        guard cost <= maxRetainedBytes else { return }

        let key = Key(path: url.path, stamp: stamp)
        lock.lock()
        defer { lock.unlock() }
        if entries[key] != nil { touch(key); return }
        entries[key] = fs
        order.append(key)
        retained += cost
        while order.count > maxEntries || retained > maxRetainedBytes {
            guard let oldest = order.first else { break }
            order.removeFirst()
            if let evicted = entries.removeValue(forKey: oldest) { retained -= evicted.retainedBytes }
        }
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        order.removeAll()
        retained = 0
    }

    /// Entry count, for tests and diagnostics.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    /// Caller must hold the lock.
    private func touch(_ key: Key) {
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            order.append(key)
        }
    }

    /// One of *our* extractions, rather than merely a file in the temp directory.
    ///
    /// The first version tested for the temp directory itself, which is too broad by far:
    /// somebody's archive is allowed to live in /tmp, and refusing to remember it there
    /// would be an arbitrary hole in the cache. What must not be remembered is the
    /// staging directory an archive mount extracts into — a name used once, deleted as
    /// soon as the descent that made it is done.
    private static func isTemporary(_ url: URL) -> Bool {
        url.pathComponents.contains { $0.hasPrefix("PCArchive-") }
    }
}
