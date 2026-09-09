// SPDX-License-Identifier: Apache-2.0
// SyncRunStore.swift - Where a run's record lives, how much of it is kept, and what goes first.
//
// One JSONL file per **run**, which is the unit that is written, listed, acted on, forgotten and
// trimmed. The two neighbours in this project each answer a different question and neither shape
// fits:
//
//   * `AuditLog` keeps one capped file and rewrites it whole on every append. A twenty-thousand-row
//     run written every hour would mean rewriting megabytes hourly, its cap counts *lines*, so one
//     large run would evict every other run's history, and one bad byte would cost the lot.
//   * `SyncStateStore` keeps one file per folder pair, which is right there because the pair is what
//     a record describes. Here it would mean a pair synced hourly growing one file without bound,
//     and trimming inside it means rewriting a large file — the very cost that made that file JSONL.
//
// One file per run makes writing a single atomic create, trimming a `removeItem`, and listing a
// bounded read of each header (`FileHeadLine`, which exists because the claim was made before it
// was true). One unreadable file costs one run.
//
// And unlike `sync-state`, trimming here is *correct* rather than merely tolerable. That store
// refuses to reap because losing a record changes what the next run does — the pair silently stops
// carrying deletions across. A run log is inert: losing it takes away no behaviour, only the offer
// to put something back. That difference is the whole justification, and it is why the numbers below
// are constants rather than a question in the settings.

import Foundation

public final class SyncRunStore {

    /// Above this many planned rows, only the rows that did not run smoothly are written.
    ///
    /// Not the state store's 200 000: a line here carries two absolute paths and a dozen fields, so
    /// it is roughly ten times the size of a state line, and this is a *per run* cost paid as often
    /// as somebody synchronises. What is kept above the cap is every deletion, every refusal and
    /// every failure — the rows a person comes looking for — and the header says the rest are
    /// missing, in the voice `SyncStateStore`'s own refusal uses.
    public static let maximumItems = 20_000
    /// How many runs are kept. Older files go, oldest first, as each new one is written.
    public static let maximumRuns = 200
    /// …and a byte ceiling, because a hundred large runs is a different quantity from a hundred
    /// small ones and only one of the two numbers can be the binding one.
    ///
    /// Not covered by a test, said here rather than left to be assumed: reaching it means writing
    /// sixty-four megabytes of records, which is not a unit test. It shares its loop and its
    /// ordering with `maximumRuns`, and that half *is* pinned — so what is unproven is the
    /// arithmetic of the ceiling, not which file the trim reaches for.
    public static let maximumBytes = 64 * 1024 * 1024

    private let directory: URL

    public init(directory: URL) { self.directory = directory }

    private func file(_ id: String) -> URL {
        directory.appendingPathComponent(id + ".jsonl")
    }

    // MARK: - Writing

    public enum SaveOutcome: Sendable, Equatable {
        case written(id: String, items: Int)
        /// Nothing was written, and why. Said out loud rather than swallowed: a run that left no
        /// record is a run nothing can be put back from, and the reader has no other way to find out.
        case refused(reason: String)
    }

    /// Write one run's record.
    ///
    /// The header is stamped with the current version and with the counts of what is actually being
    /// written, so `itemsListed` and the file can never disagree.
    @discardableResult
    public func write(header: SyncRunHeader, items: [SyncRunItem]) -> SaveOutcome {
        var stamped = header
        stamped.version = SyncRunHeader.currentVersion

        var kept = items
        if items.count > Self.maximumItems {
            kept = items.filter { !$0.isPlainSuccess }
            stamped.itemsListed = false
            stamped.undoUnavailable = "this run had \(items.count) items, more than the "
                + "\(Self.maximumItems) a full record is kept for — every deletion and every "
                + "problem is listed, the copies that went through are not"
        }

        let id = SyncRunRecord.identifier(runAt: stamped.runDate,
                                          leftRoot: stamped.leftRoot, rightRoot: stamped.rightRoot)
        // A run in the same second as an existing one gets its own file rather than replacing it —
        // `AuditLog`'s writer nudges its timestamp for the same reason. Two windows on one pair is
        // the case; it is not worth a lock, but it is worth not losing one of them.
        var unique = id
        var suffix = 2
        while FileManager.default.fileExists(atPath: file(unique).path) {
            unique = "\(id)-\(suffix)"
            suffix += 1
        }

        let encoder = Self.encoder()
        guard let headerData = try? encoder.encode(stamped) else {
            return .refused(reason: "the record could not be encoded")
        }
        var out = headerData
        out.append(UInt8(ascii: "\n"))
        for item in kept {
            guard let line = try? encoder.encode(item) else { continue }
            out.append(line)
            out.append(UInt8(ascii: "\n"))
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try out.write(to: file(unique), options: .atomic)
        } catch {
            return .refused(reason: error.localizedDescription)
        }
        trim()
        return .written(id: unique, items: kept.count)
    }

    /// Drop the oldest whole files until both ceilings hold.
    ///
    /// At write time, which is where `AuditLog.append` trims too. Sorting is by filename, and the
    /// filename begins with a fixed-width UTC timestamp, so this needs no reads at all.
    private func trim() {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        var files = names.filter { $0.hasSuffix(".jsonl") }.sorted()      // oldest first
        func size(_ name: String) -> Int {
            (try? fm.attributesOfItem(atPath: directory.appendingPathComponent(name).path)[.size]
                as? NSNumber)??.intValue ?? 0
        }
        var total = files.reduce(0) { $0 + size($1) }
        while files.count > Self.maximumRuns || (total > Self.maximumBytes && files.count > 1) {
            let oldest = files.removeFirst()
            total -= size(oldest)
            try? fm.removeItem(at: directory.appendingPathComponent(oldest))
        }
    }

