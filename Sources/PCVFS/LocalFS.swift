// SPDX-License-Identifier: Apache-2.0
// LocalFS.swift - The local-disk VirtualFileSystem (SPEC-006 §3).
//
// This is the reference VFS implementation and the first consumer of the
// conformance battery. It is intentionally self-contained (its own FS access) so
// PCVFS remains the single place that touches the file system directly.

import Foundation
import PCFoundation

/// Streams a local file's bytes in chunks (seekable via the backing fd).
public final class LocalReadStream: VFSReadStream, @unchecked Sendable {
    public typealias Element = Data

    private let fd: Int32
    private let chunkSize: Int
    private var closed = false

    init(fd: Int32, chunkSize: Int = 1 << 20) {
        self.fd = fd
        self.chunkSize = chunkSize
    }

    fileprivate func readChunk() -> Data? {
        guard !closed else { return nil }
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        let n = buffer.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, chunkSize) }
        guard n > 0 else { return nil }
        return Data(buffer[0..<n])
    }

    public func close() async throws {
        if !closed { Darwin.close(fd); closed = true }
    }

    deinit { if !closed { Darwin.close(fd) } }

    public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let stream: LocalReadStream
        public func next() async -> Data? { stream.readChunk() }
    }
}

/// Writes bytes to a local file via a backing fd.
public final class LocalWriteStream: VFSWriteStream, @unchecked Sendable {
    private let fd: Int32
    private var closed = false

    init(fd: Int32) { self.fd = fd }

    public func write(_ data: Data) async throws {
        var thrown: Error?
        data.withUnsafeBytes { raw in
            var off = 0
            let base = raw.baseAddress
            while off < data.count {
                let n = Darwin.write(fd, base?.advanced(by: off), data.count - off)
                if n <= 0 { thrown = VFSError.fromErrno(errno); return }
                off += n
            }
        }
        if let thrown { throw thrown }
    }

    public func close() async throws {
        if !closed { Darwin.close(fd); closed = true }
    }

    deinit { if !closed { Darwin.close(fd) } }
}

/// The local-disk file system.
public final class LocalFS: VirtualFileSystem, @unchecked Sendable {
    public let scheme = "file"
    public var capabilities: VFSCapabilities {
        [.read, .write, .rename, .watch, .execute, .seekableStreams]
    }

    public init() {}

