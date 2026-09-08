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

/// One thing that did not happen, and why.
///
/// A plain string used to carry both, joined by ": " — which meant the caller could count failures
/// and nothing else. The error log this feeds (`ErrorLogWindowController`) lists a path against a
/// reason, so the two travel separately rather than being split apart again at the far end.
public struct SyncError: Sendable, Equatable {
    /// The item's path relative to the two roots, or the empty string for a failure that belongs to
    /// the run rather than to one file (an archive rewrite, say).
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

/// How far a scan has got, for a caller that has a user waiting on it.
///
/// Two shapes rather than one number, because for most of a scan there is no denominator to divide
/// by: while a tree is being walked nobody knows how many entries it holds, so the honest report is
/// the count so far. Only the comparison afterwards knows its total.
public enum SyncScanPhase: Sendable, Equatable {
    /// Walking the left tree; `count` items found so far.
    case scanningLeft(count: Int)
    /// Walking the right tree; `count` items found so far.
    case scanningRight(count: Int)
    /// Comparing the matched paths — this is the phase that reads file contents.
    case comparing(done: Int, total: Int)
}

/// Recursive scanner producing SyncItems for two sides (local dirs and/or a zip).
public enum SyncScanner {
    private struct Meta { var size: Int64; var modified: Date; var isDir: Bool }

    /// How many entries pass before the walk reports again. A scan of a large tree finds thousands
    /// of entries in the time it takes to draw one frame, and a report per entry would spend the
    /// scan's time hopping to the main actor instead of scanning.
    private static let progressStride = 250

    /// Compare two sides and return one `SyncItem` per matched relative path.
    ///
    /// - Parameter progress: Called as the scan advances, off the main actor — a caller that shows
    ///   it must hop. Omitted, the scan runs exactly as it did before.
    ///
    /// Honours `Task.isCancelled` at the same points it reports progress, so a comparison of a large
    /// tree can be called off; a cancelled scan returns what it had rather than throwing, and the
    /// caller is expected to check `Task.isCancelled` before believing the result.
    public static func scan(left: SyncSide, right: SyncSide, mask: String,
                            withSubdirs: Bool, byContent: Bool,
                            ignoreHidden: Bool = false, caseSensitive: Bool = true,
                            progress: (@Sendable (SyncScanPhase) -> Void)? = nil) async -> [SyncItem] {
        let wildcard = WildcardMask(mask.isEmpty ? "*.*" : mask)
        let leftMeta = await enumerate(left, withSubdirs: withSubdirs, wildcard: wildcard,
                                       ignoreHidden: ignoreHidden,
                                       found: progress.map { p in { p(.scanningLeft(count: $0)) } })
        if Task.isCancelled { return [] }
        let rightMeta = await enumerate(right, withSubdirs: withSubdirs, wildcard: wildcard,
                                        ignoreHidden: ignoreHidden,
                                        found: progress.map { p in { p(.scanningRight(count: $0)) } })
        if Task.isCancelled { return [] }
        // Open each zip once for the content-comparison reads below.
        let leftZip = zipReader(left), rightZip = zipReader(right)

        var items: [SyncItem] = []
        let sorted = pair(leftMeta, rightMeta, caseSensitive: caseSensitive)
        progress?(.comparing(done: 0, total: sorted.count))
        for (index, entry) in sorted.enumerated() {
            if index > 0, index % progressStride == 0 {
                if Task.isCancelled { return items }
                progress?(.comparing(done: index, total: sorted.count))
            }
            let key = entry.key
            let l = entry.left?.meta, r = entry.right?.meta
            let isDir = (l?.isDir ?? false) || (r?.isDir ?? false)
            var contentEqual: Bool? = nil
            if byContent, !isDir, let l, let r {
                if l.size != r.size {
                    contentEqual = false
                } else if case .localDir = left, case .localDir = right {
                    // Two local folders, and only then: this reads the two paths as files on this
                    // machine. The test used to be `!isZip && !isZip`, which let a *server* side in —
                    // and `SyncSide.path` is the path on the server, so this opened `/srv/backup/…`
                    // locally, found nothing, and reported every same-sized file as different. Worse
                    // when such a path did exist here: it compared the wrong file and said nothing.
                    // Each side's own spelling: under case-insensitive matching the two names can
                    // differ in case, and reading the left one out of the right folder finds nothing.
                    contentEqual = filesEqual((left.path as NSString).appendingPathComponent(entry.left?.key ?? key),
                                              (right.path as NSString).appendingPathComponent(entry.right?.key ?? key))
                } else {
                    // Comparing by content across a remote side downloads both files. That is what
                    // ticking the box asks for, and it is why the option is not the default.
                    let leftData = await loadData(left, key: entry.left?.key ?? key, zip: leftZip)
                    let rightData = await loadData(right, key: entry.right?.key ?? key, zip: rightZip)
                    contentEqual = leftData == rightData
                }
            }
            items.append(SyncItem(relativePath: key, isDirectory: isDir,
                                  leftSize: l?.size, leftModified: l?.modified,
                                  rightSize: r?.size, rightModified: r?.modified,
                                  contentEqual: contentEqual))
        }
        progress?(.comparing(done: sorted.count, total: sorted.count))
        return items
    }

