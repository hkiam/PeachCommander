// SPDX-License-Identifier: Apache-2.0
// ShellArchiveEditor.swift - Adding files to a tar or 7z archive (F-139).
//
// The zip case rewrites the archive in Swift (ArchiveEditor). tar and 7z can be added to in place by
// the tools themselves, which is both faster and safer than re-emitting a format this app does not
// write: `tar -rf` appends to an uncompressed tar, `7z a` adds to a .7z. What each of them can really
// do was measured; ArchiveWriteSupport records the answers and why.
//
// Two things matter about how the tools are called.
//
// **A staging directory.** Both tools store the path they are given, relative to the working directory.
// To place a file at `docs/notes.txt` inside the archive, the file has to *be* at `docs/notes.txt`
// relative to somewhere — so a temporary tree is built with exactly the wanted layout, hard-linked to
// the originals where possible so nothing is copied twice, and the tool runs with that tree as its
// working directory. It is removed afterwards whatever happens.
//
// **No shell.** The tool is executed directly with an argument vector, so no quoting question arises at
// all — and `--` goes before the names, because a file called `-C` handed to tar is not a file but an
// instruction to change directory and archive something else entirely.

import Foundation
import PCFoundation

public enum ShellArchiveEditError: Error, Equatable {
    case unsupported(ArchiveWriteSupport.Reason)
    case failed(tool: String, status: Int32, output: String)
    case cannotStage(String)
}

public enum ShellArchiveEditor {

    /// Add local files/directories to the archive at `url`, at the given archive-relative paths.
    ///
    /// Mirrors `ArchiveEditor.add` so the caller can route on the format alone.
    public static func add(to url: URL, entries: [(localPath: String, arcPath: String)]) throws {
        guard !entries.isEmpty else { return }
        let capability = ArchiveWriteSupport.capability(forArchiveAt: url.path)
        if case .unsupported(let reason) = capability { throw ShellArchiveEditError.unsupported(reason) }

        let staging = try stage(entries)
        defer { try? FileManager.default.removeItem(at: staging.root) }

        switch capability {
        case .appendTar(let tar):
            // `-r` appends; it works only on an uncompressed tar, which is what the capability check
            // has already established.
            try run(tar, ["-rf", url.path, "--"] + staging.topLevelNames, in: staging.root)
        case .sevenZip(let sevenZip):
            // `a` adds to an existing archive or creates one. `-bso0 -bsp0` silence the progress
            // chatter; failures still come back on stderr and through the exit status.
            try run(sevenZip, ["a", "-bso0", "-bsp0", url.path, "--"] + staging.topLevelNames,
                    in: staging.root)
        case .rewrite, .unsupported:
            // zip is ArchiveEditor's; the caller routes on the same capability and must not arrive here.
            throw ShellArchiveEditError.unsupported(.formatNotWritable(url.pathExtension))
        }
    }

    // MARK: - Staging

    private struct Staging {
        let root: URL
        /// The first path component of each entry, which is what the tool is asked to add.
        let topLevelNames: [String]
    }

    /// Build a temporary tree mirroring the wanted archive layout.
    ///
    /// Hard-linked to the originals where the file system allows it — the same bytes, no second copy,
    /// and the link disappears with the staging directory. A link across volumes is impossible, so a
    /// copy is the fallback rather than a failure.
    private static func stage(_ entries: [(localPath: String, arcPath: String)]) throws -> Staging {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("pc-arcadd-\(UUID().uuidString)",
                                                                isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        var tops: [String] = []
        for entry in entries {
            let components = entry.arcPath.split(separator: "/").map(String.init).filter { !$0.isEmpty }
            guard let first = components.first else { continue }
            // The archive path comes from the panel, and a component that is not a name would put the
            // staged file outside the staging tree — the same rule as everywhere else a name from
            // elsewhere becomes a path.
            guard components.allSatisfy({ PathContainment.isSafeComponent($0) }) else {
                throw ShellArchiveEditError.cannotStage(entry.arcPath)
            }
            let target = components.reduce(root) { $0.appendingPathComponent($1) }
            try fm.createDirectory(at: target.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            let source = URL(fileURLWithPath: entry.localPath)
            if (try? fm.linkItem(at: source, to: target)) == nil {
                try fm.copyItem(at: source, to: target)
            }
            if !tops.contains(first) { tops.append(first) }
        }
        guard !tops.isEmpty else { throw ShellArchiveEditError.cannotStage("no entries") }
        return Staging(root: root, topLevelNames: tops)
    }

    // MARK: - Running the tool

    private static func run(_ tool: String, _ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        // Same environment as the packers: no AppleDouble companions. See PackEngine.
        process.environment = PackEngine.environmentForTools()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ShellArchiveEditError.failed(tool: (tool as NSString).lastPathComponent,
                                               status: process.terminationStatus,
                                               output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
