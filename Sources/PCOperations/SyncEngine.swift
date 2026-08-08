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

public enum SyncSide: Sendable, Equatable {
    case localDir(String)
    case zip(String)   // on-disk .zip path

    public var isZip: Bool { if case .zip = self { return true } else { return false } }
    public var path: String { switch self { case .localDir(let p), .zip(let p): return p } }
}

/// Recursive scanner producing SyncItems for two sides (local dirs and/or a zip).
public enum SyncScanner {
    private struct Meta { var size: Int64; var modified: Date; var isDir: Bool }

    public static func scan(left: SyncSide, right: SyncSide, mask: String,
                     withSubdirs: Bool, byContent: Bool, ignoreHidden: Bool = false) -> [SyncItem] {
        let wildcard = WildcardMask(mask.isEmpty ? "*.*" : mask)
        let leftMeta = enumerate(left, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        let rightMeta = enumerate(right, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
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
                    contentEqual = loadData(left, key: key, zip: leftZip) == loadData(right, key: key, zip: rightZip)
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
                                  ignoreHidden: Bool) -> [String: Meta] {
        switch side {
        case .localDir(let dir): return walk(dir, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        case .zip(let url): return walkZip(url, withSubdirs: withSubdirs, wildcard: wildcard, ignoreHidden: ignoreHidden)
        }
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
    private static func loadData(_ side: SyncSide, key: String, zip: ZipReader?) -> Data? {
        switch side {
        case .localDir(let dir):
            return try? Data(contentsOf: URL(fileURLWithPath: (dir as NSString).appendingPathComponent(key)))
        case .zip:
            guard let zip, let e = zip.entries.first(where: { entryKey($0.path) == key }) else { return nil }
            return try? zip.data(for: e)
        }
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
                        toTrash: Bool) -> [String] {
        let fm = FileManager.default
        var errors: [String] = []
        var zipAdds: [(localPath: String, arcPath: String)] = []   // local → zip, batched
        var zipDeletes: [String] = []                              // entries to delete from the zip (F-192)

        func local(_ side: SyncSide, _ rel: String) -> String {
            (side.path as NSString).appendingPathComponent(rel)
        }

        /// Copy one file/dir from `src` side to `dst` side.
        func copy(rel: String, isDir: Bool, src: SyncSide, dst: SyncSide) {
            switch (src, dst) {
            case (.localDir, .localDir):
                copyLocalToLocal(local(src, rel), local(dst, rel), isDir: isDir)
            case (.localDir, .zip):
                if !isDir { zipAdds.append((localPath: local(src, rel), arcPath: rel)) }
                // Empty-dir entries are implicit via child arc paths; skip standalone dirs.
            case (.zip(let url), .localDir):
                extractFromZip(url, rel: rel, to: local(dst, rel), isDir: isDir)
            case (.zip, .zip):
                errors.append("\(rel): archive-to-archive sync not supported")
            }
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

        func remove(_ side: SyncSide, _ rel: String) {
            if case .zip = side {                         // batched into one rewrite below (F-192)
                zipDeletes.append(rel); return
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
            if r.action == .copyToRight { copy(rel: rel, isDir: r.item.isDirectory, src: left, dst: right) }
            else { copy(rel: rel, isDir: r.item.isDirectory, src: right, dst: left) }
        }
        // One rewrite for all files copied into the zip.
        if !zipAdds.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.add(to: URL(fileURLWithPath: zipURL), entries: zipAdds) }
            catch { errors.append("archive update failed: \(error.localizedDescription)") }
        }
        for r in deletes {
            remove(r.action == .deleteRight ? right : left, r.item.relativePath)
        }
        // One rewrite for all entries deleted from the zip (F-192).
        if !zipDeletes.isEmpty, let zipURL = (left.isZip ? left : right).path as String? {
            do { try ArchiveEditor.remove(from: URL(fileURLWithPath: zipURL), paths: zipDeletes) }
            catch { errors.append("archive delete failed: \(error.localizedDescription)") }
        }
        return errors
    }
}
