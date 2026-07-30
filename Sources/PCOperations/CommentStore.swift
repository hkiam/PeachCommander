// SPDX-License-Identifier: Apache-2.0
// CommentStore.swift - Read/write per-file comments via descript.ion (SPEC-016 §7).
//
// Comments live in a "descript.ion" file in the same directory as the files they
// annotate. This reads/updates that file through the VFS so it works on local
// disk and (capability permitting) network locations.

import Foundation
import PCFoundation
import PCVFS

public enum CommentStore {
    public static let fileName = "descript.ion"

    /// The comment for `name` in `dir`, or nil if none.
    public static func comment(for name: String, inDir dir: VFSPath, on fs: VirtualFileSystem) async -> String? {
        guard let data = try? await readAll(dir.joining(fileName), on: fs) else { return nil }
        return DescriptionFile(parsing: String(decoding: data, as: UTF8.self)).comment(for: name)
    }

    /// All comments in `dir` as a name → comment map (empty if the file is missing
    /// or unreadable). Used to populate the panel's Comment column in one read.
    public static func comments(inDir dir: VFSPath, on fs: VirtualFileSystem) async -> [String: String] {
        guard let data = try? await readAll(dir.joining(fileName), on: fs) else { return [:] }
        return DescriptionFile(parsing: String(decoding: data, as: UTF8.self)).comments
    }

    /// Set (or clear, when nil/empty) the comment for `name` in `dir`. Removes the
    /// descript.ion file entirely once it has no comments left.
    public static func setComment(_ comment: String?, for name: String, inDir dir: VFSPath,
                                  on fs: VirtualFileSystem) async throws {
        let path = dir.joining(fileName)
        var doc = DescriptionFile()
        if let data = try? await readAll(path, on: fs) {
            doc = DescriptionFile(parsing: String(decoding: data, as: UTF8.self))
        }
        doc.setComment(comment, for: name)
        if doc.isEmpty {
            try? await fs.delete(path)
        } else {
            let writer = try await fs.openWrite(path, options: WriteOptions())
            try await writer.write(Data(doc.serialized().utf8))
            try await writer.close()
        }
    }

    private static func readAll(_ path: VFSPath, on fs: VirtualFileSystem) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        try? await stream.close()
        return data
    }
}
