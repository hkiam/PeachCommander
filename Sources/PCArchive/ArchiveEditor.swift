// SPDX-License-Identifier: Apache-2.0
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
    /// Items that were to go into the archive and could not be read.
    ///
    /// Thrown rather than substituted, which is what used to happen: a file the process cannot read
    /// became a **zero-byte entry** with the right name and the right path, and a directory it
    /// cannot list became an *empty folder* entry. Both silently. The consequence is worst on the
    /// path that made it reachable — F6 into an archive trashes the sources once the add reports
    /// success, so the content was gone from the archive and the original was in the Trash, with
    /// the operation reported as done.
    ///
    /// Every path at once, `RenameBatchPlan`'s rule: one dialog per unreadable file in a folder of
    /// them is a dialog nobody reads to the end.
    case unreadableItems([String])
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
        // Collected, then thrown once. Substituting an empty value here — which is what `?? []` and
        // `?? Data()` did — writes an entry that claims the folder was empty or the file had no
        // content, and says nothing.
        var unreadable: [String] = []
        func walk(local: String, arc: String) {
            let arcN = normalize(arc)
            guard !arcN.isEmpty else { return }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: local, isDirectory: &isDir) else { return }
            if isDir.boolValue {
                guard let kids = try? fm.contentsOfDirectory(atPath: local) else {
                    // Distinguishable from a folder that really is empty only here: after this
                    // point both are "no children", and the archive would have said empty.
                    unreadable.append(local)
                    return
                }
                if kids.isEmpty { newFiles.append((arcN + "/", Data())) }
                for k in kids.sorted() {
                    walk(local: (local as NSString).appendingPathComponent(k), arc: arcN + "/" + k)
                }
            } else {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: local)) else {
                    unreadable.append(local)
                    return
                }
                newFiles.append((arcN, data))
            }
        }
        for e in entries { walk(local: e.localPath, arc: e.arcPath) }
        // Before the rewrite, so an archive is never left half-updated over this: both callers
        // treat a throw as "nothing was added" — the panel then does not trash the sources, and the
        // sync executor names every staged entry as failed.
        guard unreadable.isEmpty else { throw ArchiveEditError.unreadableItems(unreadable) }

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
