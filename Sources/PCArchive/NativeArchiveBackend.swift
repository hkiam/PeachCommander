// SPDX-License-Identifier: Apache-2.0
// NativeArchiveBackend.swift - What the built-in readers can open (F-463).
//
// This is where the built-in half of "is this an archive" now lives: next to the
// readers that actually implement it, rather than copied into the search engine,
// the panel and the write-capability check, each with a different answer.
//
// The names here are the union of what `ZipReader`, `TarReader` and
// `ShellArchiveSource` can actually parse. If a reader gains a format, this list
// is the one place that has to hear about it — and the panel, the search, unpack
// and test-archive all learn at once.

import Foundation
import PCVFS

/// The zip, tar and libarchive-via-bsdtar formats, opened through `ArchiveFS`.
public struct NativeArchiveBackend: ArchiveBackend {
    public let backendID = "native"

    public init() {}

    /// Zip proper plus the many specialisations that are zips underneath.
    ///
    /// Office and OpenDocument files are zips too and are deliberately absent: a
    /// text search that descends into them drowns in `word/document.xml`. Anyone
    /// who wants that adds the extension under Settings ▸ Extra archive
    /// extensions, which already exists and now reaches the search as well.
    public static let zipFamily: Set<String> =
        ["zip", "zipx", "jar", "war", "ear", "apk", "aar", "ipa", "jmod", "xpi", "crx", "epub"]

    /// Tar, plain and compressed. The single-extension aliases and the two-part
    /// forms are both needed: `x.tgz` and `x.tar.gz` are the same archive spelled
    /// two ways, and `pathExtension` only ever sees the second half of the second one.
    public static let tarFamily: Set<String> =
        ["tar", "tgz", "taz", "tbz", "tbz2", "txz", "tzst"]

    public static let tarCompoundSuffixes: Set<String> =
        [".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tar.z"]

    /// The whole built-in vocabulary, in one value.
    ///
    /// `splitFirstPartStems` carries `name.zip.001` (F-382): the rule used to live in
    /// the panel, which is why a split zip was browsable but never searchable, even
    /// though `ZipVolumes.open` gathers the sibling parts for whoever opens it.
    public static var nameSet: ArchiveNameSet {
        ArchiveNameSet(extensions: zipFamily
                        .union(tarFamily)
                        .union(ShellArchiveSource.handledExtensions),
                       compoundSuffixes: tarCompoundSuffixes,
                       splitFirstPartStems: ["zip"])
    }

    /// Something worth saying about an archive that opened anyway.
    ///
    /// An encrypted archive is searched by name and not by content: the member names are
    /// stored in clear and still match, and every attempt to read the bytes throws and is
    /// swallowed. That used to be the whole of it — the term could be sitting in a file
    /// the search had walked straight past, and nothing said so.
    ///
    /// Only for a background walk. Enter prompts for a password and then knows the answer;
    /// a walk must never prompt, so all it can do is report.
    private static func warning(for fs: ArchiveFS, intent: ArchiveOpenIntent) -> SearchNotice.Reason? {
        guard intent == .background, fs.hasEncryptedEntries, !fs.passwordIsValid() else { return nil }
        return .needsPassword
    }

    public func nameSet() async -> ArchiveNameSet { Self.nameSet }

    /// All of it: the built-in readers are compiled in, so nothing has to load first.
    public var staticNameSet: ArchiveNameSet { Self.nameSet }

    /// What a gzip-wrapped tar may expand to during a background walk.
    ///
    /// Compressed size says almost nothing here — 200 MB of tar.gz is routinely 2 GB of
    /// tar — so the on-disk ceiling the registry applies is not enough on its own.
    public static let backgroundMaxExpandedBytes: Int64 = 512 * 1024 * 1024

    public func open(localFile: URL, intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome {
        // An archive already open for this exact file (same size, mtime and inode) is
        // handed back rather than parsed again — entering an archive, leaving it and
        // entering it again used to re-read the whole central directory each time, and
        // so did unpacking it afterwards.
        if let cached = ArchiveDirectoryCache.shared.archive(for: localFile) {
            return .opened(OpenedArchive(fs: cached, localURL: localFile, isTemporary: false,
                                         memberAccessCost: cached.memberAccessCost,
                                         backendID: backendID,
                                         warning: Self.warning(for: cached, intent: intent)),
                           dispose: {})
        }
        let ceiling = intent == .background ? Self.backgroundMaxExpandedBytes : 0
        let limits = TarReader.Limits(maxExpandedBytes: ceiling)
        if let fs = ArchiveFS(archiveFileURL: localFile, fsID: "zip:\(localFile.path)",
                              tarLimits: limits) {
            // Only what a person is looking at is worth keeping. A walk meets archives it
            // will never see again, and remembering each one would let a single search
            // pin its own byte budget for the rest of the session.
            if intent == .interactive { ArchiveDirectoryCache.shared.store(fs, for: localFile) }
            return .opened(OpenedArchive(fs: fs, localURL: localFile, isTemporary: false,
                                         memberAccessCost: fs.memberAccessCost,
                                         backendID: backendID,
                                         warning: Self.warning(for: fs, intent: intent)),
                           dispose: {})
        }
        // Distinguish declining from not recognising: if this is a gzip stream whose own
        // trailer says it expands past the ceiling, say *that* rather than "unreadable".
        // Re-read is bounded — the last four bytes of a mapping.
        if ceiling > 0, let mapped = try? Data(contentsOf: localFile, options: [.mappedIfSafe]),
           mapped.count > 18, mapped[mapped.startIndex] == 0x1f, mapped[mapped.startIndex + 1] == 0x8b,
           let declared = TarReader.declaredExpandedSize(mapped), declared > ceiling {
            return .skipped(.tooLarge(declared, limit: ceiling))
        }
        return .notAnArchive
    }
}