    /// Build a `file` VFSPath from a local path.
    public static func path(_ local: String) -> VFSPath { VFSPath(filesystemId: "file", path: local) }

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        AsyncThrowingStream { continuation in
            let dirPath = dir.path
            do {
                // A directory too deep to name is listed through a descriptor for it, and each entry
                // is stat'ed relative to that same descriptor (F-383). Worth noting that this is not
                // only the way that works — it is also fewer syscalls, since the walk happens once
                // instead of being redone inside every lstat.
                if DeepPath.isDeep(dirPath) {
                    try Self.listDeep(dirPath, into: continuation)
                    return
                }
                // One syscall per *batch* rather than one per file. On a local disk the difference is
                // invisible; over SMB every lstat is a round trip, and the per-file walk below is the
                // whole reason a network folder takes seconds to open (measured cold over SMB: 3375
                // entries in 146 ms against 16.3 s, 13450 in 927 ms against 20.9 s).
                //
                // Returns false — rather than throwing — when the filesystem cannot answer in bulk, so
                // an unsupported volume simply takes the old path instead of failing to list at all.
                if try LocalBulkList.list(dirPath, into: continuation) { return }
                let names = try FileManager.default.contentsOfDirectory(atPath: dirPath)
                var batch: [VFSEntry] = []
                batch.reserveCapacity(min(names.count, 4096))
                for name in names {
                    let full = (dirPath as NSString).appendingPathComponent(name)
                    if let entry = Self.entry(atPath: full, name: name) { batch.append(entry) }
                    if batch.count >= 4096 {
                        continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: false))
                        batch.removeAll(keepingCapacity: true)
                    }
                }
                continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: true))
                continuation.finish()
            } catch {
                continuation.finish(throwing: VFSError.fromErrno(errno, path: dirPath))
            }
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        let name = (path.path as NSString).lastPathComponent
        if DeepPath.isDeep(path.path) {
            let entry = DeepPath.withParent(of: path.path) { fd, leaf in
                LocalStat.entry(leaf, relativeTo: fd)
            }
            guard let entry = entry ?? nil else { throw VFSError.notFound(path.path) }
            return entry
        }
        guard let entry = Self.entry(atPath: path.path, name: name) else {
            throw VFSError.notFound(path.path)
        }
        return entry
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        let fd = Self.openFile(path.path, flags: O_RDONLY, mode: 0)
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: path.path) }
        return LocalReadStream(fd: fd)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        var flags: Int32 = O_WRONLY
        if options.create { flags |= O_CREAT }
        if options.append { flags |= O_APPEND } else if options.truncate { flags |= O_TRUNC }
        let fd = Self.openFile(path.path, flags: flags, mode: 0o644)
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: path.path) }
        return LocalWriteStream(fd: fd)
    }

    public func mkdir(_ path: VFSPath) async throws {
        // Deep on purpose whenever the *result* would be deep, not only when the argument already is:
        // creating the last few components of a 1200-byte path is exactly the case FileManager cannot
        // do, and it is how such a tree comes into existence in the first place (F-383).
        if DeepPath.isDeep(path.path) {
            guard DeepPath.createDirectory(path.path) else {
                throw VFSError.fromErrno(errno, path: path.path)
            }
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: path.path, withIntermediateDirectories: true)
        } catch {
            throw VFSError.fromErrno(errno, path: path.path)
        }
    }

    public func delete(_ path: VFSPath) async throws {
        if DeepPath.isDeep(path.path) {
            let removed = DeepPath.withParent(of: path.path) { fd, leaf in
                DeepPath.removeRecursively(leaf, in: fd)
            }
            guard removed == true else { throw VFSError.fromErrno(errno, path: path.path) }
            return
        }
        do { try FileManager.default.removeItem(atPath: path.path) }
        catch { throw VFSError.fromErrno(errno, path: path.path) }
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        // `renameat` takes a descriptor per side, so either end being too deep to name is fine — and
        // either end *may* be, since a rename is how something usually arrives at that depth (F-383).
        if DeepPath.isDeep(from.path) || DeepPath.isDeep(to.path) {
            let ok = DeepPath.withParent(of: from.path) { fromFd, fromName in
                DeepPath.withParent(of: to.path) { toFd, toName in
                    renameat(fromFd, fromName, toFd, toName) == 0
                }
            }
            guard ok == true else { throw VFSError.fromErrno(errno, path: from.path) }
            return
        }
        let rc = from.path.withCString { f in to.path.withCString { t in Darwin.rename(f, t) } }
        if rc != 0 { throw VFSError.fromErrno(errno, path: from.path) }
    }

    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws {
        // BSD flags (e.g. user-immutable) block permission/owner changes, so clear
        // them first, apply everything else, then set the requested flags last.
        if attributes.bsdFlags != nil { _ = path.path.withCString { chflags($0, 0) } }

        var attrs: [FileAttributeKey: Any] = [:]
        if let mode = attributes.posixMode { attrs[.posixPermissions] = NSNumber(value: mode) }
        if let modified = attributes.modified { attrs[.modificationDate] = modified }
        if let owner = attributes.ownerName, !owner.isEmpty { attrs[.ownerAccountName] = owner }
        if let group = attributes.groupName, !group.isEmpty { attrs[.groupOwnerAccountName] = group }
        if !attrs.isEmpty {
            do { try FileManager.default.setAttributes(attrs, ofItemAtPath: path.path) }
            catch { throw VFSError.fromErrno(errno, path: path.path) }
        }

        if let flags = attributes.bsdFlags {
            let rc = path.path.withCString { chflags($0, flags) }
            if rc != 0 { throw VFSError.fromErrno(errno, path: path.path) }
        }
    }

    /// An FSEvents-backed stream of "something in this directory changed" (F-361).
    ///
    /// The event carries the directory, not the individual file: FSEvents coalesces a burst, and the
    /// consumer re-lists the directory anyway. `.modified` for the same reason — distinguishing added
    /// from removed would mean diffing the listing, which is exactly what the re-list does.
    ///
    /// Cancelling the stream's task stops the watcher; nothing else has to be remembered by the caller.
    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? {
        guard isDirectory(atPath: dir.path) else { return nil }
        return AsyncStream { continuation in
            let watcher = DirectoryWatcher(path: dir.path) {
                continuation.yield(VFSChangeEvent(path: dir, type: .modified))
            }
            watcher.start()
            continuation.onTermination = { _ in watcher.stop() }
        }
    }

    private func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        FileManager.default.fileExists(atPath: path.path) ? URL(fileURLWithPath: path.path) : nil
    }

    static func entry(atPath full: String, name: String) -> VFSEntry? {
        LocalStat.entry(atPath: full, name: name)
    }

    /// Kept as a name here because both call sites read better for it; the walk itself is shared.
    private static func openFile(_ path: String, flags: Int32, mode: mode_t) -> Int32 {
        DeepPath.open(path, flags, mode)
    }

    /// Lists a directory whose path no syscall will accept, through one descriptor for it (F-383).
    private static func listDeep(_ dirPath: String,
                                 into continuation: AsyncThrowingStream<VFSEntryBatch, Error>.Continuation) throws {
        let fd = DeepPath.openDirectory(dirPath)
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: dirPath) }
        guard let stream = fdopendir(fd) else {
            let failure = errno
            close(fd)
            throw VFSError.fromErrno(failure, path: dirPath)
        }
        defer { closedir(stream) }   // owns fd

        var batch: [VFSEntry] = []
        while let dirent = readdir(stream) {
            let name = withUnsafeBytes(of: dirent.pointee.d_name) { raw in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            if name == "." || name == ".." { continue }
            if let entry = LocalStat.entry(name, relativeTo: dirfd(stream)) { batch.append(entry) }
            if batch.count >= 4096 {
                continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: false))
                batch.removeAll(keepingCapacity: true)
            }
        }
        continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: true))
        continuation.finish()
    }
}

