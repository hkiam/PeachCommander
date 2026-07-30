// ArchiveEditor.swift - In-place edits of a zip by full rewrite (F-133).
//
// The zip format has no cheap in-place delete/rename, so these operations read
// every surviving entry through ZipReader and re-emit the archive with
// ZipWriter. This matches the "zip in-place update (rewrite)" approach noted in
// the feature inventory. Note: modification timestamps are not preserved by
// ZipWriter (it stamps the write time); the byte contents are preserved exactly.

import Foundation

public enum ArchiveEditError: Error, Equatable {
    case unreadableArchive
}

public enum ArchiveEditor {
    /// Rewrites the zip at `url`, dropping every entry whose archive path — or a
    /// parent directory thereof — appears in `paths`. Paths may be given in
    /// leading-slash form ("/a/b"); they are normalized for comparison.
    public static func remove(from url: URL, paths: [String]) throws {
        guard let reader = ZipReader(fileURL: url) else { throw ArchiveEditError.unreadableArchive }
        let targets = Set(paths.map(normalize))
        var files: [(path: String, data: Data)] = []
        for entry in reader.entries {
            if isUnder(normalize(entry.path), targets) { continue }
            files.append((entry.path, entry.isDirectory ? Data() : try reader.data(for: entry)))
        }
        try ZipWriter.create(at: url, files: files)
    }

    /// Rewrites the zip at `url`, renaming the entry at `from` to `to` (and, for
    /// a directory, every entry beneath it). Paths may be in leading-slash form.
    public static func rename(in url: URL, from: String, to: String) throws {
        guard let reader = ZipReader(fileURL: url) else { throw ArchiveEditError.unreadableArchive }
        let oldName = normalize(from), newName = normalize(to)
        guard !oldName.isEmpty, !newName.isEmpty else { return }
        var files: [(path: String, data: Data)] = []
        for entry in reader.entries {
            let current = normalize(entry.path)
            var renamed = current
            if current == oldName {
                renamed = newName
            } else if current.hasPrefix(oldName + "/") {
                renamed = newName + String(current.dropFirst(oldName.count))
            }
            let outPath = entry.isDirectory ? renamed + "/" : renamed
            files.append((outPath, entry.isDirectory ? Data() : try reader.data(for: entry)))
        }
        try ZipWriter.create(at: url, files: files)
    }

    /// Rewrites the zip at `url`, adding local files/directories at the given
    /// archive paths (directories are walked recursively). Existing entries are
    /// preserved; an added path that already exists overwrites it. Enables copying
    /// INTO an archive (F-133) and, via a temp extraction, between two archives
    /// (F-139).
    public static func add(to url: URL, entries: [(localPath: String, arcPath: String)]) throws {
        guard let reader = ZipReader(fileURL: url) else { throw ArchiveEditError.unreadableArchive }
        let fm = FileManager.default
        var newFiles: [(path: String, data: Data)] = []
        func walk(local: String, arc: String) {
            let arcN = normalize(arc)
            guard !arcN.isEmpty else { return }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: local, isDirectory: &isDir) else { return }
            if isDir.boolValue {
                let kids = (try? fm.contentsOfDirectory(atPath: local))?.sorted() ?? []
                if kids.isEmpty { newFiles.append((arcN + "/", Data())) }
                for k in kids { walk(local: (local as NSString).appendingPathComponent(k), arc: arcN + "/" + k) }
            } else {
                let data = (try? Data(contentsOf: URL(fileURLWithPath: local))) ?? Data()
                newFiles.append((arcN, data))
            }
        }
        for e in entries { walk(local: e.localPath, arc: e.arcPath) }

        // Keep existing entries not overwritten by an added path.
        let added = Set(newFiles.map { normalize($0.path) })
        var files: [(path: String, data: Data)] = []
        for entry in reader.entries where !added.contains(normalize(entry.path)) {
            files.append((entry.path, entry.isDirectory ? Data() : try reader.data(for: entry)))
        }
        files.append(contentsOf: newFiles)
        try ZipWriter.create(at: url, files: files)
    }

    // MARK: - Helpers

    /// Strips leading/trailing slashes so "/a/b/" and "a/b" compare equal.
    private static func normalize(_ path: String) -> String {
        var s = Substring(path)
        while s.hasPrefix("/") { s = s.dropFirst() }
        while s.hasSuffix("/") { s = s.dropLast() }
        return String(s)
    }

    /// True when `path` equals, or is nested under, any entry in `targets`.
    private static func isUnder(_ path: String, _ targets: Set<String>) -> Bool {
        if targets.contains(path) { return true }
        for t in targets where !t.isEmpty && path.hasPrefix(t + "/") { return true }
        return false
    }
}
