// SPDX-License-Identifier: Apache-2.0
// SyncStateStore.swift - Where a pair's record lives, and what happens when it cannot be read.
//
// One file per pair, in a directory of its own, following the argument `MacroStore` writes down and
// `ConfigPaths` repeats: a single unparseable entry there once cost *every* macro, so each unit gets
// its own file with a name derived from its identity. For a synchronisation record that argument is
// stronger, because losing one is not an inconvenience — a run with no record deletes nothing, so a
// lost record silently turns the mode off.
//
// JSONL and not one JSON object, for two reasons that pull the same way. A tree of a hundred thousand
// paths would be encoded and rewritten whole on every run. And one bad byte in an object costs the
// pair's entire history, while one bad line costs one path — and a path with no record cannot be
// deleted, so the failure direction is right by construction. `AuditLog` is the precedent for the
// format and for the per-line tolerance.
//
// The one thing worth guarding hard is the header: it is the line whose loss would be catastrophic,
// and it is the one line `SyncPresetStore`'s rule applies to — refuse to overwrite a file that
// exists, is not empty, and does not parse.
//
// And the reading has to distinguish two things that `[:]` cannot: "the last run recorded nothing"
// and "I have no idea what the last run saw". A deletion may follow from the first and never from
// the second.

import Foundation

/// What reading a pair's record produced.
public enum SyncStateLoad: Sendable, Equatable {
    /// No usable record. **No deletion may be derived from this** — it is not "nothing was there",
    /// it is "nothing is known". The reason is carried so the window can say which it was.
    case unknown(reason: String)
    case known(header: SyncStateHeader, entries: [String: SyncStateEntry])

    public var header: SyncStateHeader? {
        if case .known(let header, _) = self { return header }
        return nil
    }

    public var entries: [String: SyncStateEntry] {
        if case .known(_, let entries) = self { return entries }
        return [:]
    }

    public var isKnown: Bool {
        if case .known = self { return true }
        return false
    }
}

public final class SyncStateStore {
    /// Above this many paths no record is written, and the caller is told so.
    ///
    /// A stated refusal rather than a silent slowdown, in the voice `AuditLog.unavailableReason`
    /// uses: without a cap the feature makes every run of a very large pair slower to no visible
    /// purpose, and a *truncated* record would be far worse than none, because the paths it left out
    /// would read as deletions.
    public static let maximumEntries = 200_000

    private let directory: URL

    public init(directory: URL) { self.directory = directory }

    private func url(leftRoot: String, rightRoot: String) -> URL {
        directory.appendingPathComponent(SyncState.key(leftRoot: leftRoot, rightRoot: rightRoot)
                                            + ".jsonl")
    }

    // MARK: - Reading

    /// The record for this pair, with the sides oriented the way the caller holds them.
    ///
    /// A record written before the user pressed "Swap sides" has the two roots the other way round.
    /// The key is over the sorted pair so it is still found; the header says which root was on the
    /// left, and every entry is exchanged on the way in when that no longer matches. Without this,
    /// swapping the sides would read every left as a right and propose the exact opposite of the
    /// truth.
    public func load(leftRoot: String, rightRoot: String) -> SyncStateLoad {
        let file = url(leftRoot: leftRoot, rightRoot: rightRoot)
        guard let data = try? Data(contentsOf: file), !data.isEmpty else {
            return .unknown(reason: "no record of a previous run for these two folders")
        }
        var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        guard let headerLine = lines.first else {
            return .unknown(reason: "the record for these two folders is empty")
        }
        lines.removeFirst()
        let decoder = Self.decoder()
        guard let header = try? decoder.decode(SyncStateHeader.self, from: Data(headerLine)),
              header.version > 0 else {
            return .unknown(reason: "the record for these two folders could not be read")
        }
        guard header.version <= SyncStateHeader.currentVersion else {
            return .unknown(reason: "the record was written by a newer version of the app")
        }
        // The collision check the roots are in the header for.
        let wantA = (leftRoot as NSString).standardizingPath.precomposedStringWithCanonicalMapping
        let wantB = (rightRoot as NSString).standardizingPath.precomposedStringWithCanonicalMapping
        guard Set([header.leftRoot, header.rightRoot]) == Set([wantA, wantB]) else {
            return .unknown(reason: "the record found for these two folders names different ones")
        }
        let swapped = header.leftRoot != wantA

        var entries: [String: SyncStateEntry] = [:]
        entries.reserveCapacity(lines.count)
        for line in lines {
            // One bad line costs one path. `compactMap`'s shape, from `AuditLog.load`.
            guard let entry = try? decoder.decode(SyncStateEntry.self, from: Data(line)),
                  !entry.relativePath.isEmpty else { continue }
            let oriented = swapped ? entry.swapped : entry
            entries[oriented.relativePath] = oriented
        }
        let orientedHeader = swapped
            ? headerWithSidesExchanged(header)
            : header
        return .known(header: orientedHeader, entries: entries)
    }

