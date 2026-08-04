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
        self.path = path
        entries = []
        let batch = try await lister.listDirectory(path)
        entries = batch.entries
        return createSnapshot()
    }

    /// Load entries from a filesystem through the VFS streaming protocol (I08).
    public func load(_ path: String, fs: VirtualFileSystem) async throws -> DirectorySnapshot {
        self.path = path
        var collected: [VFSEntry] = []
        let dir = VFSPath(filesystemId: fs.scheme, path: path)
        for try await batch in fs.list(dir) {
            collected.append(contentsOf: batch.entries)
        }
        entries = collected
        return createSnapshot()
    }

    /// Create an immutable snapshot with sorting and filtering applied
    private func createSnapshot() -> DirectorySnapshot {
        var result = entries

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