/// lstat-based entry construction, kept out of `LocalFS` so the C `stat` type is
/// not shadowed by the protocol's `stat(_:)` method.
private enum LocalStat {
    static func entry(atPath full: String, name: String) -> VFSEntry? {
        build(base: AT_FDCWD, at: full, name: name, resolvable: full)
    }

    /// The same for a file whose directory is too deep to name (F-383): every call goes through the
    /// directory's descriptor, so no syscall sees more than the entry's own name.
    ///
    /// `resolvable` is nil here — a Finder alias is resolved through a URL, which is a path API and
    /// therefore the one thing that cannot follow. Such a file lists as a plain file, the way a broken
    /// alias already did, rather than the listing failing over it.
    static func entry(_ name: String, relativeTo base: Int32) -> VFSEntry? {
        build(base: base, at: name, name: name, resolvable: nil)
    }

    /// `lstat(p)` is `fstatat(AT_FDCWD, p, …, AT_SYMLINK_NOFOLLOW)`, so the shallow path goes through
    /// the same code with the same meaning — the base descriptor is the only difference.
    private static func build(base: Int32, at path: String, name: String, resolvable: String?) -> VFSEntry? {
        var info = stat()
        guard fstatat(base, path, &info, AT_SYMLINK_NOFOLLOW) == 0 else { return nil }
        let fmt = info.st_mode & S_IFMT
        let isSymlink = fmt == S_IFLNK
        var kind: VFSEntry.Kind
        var aliasTarget: String?
        if isSymlink {
            var target = stat()
            let targetIsDir = fstatat(base, path, &target, 0) == 0 && (target.st_mode & S_IFMT) == S_IFDIR
            kind = targetIsDir ? .symlinkDir : .symlinkFile
        } else if fmt == S_IFDIR {
            kind = name.hasSuffix(".app") ? .appBundle : .directory
        } else {
            kind = .file
            // F-036: a macOS Finder alias is a regular file with the kIsAlias
            // Finder flag. Treat it like a symlink (arrow badge, follow on Enter).
            // The flag check is a cheap getattrlist; the (costly) target resolve
            // runs only for the rare files that are actually aliases.
            if hasAliasFlag(at: path, relativeTo: base), let resolvable, let resolved = resolveAlias(resolvable) {
                if resolved.isDir {
                    // An alias to an .app launches it; to a folder, navigates in.
                    kind = resolved.target.hasSuffix(".app") ? .appBundle : .symlinkDir
                } else {
                    kind = .symlinkFile
                }
                aliasTarget = resolved.target
            }
        }
        let ext = (kind == .directory || kind == .symlinkDir) ? "" : (name as NSString).pathExtension
        let modified = Date(timeIntervalSince1970: TimeInterval(info.st_mtimespec.tv_sec))
        let created = Date(timeIntervalSince1970: TimeInterval(info.st_ctimespec.tv_sec))
        return VFSEntry(
            name: name,
            ext: ext,
            kind: kind,
            size: Int64(info.st_size),
            modified: modified,
            created: created,
            posixMode: UInt16(info.st_mode & 0o7777),
            bsdFlags: UInt32(info.st_flags),
            // Two ways a file is hidden on macOS, and only one of them is a dot: `chflags hidden` sets
            // UF_HIDDEN, which is how the system hides /usr and /bin and how a user hides a file
            // without renaming it. The flag was already being read into `bsdFlags` (the attribute
            // column shows it as "h") and simply never consulted here, so such a file stayed visible
            // with "show hidden files" switched off (F-028).
            isHidden: name.hasPrefix(".") || (info.st_flags & UInt32(UF_HIDDEN)) != 0,
            linkTarget: isSymlink ? readlink(at: path, relativeTo: base) : aliasTarget
        )
    }