    private func headerWithSidesExchanged(_ header: SyncStateHeader) -> SyncStateHeader {
        var out = header
        out.leftRoot = header.rightRoot
        out.rightRoot = header.leftRoot
        out.leftRootInode = header.rightRootInode
        out.rightRootInode = header.leftRootInode
        return out
    }

    // MARK: - Writing

    public enum SaveOutcome: Sendable, Equatable {
        case written(entries: Int)
        /// Nothing was written, and why. The caller has to say so: silently keeping no record turns
        /// the mode off on the next run with no explanation.
        case refused(reason: String)
    }

    /// Replace this pair's record.
    ///
    /// Refuses when the file that is there cannot be read, for the reason `SyncPresetStore.upsert`
    /// records and one degree sharper: `load` answers `unknown` both for "no record" and for "could
    /// not read it", so writing over the second would throw away a history that a later version — or
    /// a fixed bug — might have been able to use.
    @discardableResult
    public func save(header: SyncStateHeader, entries: [SyncStateEntry]) -> SaveOutcome {
        guard entries.count <= Self.maximumEntries else {
            return .refused(reason: "\(entries.count) paths is more than a record is kept for "
                            + "(\(Self.maximumEntries)) — deletions will not be propagated for this pair")
        }
        let file = url(leftRoot: header.leftRoot, rightRoot: header.rightRoot)
        if let existing = try? Data(contentsOf: file), !existing.isEmpty {
            let firstLine = existing.split(separator: UInt8(ascii: "\n"),
                                           maxSplits: 1, omittingEmptySubsequences: true).first
            let readable = firstLine.flatMap {
                try? Self.decoder().decode(SyncStateHeader.self, from: Data($0))
            }
            guard readable?.version ?? 0 > 0 else {
                return .refused(reason: "the existing record for these two folders could not be "
                                + "read, and is left alone rather than overwritten")
            }
        }

        var stamped = header
        stamped.version = SyncStateHeader.currentVersion
        stamped.entryCount = entries.count

        let encoder = Self.encoder()
        guard let headerData = try? encoder.encode(stamped) else {
            return .refused(reason: "the record could not be encoded")
        }
        var out = headerData
        out.append(UInt8(ascii: "\n"))
        for entry in entries {
            guard let line = try? encoder.encode(entry) else { continue }
            out.append(line)
            out.append(UInt8(ascii: "\n"))
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try out.write(to: file, options: .atomic)
        } catch {
            return .refused(reason: error.localizedDescription)
        }
        return .written(entries: entries.count)
    }

    /// Forget this pair. Deleting the file rather than writing an empty one, so that "no record"
    /// stays one state instead of two — the same rule `RecentLines.clear` and `CommentStore` follow.
    @discardableResult
    public func forget(leftRoot: String, rightRoot: String) -> Bool {
        (try? FileManager.default.removeItem(at: url(leftRoot: leftRoot, rightRoot: rightRoot))) != nil
    }

    /// One line per record, so `.sortedKeys` is what makes a file comparable between runs, and
    /// `.iso8601` covers the header's own timestamp. The per-path times are a `Double` and do not
    /// depend on this — see `SyncStateSide.modifiedUnix`.
    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
