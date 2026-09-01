// SPDX-License-Identifier: Apache-2.0
// ArchiveExtractor.swift - Extract every member of an archive (any VirtualFileSystem,
// e.g. ArchiveFS) to a destination directory, preserving its folder structure.
// Backs the "Unpack" (cm_UnpackFiles) command; the destination prompt/progress UI
// is layered on top.

import Foundation
import PCFoundation
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

    private static func walk(fs: VirtualFileSystem, path: String, dest: URL, root: URL) async throws -> (Int, Int64) {
        var files = 0
        var bytes: Int64 = 0
        let vpath = VFSPath(filesystemId: fs.scheme, path: path)
        for try await batch in fs.list(vpath) {
            for entry in batch.entries {
                if Task.isCancelled { throw CancellationError() }
                let child = (path == "/" ? "/" : path + "/") + entry.name
                // The same rule the panel's extract walk uses; see PathContainment.
                guard let outURL = PathContainment.childURL(entry.name, under: dest, root: root)
                else { continue }
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

    /// One member, written out as it arrives rather than assembled first.
    ///
    /// The first version accumulated the whole member into a `Data` and wrote that, so unpacking a
    /// 4 GB file needed 4 GB of memory before a single byte reached the disk. The stream is chunked
    /// (`ArchiveReadStream`), so there is nothing to assemble.
    ///
    /// Still atomic from the destination's point of view: the bytes go to a sibling temporary file
    /// and are moved into place at the end, so a cancelled or failed extraction leaves no
    /// half-written file where a whole one is expected — which `.atomic` used to provide.
    private static func extractFile(fs: VirtualFileSystem, path: String, to outURL: URL) async throws -> Int64 {
        let directory = outURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let partial = directory.appendingPathComponent(".\(outURL.lastPathComponent).pcpart")
        try? FileManager.default.removeItem(at: partial)
        guard FileManager.default.createFile(atPath: partial.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: partial) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let stream = try await fs.openRead(VFSPath(filesystemId: fs.scheme, path: path))
        var written: Int64 = 0
        do {
            for try await element in stream {
                if Task.isCancelled { throw CancellationError() }
                guard let chunk = element as? Data else { continue }
                try handle.write(contentsOf: chunk)
                written += Int64(chunk.count)
                // A crafted archive may claim an enormous single entry; the cap is the viewer's and
                // the search's, and it truncates rather than failing, as it always has.
                if written >= perFileLimit { break }
            }
        } catch {
            try? handle.close()
            try? await stream.close()
            try? FileManager.default.removeItem(at: partial)
            throw error
        }
        try? handle.close()
        try? await stream.close()

        try? FileManager.default.removeItem(at: outURL)
        try FileManager.default.moveItem(at: partial, to: outURL)
        return written
    }
}
