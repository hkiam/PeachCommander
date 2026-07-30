// DirectorySizeCalculator.swift - Asynchronous, cancellable directory size computation
//
// Computes the total byte size of a directory tree (SPEC-002 §5 "space on dir").
// Pure Foundation, no AppKit. Results are cached per path and invalidated when the
// directory's own modification date changes.

import Foundation
import PCFoundation

/// Computes the recursive byte size of directory trees, with per-path caching and
/// bounded-concurrency batch support.
///
/// Cancellation: `size(of:)` checks `Task.isCancelled` between directory-stack pops.
/// When cancellation is detected, the walk stops immediately and the method returns
/// the number of bytes accumulated so far (a partial sum), rather than throwing or
/// returning 0. Partial results are never cached, so a subsequent call will redo the
/// full walk. `sizes(of:maxConcurrency:)` stops launching new per-path computations
/// once the enclosing task is cancelled and returns whatever entries have completed.
public actor DirectorySizeCalculator {
    private let logger = PCFoundationLogger.logger

    /// A cached result: the computed size plus the directory's mtime at the time of
    /// computation, used to validate the cache entry on subsequent lookups.
    private struct CacheEntry {
        let size: Int64
        let modificationDate: Date
    }

    private var cache: [String: CacheEntry] = [:]

    public init() {}

    /// Total byte size (sum of regular file sizes) of the directory tree at `path`.
    ///
    /// Symbolic links (whether pointing to files or directories) are never followed
    /// or counted, which avoids cycles and escaping the tree.
    ///
    /// Cancellable: if the surrounding task is cancelled mid-walk, the bytes summed
    /// so far are returned immediately (a partial result); such a partial result is
    /// not cached.
    ///
    /// Caches by path; a cache hit is reused only if the directory's own modification
    /// date is unchanged since the cached computation (mtime stored alongside size).
    public func size(of path: String) async -> Int64 {
        let currentModificationDate = Self.modificationDate(of: path)

        // A nil mtime means the path could not be stat'd; treat as never-cacheable
        // so we never claim a false cache hit off two unrelated failures.
        if let currentModificationDate,
           let cached = cache[path],
           cached.modificationDate == currentModificationDate {
            return cached.size
        }

        let (total, wasCancelled) = Self.walk(path)

        if !wasCancelled, let currentModificationDate {
            cache[path] = CacheEntry(size: total, modificationDate: currentModificationDate)
        } else if wasCancelled {
            logger.debug("DirectorySizeCalculator: cancelled while sizing \(path, privacy: .public); returning partial result")
        }

        return total
    }

    /// Compute sizes for many directories with bounded concurrency (default 4).
    /// Returns a map path -> size. Cancellable: once the surrounding task is
    /// cancelled, no further per-path computations are started and the map contains
    /// only the paths that finished before cancellation was observed.
    public func sizes(of paths: [String], maxConcurrency: Int = 4) async -> [String: Int64] {
        guard !paths.isEmpty else { return [:] }
        let limit = max(1, maxConcurrency)

        var results: [String: Int64] = [:]
        var iterator = paths.makeIterator()

        await withTaskGroup(of: (String, Int64).self) { group in
            func addNextIfAny() {
                guard !Task.isCancelled, let nextPath = iterator.next() else { return }
                group.addTask {
                    let value = await self.size(of: nextPath)
                    return (nextPath, value)
                }
            }

            for _ in 0..<limit {
                addNextIfAny()
            }

            while let (path, value) = await group.next() {
                results[path] = value
                addNextIfAny()
            }
        }

        return results
    }

    /// Drop a cached entry (e.g. after the directory changed).
    public func invalidate(_ path: String) {
        cache.removeValue(forKey: path)
    }

    /// Drop all cache entries.
    public func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Walk

    /// Walks the directory tree at `path` using a manual stack (never following
    /// symbolic links), summing regular file sizes. Returns the accumulated total
    /// and whether the walk was cut short by cancellation.
    private static func walk(_ rootPath: String) -> (total: Int64, cancelled: Bool) {
        var total: Int64 = 0
        var stack: [String] = [rootPath]
        let fileManager = FileManager.default

        while let currentPath = stack.popLast() {
            if Task.isCancelled {
                return (total, true)
            }

            guard let childNames = try? fileManager.contentsOfDirectory(atPath: currentPath) else {
                continue
            }

            for childName in childNames {
                let childPath = (currentPath as NSString).appendingPathComponent(childName)

                guard let attributes = try? fileManager.attributesOfItem(atPath: childPath) else {
                    continue
                }

                let fileType = attributes[.type] as? FileAttributeType

                // Never follow symbolic links: skip entirely (safety requirement).
                if fileType == .typeSymbolicLink {
                    continue
                }

                if fileType == .typeDirectory {
                    stack.append(childPath)
                } else if fileType == .typeRegular {
                    total += (attributes[.size] as? Int64) ?? 0
                }
            }
        }

        return (total, false)
    }

    /// Reads the content modification date of the directory at `path`, used as the
    /// cache validity key. Returns nil if the path cannot be stat'd (treated as
    /// always-invalid, so a cache hit never occurs).
    private static func modificationDate(of path: String) -> Date? {
        let url = URL(fileURLWithPath: path)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }
}
