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
/// What a scan found, and how much of the two trees it deliberately did not look at.
///
/// `heldBack` counts only what the *filter* excluded — distinct relative paths, so an excluded
/// folder counts once rather than once per file inside it. The file mask's own exclusions are not in
/// it: the mask is on screen and always has been, while a filter lives behind a button and a
/// forgotten one is how a backup ends up incomplete without anybody being told.
public struct SyncScanOutcome: Sendable {
    public let items: [SyncItem]
    public let heldBack: Int
    /// What each side's walk was actually able to see. A comparison decides what to *copy* from the
    /// entries; deciding what to *delete* needs this as well, because a deletion is derived from
    /// something being **absent**, and absence is only evidence if the walk would have found it.
    public let leftScope: SyncSideScope
    public let rightScope: SyncSideScope

    public init(items: [SyncItem], heldBack: Int,
                leftScope: SyncSideScope = .unknown, rightScope: SyncSideScope = .unknown) {
        self.items = items
        self.heldBack = heldBack
        self.leftScope = leftScope
        self.rightScope = rightScope
    }
}


public enum SyncScanner {
    private struct Meta { var size: Int64; var modified: Date; var isDir: Bool }

    /// What one side's walk found, and what it left behind.
    private struct Walk {
        var entries: [String: Meta] = [:]
        /// The walk could be started. False for an enumerator that answered nil, an archive that
        /// would not open, and a remote root whose listing failed — three shapes of the same thing,
        /// each of which used to return an empty result indistinguishable from an empty folder.
        var rootEnumerable = true
        /// A plain listing of the root found something, asked independently of the walk.
        var rootObservedNonEmpty = false
        /// Every entry the walk was handed, whether or not a rule kept it.
        var visited = 0

        var scope: SyncSideScope {
            SyncSideScope(rootEnumerable: rootEnumerable, rootObservedNonEmpty: rootObservedNonEmpty,
                          entriesFound: entries.count, entriesVisited: visited,
                          filtered: filtered, incompleteDirs: incompleteDirs)
        }
        /// Paths the filter excluded. Reported to the user as a count.
        var filtered: Set<String> = []
        /// Folders that still hold something this walk did not record — by *any* rule, the mask and
        /// "ignore hidden" included. This is the set a mirror needs, because what makes deleting a
        /// folder unsafe is that something is in it, not which rule kept it out of the comparison.
        var incompleteDirs: Set<String> = []

        /// Record that `rel` was left out, and that every folder above it is therefore incomplete.
        mutating func heldBack(_ rel: String, byFilter: Bool) {
            if byFilter { filtered.insert(rel) }
            var prefix = ""
            for part in rel.split(separator: "/", omittingEmptySubsequences: true).dropLast() {
                prefix = prefix.isEmpty ? String(part) : prefix + "/" + part
                incompleteDirs.insert(prefix)
            }
        }

        /// Record a folder that was recorded but never looked inside — "without subdirs", or a
        /// listing that failed. Nothing under it was compared, so a mirror must leave it alone.
        mutating func notDescended(_ rel: String) { incompleteDirs.insert(rel) }
    }

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
    /// How the two sides' roots relate on disk.
    ///
    /// Asked here rather than in the guard because it needs the filesystem, and by device and inode
    /// rather than by string: two different paths reach the same folder through a symlink, a bind
    /// mount, or `/tmp` against `/private/tmp` — and a comparison of a folder against itself has no
    /// meaning, while a mirror of one would delete everything it just decided to keep. `CopyEngine`
    /// refuses the same shape for a single copy; the sync path had nothing.
    ///
    /// A zip or a server side is always `.distinct`: an archive is a file, not a directory, and a
    /// remote path belongs to another machine's namespace, so neither can *be* the local folder.
    public static func rootRelation(left: SyncSide, right: SyncSide) -> SyncPlanGuard.RootRelation {
        guard case .localDir(let l) = left, case .localDir(let r) = right else { return .distinct }
        if FSLowLevel.isSameFile(l, r) { return .same }
        let lu = URL(fileURLWithPath: l), ru = URL(fileURLWithPath: r)
        if PathContainment.isInside(lu, root: ru) || PathContainment.isInside(ru, root: lu) {
            return .nested
        }
        return .distinct
    }