    /// True if `path`'s Finder info has the kIsAlias bit set (i.e. it is a macOS
    /// alias file), via a single getattrlist. Cheap enough to run per regular file.
    private static func hasAliasFlag(at path: String, relativeTo base: Int32) -> Bool {
        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        attrList.commonattr = attrgroup_t(ATTR_CMN_FNDRINFO)
        // Layout: 4-byte length prefix, then 32 bytes of Finder info; the file's
        // finderFlags are a big-endian UInt16 at offset 8 within the Finder info.
        var buffer = [UInt8](repeating: 0, count: 36)
        let rc = path.withCString { getattrlistat(base, $0, &attrList, &buffer, buffer.count, 0) }
        guard rc == 0 else { return false }
        let flags = (UInt16(buffer[4 + 8]) << 8) | UInt16(buffer[4 + 9])
        return (flags & 0x8000) != 0   // kIsAlias
    }

    /// Resolve a Finder alias file to its target (no UI, no mounting). Returns the
    /// target path and whether it is a directory, or nil for a broken alias.
    private static func resolveAlias(_ path: String) -> (isDir: Bool, target: String)? {
        let url = URL(fileURLWithPath: path)
        guard let resolved = try? URL(resolvingAliasFileAt: url, options: [.withoutUI, .withoutMounting])
        else { return nil }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)
        return (isDir.boolValue, resolved.path)
    }

    private static func readlink(at path: String, relativeTo base: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let n = path.withCString { Foundation.readlinkat(base, $0, &buffer, buffer.count - 1) }
        guard n >= 0 else { return nil }
        buffer[n] = 0
        return String(cString: buffer)
    }
}

/// Directory listing through `getattrlistbulk(2)`: the metadata for a whole batch of entries in one
/// syscall, instead of one `lstat` per name.
///
/// Locally this changes nothing anyone can feel — a stat on APFS is free. It exists for network
/// volumes, where every per-file stat is a round trip and the old walk is the whole reason opening a
/// folder takes seconds. Measured on a 514-entry SMB directory: **42 ms** here against **338 ms** for
/// `readdir` + `lstat`, and that with this pass running *first*, so it warmed the cache for the
/// comparison and the real gap is wider. On the same share a 1366-entry folder costs 0.098 s to read
/// the names and 19.6 s to stat them one by one.
///
/// Only the entries this can answer *completely* are built here. A directory, a symlink and a Finder
/// alias each still need the per-file path, for reasons given at `needsPerFilePath`. Files — nearly
/// all of any real listing — need nothing further, and they are where the time went.
///
/// Internal rather than private so `BulkListingTests` can assert that this path is the one answering:
/// without that, the differential test there would pass just as happily with every entry quietly
/// taking the per-file fallback, having tested nothing.
enum LocalBulkList {
    /// Yield size, matched to the per-file path so no caller can tell the two apart by batch shape.
    private static let batchLimit = 4096
    /// One allocation for the whole listing; a typical directory then needs a handful of syscalls.
    private static let bufferSize = 256 * 1024

    /// vnode types from `<sys/vnode.h>`. Spelled out rather than imported: the C header exposes these
    /// as an anonymous enum, and what it maps to in Swift is not something to rely on here.
    private static let vregular: UInt32 = 1
    private static let vdirectory: UInt32 = 2
    private static let vsymlink: UInt32 = 5

    /// `kIsAlias` in the Finder flags — the same bit `hasAliasFlag` reads, arriving here for free.
    private static let kIsAlias: UInt16 = 0x8000