    /// One relative path as it appears on each side, with the metadata found there.
    ///
    /// Two spellings rather than one, because case-insensitive matching pairs `README.md` on one side
    /// with `readme.md` on the other, and every read afterwards has to use the name that side
    /// actually has. `key` is what the row is called and what a copy is written as: the left side's
    /// spelling when it is there, otherwise the right's.
    private struct PairedEntry {
        let key: String
        let left: (key: String, meta: Meta)?
        let right: (key: String, meta: Meta)?
    }

    /// Match the two sides' entries up, by exact name or folded case.
    ///
    /// `SyncOptions.caseSensitive` was declared, persisted in presets, and never read: matching was
    /// always exact. On a case-insensitive volume — which is what macOS formats by default — a pair
    /// differing only in case therefore showed up as two rows, each "only on one side", and syncing
    /// them copied each onto the other: on such a volume that is the same file twice.
    private static func pair(_ leftMeta: [String: Meta], _ rightMeta: [String: Meta],
                             caseSensitive: Bool) -> [PairedEntry] {
        if caseSensitive {
            var keys = Set(leftMeta.keys)
            keys.formUnion(rightMeta.keys)
            return keys.sorted().map { key in
                PairedEntry(key: key,
                            left: leftMeta[key].map { (key, $0) },
                            right: rightMeta[key].map { (key, $0) })
            }
        }
        var byFold: [String: PairedEntry] = [:]
        for (key, meta) in leftMeta {
            byFold[key.lowercased()] = PairedEntry(key: key, left: (key, meta), right: nil)
        }
        for (key, meta) in rightMeta {
            let fold = key.lowercased()
            if let existing = byFold[fold] {
                byFold[fold] = PairedEntry(key: existing.key, left: existing.left, right: (key, meta))
            } else {
                byFold[fold] = PairedEntry(key: key, left: nil, right: (key, meta))
            }
        }
        return byFold.values.sorted { $0.key < $1.key }
    }

