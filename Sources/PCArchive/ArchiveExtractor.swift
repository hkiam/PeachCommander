// SPDX-License-Identifier: Apache-2.0
// ArchiveExtractor.swift - Extract every member of an archive (any VirtualFileSystem,
// e.g. ArchiveFS) to a destination directory, preserving its folder structure.
// Backs the "Unpack" (cm_UnpackFiles) command; the destination prompt/progress UI
// is layered on top.

import Foundation
import PCVFS

public enum ArchiveExtractor {
    public struct Result: Sendable, Equatable {
        public let files: Int
        public let bytes: Int64
        public init(files: Int, bytes: Int64) { self.files = files; self.bytes = bytes }
    }

    /// Read cap per member (matches the viewer/search cap), guarding against a
    /// crafted archive claiming an enormous single entry.
    private static let perFileLimit = 512 * 1024 * 1024

    /// Extract the whole `fs` tree into `destination` (created if needed).
    ///
    /// Members whose name would put them outside `destination` are skipped rather than written. An
    /// archive is data from somewhere else, and a member called `../../evil.txt` is the oldest trick
    /// there is ("zip slip"): extracted naively it lands beside or above the folder the user chose,
    /// silently, while the extraction reports success. Measured before it was fixed — both `../` and
    /// `../../` members landed outside.
    @discardableResult
    public static func extractAll(from fs: VirtualFileSystem, to destination: URL) async throws -> Result {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let root = destination.resolvingSymlinksInPath().standardizedFileURL
        let (files, bytes) = try await walk(fs: fs, path: "/", dest: destination, root: root)
        return Result(files: files, bytes: bytes)
    }

    /// Is `candidate` really inside `root`? Resolved first, because the destination itself is usually
    /// reached through a symlink (`/var` → `/private/var`) and a textual prefix test would say no.
    private static func isInside(_ candidate: URL, root: URL) -> Bool {
        let resolved = candidate.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
        guard resolved != root else { return true }
        return resolved.path.hasPrefix(root.path.hasSuffix("/") ? root.path : root.path + "/")
    }

    private static func walk(fs: VirtualFileSystem, path: String, dest: URL, root: URL) async throws -> (Int, Int64) {
        var files = 0
        var bytes: Int64 = 0
        let vpath = VFSPath(filesystemId: fs.scheme, path: path)
        for try await batch in fs.list(vpath) {
            for entry in batch.entries {
                if Task.isCancelled { throw CancellationError() }
                let child = (path == "/" ? "/" : path + "/") + entry.name
                let outURL = dest.appendingPathComponent(entry.name)
                // Both checks, because they fail differently: a name that is not a single component is
                // malformed whatever it resolves to, and the containment test catches anything that
                // slips past by a spelling not thought of here.
                guard entry.name != "..", entry.name != ".", !entry.name.isEmpty,
                      isInside(outURL, root: root) else { continue }
                switch entry.kind {
                case .directory, .appBundle, .package:
                    try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
                    let sub = try await walk(fs: fs, path: child, dest: outURL, root: root)
                    files += sub.0; bytes += sub.1
                case .file, .symlinkFile, .symlinkDir:
                    let n = try await extractFile(fs: fs, path: child, to: outURL)
                    files += 1; bytes += n
                }
            }
            if batch.isLastBatch { break }
        }
        return (files, bytes)
    }

    private static func extractFile(fs: VirtualFileSystem, path: String, to outURL: URL) async throws -> Int64 {
        let stream = try await fs.openRead(VFSPath(filesystemId: fs.scheme, path: path))
        var data = Data()
        for try await element in stream {
            if Task.isCancelled { try? await stream.close(); throw CancellationError() }
            if let chunk = element as? Data { data.append(chunk) }
            if data.count >= perFileLimit { break }
        }
        try? await stream.close()
        try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: outURL, options: .atomic)
        return Int64(data.count)
    }
}
