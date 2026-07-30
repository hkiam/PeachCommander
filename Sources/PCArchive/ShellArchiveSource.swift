// SPDX-License-Identifier: Apache-2.0
// ShellArchiveSource.swift - libarchive-backed archive browsing via bsdtar (F-130).
//
// ArchiveFS reads zip and tar natively; this fallback backend hands the remaining
// libarchive-supported formats (cpio, iso9660, cab, lzh/lha, xar, ar, …) to the
// system `bsdtar` for listing (`-tvf`) and single-member extraction (`-xOf`).
// bsdtar formats its own verbose listing uniformly regardless of the underlying
// format, so one parser covers them all.

import Foundation

public final class ShellArchiveSource: ArchiveSource, @unchecked Sendable {
    private let fileURL: URL
    private let bsdtar: String
    public let members: [ArchiveMember]
    /// The exact member strings bsdtar listed, used verbatim for `-xOf` extraction
    /// (parallel to `members`).
    private let rawPaths: [String]

    /// Extensions handled by this shell backend (not covered by the native
    /// zip/tar readers). Used to extend the panel's "enterable archive" set.
    public static let handledExtensions: Set<String> =
        ["cpio", "iso", "cab", "lzh", "lha", "xar", "pax", "ar", "cpgz", "img"]

    public init?(fileURL: URL) {
        guard let bsdtar = Self.bsdtarPath else { return nil }
        self.fileURL = fileURL
        self.bsdtar = bsdtar
        guard let listing = Self.runText(bsdtar, ["-tvf", fileURL.path]),
              !listing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        var mem: [ArchiveMember] = []
        var raws: [String] = []
        for line in listing.split(whereSeparator: \.isNewline) {
            // bsdtar -tvf: mode links owner group size Mon DD time/year name…
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 9, let mode = tokens.first else { continue }
            let isDir = mode.hasPrefix("d")
            let size = Int64(tokens[4]) ?? 0
            let rawName = tokens[8...].joined(separator: " ")
            var norm = rawName
            if norm.hasPrefix("./") { norm.removeFirst(2) }
            norm = norm.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if norm.isEmpty || norm == "." { continue }              // archive root
            if isDir { norm += "/" }
            mem.append(ArchiveMember(path: norm, uncompressedSize: isDir ? -1 : size,
                                     isDirectory: isDir, modified: nil))
            raws.append(rawName)
        }
        guard !mem.isEmpty else { return nil }
        self.members = mem
        self.rawPaths = raws
    }

    public func data(atIndex index: Int, password: String?) throws -> Data {
        guard rawPaths.indices.contains(index), !members[index].isDirectory else { return Data() }
        guard let out = Self.runData(bsdtar, ["-xOf", fileURL.path, rawPaths[index]]) else {
            throw NSError(domain: "PCArchive.Shell", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bsdtar could not extract \(rawPaths[index])"])
        }
        return out
    }

    // MARK: - bsdtar plumbing

    private static let bsdtarPath: String? =
        ["/usr/bin/bsdtar", "/usr/bin/tar"].first { FileManager.default.isExecutableFile(atPath: $0) }

    private static func runText(_ launch: String, _ args: [String]) -> String? {
        guard let data = runData(launch, args) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Run `launch args`, returning stdout bytes, or nil when the tool exits
    /// non-zero (e.g. the file is not a readable archive).
    private static func runData(_ launch: String, _ args: [String]) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch)
        p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return p.terminationStatus == 0 ? data : nil
    }
}
