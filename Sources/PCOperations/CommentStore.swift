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

    /// Move a comment along with the file it describes (F-372).
    ///
    /// Nothing in this app used to do this. A comment lives in the `descript.ion` of the directory the
    /// file is in, keyed by the file's name — so renaming the file left the comment behind under the old
    /// name, and moving it to another directory left the comment in the source directory. Both silently.
    /// In a file manager whose two most-used keys are Copy and Move, a per-file comment that does not
    /// survive either is a note-taking feature that loses notes.
    ///
    /// Best-effort on purpose: a comment that cannot be carried must never fail the file operation that
    /// is carrying it. The caller has already moved the bytes; refusing afterwards would be worse.
    ///
    /// `keepSource` distinguishes a copy (the source keeps its comment) from a move (it does not).
    public static func carry(name: String, from srcDir: VFSPath,
                            toName dstName: String, in dstDir: VFSPath,
                            on fs: VirtualFileSystem, keepSource: Bool) async {
        // The comment file itself is not something that has a comment.
        guard name != fileName, dstName != fileName else { return }
        guard let comment = await comment(for: name, inDir: srcDir, on: fs), !comment.isEmpty else {
            return                                     // nothing to carry, and no descript.ion to create
        }
        do {
            try await setComment(comment, for: dstName, inDir: dstDir, on: fs)
        } catch {
            return                                     // target not writable: the file still moved
        }
        if !keepSource, srcDir != dstDir || name != dstName {
            try? await setComment(nil, for: name, inDir: srcDir, on: fs)
        }
    }

    /// `carry` for two local paths — what the copy, move and rename engines have.
    ///
    /// A separate entry point rather than making the engines build `VFSPath`s and a filesystem: they are
    /// local-only (they work through `FSLowLevel`), and one line at the call site is what keeps this from
    /// being forgotten at the next one.
    public static func carryLocal(from src: String, to dst: String, keepSource: Bool) async {
        let fs = LocalFS()
        let srcDir = VFSPath(filesystemId: fs.scheme, path: (src as NSString).deletingLastPathComponent)
        let dstDir = VFSPath(filesystemId: fs.scheme, path: (dst as NSString).deletingLastPathComponent)
        await carry(name: (src as NSString).lastPathComponent, from: srcDir,
                    toName: (dst as NSString).lastPathComponent, in: dstDir,
                    on: fs, keepSource: keepSource)
    }

    private static func readAll(_ path: VFSPath, on fs: VirtualFileSystem) async throws -> Data {
        let stream = try await fs.openRead(path)
        var data = Data()
        for try await chunk in stream { if let d = chunk as? Data { data.append(d) } }
        try? await stream.close()
        return data
    }
}
