// SPDX-License-Identifier: Apache-2.0
// ScanEngine.swift — the fast disk-usage scanner behind Disk Map.
//
// Speed is the primary goal, so this deliberately avoids Foundation's per-file
// `FileManager.attributesOfItem` (one heavy `stat` + NSDictionary bridge per file).
// Instead it enumerates each directory with `getattrlistbulk(2)`, which returns the
// name, object type, inode and ALLOCATED size for many entries in a single syscall,
// usually without the kernel creating a vnode per file. This is the same technique
// the fastest native scanners (diskly, dumac, MacDirStat) use — 2–3× faster than du.
//
// On top of that:
//   • Traversal runs in parallel across subdirectories, bounded to the core count
//     ("spawn if budget, else recurse inline" — never blocks a worker, so no deadlock).
//   • Sizes are the on-disk ALLOCATED size (matches Finder/du), not logical length.
//   • Hard links / are counted once via a sharded (inode) set (Time-Machine local
//     links, hard-linked files) so space isn't double-counted.
//   • The scan stays on the starting volume (device id from the dir fd), so it never
//     wanders into other mounted volumes or network shares.

import Foundation

// vnode object types (from <sys/vnode.h>) as returned by ATTR_CMN_OBJTYPE.
private let VREG: UInt32 = 1
private let VDIR: UInt32 = 2
private let VLNK: UInt32 = 5

/// A node in the scanned tree. Sizes aggregate bottom-up (allocated bytes).
final class Node {
    let name: String
    let path: String
    let isDir: Bool
    var size: Int64 = 0
    var itemCount: Int = 1          // files under here (self = 1 for a file)
    var children: [Node] = []
    weak var parent: Node?
    init(name: String, path: String, isDir: Bool, parent: Node?) {
        self.name = name; self.path = path; self.isDir = isDir; self.parent = parent
    }
}

/// Thread-safe cancellation flag shared with a running scan.
final class ScanControl {
    private let lock = NSLock()
    private var _cancelled = false
    var cancelled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _cancelled }
        set { lock.lock(); _cancelled = newValue; lock.unlock() }
    }
}

/// Volume space breakdown (macOS/APFS-aware), used for the reconciling ring.
struct VolumeSpace {
    var total: Int64 = 0        // volumeTotalCapacity
    var free: Int64 = 0         // volumeAvailableCapacity (plain)
    var important: Int64 = 0    // volumeAvailableCapacityForImportantUsage (free + purgeable)
    var mountPath: String = "/" // the volume's mount point
    /// Space macOS can reclaim on demand (local snapshots, caches, optimized storage).
    var purgeable: Int64 { max(0, important - free) }
    /// Truly occupied (non-purgeable) space, per the system.
    var used: Int64 { max(0, total - important) }

    static func read(forPath path: String) -> VolumeSpace? {
        let url = URL(fileURLWithPath: path)
        guard let v = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeURLKey]) else { return nil }
        var s = VolumeSpace()
        s.total = Int64(v.volumeTotalCapacity ?? 0)
        s.free = Int64(v.volumeAvailableCapacity ?? 0)
        s.important = v.volumeAvailableCapacityForImportantUsage ?? s.free
        s.mountPath = v.volume?.path ?? "/"
        return s.total > 0 ? s : nil
    }
}

/// Bounds the number of concurrently-spawned directory tasks so we parallelise
/// without oversubscribing. Callers that can't get budget just recurse inline.
private final class ConcurrencyBudget {
    private let lock = NSLock()
    private var inUse = 0
    private let limit: Int
    init(limit: Int) { self.limit = max(1, limit) }
    func tryAcquire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if inUse < limit { inUse += 1; return true }
        return false
    }
    func release() { lock.lock(); inUse -= 1; lock.unlock() }
}

/// Deduplicates hard links across threads by inode, sharded to cut lock contention.
private final class InodeSet {
    private let shards: Int
    private var sets: [Set<UInt64>]
    private var locks: [NSLock]
    init(shards: Int = 64) {
        self.shards = shards
        sets = Array(repeating: [], count: shards)
        locks = (0..<shards).map { _ in NSLock() }
    }
    /// Returns true the first time an inode is seen; false if already counted.
    func firstSight(_ inode: UInt64) -> Bool {
        let i = Int(inode % UInt64(shards))
        locks[i].lock(); defer { locks[i].unlock() }
        return sets[i].insert(inode).inserted
    }
}