    // MARK: - Reading

    /// One stored run, enough to list it and to decide whether to open it.
    public struct Run: Sendable, Equatable {
        /// The filename's stem — what every other call here takes.
        public let id: String
        public let header: SyncRunHeader
        public let byteSize: Int

        public init(id: String, header: SyncRunHeader, byteSize: Int) {
            self.id = id
            self.header = header
            self.byteSize = byteSize
        }

        /// A header that would not parse. Listed rather than hidden, `SyncStateStore.records()`'s
        /// rule: a record the app knows about and will not name is worse than an ugly row.
        public var isReadable: Bool { header.version > 0 }
    }

    /// Every run kept here, newest first.
    ///
    /// Header lines only, through `FileHeadLine`, so listing two hundred runs does not mean reading
    /// two hundred plans.
    public func runs() -> [Run] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return [] }
        var out: [Run] = []
        for name in names where name.hasSuffix(".jsonl") {
            let url = directory.appendingPathComponent(name)
            let id = String(name.dropLast(".jsonl".count))
            let bytes = (try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)??.intValue ?? 0
            guard let line = FileHeadLine.read(at: url),
                  let header = try? Self.decoder().decode(SyncRunHeader.self, from: line),
                  header.version > 0
            else {
                out.append(Run(id: id,
                               header: SyncRunHeader(version: 0, runAt: 0, leftRoot: "",
                                                     rightRoot: "", mode: ""),
                               byteSize: bytes))
                continue
            }
            out.append(Run(id: id, header: header, byteSize: bytes))
        }
        // By id, not by `runAt`: the id is the timestamp, and an unreadable file has no `runAt` at
        // all — sorting by that would bury it at the bottom, which is the one row somebody is
        // looking for.
        return out.sorted { $0.id > $1.id }
    }

    /// The rows of one run.
    ///
    /// Per-line tolerant: one bad line costs one row. Empty for a file whose header will not read —
    /// a record whose header is gone cannot be trusted to say what its rows mean.
    public func items(id: String) -> [SyncRunItem] {
        guard let data = try? Data(contentsOf: file(id)) else { return [] }
        var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        guard let headerLine = lines.first,
              let header = try? Self.decoder().decode(SyncRunHeader.self, from: Data(headerLine)),
              header.version > 0, header.version <= SyncRunHeader.currentVersion
        else { return [] }
        lines.removeFirst()
        let decoder = Self.decoder()
        return lines.compactMap { line in
            guard let item = try? decoder.decode(SyncRunItem.self, from: Data(line)),
                  !item.relativePath.isEmpty else { return nil }
            return item
        }
    }

    /// The header of one run, without its rows.
    public func header(id: String) -> SyncRunHeader? {
        guard let line = FileHeadLine.read(at: file(id)),
              let header = try? Self.decoder().decode(SyncRunHeader.self, from: line),
              header.version > 0 else { return nil }
        return header
    }

    // MARK: - Acting on it

    /// Mark these rows as acted on, so nothing is done to them twice.
    ///
    /// `AuditLog.markUndone`'s semantics: the row stays, loses its offer and gains its reason. The
    /// record of what a run did has to survive undoing part of it — otherwise the second undo has
    /// nothing to refuse.
    ///
    /// Rewrites the whole file, which is affordable precisely because a run's file is bounded by
    /// `maximumItems` — the reason `AuditLog` can do the same and `sync-state` cannot.
    @discardableResult
    public func markUndone(id: String, paths: Set<String>, at when: Date = Date(),
                           reason: String) -> Int {
        guard !paths.isEmpty, let header = header(id: id) else { return 0 }
        let rows = items(id: id)
        var marked = 0
        let updated = rows.map { row -> SyncRunItem in
            guard paths.contains(row.relativePath), row.undoneAt == nil else { return row }
            var copy = row
            copy.undoneAt = when.timeIntervalSince1970
            copy.undoUnavailable = reason
            marked += 1
            return copy
        }
        guard marked > 0 else { return 0 }

        let encoder = Self.encoder()
        guard let headerData = try? encoder.encode(header) else { return 0 }
        var out = headerData
        out.append(UInt8(ascii: "\n"))
        for item in updated {
            guard let line = try? encoder.encode(item) else { continue }
            out.append(line)
            out.append(UInt8(ascii: "\n"))
        }
        guard (try? out.write(to: file(id), options: .atomic)) != nil else { return 0 }
        return marked
    }

    /// Forget one run. Removing the file rather than emptying it, so "no record" stays one state
    /// instead of two — `RecentLines.clear`'s rule, which `SyncStateStore.forget` follows too.
    @discardableResult
    public func forget(id: String) -> Bool {
        (try? FileManager.default.removeItem(at: file(id))) != nil
    }

    /// Forget every run. The whole of the answer to "this holds the absolute paths of both trees":
    /// there is no age setting and no switch to turn the record off, there is this.
    @discardableResult
    public func forgetAll() -> Int {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return 0 }
        var gone = 0
        for name in names where name.hasSuffix(".jsonl") {
            if (try? fm.removeItem(at: directory.appendingPathComponent(name))) != nil { gone += 1 }
        }
        return gone
    }

    /// `.sortedKeys` so two runs' files are comparable line by line; no date strategy at all,
    /// because every time in this record is a `Double` — see `SyncRunRecord`'s header.
    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }

    private static func decoder() -> JSONDecoder { JSONDecoder() }
}