    /// List `dirPath` in bulk. Returns false when the volume cannot answer this way and the caller
    /// should take the per-file path instead.
    ///
    /// The fallback is only ever offered before the first batch is handed over. Once entries have gone
    /// to the caller, re-listing by another route would repeat them, so a failure after that point is
    /// thrown rather than swallowed.
    static func list(_ dirPath: String,
                     into continuation: AsyncThrowingStream<VFSEntryBatch, Error>.Continuation) throws -> Bool {
        let fd = open(dirPath, O_RDONLY)
        guard fd >= 0 else { throw VFSError.fromErrno(errno, path: dirPath) }
        defer { close(fd) }

        var attrList = attrlist()
        attrList.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        // ATTR_CMN_RETURNED_ATTRS is not a nicety: a network volume answers some of these and not
        // others, and without being told which arrived, every field after a missing one is read from
        // the wrong offset. It also gives the honest gate for falling back per entry.
        // Built up one at a time: as a single `|` chain of the C constants this is an expression the
        // type checker gives up on ("unable to type-check in reasonable time").
        // `ATTR_CMN_RETURNED_ATTRS` is 0x80000000 and so imports as UInt32 while the rest import as
        // Int32; they cannot share one array literal.
        var wanted: attrgroup_t = ATTR_CMN_RETURNED_ATTRS
        for attribute in [ATTR_CMN_NAME, ATTR_CMN_OBJTYPE,
                          ATTR_CMN_MODTIME, ATTR_CMN_CHGTIME, ATTR_CMN_FNDRINFO,
                          ATTR_CMN_ACCESSMASK, ATTR_CMN_FLAGS] {
            wanted |= attrgroup_t(attribute)
        }
        attrList.commonattr = wanted
        attrList.fileattr = attrgroup_t(ATTR_FILE_DATALENGTH)

        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var batch: [VFSEntry] = []
        batch.reserveCapacity(batchLimit)
        var handedOver = false

        while true {
            let produced = buffer.withUnsafeMutableBytes { raw in
                getattrlistbulk(fd, &attrList, raw.baseAddress, raw.count, 0)
            }
            if produced == 0 { break }               // the whole directory has been read
            if produced < 0 {
                if handedOver { throw VFSError.fromErrno(errno, path: dirPath) }
                return false                          // unsupported here — let the caller walk it
            }

            buffer.withUnsafeBytes { raw in
                var record = raw.baseAddress!
                for _ in 0..<Int(produced) {
                    let length = record.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
                    if let parsed = parse(record: record) {
                        let entry = parsed.entry
                            ?? LocalStat.entry(atPath: (dirPath as NSString)
                                                          .appendingPathComponent(parsed.name),
                                               name: parsed.name)
                        if let entry { batch.append(entry) }
                    }
                    record = record.advanced(by: Int(length))
                }
            }

            while batch.count >= batchLimit {
                let chunk = Array(batch.prefix(batchLimit))
                batch.removeFirst(batchLimit)
                continuation.yield(VFSEntryBatch(entries: chunk, isLastBatch: false))
                handedOver = true
            }
        }

        continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: true))
        continuation.finish()
        return true
    }

    /// What one packed record amounts to: its name always, and the finished entry when this record
    /// alone is enough to build one.
    private struct Parsed {
        let name: String
        /// nil when the entry needs the per-file path after all — see `needsPerFilePath`.
        let entry: VFSEntry?
    }

    /// Unpack one record.
    ///
    /// **The order below is the wire order and is not free to rearrange.** The kernel packs the
    /// attributes sorted by their bit value, not in the order they were asked for, so FNDRINFO
    /// (`0x4000`) arrives *before* ACCESSMASK (`0x20000`) and FLAGS (`0x40000`). Reading it after them
    /// — which is the order they are named in most documentation — shifts every field that follows;
    /// it reads back as mode `0` on every file, and it verified as such before this was corrected.
    private static func parse(record: UnsafeRawPointer) -> Parsed? {
        var cursor = record.advanced(by: MemoryLayout<UInt32>.size)   // past the record length
        let returned = cursor.loadUnaligned(as: attribute_set_t.self)
        cursor = cursor.advanced(by: MemoryLayout<attribute_set_t>.size)

        func has(_ attribute: Int32) -> Bool { (returned.commonattr & attrgroup_t(attribute)) != 0 }
        func take<T>(_ type: T.Type) -> T {
            defer { cursor = cursor.advanced(by: MemoryLayout<T>.size) }
            return cursor.loadUnaligned(as: type)
        }

        // A record that cannot even name itself is not something the per-file path could rescue.
        guard has(ATTR_CMN_NAME) else { return nil }
        let nameRef = cursor.loadUnaligned(as: attrreference_t.self)
        let name = String(cString: cursor.advanced(by: Int(nameRef.attr_dataoffset))
                                         .assumingMemoryBound(to: CChar.self))
        cursor = cursor.advanced(by: MemoryLayout<attrreference_t>.size)

        let objectType = has(ATTR_CMN_OBJTYPE) ? take(UInt32.self) : 0
        let modified = has(ATTR_CMN_MODTIME) ? take(timespec.self) : nil
        let changed = has(ATTR_CMN_CHGTIME) ? take(timespec.self) : nil
        // Absent on SMB, and that is the right answer there rather than a gap: `hasAliasFlag` is a
        // getattrlist for the same attribute and fails on such a volume too, so a share has never had
        // aliases detected. Treating "not reported" as "not an alias" is what the old path did.
        var isAlias = false
        if has(ATTR_CMN_FNDRINFO) {
            let finderFlags = (UInt16(cursor.loadUnaligned(fromByteOffset: 8, as: UInt8.self)) << 8)
                            | UInt16(cursor.loadUnaligned(fromByteOffset: 9, as: UInt8.self))
            isAlias = (finderFlags & kIsAlias) != 0
            cursor = cursor.advanced(by: 32)
        }
        let accessMask = has(ATTR_CMN_ACCESSMASK) ? take(UInt32.self) : nil
        let bsdFlags = has(ATTR_CMN_FLAGS) ? take(UInt32.self) : nil
        let dataLength = (returned.fileattr & attrgroup_t(ATTR_FILE_DATALENGTH)) != 0
            ? take(off_t.self) : nil

        if needsPerFilePath(objectType: objectType, isAlias: isAlias) {
            return Parsed(name: name, entry: nil)
        }
        // Anything the volume declined to report also goes the long way, so an unusual filesystem
        // costs speed rather than correctness.
        guard let modified, let changed, let accessMask, let bsdFlags, let dataLength else {
            return Parsed(name: name, entry: nil)
        }

        return Parsed(name: name, entry: VFSEntry(
            name: name,
            ext: (name as NSString).pathExtension,
            kind: .file,
            size: Int64(dataLength),
            modified: Date(timeIntervalSince1970: TimeInterval(modified.tv_sec)),
            // `created` is built from CHGTIME because the per-file path builds it from `st_ctimespec`.
            // Reading it as the birth time would be defensible and would NOT match what the panel has
            // always shown, which is the thing that matters here.
            created: Date(timeIntervalSince1970: TimeInterval(changed.tv_sec)),
            posixMode: UInt16(accessMask & 0o7777),
            bsdFlags: bsdFlags,
            // Two ways a file is hidden, and only one of them is a dot — the same rule as the per-file
            // path (F-028).
            isHidden: name.hasPrefix(".") || (bsdFlags & UInt32(UF_HIDDEN)) != 0,
            linkTarget: nil
        ))
    }

    /// Whether this entry has to be built by the per-file path after all.
    ///
    /// Three cases, each because the bulk record genuinely lacks something:
    /// * a **directory** — `ATTR_FILE_DATALENGTH` is a file attribute and is not reported for one
    ///   (verified on both APFS and SMB). The panel draws `<DIR>` rather than that number, but sorting
    ///   by size orders directories among themselves with it, so dropping it would quietly reshuffle a
    ///   sorted panel;
    /// * a **symlink** — its kind depends on whether the *target* is a directory, which is a second
    ///   stat of a path this record does not describe, and it needs `readlink` besides;
    /// * a **Finder alias** — resolving one goes through a URL API, and the flag that identifies it is
    ///   the only part that arrives here.
    ///
    /// All three are a small minority of a real listing; plain files are the case that had to get
    /// cheaper, and they do.
    private static func needsPerFilePath(objectType: UInt32, isAlias: Bool) -> Bool {
        if objectType == vdirectory || objectType == vsymlink { return true }
        // Everything that is not a directory or a symlink is listed as a file, including the device
        // nodes and sockets the per-file path also calls files.
        return objectType == vregular && isAlias
    }
}
