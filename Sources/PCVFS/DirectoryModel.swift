// SPDX-License-Identifier: Apache-2.0
// DirectoryModel.swift - Directory listing model with sorting and filtering
//
// This actor holds the full entry array and provides immutable snapshots
// for the main thread. It handles sorting, filtering, and the `..` entry.

import Foundation
import PCFoundation

/// Immutable snapshot of a directory listing for the main thread
public struct DirectorySnapshot: Sendable {
    public let entries: [VFSEntry]
    public let path: String

    public init(entries: [VFSEntry], path: String) {
        self.entries = entries
        self.path = path
    }
}

/// Directory model actor - holds full entry array + derived visible snapshot
/// Thrown by `DirectoryModel.load` when a newer load for the same model has started.
///
/// Not a failure of the directory, and callers must not report it as one: it means the user navigated
/// again while this listing was still arriving, and the answer they are waiting for is the other one.
public struct DirectoryLoadSuperseded: Error {}

public actor DirectoryModel {
    private let logger = PCFoundationLogger.logger

    private var entries: [VFSEntry] = []
    private var path: String = ""
    private var currentSort: SortSpec = .init(descriptor: .name(ascending: true))
    private var filter: WildcardMask?

    /// Sort descriptor for directory entries
    public enum SortDescriptor: Equatable {
        case name(ascending: Bool)
        case ext(ascending: Bool)
        case size(ascending: Bool)
        case date(ascending: Bool)

        var keyPath: String {
            switch self {
            case .name: return "name"
            case .ext: return "ext"
            case .size: return "size"
            case .date: return "modified"
            }
        }

        public var isAscending: Bool {
            switch self {
            case .name(let asc), .ext(let asc), .size(let asc), .date(let asc):
                return asc
            }
        }

        /// Get the sort column name
        var sortKey: String {
            switch self {
            case .name: return "name"
            case .ext: return "ext"
            case .size: return "size"
            case .date: return "modified"
            }
        }

        /// Reverse the sort direction
        public func reversed() -> SortDescriptor {
            switch self {
            case .name(let asc): return .name(ascending: !asc)
            case .ext(let asc): return .ext(ascending: !asc)
            case .size(let asc): return .size(ascending: !asc)
            case .date(let asc): return .date(ascending: !asc)
            }
        }

        /// Get the sort description for display
        public func toDisplayString() -> String {
            let column: String
            switch self {
            case .name: column = "Name"
            case .ext: column = "Ext"
            case .size: column = "Size"
            case .date: column = "Date"
            }

            let direction = isAscending ? "↑" : "↓"
            return "\(column) \(direction)"
        }
    }

    /// Sort specification for persistence
    public struct SortSpec: Equatable {
        public let descriptor: SortDescriptor
        public let dirsFirst: Bool

        public init(descriptor: SortDescriptor, dirsFirst: Bool = true) {
            self.descriptor = descriptor
            self.dirsFirst = dirsFirst
        }
    }

    /// Whether entry names sort in natural (numeric) order; a global display
    /// option (F-026), applied on the next snapshot.
    private var naturalSort = true

    /// Set the natural-sort option (re-sort happens on the next snapshot/sort call).
    public func setNaturalSort(_ on: Bool) { naturalSort = on }

    public init() {
        logger.info("DirectoryModel initialized")
    }

    /// Load entries from a path (legacy lister path; retained for tests).
    public func load(_ path: String, lister: LocalDirectoryLister) async throws -> DirectorySnapshot {
        let batch = try await lister.listDirectory(path)
        commit(path: path, entries: batch.entries)
        return createSnapshot()
    }

    /// Which load is the current one. See `load(_:fs:onPartial:)`.
    private var generation = 0

    /// Below this many entries a listing is over before anybody could look at it, so partial
    /// snapshots are not offered: two table reloads instead of one, for no gain. `LocalFS` batches at
    /// 4096 and the plugin adapter at 128, so this is about the *accumulated* count rather than a
    /// batch size.
    private static let partialThreshold = 200

    /// Load entries from a filesystem through the VFS streaming protocol (I08).
    ///
    /// `onPartial` is called, on the caller's behalf and off the main actor, each time enough more
    /// entries have arrived to be worth showing. It exists because the streaming was being thrown
    /// away: `VirtualFileSystem.list` has yielded batches since I08 — 4096 at a time from `LocalFS`,
    /// 128 from a plugin mount — and this method collected every one of them before answering. A
    /// bucket with fifty thousand objects showed an empty panel until the last page arrived.
    ///
    /// The returned snapshot is still the whole listing, and it is the only one that is *committed*.
    /// A partial is a value handed out for display; the model's own state does not move until the
    /// enumeration finishes. That is deliberate and it is F-445's invariant: `getPath()` has twenty-odd
    /// callers, and a path that changed before its entries did is how a panel came to name one folder
    /// and list another.
    public func load(_ path: String, fs: VirtualFileSystem,
                     onPartial: (@Sendable (DirectorySnapshot) -> Void)? = nil) async throws
        -> DirectorySnapshot {
        generation += 1
        let mine = generation
        var collected: [VFSEntry] = []
        var offered = 0
        let dir = VFSPath(filesystemId: fs.scheme, path: path)
        for try await batch in fs.list(dir) {
            // Actors are re-entrant at every `await`, so a second `load` can start while this one is
            // waiting for its next batch. Before, the one that finished last won whatever the user
            // asked for last; now the newest request wins and an overtaken one stops. Without this,
            // partial snapshots from two directories would be appended into one list.
            guard mine == generation else { throw DirectoryLoadSuperseded() }
            collected.append(contentsOf: batch.entries)
            if let onPartial, !batch.isLastBatch,
               collected.count >= Self.partialThreshold, collected.count > offered {
                offered = collected.count
                onPartial(snapshot(path: path, of: collected))
            }
        }
        guard mine == generation else { throw DirectoryLoadSuperseded() }
        commit(path: path, entries: collected)
        return createSnapshot()
    }

    /// The new listing and the path it came from, together — the invariant this type has to keep
    /// (F-445).
    ///
    /// Both assignments used to happen around the enumeration rather than after it: `self.path` first,
    /// `entries` at the end. A listing that threw — a directory macOS keeps private, a permission, a
    /// connection that died — therefore left the model holding the new path with the *previous*
    /// directory's entries, and `getPath()` has twenty-odd callers that then disagreed with the list
    /// on screen. The panel's tab and breadcrumb ended up naming different folders, and the path was
    /// written to the session, so the next launch opened somewhere it could not list.
    private func commit(path: String, entries: [VFSEntry]) {
        self.path = path
        self.entries = entries
    }

    /// Create an immutable snapshot with sorting and filtering applied
    private func createSnapshot() -> DirectorySnapshot {
        snapshot(path: path, of: entries)
    }

    /// The same sorting and filtering, over entries that are not (yet) the model's own.
    ///
    /// Used for partial snapshots during a load. Each one is sorted in full rather than appended to
    /// the last, so a row can move as more arrive — which is what an incrementally sorted listing
    /// does, and is why the panel keeps the cursor on its *item* rather than on its row index.
    private func snapshot(path: String, of source: [VFSEntry]) -> DirectorySnapshot {
        var result = source

        // Sort: dirs first, then by current sort descriptor
        result.sort { a, b -> Bool in
            // Dirs always first (configurable)
            if currentSort.dirsFirst {
                let aIsDir = a.kind == .directory || a.kind == .symlinkDir || a.kind == .package
                let bIsDir = b.kind == .directory || b.kind == .symlinkDir || b.kind == .package
                if aIsDir != bIsDir {
                    return aIsDir
                }
            }

            // Same type - apply sort descriptor
            switch currentSort.descriptor {
            case .name(let asc):
                let cmp = naturalCompare(a.name, b.name, natural: naturalSort)
                return asc ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            case .ext(let asc):
                let cmp = naturalCompare(a.ext, b.ext, natural: naturalSort)
                if cmp != .orderedSame {
                    return asc ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
                let nameCmp = naturalCompare(a.name, b.name, natural: naturalSort)
                return asc ? (nameCmp == .orderedAscending) : (nameCmp == .orderedDescending)
            case .size(let asc):
                if a.size != b.size {
                    return asc ? (a.size < b.size) : (a.size > b.size)
                }
                let nameCmp = naturalCompare(a.name, b.name, natural: naturalSort)
                return asc ? (nameCmp == .orderedAscending) : (nameCmp == .orderedDescending)
            case .date(let asc):
                if a.modified != b.modified {
                    return asc ? (a.modified < b.modified) : (a.modified > b.modified)
                }
                let nameCmp = naturalCompare(a.name, b.name, natural: naturalSort)
                return asc ? (nameCmp == .orderedAscending) : (nameCmp == .orderedDescending)
            }
        }

        // Apply filter if set
        if let filter = filter {
            result = result.filter { entry in
                filter.matches(entry.name)
            }
        }

        return DirectorySnapshot(entries: result, path: path)
    }

    /// Sort by the given spec
    public func sort(by spec: SortSpec) {
        currentSort = spec
    }

    /// Sort by the given descriptor (with default dirsFirst)
    public func sort(by descriptor: SortDescriptor) {
        currentSort = .init(descriptor: descriptor)
    }

    /// Set filter wildcard (TC format: `*.c;*.h|*.bak`)
    public func setFilter(_ wildcard: String?) {
        filter = wildcard.map { WildcardMask($0) }
    }

    /// Get current snapshot
    public func snapshot() -> DirectorySnapshot {
        createSnapshot()
    }

    /// Get the current path
    public func getPath() -> String {
        path
    }

    /// Get current sort descriptor
    public func getSortDescriptor() -> SortDescriptor {
        currentSort.descriptor
    }

    /// Toggle sort direction (ascending/descending)
    public func toggleSortDirection() {
        currentSort = .init(descriptor: currentSort.descriptor.reversed(), dirsFirst: currentSort.dirsFirst)
    }

    /// Set sort direction explicitly
    public func setSortDirection(_ ascending: Bool) {
        currentSort = .init(descriptor: .name(ascending: ascending), dirsFirst: true)
    }

    /// Set dirs first option
    public func setDirsFirst(_ dirsFirst: Bool) {
        currentSort = .init(descriptor: currentSort.descriptor, dirsFirst: dirsFirst)
    }

    // MARK: - Auto-Refresh
    //
    // Deliberately not here any more (F-361). The model used to own a `DirectoryWatcher` and start one
    // on every load without ever stopping it — and the watcher had no callback, so nothing could ever
    // arrive. Watching belongs to the filesystem, which knows whether it *can* be watched:
    // `VirtualFileSystem.watch(_:)` returns a stream for a local directory and nil for an archive, an
    // FTP site or a plugin mount. The panel consumes that stream; see `PanelController.startWatching`.

    /// Reload entries from the current path
    public func reload(lister: LocalDirectoryLister) async throws -> DirectorySnapshot {
        guard !path.isEmpty else { return createSnapshot() }

        let batch = try await lister.listDirectory(path)
        entries = batch.entries

        let snapshot = createSnapshot()
        logger.info("Directory reloaded with \(self.entries.count) entries")
        return snapshot
    }
}