    /// The items alone, for the callers that want nothing else. One line over `scanDetailed`, so
    /// there is one implementation and the twenty-odd existing call sites did not have to change.
    public static func scan(left: SyncSide, right: SyncSide, mask: String,
                            withSubdirs: Bool, byContent: Bool,
                            ignoreHidden: Bool = false, caseSensitive: Bool = true,
                            filter: SyncFilter = SyncFilter(),
                            progress: (@Sendable (SyncScanPhase) -> Void)? = nil) async -> [SyncItem] {
        await scanDetailed(left: left, right: right, mask: mask, withSubdirs: withSubdirs,
                           byContent: byContent, ignoreHidden: ignoreHidden,
                           caseSensitive: caseSensitive, filter: filter, progress: progress).items
    }

    /// The same scan, plus how much the filter held back.
    ///
    /// - Parameter filter: Name and path rules act inside each walk, where they are safe because the
    ///   relative path is the same on both sides. Size and date rules act on the pair below, where
    ///   they have to: per side, "nothing over 2 GB" would drop the large half of a mismatched pair,
    ///   the pair would read as one-sided, and the small file would be copied over the large one.
    /// - Parameter now: What "modified within the last N days" is measured against. A parameter so a
    ///   test can put the run at a chosen moment; a preset stores the window, not a date.
    public static func scanDetailed(left: SyncSide, right: SyncSide, mask: String,
                                    withSubdirs: Bool, byContent: Bool,
                                    ignoreHidden: Bool = false, caseSensitive: Bool = true,
                                    filter: SyncFilter = SyncFilter(), now: Date = Date(),
                                    progress: (@Sendable (SyncScanPhase) -> Void)? = nil) async -> SyncScanOutcome {
        let wildcard = WildcardMask(mask.isEmpty ? "*.*" : mask)
        let exclusions = filter.exclusions()
        let leftWalk = await enumerate(left, withSubdirs: withSubdirs, wildcard: wildcard,
                                       ignoreHidden: ignoreHidden, exclusions: exclusions,
                                       found: progress.map { p in { p(.scanningLeft(count: $0)) } })
        if Task.isCancelled { return SyncScanOutcome(items: [], heldBack: 0) }
        let rightWalk = await enumerate(right, withSubdirs: withSubdirs, wildcard: wildcard,
                                        ignoreHidden: ignoreHidden, exclusions: exclusions,
                                        found: progress.map { p in { p(.scanningRight(count: $0)) } })
        if Task.isCancelled { return SyncScanOutcome(items: [], heldBack: 0) }
        let leftScope = leftWalk.scope, rightScope = rightWalk.scope
        let leftMeta = leftWalk.entries, rightMeta = rightWalk.entries
        let incomplete = leftWalk.incompleteDirs.union(rightWalk.incompleteDirs)
        var heldBack = leftWalk.filtered.union(rightWalk.filtered)
        // Open each zip once for the content-comparison reads below.
        let leftZip = zipReader(left), rightZip = zipReader(right)

        var items: [SyncItem] = []
        let sorted = pair(leftMeta, rightMeta, caseSensitive: caseSensitive)
        progress?(.comparing(done: 0, total: sorted.count))
        for (index, entry) in sorted.enumerated() {
            if index > 0, index % progressStride == 0 {
                if Task.isCancelled {
                    return SyncScanOutcome(items: items, heldBack: heldBack.count,
                                           leftScope: leftScope, rightScope: rightScope)
                }
                progress?(.comparing(done: index, total: sorted.count))
            }
            let key = entry.key
            let l = entry.left?.meta, r = entry.right?.meta
            let isDir = (l?.isDir ?? false) || (r?.isDir ?? false)
            // Before the byte comparison, not after: reading both files is the most expensive thing
            // in this loop, and a pair that is not in the comparison should not pay for it.
            if filter.hasPairCriteria,
               !filter.keepsPair(leftSize: l?.size, leftModified: l?.modified,
                                 rightSize: r?.size, rightModified: r?.modified,
                                 isDirectory: isDir, now: now) {
                heldBack.insert(key)
                continue
            }
            var contentEqual: Bool? = nil
            if byContent, !isDir, let l, let r {
                if l.size != r.size {
                    contentEqual = false
                } else {
                    // Each side's own spelling: under case-insensitive matching the two names can
                    // differ in case, and reading the left one out of the right folder finds nothing.
                    // Never `SyncSide.path` joined by hand — that was once done for what looked like
                    // two local folders and let a *server* side in, where the path is the path on the
                    // server: it opened `/srv/backup/…` locally, found nothing, and reported every
                    // same-sized file as different. Which side a key belongs to is decided in one
                    // place now, inside the comparison.
                    contentEqual = await streamedContentEqual(
                        left: left, right: right,
                        leftKey: entry.left?.key ?? key, rightKey: entry.right?.key ?? key,
                        leftZip: leftZip, rightZip: rightZip)
                }
            }
            // Each side's own spelling as well as the row's: under case-insensitive matching the
            // folder can be `Build` on one side and `build` on the other, and the walk recorded
            // whichever it saw.
            let held = isDir && (incomplete.contains(key)
                                 || entry.left.map { incomplete.contains($0.key) } == true
                                 || entry.right.map { incomplete.contains($0.key) } == true)
            items.append(SyncItem(relativePath: key, isDirectory: isDir,
                                  leftSize: l?.size, leftModified: l?.modified,
                                  rightSize: r?.size, rightModified: r?.modified,
                                  contentEqual: contentEqual,
                                  hasHeldBackContent: held))
        }
        progress?(.comparing(done: sorted.count, total: sorted.count))
        return SyncScanOutcome(items: items, heldBack: heldBack.count,
                               leftScope: leftScope, rightScope: rightScope)
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
                                  ignoreHidden: Bool, exclusions: SyncFilter.Exclusions,
                                  found: (@Sendable (Int) -> Void)? = nil) async -> Walk {
        switch side {
        case .localDir(let dir): return walk(dir, withSubdirs: withSubdirs, wildcard: wildcard,
                                             ignoreHidden: ignoreHidden, exclusions: exclusions,
                                             found: found)
        case .zip(let url): return walkZip(url, withSubdirs: withSubdirs, wildcard: wildcard,
                                           ignoreHidden: ignoreHidden, exclusions: exclusions)
        case .remote(let r): return await walkRemote(r, withSubdirs: withSubdirs, wildcard: wildcard,
                                                     ignoreHidden: ignoreHidden, exclusions: exclusions,
                                                     found: found)
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
                                   exclusions: SyncFilter.Exclusions,
                                   found: (@Sendable (Int) -> Void)? = nil) async -> Walk {
        var w = Walk()
        var queue: [String] = [""]
        while let prefix = queue.popLast() {
            do {
                for try await batch in source.fs.list(source.vpath(prefix)) {
                    for entry in batch.entries {
                        // The name comes off the wire; a component that is not a name would make the
                        // relative key — and with it a local path on the other side — mean something
                        // else. See PathContainment.
                        w.visited += 1
                        guard PathContainment.isSafeComponent(entry.name) else { continue }
                        let rel = prefix.isEmpty ? entry.name : "\(prefix)/\(entry.name)"
                        let isDir = entry.kind == .directory || entry.kind == .appBundle
                                 || entry.kind == .package
                        // Not enqueueing an excluded folder is the only pruning a server walk can
                        // do, and like the local one it is a speed-up: `excludes` answers for every
                        // entry beneath it as well.
                        if exclusions.excludes(relativePath: rel, isDirectory: isDir) {
                            w.heldBack(rel, byFilter: true); continue
                        }
                        if ignoreHidden, isHiddenRel(rel) { w.heldBack(rel, byFilter: false); continue }
                        if !isDir, !wildcard.matches(entry.name) { w.heldBack(rel, byFilter: false); continue }
                        w.entries[rel] = Meta(size: max(0, entry.size), modified: entry.modified, isDir: isDir)
                        if isDir {
                            if withSubdirs { queue.append(rel) } else { w.notDescended(rel) }
                        }
                    }
                    // Reported per listing batch rather than per stride: a server hands out entries
                    // in batches with a round trip between them, so the batch is the unit that takes
                    // time here — and this is the walk a user waits on longest.
                    found?(w.entries.count)
                }
            } catch {
                // A listing that failed part-way leaves its folder incomplete, and a mirror may not
                // delete a folder it could not read to the end. For the *root* there is no folder to
                // mark — that case used to leave no trace at all, so the whole side is unreliable.
                if prefix.isEmpty { w.rootEnumerable = false } else { w.notDescended(prefix) }
                return w
            }
        }
        return w
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
    private static func walkZip(_ url: String, withSubdirs: Bool, wildcard: WildcardMask,
                                ignoreHidden: Bool, exclusions: SyncFilter.Exclusions) -> Walk {
        var w = Walk()
        guard let reader = ZipReader(fileURL: URL(fileURLWithPath: url)) else {
            // A corrupt or unreadable archive read as an empty one, which in mirror mode is
            // "delete everything on the other side".
            w.rootEnumerable = false
            w.rootObservedNonEmpty = FileManager.default.fileExists(atPath: url)
            return w
        }
        for e in reader.entries {
            w.visited += 1
            var rel = e.path
            while rel.hasSuffix("/") { rel.removeLast() }
            guard !rel.isEmpty else { continue }
            // There is no descent to cut off here — the entry list is flat — which is exactly why
            // `excludes` has to answer for every entry rather than for folders alone: an archive
            // legitimately holds `node_modules/x/y.js` with no `node_modules/` entry to prune.
            if exclusions.excludes(relativePath: rel, isDirectory: e.isDirectory) {
                w.heldBack(rel, byFilter: true); continue
            }
            if !withSubdirs && rel.contains("/") { w.heldBack(rel, byFilter: false); continue }
            if ignoreHidden, isHiddenRel(rel) { w.heldBack(rel, byFilter: false); continue }   // F-192
            let leaf = (rel as NSString).lastPathComponent
            if !e.isDirectory, !wildcard.matches(leaf) { w.heldBack(rel, byFilter: false); continue }
            w.entries[rel] = Meta(size: e.uncompressedSize,
                                  modified: e.modified ?? Date(timeIntervalSince1970: 0),
                                  isDir: e.isDirectory)
        }
        return w
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

    /// How much of each side is held at once while comparing. The same 64 KB the local-to-local
    /// comparison always used.
    private static let contentChunk = 1 << 16

    /// One side's bytes, pulled a block at a time.
    ///
    /// Local files and zip members can both be *pulled* from — a file handle reads what it is asked
    /// for, and `ZipReader.reader(for:)` hands out a member piece by piece. A server cannot: a
    /// `VFSReadStream` is an AsyncSequence with an unconstrained Element, so there is no way to hold
    /// an iterator and ask it for the next block on demand. That is why the remote case is driven
    /// the other way round below, and why this returns nil for it rather than pretending.
    private final class Feed {
        private let handle: FileHandle?
        private let member: ArchiveMemberReader?
        private var failed = false

        init?(_ side: SyncSide, key: String, zip: ZipReader?) {
            switch side {
            case .localDir(let dir):
                let path = (dir as NSString).appendingPathComponent(key)
                guard let h = FileHandle(forReadingAtPath: path) else { return nil }
                handle = h; member = nil
            case .zip:
                guard let zip,
                      let entry = zip.entries.first(where: { SyncScanner.entryKey($0.path) == key }),
                      // One optional, not two: `try?` flattens (SE-0230), so this is nil both for
                      // a member that cannot be streamed — encrypted, or a compression method this
                      // build does not implement — and for one that threw on the way.
                      let reader = try? zip.reader(for: entry, password: nil)
                else { return nil }
                handle = nil; member = reader
            case .remote:
                return nil
            }
        }

        /// `n` bytes, fewer only at the end of this side; nil when the read itself failed.
        ///
        /// Looped rather than one call: a file handle returns what it has, but an archive member
        /// reader is allowed to hand back less than it was asked for, and comparing two blocks of
        /// different lengths would report a difference that is not there.
        func readFully(_ n: Int) -> Data? {
            guard !failed else { return nil }
            var out = Data()
            while out.count < n {
                let want = n - out.count
                let piece: Data
                if let handle {
                    piece = handle.readData(ofLength: want)
                } else if let member {
                    // `do`/`catch` and not `try?`: since SE-0230 `try?` *flattens* an already
                    // optional result, so `try? member.next(…)` is `Data?` and not `Data??` — and a
                    // `guard let` over that treats the reader's nil-at-the-end as a failed read.
                    // Measured: every zip comparison came back "not compared", because reaching the
                    // end of a member looked exactly like being unable to read it.
                    do {
                        piece = try member.next(maxBytes: want) ?? Data()
                    } catch {
                        failed = true
                        return nil
                    }
                } else {
                    return nil
                }
                if piece.isEmpty { break }
                out.append(piece)
            }
            return out
        }

        func close() { try? handle?.close() }
    }

    /// Byte-compare one entry across two sides without holding either file.
    ///
    /// Two things are deliberate here.
    ///
    /// It is **streamed, and stopped at the first difference.** The version before this read both
    /// files whole into memory and compared the two buffers, so a 3 GB pair across a share or an
    /// archive held six gigabytes at once and read all of it even when the first byte already
    /// differed. Two local folders were compared in blocks all along; a server or a zip side was
    /// not, and the comment there mentioned the download without mentioning the memory.
    ///
    /// And **nil means the bytes were not read**, not a verdict. The old code answered
    /// `leftData == rightData` over two `Data?`, and `nil == nil` is true — so a pair neither side of
    /// which could be read came out as *identical*, in the grid and in the plan. Measured. Nil makes
    /// `classify` fall back to size and date, which is what a comparison that was not by content
    /// would have said anyway; it is the honest degradation, where "identical" was a claim about
    /// bytes nobody had seen.
    private static func streamedContentEqual(left: SyncSide, right: SyncSide,
                                             leftKey: String, rightKey: String,
                                             leftZip: ZipReader?, rightZip: ZipReader?) async -> Bool? {
        // At most one side is a server — `scan` refuses two — and that is what makes this workable.
        // A read stream can only be pushed through, so the remote side drives the loop and the other
        // side is asked for blocks of matching length.
        if case .remote(let r) = left {
            return await compareStreamed(driver: r, driverKey: leftKey,
                                         other: right, otherKey: rightKey, otherZip: rightZip)
        }
        if case .remote(let r) = right {
            return await compareStreamed(driver: r, driverKey: rightKey,
                                         other: left, otherKey: leftKey, otherZip: leftZip)
        }
        guard let a = Feed(left, key: leftKey, zip: leftZip),
              let b = Feed(right, key: rightKey, zip: rightZip) else { return nil }
        defer { a.close(); b.close() }
        while true {
            guard let da = a.readFully(contentChunk), let db = b.readFully(contentChunk) else { return nil }
            if da != db { return false }
            if da.isEmpty { return true }
        }
    }

    /// The remote half: the server's stream sets the pace, the other side supplies the same lengths.
    private static func compareStreamed(driver: RemoteSyncSource, driverKey: String,
                                        other: SyncSide, otherKey: String,
                                        otherZip: ZipReader?) async -> Bool? {
        guard let feed = Feed(other, key: otherKey, zip: otherZip) else { return nil }
        defer { feed.close() }
        guard let stream = try? await driver.fs.openRead(driver.vpath(driverKey)) else { return nil }
        var equal = true
        var failure = false
        do {
            for try await element in stream {
                // `as? Data`, as everywhere else that reads a VFS stream: the protocol gives Element
                // a default of Data but does not constrain it, so the concrete type is not known here.
                guard let piece = element as? Data, !piece.isEmpty else { continue }
                guard let mine = feed.readFully(piece.count) else { failure = true; break }
                if mine != piece { equal = false; break }
            }
            // Both sides have to end together. The caller only asks when the two listings agree on
            // the size, so anything left over here means one of them was not what it said.
            if equal, !failure, let tail = feed.readFully(1), !tail.isEmpty { equal = false }
        } catch {
            failure = true
        }
        // Closed on every path, including the early break — which is the point of breaking: the rest
        // of the file is not downloaded.
        try? await stream.close()
        return failure ? nil : equal
    }

    /// A zip entry path reduced to the comparison key (no trailing slash).
    private static func entryKey(_ path: String) -> String {
        var s = path
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    private static func walk(_ dir: String, withSubdirs: Bool, wildcard: WildcardMask,
                             ignoreHidden: Bool, exclusions: SyncFilter.Exclusions,
                             found: (@Sendable (Int) -> Void)? = nil) -> Walk {
        let fm = FileManager.default
        let base = (dir as NSString).standardizingPath
        var w = Walk()
        // Use the path-based enumerator: it yields paths RELATIVE to `base`, so there
        // is no prefix to strip. (The URL enumerator reports resolved paths like
        // /private/tmp/… that don't match a /tmp/… base, silently dropping everything
        // under a symlinked root.)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        // Asked before the walk, because after it an empty `entries` has two very different
        // causes: a folder with nothing in it, and a folder this process cannot read. `nil` from
        // `contentsOfDirectory` is itself the second answer.
        let listing = try? fm.contentsOfDirectory(atPath: base)
        w.rootObservedNonEmpty = listing.map { !$0.isEmpty } ?? true
        guard let en = fm.enumerator(atPath: base) else {
            w.rootEnumerable = false
            return w
        }
        for case let rel as String in en {
            w.visited += 1
            let full = (base as NSString).appendingPathComponent(rel)
            let vals = try? URL(fileURLWithPath: full).resourceValues(forKeys: Set(keys))
            let isDir = vals?.isDirectory ?? false
            // An excluded folder is not descended into. That is a speed-up and nothing more:
            // `excludes` answers the same for everything beneath it, so a walk that forgot to prune
            // would be slow rather than wrong.
            if exclusions.excludes(relativePath: rel, isDirectory: isDir) {
                if isDir { en.skipDescendants() }
                w.heldBack(rel, byFilter: true)
                continue
            }
            // Top-level-only mode: include the directory itself but don't descend.
            if !withSubdirs && isDir { en.skipDescendants(); w.notDescended(rel) }
            // Ignore hidden items (any dotfile component), F-192.
            if ignoreHidden, isHiddenRel(rel) {
                if isDir { en.skipDescendants() }
                w.heldBack(rel, byFilter: false)
                continue
            }
            let leaf = (rel as NSString).lastPathComponent
            if !isDir, !wildcard.matches(leaf) { w.heldBack(rel, byFilter: false); continue }
            w.entries[rel] = Meta(size: Int64(vals?.fileSize ?? 0),
                                  modified: vals?.contentModificationDate ?? Date(timeIntervalSince1970: 0),
                                  isDir: isDir)
            if w.entries.count % progressStride == 0 {
                if Task.isCancelled { return w }
                found?(w.entries.count)
            }
        }
        found?(w.entries.count)
        return w
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