    private static func enumerate(_ side: SyncSide, withSubdirs: Bool, wildcard: WildcardMask,
                                  ignoreHidden: Bool,
                                  found: (@Sendable (Int) -> Void)? = nil) async -> [String: Meta] {
        switch side {
        case .localDir(let dir): return walk(dir, withSubdirs: withSubdirs, wildcard: wildcard,
                                             ignoreHidden: ignoreHidden, found: found)
        case .zip(let url): return walkZip(url, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        case .remote(let r): return await walkRemote(r, withSubdirs: withSubdirs, wildcard: wildcard,
                                                     ignoreHidden: ignoreHidden, found: found)
        }
    }

    /// Enumerate a live filesystem the same way, one directory listing at a time (F-193).
    ///
    /// Depth-first over `fs.list`, which is what every VFS offers; no assumption that a server can
    /// produce a recursive listing, because most cannot. A listing that fails part-way returns what was
    /// gathered so far rather than nothing: half a comparison the user can see beats an empty window
    /// with no reason given — the failure is visible as the missing rows.
    private static func walkRemote(_ source: RemoteSyncSource, withSubdirs: Bool,
                                   wildcard: WildcardMask, ignoreHidden: Bool,
                                   found: (@Sendable (Int) -> Void)? = nil) async -> [String: Meta] {
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
                    // Reported per listing batch rather than per stride: a server hands out entries
                    // in batches with a round trip between them, so the batch is the unit that takes
                    // time here — and this is the walk a user waits on longest.
                    found?(out.count)
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

    private static func walk(_ dir: String, withSubdirs: Bool, wildcard: WildcardMask,
                             ignoreHidden: Bool, found: (@Sendable (Int) -> Void)? = nil) -> [String: Meta] {
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
            if out.count % progressStride == 0 {
                if Task.isCancelled { return out }
                found?(out.count)
            }
        }
        found?(out.count)
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
    /// Whether carrying `results` out would delete something that cannot be taken back.
    ///
    /// Local deletions go to the Trash (`toTrash`), so they can be undone by the person who did
    /// them. A server has no Trash and `remove` says so in a comment — "the dialog says so before
    /// the actions run" — which was not true of any dialog: the confirmation showed a count and
    /// nothing else. This is the question that sentence assumed someone was asking.
    public static func deletesPermanently(_ results: [SyncResult],
                                          left: SyncSide, right: SyncSide) -> Bool {
        results.contains { r in
            (r.action == .deleteRight && right.isRemote) || (r.action == .deleteLeft && left.isRemote)
        }
    }

    /// Carry out `results`, and report what did not work.
    ///
    /// - Parameter progress: Called before each item with (done, total), off the main actor.
    ///
    /// Honours `Task.isCancelled` between items, so a long run can be called off; what has already
    /// been copied stays copied — each item is finished before the next is started, so stopping
    /// leaves a partial sync rather than a partial file.
    public static func execute(_ results: [SyncResult], left: SyncSide, right: SyncSide,
                               toTrash: Bool,
                               progress: (@Sendable (Int, Int) -> Void)? = nil) async -> [SyncError] {
        let fm = FileManager.default
        var errors: [SyncError] = []
        var zipAdds: [(localPath: String, arcPath: String)] = []   // local → zip, batched
        var zipDeletes: [String] = []                              // entries to delete from the zip (F-192)

        /// Every path this plan intends to delete. `holdsUncomparedContent` asks the zip whether an
        /// entry beneath a folder is in here; if it is not, the comparison never saw it.
        let deletedKeys = Set(results.filter { $0.action == .deleteRight || $0.action == .deleteLeft }
                                     .map(\.item.relativePath))
        /// The archive's entry list, read once and only when it can be needed: re-parsing the zip
        /// for every stray folder would turn one rewrite into a walk per directory.
        let zipEntryKeys: [String] = {
            guard left.isZip || right.isZip,
                  results.contains(where: { $0.item.isDirectory && ($0.action == .deleteRight || $0.action == .deleteLeft) })
            else { return [] }
            let archive = left.isZip ? left.path : right.path
            guard let reader = ZipReader(fileURL: URL(fileURLWithPath: archive)) else { return [] }
            return reader.entries.map { entry in
                var key = entry.path
                while key.hasSuffix("/") { key.removeLast() }
                return key
            }
        }()

        func local(_ side: SyncSide, _ rel: String) -> String {
            (side.path as NSString).appendingPathComponent(rel)
        }

        /// Copy one file/dir from `src` side to `dst` side.
        ///
        /// `modified` is the source's own timestamp, carried across with the bytes. Without it the
        /// destination is stamped with the moment of the write, and the *next* comparison — which
        /// matches on size and date unless told otherwise — sees a file that is newer on the far
        /// side and offers to copy it back. Measured before this was passed: a sync onto a server
        /// answered `copyToLeft` for the file it had just uploaded, every run, for ever.
        func copy(rel: String, isDir: Bool, src: SyncSide, dst: SyncSide, modified: Date?) async {
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
                             to: r, isDir: isDir, modified: modified)
            case (.remote(let r), .localDir(let dir)):
                await download(rel: rel, from: r, toLocalRoot: dir, isDir: isDir, modified: modified)
            case (.zip, .zip):
                errors.append(SyncError(path: rel, message: "archive-to-archive sync not supported"))
            case (.remote, .remote):
                // Not a limitation worth hiding: the bytes would go down and up again through this
                // machine, and neither FTP nor SFTP is asked to move them directly (that is FXP, F-216).
                errors.append(SyncError(path: rel, message: "syncing one server to another is not supported"))
            case (.zip, .remote), (.remote, .zip):
                errors.append(SyncError(path: rel, message: "syncing an archive with a server is not supported"))
            }
        }

        /// Local file → server. Written through the VFS write stream in chunks, so a large file does
        /// not have to fit in memory.
        func upload(from srcPath: String, rel: String, to r: RemoteSyncSource, isDir: Bool,
                    modified: Date?) async {
            do {
                if isDir { try await r.fs.mkdir(r.vpath(rel)); return }
                // The parent must exist: a server does not create it on the way, and a sync of a new
                // subtree copies the folder before its files only because `creates` is ordered that way.
                let parent = (rel as NSString).deletingLastPathComponent
                if !parent.isEmpty { try? await r.fs.mkdir(r.vpath(parent)) }
                guard let handle = FileHandle(forReadingAtPath: srcPath) else {
                    errors.append(SyncError(path: rel, message: "cannot read")); return
                }
                defer { try? handle.close() }
                let stream = try await r.fs.openWrite(r.vpath(rel),
                                                      options: WriteOptions(create: true, truncate: true))
                while case let chunk = handle.readData(ofLength: 1 << 16), !chunk.isEmpty {
                    try await stream.write(chunk)
                }
                try await stream.close()
                // Best effort, and deliberately not an error when it fails: SFTP can set a
                // timestamp, plain FTP has no standard way to and refuses (see FTPFileSystem), and a
                // protocol that cannot carry the date must not turn an upload that did arrive into a
                // reported failure. On such a server the date is still the time of the write, so
                // "Ignore date" or "By content" remains the way to sync it without churn.
                if let modified {
                    try? await r.fs.setAttributes(r.vpath(rel), attributes: VFSAttributes(modified: modified))
                }
            } catch { errors.append(SyncError(path: rel, message: error.localizedDescription)) }
        }

        /// Server → local file.
        ///
        /// The destination is built from a name the *server* chose, so it goes through the same
        /// containment rule as an archive member: a listing offering `..` must not put the write above
        /// the folder the user picked. The scanner already refuses such a component, and this refuses
        /// it again — the two are far enough apart that one of them will be edited alone one day.
        func download(rel: String, from r: RemoteSyncSource, toLocalRoot root: String, isDir: Bool,
                      modified: Date?) async {
            guard let dst = safeLocalPath(rel, under: root) else {
                errors.append(SyncError(path: rel, message: "refused — it would be written outside the folder")); return
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
                // The other half of the same rule: a downloaded file stamped "now" is newer than the
                // server's copy, and the next run offers to upload it straight back.
                if let modified {
                    try? fm.setAttributes([.modificationDate: modified], ofItemAtPath: dst)
                }
            } catch { errors.append(SyncError(path: rel, message: error.localizedDescription)) }
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
            } catch { errors.append(SyncError(path: (src as NSString).lastPathComponent, message: error.localizedDescription)) }
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
                    errors.append(SyncError(path: rel, message: "not found in archive")); return
                }
                let data = try reader.data(for: entry)
                try fm.createDirectory(atPath: (dst as NSString).deletingLastPathComponent,
                                       withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: dst))
                // The same rule as for a server: the extracted file kept the moment of extraction,
                // which is newer than the entry it came from, so the next comparison offered to put
                // it straight back into the archive. Masked until now because the window forces
                // "ignore date" for a zip side — but the engine is used without that window too.
                if let modified = entry.modified {
                    try? fm.setAttributes([.modificationDate: modified], ofItemAtPath: dst)
                }
            } catch { errors.append(SyncError(path: rel, message: error.localizedDescription)) }
        }

        /// Does this directory still hold something the comparison never looked at?
        ///
        /// Deleting a directory is one call and that call is recursive — `fm.trashItem` on a folder
        /// takes everything under it, and `ArchiveEditor.remove` drops every entry beneath the path
        /// it is given. Whatever the mask or `ignoreHidden` held back is under that folder and was
        /// never a row in this plan, so it went too. Measured before this guard existed: mirror mode,
        /// a right-only folder, mask `*.txt`, and the `.jpg` inside it ended up in the Trash — after
        /// the window had shown the user that the file was not part of the comparison.
        ///
        /// A mirror may delete what it compared. It may not delete what it declined to look at.
        ///
        /// For a local or a remote side the question is simply whether the folder is empty *now*:
        /// deletes run deepest-first (`relativePath.count` descending, which is a valid topological
        /// order because a child's path is always longer than its ancestor's), so by the time a
        /// directory is reached everything about it that was compared is already gone, and what
        /// remains is what was held back. A zip is decided differently because its deletions are
        /// batched and nothing has been removed from it yet — there the archive's own entry list is
        /// compared against the plan.
        func holdsUncomparedContent(_ side: SyncSide, _ rel: String) async -> Bool {
            switch side {
            case .localDir:
                guard let names = try? fm.contentsOfDirectory(atPath: local(side, rel)) else {
                    return false      // unreadable: the delete below will fail on its own terms
                }
                return !names.isEmpty
            case .remote(let r):
                do {
                    for try await batch in r.fs.list(r.vpath(rel)) {
                        if batch.entries.contains(where: { $0.name != "." && $0.name != ".." }) { return true }
                    }
                    return false
                } catch { return false }
            case .zip:
                let prefix = rel + "/"
                return zipEntryKeys.contains { $0.hasPrefix(prefix) && !deletedKeys.contains($0) }
            }
        }

        func remove(_ side: SyncSide, _ rel: String, isDir: Bool) async {
            if isDir, await holdsUncomparedContent(side, rel) {
                errors.append(SyncError(path: rel,
                                        message: "kept: it holds something this comparison did not include"))
                return
            }
            if case .zip = side {                         // batched into one rewrite below (F-192)
                zipDeletes.append(rel); return
            }
            if case .remote(let r) = side {
                // `toTrash` cannot be honoured here: a server has no Trash, so this is permanent. The
                // dialog says so before the actions run rather than reporting it afterwards.
                do { try await r.fs.delete(r.vpath(rel)) }
                catch { errors.append(SyncError(path: rel, message: error.localizedDescription)) }
                return
            }
            let path = local(side, rel)
            do {
                if toTrash { try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil) }
                else { try fm.removeItem(atPath: path) }
            } catch { errors.append(SyncError(path: (path as NSString).lastPathComponent, message: error.localizedDescription)) }
        }

        // Create dirs (shallowest first), then copy files, then delete (deepest first).
        let creates = results.filter { $0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
            .sorted { $0.item.relativePath.count < $1.item.relativePath.count }
        let fileCopies = results.filter { !$0.item.isDirectory && ($0.action == .copyToRight || $0.action == .copyToLeft) }
        let deletes = results.filter { $0.action == .deleteRight || $0.action == .deleteLeft }
            .sorted { $0.item.relativePath.count > $1.item.relativePath.count }

        let ordered = creates + fileCopies
        let total = ordered.count + deletes.count
        var done = 0
        for r in ordered {
            if Task.isCancelled { return errors }
            progress?(done, total)
            done += 1
            let rel = r.item.relativePath
            // The timestamp travels with the direction: whichever side is being read from is the one
            // whose date the copy should end up carrying.
            if r.action == .copyToRight {
                await copy(rel: rel, isDir: r.item.isDirectory, src: left, dst: right,
                           modified: r.item.leftModified)
            } else {
                await copy(rel: rel, isDir: r.item.isDirectory, src: right, dst: left,
                           modified: r.item.rightModified)
            }
        }
        // One rewrite for all files copied into the zip.
        if !zipAdds.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.add(to: URL(fileURLWithPath: zipURL), entries: zipAdds) }
            catch { errors.append(SyncError(path: "", message: "archive update failed: \(error.localizedDescription)")) }
        }
        for r in deletes {
            if Task.isCancelled { return errors }
            progress?(done, total)
            done += 1
            await remove(r.action == .deleteRight ? right : left, r.item.relativePath,
                         isDir: r.item.isDirectory)
        }
        progress?(total, total)
        // One rewrite for all entries deleted from the zip (F-192).
        if !zipDeletes.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.remove(from: URL(fileURLWithPath: zipURL), paths: zipDeletes) }
            catch { errors.append(SyncError(path: "", message: "archive delete failed: \(error.localizedDescription)")) }
        }
        return errors
    }
}
