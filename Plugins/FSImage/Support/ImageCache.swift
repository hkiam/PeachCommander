// SPDX-License-Identifier: Apache-2.0
// ImageCache.swift — parse an image once, answer every later open from memory.
//
// This is not an optimisation; without it the plugin is unusable on real images.
// The host's PCX adapter reopens the archive for every single file it reads:
// `PCXArchive.extract` calls OpenArchive again and walks ReadHeaderEx until the
// name matches, and `PCXArchiveFS.openRead` calls that once per read. For a zip
// with two hundred entries nobody notices. For an ext4 rootfs with 50,000 files it
// means re-parsing the superblock, the group descriptors and the inode table
// 50,000 times — copying the tree out becomes quadratic in parse work and the
// panel stops responding.
//
// The fix lives entirely inside the plugin, which is what keeps this "API only":
// OpenArchive after the first is a dictionary lookup, ReadHeaderEx walks a
// prebuilt array, and ProcessFile reads blocks the driver already knows how to
// find.
//
// The key includes size, mtime and inode, not just the path. An image that is
// re-flashed or swapped in place keeps its name, and serving the previous parse
// for it would show the user a tree that is no longer in the file.

import Foundation

/// Identity of a cached parse. Two opens share a driver only if the file is, as
/// far as the filesystem can tell, the same bytes.
private struct ImageKey: Hashable {
    let path: String
    let size: Int64
    let mtime: Int64
    let inode: UInt64

    /// Nil when the file cannot be stat'ed — an unidentifiable file is not cached
    /// rather than cached under a guess.
    init?(path: String) {
        var st = stat()
        guard stat(path, &st) == 0 else { return nil }
        self.path = path
        self.size = Int64(st.st_size)
        self.mtime = Int64(st.st_mtimespec.tv_sec)
        self.inode = UInt64(st.st_ino)
    }
}

/// Process-wide LRU of parsed images.
///
/// Thread-safe because the host's serialisation guarantee is per handle, not
/// global: two panels browsing two images call in concurrently, and both reach
/// this. The lock is held only around the dictionary, never across a parse — a
/// slow parse of a large image must not block an unrelated lookup.
final class ImageCache {
    static let shared = ImageCache()

    /// How many parsed images stay resident. Each holds its entry array and the
    /// driver's metadata tables, so this is bounded by count rather than bytes:
    /// the dominant cost is proportional to entries, and `ImageLimits.maxEntries`
    /// already caps that per image. Four covers both panels plus the two most
    /// recently visited images, which is what navigating firmware looks like.
    private let capacity = 4

    private let lock = NSLock()
    private var entries: [ImageKey: any ImageFilesystemDriver] = [:]
    /// Least-recently-used first.
    private var order: [ImageKey] = []

    private init() {}

    /// The driver for `path`, parsing it only if it is not already cached.
    ///
    /// A parse that throws is not cached: a truncated image being written right now
    /// would otherwise keep failing from memory after it is complete.
    func driver(for path: String) throws -> any ImageFilesystemDriver {
        guard let key = ImageKey(path: path) else { return try DriverRegistry.open(path: path) }

        lock.lock()
        if let cached = entries[key] {
            touch(key)
            lock.unlock()
            return cached
        }
        lock.unlock()

        // Parsed outside the lock. Two threads racing on the same cold image both
        // parse it and the second store wins; that costs one redundant parse and
        // avoids serialising every other image behind this one.
        let driver = try DriverRegistry.open(path: path)

        lock.lock()
        defer { lock.unlock() }
        if entries[key] == nil {
            entries[key] = driver
            order.append(key)
            while order.count > capacity {
                entries.removeValue(forKey: order.removeFirst())
            }
        }
        return entries[key] ?? driver
    }

    /// Drop everything. Only for tests, which need each case to start from a cold
    /// cache — otherwise a test that rewrites a fixture at the same path within the
    /// same second could be served the previous parse.
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        order.removeAll()
    }

    /// Move `key` to the most-recently-used end. Caller holds the lock.
    private func touch(_ key: ImageKey) {
        guard let index = order.firstIndex(of: key) else { return }
        order.remove(at: index)
        order.append(key)
    }
}
