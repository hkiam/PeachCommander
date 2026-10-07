// SPDX-License-Identifier: Apache-2.0
// FileSystemLowLevel.swift - lstat-based helpers shared by the engines
//
// Uses lstat semantics throughout so symbolic links are treated as links, never
// silently followed (a safety requirement for recursive copy/delete).

import Foundation
import PCFoundation

enum FSKind: Equatable {
    case file
    case directory
    case symlink
}

enum FSLowLevel {
    /// Kind of the item at `path` (does not follow symlinks). nil if it does not exist.
    static func kind(of path: String) -> FSKind? {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return nil }
        let fmt = st.st_mode & S_IFMT
        if fmt == S_IFLNK { return .symlink }
        if fmt == S_IFDIR { return .directory }
        return .file
    }

    static func exists(_ path: String) -> Bool {
        var st = stat()
        return lstatPath(path, &st) == 0
    }

    static func size(of path: String) -> Int64 {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return 0 }
        return Int64(st.st_size)
    }

    /// Size and allocated bytes in one `lstat`. The difference is what a placeholder still lacks —
    /// see `BulkEntry.allocated`.
    static func sizeAndAllocated(of path: String) -> (size: Int64, allocated: Int64) {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return (0, 0) }
        return (Int64(st.st_size), Int64(st.st_blocks) * 512)
    }

    static func facts(of path: String) -> FileFacts? {
        var st = stat()
        guard lstatPath(path, &st) == 0 else { return nil }
        let fmt = st.st_mode & S_IFMT
        let isDir = fmt == S_IFDIR
        let mtime = Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec)
                         + TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000)
        return FileFacts(path: path,
                         name: (path as NSString).lastPathComponent,
                         size: Int64(st.st_size),
                         modified: mtime,
                         isDirectory: isDir)
    }

    /// Same-device check for two paths (for rename vs copy+delete, clone eligibility).
    static func sameDevice(_ a: String, _ b: String) -> Bool {
        var sa = stat(), sb = stat()
        let ra = lstatPath(a, &sa)
        // b may not exist yet; stat its parent directory instead.
        let bParent = (b as NSString).deletingLastPathComponent
        let rb = lstatPath(bParent.isEmpty ? "/" : bParent, &sb)
        guard ra == 0, rb == 0 else { return false }
        return sa.st_dev == sb.st_dev
    }

    /// Whether two paths name the same file on disk — asked of the filesystem, not of the strings.
    ///
    /// String comparison is not enough and being nearly right here costs the file: macOS is normally
    /// case-insensitive, `/a//b` and `/a/b` are the same place, `.` and `..` resolve, and a hard link
    /// is genuinely the same bytes under a second name. The device and inode pair is what the
    /// filesystem itself considers identity, so that is what is compared.
    ///
    /// `lstat`, not `stat`: a symlink pointing at the source is a *different* file that happens to
    /// lead there, and copying onto it should replace the link, not be refused.
    ///
    /// False when either path does not exist — the ordinary case of copying somewhere new.
    static func isSameFile(_ a: String, _ b: String) -> Bool {
        var sa = stat(), sb = stat()
        guard lstatPath(a, &sa) == 0, lstatPath(b, &sb) == 0 else { return false }
        return sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino
    }

    static func readSymlink(_ path: String) -> String? {
        DeepPath.readSymlink(path)
    }

    /// One directory entry as `getattrlistbulk(2)` reported it. `kind` is nil when the volume did not
    /// say what the entry is; the caller then has to ask per file.
    struct BulkEntry {
        let name: String
        let kind: FSKind?
        let size: Int64
        /// Bytes on disk. Below `size` for a sparse file — and for the placeholders the Windows App
        /// fills in place while a coordinated read waits, which is how that wait can show progress.
        let allocated: Int64
    }

    /// The entries of `dir` with their kind and size, read in batches rather than one `lstat` each.
    ///
    /// For the copy's plan, which needs nothing but kind and size of every item in the tree. On a
    /// network volume each `lstat` is a round trip: `LocalBulkList` in PCVFS measured 19.6 s to stat a
    /// 1366-entry SMB folder one by one, against 0.098 s for its names, and the plan used to stat every
    /// file twice before the first byte moved. nil when the directory cannot be opened or the volume
    /// cannot answer this way; the caller walks it per file instead.
    static func bulkEntries(of dir: String) -> [BulkEntry]? {
        let fd = DeepPath.isDeep(dir) ? DeepPath.openDirectory(dir) : open(dir, O_RDONLY | O_DIRECTORY)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        // RETURNED_ATTRS so a volume that leaves one out does not shift every field after it.
        var wanted: attrgroup_t = ATTR_CMN_RETURNED_ATTRS
        wanted |= attrgroup_t(ATTR_CMN_NAME)
        wanted |= attrgroup_t(ATTR_CMN_OBJTYPE)
        attrList.commonattr = wanted
        attrList.fileattr = attrgroup_t(ATTR_FILE_DATALENGTH) | attrgroup_t(ATTR_FILE_DATAALLOCSIZE)

        var buffer = [UInt8](repeating: 0, count: 128 * 1024)
        var entries: [BulkEntry] = []
        while true {
            let produced = buffer.withUnsafeMutableBytes { raw in
                getattrlistbulk(fd, &attrList, raw.baseAddress, raw.count, 0)
            }
            if produced == 0 { return entries }
            // Nothing has gone to the caller yet, so walking it per file instead repeats nothing.
            if produced < 0 { return nil }
            buffer.withUnsafeBytes { raw in
                var record = raw.baseAddress!
                for _ in 0..<Int(produced) {
                    let length = record.loadUnaligned(as: UInt32.self)
                    if let entry = parseBulkRecord(record) { entries.append(entry) }
                    record = record.advanced(by: Int(length))
                }
            }
        }
    }

    /// vnode types from `<sys/vnode.h>`, spelled out for the reason `LocalBulkList` gives.
    private static let vdirectory: UInt32 = 2
    private static let vsymlink: UInt32 = 5

    /// Unpack one record. The wire order is the order of the attribute bits: the name reference, the
    /// object type, then — file attributes coming after common ones — the data length and the data
    /// allocation size.
    private static func parseBulkRecord(_ record: UnsafeRawPointer) -> BulkEntry? {
        var cursor = record.advanced(by: MemoryLayout<UInt32>.size)
        let returned = cursor.loadUnaligned(as: attribute_set_t.self)
        cursor = cursor.advanced(by: MemoryLayout<attribute_set_t>.size)

        guard (returned.commonattr & attrgroup_t(ATTR_CMN_NAME)) != 0 else { return nil }
        let nameRef = cursor.loadUnaligned(as: attrreference_t.self)
        let name = String(cString: cursor.advanced(by: Int(nameRef.attr_dataoffset))
                                         .assumingMemoryBound(to: CChar.self))
        cursor = cursor.advanced(by: MemoryLayout<attrreference_t>.size)

        var kind: FSKind?
        if (returned.commonattr & attrgroup_t(ATTR_CMN_OBJTYPE)) != 0 {
            switch cursor.loadUnaligned(as: UInt32.self) {
            case vdirectory: kind = .directory
            case vsymlink: kind = .symlink
            // Anything else — a fifo, a device — is what `kind(of:)` calls a file too.
            default: kind = .file
            }
            cursor = cursor.advanced(by: MemoryLayout<UInt32>.size)
        }
        var size: Int64 = 0
        if (returned.fileattr & attrgroup_t(ATTR_FILE_DATALENGTH)) != 0 {
            size = Int64(cursor.loadUnaligned(as: off_t.self))
            cursor = cursor.advanced(by: MemoryLayout<off_t>.size)
        } else if kind == .file {
            kind = nil   // a file whose size did not arrive: ask for it per file
        }
        // A volume that does not report it is taken as holding everything: nothing to wait for.
        var allocated = size
        if (returned.fileattr & attrgroup_t(ATTR_FILE_DATAALLOCSIZE)) != 0 {
            allocated = Int64(cursor.loadUnaligned(as: off_t.self))
        }
        return BulkEntry(name: name, kind: kind, size: size, allocated: allocated)
    }

    /// Routed through `DeepPath` so a path past PATH_MAX answers instead of reporting "does not
    /// exist" — which is what an lstat failure reads as to every caller above (F-383).
    private static func lstatPath(_ path: String, _ st: inout stat) -> Int32 {
        DeepPath.lstat(path, &st)
    }
}
