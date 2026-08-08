// SPDX-License-Identifier: Apache-2.0
// SyncEngine.swift - comparing and reconciling two sides of a synchronisation.
//
// Moved out of SyncWindowController, which lives in PCApp: no test bundle imports PCApp, so the
// scanner and the executor — the parts that decide what will be copied and then copy it — could not be
// checked at all. That is why F-193 carried a symbol as its only evidence.
//
// The window keeps the window's work (fields, table, progress); everything here is about two sides and
// what differs between them.

import Foundation
import PCArchive
import PCFoundation
import PCVFS

/// A live filesystem as one side of a synchronisation — an FTP or SFTP mount, or a plugin's (F-193).
///
/// Held as a `VirtualFileSystem` rather than as an FTP client, because everything a sync needs of a
/// side is in that protocol: list, stat, read, write, mkdir, delete. So this works for SFTP and for a
/// filesystem plugin without knowing anything about either, which is what the feature row asks for.
///
/// Compared by scheme and path: a filesystem object is a live connection and has no meaningful
/// equality, but "the same side" is a question about which mount and which folder.
public struct RemoteSyncSource: @unchecked Sendable, Equatable {
    public let fs: VirtualFileSystem
    public let path: String

    public init(fs: VirtualFileSystem, path: String) {
        self.fs = fs
        self.path = path
    }

    public static func == (a: RemoteSyncSource, b: RemoteSyncSource) -> Bool {
        a.fs.scheme == b.fs.scheme && a.path == b.path
    }

    /// The VFS path for `rel` under this side's base.
    func vpath(_ rel: String) -> VFSPath {
        let base = path.hasSuffix("/") ? String(path.dropLast()) : path
        return VFSPath(filesystemId: fs.scheme, path: rel.isEmpty ? (base.isEmpty ? "/" : base)
                                                                  : "\(base)/\(rel)")
    }
}

public enum SyncSide: Sendable, Equatable {
    case localDir(String)
    case zip(String)   // on-disk .zip path
    case remote(RemoteSyncSource)

    public var isZip: Bool { if case .zip = self { return true } else { return false } }
    public var isRemote: Bool { if case .remote = self { return true } else { return false } }
    public var path: String {
        switch self {
        case .localDir(let p), .zip(let p): return p
        case .remote(let r): return r.path
        }
    }
}

/// Recursive scanner producing SyncItems for two sides (local dirs and/or a zip).
public enum SyncScanner {
    private struct Meta { var size: Int64; var modified: Date; var isDir: Bool }