enum ScanEngine {
    /// Scan `rootPath` into a Node tree of allocated sizes. `report` is called
    /// periodically (off the main thread) with (items, bytes, currentPath).
    /// `stayOnVolume` stops the walk at other-volume mount points.
    static func scan(rootPath: String, control: ScanControl, stayOnVolume: Bool,
                     report: @escaping (Int, Int64, String) -> Void) -> Node {
        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDir)
        let name = (rootPath as NSString).lastPathComponent.isEmpty ? rootPath
            : (rootPath as NSString).lastPathComponent
        let root = Node(name: name, path: rootPath, isDir: isDir.boolValue, parent: nil)
        guard isDir.boolValue else {
            root.size = fileAllocSize(rootPath); return root
        }
        // Device id of the starting volume (to detect mount-point crossings).
        var st = stat()
        let rootDev: Int32 = (lstat(rootPath, &st) == 0) ? st.st_dev : 0

        let budget = ConcurrencyBudget(limit: ProcessInfo.processInfo.activeProcessorCount)
        let inodes = InodeSet()
        let counters = Counters(report: report)
        scanDir(root, rootDev: rootDev, stayOnVolume: stayOnVolume, control: control,
                budget: budget, inodes: inodes, counters: counters)
        return root
    }

    /// Throttled progress aggregation shared by all worker threads.
    private final class Counters {
        private let lock = NSLock()
        private var items = 0
        private var bytes: Int64 = 0
        private var lastReport = Date.timeIntervalSinceReferenceDate
        private let report: (Int, Int64, String) -> Void
        init(report: @escaping (Int, Int64, String) -> Void) { self.report = report }
        func add(items dItems: Int, bytes dBytes: Int64, path: String) {
            lock.lock()
            items += dItems; bytes += dBytes
            let now = Date.timeIntervalSinceReferenceDate
            let due = now - lastReport > 0.08
            let snapshotItems = items, snapshotBytes = bytes
            if due { lastReport = now }
            lock.unlock()
            if due { report(snapshotItems, snapshotBytes, path) }
        }
    }

    /// Scan one directory: enumerate its entries with getattrlistbulk (single-threaded
    /// here, so `node.children` is built safely), then size its subdirectories in
    /// parallel. Fills `node.size` / `node.itemCount`.
    private static func scanDir(_ node: Node, rootDev: Int32, stayOnVolume: Bool,
                                control: ScanControl, budget: ConcurrencyBudget,
                                inodes: InodeSet, counters: Counters) {
        if control.cancelled { return }
        let fd = open(node.path, O_RDONLY | O_DIRECTORY, 0)
        guard fd >= 0 else { return }
        defer { close(fd) }
        // Mount-point crossing check via the directory's own device id.
        var dst = stat()
        if stayOnVolume, fstat(fd, &dst) == 0, rootDev != 0, dst.st_dev != rootDev { return }

        var subdirs: [Node] = []
        var fileBytes: Int64 = 0
        var fileItems = 0

        enumerate(fd: fd, dirPath: node.path) { entry in
            if control.cancelled { return false }
            switch entry.type {
            case VDIR:
                let child = Node(name: entry.name, path: entry.path, isDir: true, parent: node)
                node.children.append(child); subdirs.append(child)
            case VLNK:
                break   // never follow symlinks (cycles / double counting)
            default:    // regular & everything else with an allocation
                // Count hard-linked files only once.
                if entry.linkCount > 1, !inodes.firstSight(entry.inode) { break }
                let child = Node(name: entry.name, path: entry.path, isDir: false, parent: node)
                child.size = entry.allocSize
                node.children.append(child)
                fileBytes += entry.allocSize; fileItems += 1
            }
            return true
        }
        counters.add(items: fileItems + subdirs.count, bytes: fileBytes, path: node.path)

        // Size subdirectories, spawning parallel tasks while budget allows.
        if !subdirs.isEmpty {
            let group = DispatchGroup()
            for sub in subdirs {
                if control.cancelled { break }
                if budget.tryAcquire() {
                    DispatchQueue.global(qos: .userInitiated).async(group: group) {
                        scanDir(sub, rootDev: rootDev, stayOnVolume: stayOnVolume,
                                control: control, budget: budget, inodes: inodes, counters: counters)
                        budget.release()
                    }
                } else {
                    scanDir(sub, rootDev: rootDev, stayOnVolume: stayOnVolume,
                            control: control, budget: budget, inodes: inodes, counters: counters)
                }
            }
            group.wait()
        }

        var total = fileBytes
        var items = fileItems
        for sub in subdirs { total += sub.size; items += sub.itemCount }
        node.size = total
        node.itemCount = items
    }

    // MARK: getattrlistbulk enumeration

    private struct Entry {
        var name: String
        var path: String
        var type: UInt32
        var inode: UInt64
        var allocSize: Int64
        var linkCount: UInt32
    }

    /// Enumerate a directory fd via getattrlistbulk, invoking `body` per entry.
    /// `body` returns false to stop early. Fixed packed layout is guaranteed by
    /// FSOPT_PACK_INVAL_ATTRS; all multi-byte fields are read unaligned.
    private static func enumerate(fd: Int32, dirPath: String, _ body: (Entry) -> Bool) {
        // ABI-stable attribute bits (<sys/attr.h>), spelled as UInt32 to sidestep the
        // mixed Int32/UInt32 typing of the imported macros.
        let ATTR_CMN_RETURNED_ATTRS: UInt32 = 0x8000_0000
        let ATTR_CMN_NAME: UInt32 = 0x0000_0001
        let ATTR_CMN_OBJTYPE: UInt32 = 0x0000_0008
        let ATTR_CMN_FILEID: UInt32 = 0x0200_0000
        let ATTR_CMN_ERROR: UInt32 = 0x2000_0000
        let ATTR_FILE_LINKCOUNT: UInt32 = 0x0000_0001
        let ATTR_FILE_ALLOCSIZE: UInt32 = 0x0000_0004
        let ATTR_BIT_MAP_COUNT: UInt16 = 5
        let FSOPT_NOFOLLOW: UInt64 = 0x0000_0001
        let FSOPT_PACK_INVAL_ATTRS: UInt64 = 0x0000_0008

        var attrList = attrlist()
        attrList.bitmapcount = ATTR_BIT_MAP_COUNT
        attrList.commonattr = ATTR_CMN_RETURNED_ATTRS | ATTR_CMN_NAME
            | ATTR_CMN_OBJTYPE | ATTR_CMN_FILEID | ATTR_CMN_ERROR
        attrList.fileattr = ATTR_FILE_LINKCOUNT | ATTR_FILE_ALLOCSIZE

        let bufSize = 128 * 1024
        let buf = UnsafeMutableRawPointer.allocate(byteCount: bufSize, alignment: 8)
        defer { buf.deallocate() }
        let options = FSOPT_PACK_INVAL_ATTRS | FSOPT_NOFOLLOW

        while true {
            let count = getattrlistbulk(fd, &attrList, buf, bufSize, options)
            if count <= 0 { break }   // 0 = done, -1 = error
            var p = UnsafeRawPointer(buf)
            for _ in 0..<count {
                let len = p.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
                // Packed layout confirmed empirically (all reads unaligned):
                //   0  length (u32)
                //   4  RETURNED attribute_set_t (20): commonattr@4, fileattr@16
                //   24 ERROR (u32)
                //   28 NAME attrreference: dataoffset@28 (i32), length@32 (u32)
                //   36 OBJTYPE (u32)
                //   40 FILEID (u64)
                //   48 LINKCOUNT (u32)   — only when fileattr bits are set (files, not dirs)
                //   52 ALLOCSIZE (i64)   — "
                let returnedFile = p.loadUnaligned(fromByteOffset: 16, as: UInt32.self)
                let error = p.loadUnaligned(fromByteOffset: 24, as: UInt32.self)
                if error == 0 {
                    let nameOff = p.loadUnaligned(fromByteOffset: 28, as: Int32.self)
                    let objType = p.loadUnaligned(fromByteOffset: 36, as: UInt32.self)
                    let inode = p.loadUnaligned(fromByteOffset: 40, as: UInt64.self)
                    var linkCount: UInt32 = 1
                    var alloc: Int64 = 0
                    if returnedFile != 0 {   // file attributes present (regular files)
                        linkCount = p.loadUnaligned(fromByteOffset: 48, as: UInt32.self)
                        alloc = p.loadUnaligned(fromByteOffset: 52, as: Int64.self)
                    }
                    let name = String(cString: (p + 28 + Int(nameOff)).assumingMemoryBound(to: CChar.self))
                    if name != "." && name != ".." {
                        let full = (dirPath as NSString).appendingPathComponent(name)
                        if !body(Entry(name: name, path: full, type: objType, inode: inode,
                                       allocSize: max(0, alloc), linkCount: linkCount)) { return }
                    }
                }
                p = p.advanced(by: Int(len))
            }
        }
    }

    /// Allocated size of a single file (used when the root itself is a file).
    private static func fileAllocSize(_ path: String) -> Int64 {
        var st = stat()
        return lstat(path, &st) == 0 ? Int64(st.st_blocks) * 512 : 0
    }
}