    public static func scan(left: SyncSide, right: SyncSide, mask: String,
                            withSubdirs: Bool, byContent: Bool,
                            ignoreHidden: Bool = false) async -> [SyncItem] {
        let wildcard = WildcardMask(mask.isEmpty ? "*.*" : mask)
        let leftMeta = await enumerate(left, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        let rightMeta = await enumerate(right, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        // Open each zip once for the content-comparison reads below.
        let leftZip = zipReader(left), rightZip = zipReader(right)

        var keys = Set(leftMeta.keys)
        keys.formUnion(rightMeta.keys)
        var items: [SyncItem] = []
        for key in keys.sorted() {
            let l = leftMeta[key], r = rightMeta[key]
            let isDir = (l?.isDir ?? false) || (r?.isDir ?? false)
            var contentEqual: Bool? = nil
            if byContent, !isDir, let l, let r {
                if l.size != r.size {
                    contentEqual = false
                } else if !left.isZip && !right.isZip {
                    contentEqual = filesEqual((left.path as NSString).appendingPathComponent(key),
                                              (right.path as NSString).appendingPathComponent(key))
                } else {
                    // Comparing by content across a remote side downloads both files. That is what
                    // ticking the box asks for, and it is why the option is not the default.
                    let leftData = await loadData(left, key: key, zip: leftZip)
                    let rightData = await loadData(right, key: key, zip: rightZip)
                    contentEqual = leftData == rightData
                }
            }
            items.append(SyncItem(relativePath: key, isDirectory: isDir,
                                  leftSize: l?.size, leftModified: l?.modified,
                                  rightSize: r?.size, rightModified: r?.modified,
                                  contentEqual: contentEqual))
        }
        return items
    }

    private static func enumerate(_ side: SyncSide, withSubdirs: Bool, wildcard: WildcardMask,
                                  ignoreHidden: Bool) async -> [String: Meta] {
        switch side {
        case .localDir(let dir): return walk(dir, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        case .zip(let url): return walkZip(url, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        case .remote(let r): return await walkRemote(r, withSubdirs: withSubdirs, wildcard: wildcard,
                                                     ignoreHidden: ignoreHidden)
        }
    }

    /// Enumerate a live filesystem the same way, one directory listing at a time (F-193).
    ///
    /// Depth-first over `fs.list`, which is what every VFS offers; no assumption that a server can
    /// produce a recursive listing, because most cannot. A listing that fails part-way returns what was
    /// gathered so far rather than nothing: half a comparison the user can see beats an empty window
    /// with no reason given — the failure is visible as the missing rows.
    private static func walkRemote(_ source: RemoteSyncSource, withSubdirs: Bool,
                                   wildcard: WildcardMask, ignoreHidden: Bool) async -> [String: Meta] {
        var out: [String: Meta] = [:]
        var queue: [String] = [""]
        while let prefix = queue.popLast() {
            do {
                for try await batch in source.fs.list(source.vpath(prefix)) {
                    for entry in batch.entries {
                        // The name comes off the wire; a component that is not a name would make the
                        // relative key — and with it a local path on the other side — mean something
                        // else. See PathContainment.
                        guard PathContainment.isSafeComponent(entry.name) else { continue }
                        let rel = prefix.isEmpty ? entry.name : "\(prefix)/\(entry.name)"
                        if ignoreHidden, isHiddenRel(rel) { continue }
                        let isDir = entry.kind == .directory || entry.kind == .appBundle
                                 || entry.kind == .package
                        if !isDir, !wildcard.matches(entry.name) { continue }
                        out[rel] = Meta(size: max(0, entry.size), modified: entry.modified, isDir: isDir)
                        if isDir, withSubdirs { queue.append(rel) }
                    }
                }
            } catch {
                return out
            }
        }
        return out
    }

    /// True when any path component is a dotfile — used to skip hidden items (F-192).
    private static func isHiddenRel(_ rel: String) -> Bool {
        rel.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    private static func zipReader(_ side: SyncSide) -> ZipReader? {
        if case .zip(let url) = side { return ZipReader(fileURL: URL(fileURLWithPath: url)) }
        return nil
    }

    /// Enumerate a zip's entries as sync metadata, keyed by POSIX relative path.
    private static func walkZip(_ url: String, withSubdirs: Bool, wildcard: WildcardMask, ignoreHidden: Bool) -> [String: Meta] {
        guard let reader = ZipReader(fileURL: URL(fileURLWithPath: url)) else { return [:] }
        var out: [String: Meta] = [:]
        for e in reader.entries {
            var rel = e.path
            while rel.hasSuffix("/") { rel.removeLast() }
            guard !rel.isEmpty else { continue }
            if !withSubdirs && rel.contains("/") { continue }
            if ignoreHidden, isHiddenRel(rel) { continue }   // F-192
            let leaf = (rel as NSString).lastPathComponent
            if !e.isDirectory, !wildcard.matches(leaf) { continue }
            out[rel] = Meta(size: e.uncompressedSize,
                            modified: e.modified ?? Date(timeIntervalSince1970: 0),
                            isDir: e.isDirectory)
        }
        return out
    }

    /// Load one entry's bytes from a side (for content comparison across a zip).
    private static func loadData(_ side: SyncSide, key: String, zip: ZipReader?) async -> Data? {
        switch side {
        case .localDir(let dir):
            return try? Data(contentsOf: URL(fileURLWithPath: (dir as NSString).appendingPathComponent(key)))
        case .zip:
            guard let zip, let e = zip.entries.first(where: { entryKey($0.path) == key }) else { return nil }
            return try? zip.data(for: e)
        case .remote(let r):
            return try? await readAll(r, key)
        }
    }

    /// The whole of one remote file.
    static func readAll(_ source: RemoteSyncSource, _ rel: String) async throws -> Data {
        let stream = try await source.fs.openRead(source.vpath(rel))
        var data = Data()
        // `as? Data`, as everywhere else that reads a VFS stream: the protocol gives Element a default
        // of Data but does not constrain it, so the concrete type is not known here.
        for try await element in stream {
            if let chunk = element as? Data { data.append(chunk) }
        }
        try? await stream.close()
        return data
    }

    /// A zip entry path reduced to the comparison key (no trailing slash).
    private static func entryKey(_ path: String) -> String {
        var s = path
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private static func walk(_ dir: String, withSubdirs: Bool, wildcard: WildcardMask, ignoreHidden: Bool) -> [String: Meta] {
        let fm = FileManager.default
        let base = (dir as NSString).standardizingPath
        var out: [String: Meta] = [:]
        // Use the path-based enumerator: it yields paths RELATIVE to `base`, so there
        // is no prefix to strip. (The URL enumerator reports resolved paths like
        // /private/tmp/… that don't match a /tmp/… base, silently dropping everything
        // under a symlinked root.)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        guard let en = fm.enumerator(atPath: base) else { return out }
        for case let rel as String in en {
            let full = (base as NSString).appendingPathComponent(rel)
            let vals = try? URL(fileURLWithPath: full).resourceValues(forKeys: Set(keys))
            let isDir = vals?.isDirectory ?? false
            // Top-level-only mode: include the directory itself but don't descend.
            if !withSubdirs && isDir { en.skipDescendants() }
            // Ignore hidden items (any dotfile component), F-192.
            if ignoreHidden, isHiddenRel(rel) { if isDir { en.skipDescendants() }; continue }
            let leaf = (rel as NSString).lastPathComponent
            if !isDir, !wildcard.matches(leaf) { continue }
            out[rel] = Meta(size: Int64(vals?.fileSize ?? 0),
                            modified: vals?.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                            isDir: isDir)
        }
        return out
    }

    /// Byte-compare two files in chunks (sizes already known equal by the caller).
    private static func filesEqual(_ a: String, _ b: String) -> Bool {
        guard let fa = FileHandle(forReadingAtPath: a), let fb = FileHandle(forReadingAtPath: b) else { return false }
        defer { try? fa.close(); try? fb.close() }
        let chunk = 1 << 16
        while true {
            let da = fa.readData(ofLength: chunk)
            let db = fb.readData(ofLength: chunk)
            if da != db { return false }
            if da.isEmpty { return true }
        }
    }
}

/// Executes classified sync actions against two sides (local dirs and/or a zip).
/// Copies into a zip are batched into a single ArchiveEditor.add rewrite; extraction
/// out of a zip writes files locally. Deleting inside a zip is not supported (F-193
/// MVP) — such actions are reported as skipped.
public enum SyncExecutor {
    public static func execute(_ results: [SyncResult], left: SyncSide, right: SyncSide,
                               toTrash: Bool) async -> [String] {
        let fm = FileManager.default
        var errors: [String] = []
        var zipAdds: [(localPath: String, arcPath: String)] = []   // local → zip, batched
        var zipDeletes: [String] = []                              // entries to delete from the zip (F-192)

        func local(_ side: SyncSide, _ rel: String) -> String {
            (side.path as NSString).appendingPathComponent(rel)
        }

        /// Copy one file/dir from `src` side to `dst` side.
        func copy(rel: String, isDir: Bool, src: SyncSide, dst: SyncSide) async {
            switch (src, dst) {
            case (.localDir, .localDir):
                copyLocalToLocal(local(src, rel), local(dst, rel), isDir: isDir)
            case (.localDir, .zip):
                if !isDir { zipAdds.append((localPath: local(src, rel), arcPath: rel)) }
                // Empty-dir entries are implicit via child arc paths; skip standalone dirs.
            case (.zip(let url), .localDir):
                extractFromZip(url, rel: rel, to: local(dst, rel), isDir: isDir)
            case (.localDir(let dir), .remote(let r)):
                await upload(from: (dir as NSString).appendingPathComponent(rel), rel: rel,
                             to: r, isDir: isDir)
            case (.remote(let r), .localDir(let dir)):
                await download(rel: rel, from: r, toLocalRoot: dir, isDir: isDir)
            case (.zip, .zip):
                errors.append("\(rel): archive-to-archive sync not supported")
            case (.remote, .remote):
                // Not a limitation worth hiding: the bytes would go down and up again through this
                // machine, and neither FTP nor SFTP is asked to move them directly (that is FXP, F-216).
                errors.append("\(rel): syncing one server to another is not supported")
            case (.zip, .remote), (.remote, .zip):
                errors.append("\(rel): syncing an archive with a server is not supported")
            }
        }

        /// Local file → server. Written through the VFS write stream in chunks, so a large file does
        /// not have to fit in memory.
        func upload(from srcPath: String, rel: String, to r: RemoteSyncSource, isDir: Bool) async {
            do {
                if isDir { try await r.fs.mkdir(r.vpath(rel)); return }
                // The parent must exist: a server does not create it on the way, and a sync of a new
                // subtree copies the folder before its files only because `creates` is ordered that way.
                let parent = (rel as NSString).deletingLastPathComponent
                if !parent.isEmpty { try? await r.fs.mkdir(r.vpath(parent)) }
                guard let handle = FileHandle(forReadingAtPath: srcPath) else {
                    errors.append("\(rel): cannot read"); return
                }
                defer { try? handle.close() }
                let stream = try await r.fs.openWrite(r.vpath(rel),
                                                      options: WriteOptions(create: true, truncate: true))
                while case let chunk = handle.readData(ofLength: 1 << 16), !chunk.isEmpty {
                    try await stream.write(chunk)
                }
                try await stream.close()
            } catch { errors.append("\(rel): \(error.localizedDescription)") }
        }

        /// Server → local file.
        ///
        /// The destination is built from a name the *server* chose, so it goes through the same
        /// containment rule as an archive member: a listing offering `..` must not put the write above
        /// the folder the user picked. The scanner already refuses such a component, and this refuses
        /// it again — the two are far enough apart that one of them will be edited alone one day.
        func download(rel: String, from r: RemoteSyncSource, toLocalRoot root: String, isDir: Bool) async {
            guard let dst = safeLocalPath(rel, under: root) else {
                errors.append("\(rel): refused — it would be written outside the folder"); return
            }
            do {
                if isDir {
                    try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
                    return
                }
                let data = try await SyncScanner.readAll(r, rel)
                try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                       withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: dst))
            } catch { errors.append("\(rel): \(error.localizedDescription)") }
        }

        /// `rel` under `root`, or nil if any component of it would leave `root`.
        func safeLocalPath(_ rel: String, under root: String) -> String? {
            var current = root
            for component in rel.split(separator: "/").map(String.init) {
                guard let next = PathContainment.childPath(component, under: current, root: root) else {
                    return nil
                }
                current = next
            }
            return current == root ? nil : current
        }

        func copyLocalToLocal(_ src: String, _ dst: String, isDir: Bool) {
            do {
                if isDir {
                    try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
                } else {
                    try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                           withIntermediateDirectories: true)
                    if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
                    try fm.copyItem(atPath: src, toPath: dst)
                }
            } catch { errors.append("\((src as NSString).lastPathComponent): \(error.localizedDescription)") }
        }

        func extractFromZip(_ url: String, rel: String, to dst: String, isDir: Bool) {
            do {
                if isDir {
                    try fm.createDirectory(atPath: dst, withIntermediateDirectories: true)
                    return
                }
                guard let reader = ZipReader(fileURL: URL(fileURLWithPath: url)),
                      let entry = reader.entries.first(where: {
                          var s = $0.path; while s.hasSuffix("/") { s.removeLast() }; return s == rel }) else {
                    errors.append("\(rel): not found in archive"); return
                }
                let data = try reader.data(for: entry)
                try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                       withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: dst))
            } catch { errors.append("\(rel): \(error.localizedDescription)") }
        }

        func remove(_ side: SyncSide, _ rel: String) async {
            if case .zip = side {                         // batched into one rewrite below (F-192)
                zipDeletes.append(rel); return
            }
            if case .remote(let r) = side {
                // `toTrash` cannot be honoured here: a server has no Trash, so this is permanent. The
                // dialog says so before the actions run rather than reporting it afterwards.
                do { try await r.fs.delete(r.vpath(rel)) }
                catch { errors.append("\(rel): \(error.localizedDescription)") }
                return
            }
            let path = local(side, rel)
            do {
                if toTrash { try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil) }
                else { try fm.removeItem(atPath: path) }
            } catch { errors.append("\((path as NSString).lastPathComponent): \(error.localizedDescription)") }
        }

        // Create dirs (shallowest first), then copy files, then delete (deepest first).
        let creates = results.filter { $0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
            .sorted { $0.item.relativePath.count < $1.item.relativePath.count }
        let fileCopies = results.filter { !$0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
        let deletes = results.filter { $0.action == .deleteRight || $0.action == .deleteLeft }
            .sorted { $0.item.relativePath.count > $1.item.relativePath.count }

        for r in creates + fileCopies {
            let rel = r.item.relativePath
            if r.action == .copyToRight { await copy(rel: rel, isDir: r.item.isDirectory, src: left, dst: right) }
            else { await copy(rel: rel, isDir: r.item.isDirectory, src: right, dst: left) }
        }
        // One rewrite for all files copied into the zip.
        if !zipAdds.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.add(to: URL(fileURLWithPath: zipURL), entries: zipAdds) }
            catch { errors.append("archive update failed: \(error.localizedDescription)") }
        }
        for r in deletes {
            await remove(r.action == .deleteRight ? right : left, r.item.relativePath)
        }
        // One rewrite for all entries deleted from the zip (F-192).
        if !zipDeletes.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.remove(from: URL(fileURLWithPath: zipURL), paths: zipDeletes) }
            catch { errors.append("archive delete failed: \(error.localizedDescription)") }
        }
        return errors
    }
}
