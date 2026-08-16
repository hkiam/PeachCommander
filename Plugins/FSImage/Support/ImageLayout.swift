// SPDX-License-Identifier: Apache-2.0
// ImageLayout.swift — what is actually inside a firmware image, found by looking.
//
// Every other driver here is handed an offset by something that already knows: byte 0
// for a bare filesystem, a partition entry for a disk image. This file exists for the
// case where nothing knows. A router firmware file is a vendor header, a bootloader, a
// kernel and a rootfs concatenated at offsets the vendor chose and wrote down nowhere.
// There is no table to read. The only way in is to search the bytes for the filesystems
// themselves.
//
// **Confirmation is the whole design.** A four-byte pattern occurs by chance in
// compressed data constantly — FAT's is two bytes, and a 64 MB image contains a
// thousand of them. So a pattern match is never an answer here, only a question: each
// candidate offset is confirmed by *actually opening the filesystem there*, using the
// same driver, the same superblock checks and the same structural validation that a
// normal open would use. A coincidence fails that, and fails it cheaply. This is what
// makes scanning for a two-byte signature a reasonable thing to do rather than a
// generator of nonsense.
//
// The second half is honesty about extents. A driver that records its own length gets
// a window that ends where it ends, so a carved SquashFS cannot read into the kernel
// that follows it. JFFS2 and UBIFS record no length at all, and rather than inventing
// one, a region from those formats is reported as running to whatever comes next.
//
// What is left over — the runs no filesystem claimed — is examined for the blob
// signatures in `BlobSignature` and otherwise reported as plain unknown data. None of
// it is hidden: the bootloader is almost always in one of those runs, and somebody
// examining a device needs to be able to copy it out.

import Foundation

/// One contiguous run of an image, and what it turned out to be.
struct LayoutRegion {
    let offset: Int64
    let length: Int64
    let kind: Kind

    enum Kind {
        /// A filesystem that opened successfully at this offset.
        case filesystem(any ImageFilesystemDriver)
        /// A recognised non-filesystem blob — a kernel, a device tree, a bootloader.
        case blob(IdentifiedBlob)
        /// Bytes nothing claimed. Still listed, still extractable.
        case unknown
    }

    var isFilesystem: Bool {
        if case .filesystem = kind { return true }
        return false
    }

    /// What the region is called in a listing and in the report.
    var typeName: String {
        switch kind {
        case .filesystem(let driver): return type(of: driver).id
        case .blob(let blob): return blob.name
        case .unknown: return "unknown.bin"
        }
    }

    /// What the region is called in a panel: `0x00230044-squashfs`.
    ///
    /// The offset is in the name because in a carved image it is the identifying fact —
    /// there are no names on disk to use instead, two regions of one type are told apart
    /// only by where they begin, and anyone moving on to `dd` needs the number anyway.
    ///
    /// Fixed-width hex, so sorting the names lexically sorts them by offset. Whether a
    /// given listing does sort them that way is the host's business — the panel orders a
    /// virtual filesystem its own way — but a name that cannot be sorted meaningfully at
    /// all would be this file's fault, and this one can.
    var entryName: String {
        "\(String(format: "0x%08llx", offset))-\(typeName)"
    }

    /// The longer line for the report.
    var describedAs: String {
        switch kind {
        case .filesystem(let driver): return driver.formatDescription
        case .blob(let blob): return blob.description
        case .unknown: return "unrecognised data"
        }
    }
}

enum ImageLayout {
    /// Ceilings for the scan itself. A pattern search over attacker-supplied bytes can
    /// be made to produce an unbounded number of candidates — a file that is nothing
    /// but repeated FAT boot signatures is 128 bytes of effort to build — so the work
    /// is capped rather than trusted to be reasonable.
    enum Limits {
        /// Pattern hits considered. Past this the image is not a firmware layout.
        static let maxCandidates = 200_000
        /// Regions reported. A real firmware image has fewer than twenty.
        static let maxRegions = 4096
        /// Read granularity for the pattern search.
        static let scanChunk = 4 << 20
        /// A confirmed filesystem shorter than this is treated as a false positive.
        /// Nothing useful lives in 512 bytes, and the smallest real image here is a
        /// 4 KB cramfs.
        static let minFilesystemLength: Int64 = 512

        /// Largest file this will search end to end.
        ///
        /// Not a memory limit — the search reads in chunks and holds nothing — but a
        /// bound on how long a *wrong guess* may take. Carving is the last resort, so it
        /// is reached for every file the host asks about whose extension matched nothing,
        /// including the video somebody pressed Enter on by accident.
        ///
        /// Measured rather than guessed: 512 MB of pure entropy — the worst case, since
        /// random bytes produce the most chance signature hits, and compressed media is
        /// exactly that — is declined in about 1.3 seconds. A gigabyte would be two and a
        /// half, which is long enough to read as a hang.
        ///
        /// It also matches what the technique is for. This finds filesystems in *flash*
        /// images, and flash is not this large; the biggest embedded parts in service are
        /// a quarter of it. Anything bigger is a whole-disk dump, which carries a
        /// partition table describing itself — `PartitionedDriver`'s job, at no scanning
        /// cost at all.
        static let maxCarveLength: Int64 = 512 << 20
    }

    /// How much of `reader` a scan will actually search.
    ///
    /// `maxCarveLength` bounds the *carving driver*, and for a while that was mistaken
    /// for bounding the search. It is not: two other callers reach the same code with no
    /// ceiling at all. `PartitionedDriver` searches the runs outside its partitions, and
    /// a whole-drive dump is mostly one such run — 500 GB of unallocated tail at the
    /// measured 400 MB/s is twenty minutes of frozen panel, where before this feature
    /// existed the image opened instantly. The layout report searches whatever it is
    /// pointed at, from a menu command with no progress and no cancel.
    ///
    /// So the ceiling belongs here, where the searching happens, rather than at one
    /// entry point. What lies past it is still reported — as one unclaimed region, which
    /// is what it is — and `LayoutReport` says plainly that the search stopped early
    /// rather than letting a short list read as a complete one.
    static func scannedSpan(of reader: ImageReader) -> Int64 {
        min(reader.count, Limits.maxCarveLength)
    }

    /// Find everything in `reader`, in offset order, covering the file end to end.
    ///
    /// The returned regions are contiguous and non-overlapping, and for any image that is
    /// not a deliberate attack they cover it end to end: every byte belongs to exactly one
    /// of them. That is the point — a layout with holes invites the reader to assume the
    /// holes are empty, and in a firmware image they are usually the bootloader. The one
    /// exception is an image contrived to produce more than `maxRegions` of them, which is
    /// truncated at the ceiling and so stops short of the end.
    static func scan(_ reader: ImageReader) throws -> [LayoutRegion] {
        let confirmed = try confirmFilesystems(in: reader, candidates: findCandidates(in: reader))
        return try fillGaps(around: confirmed, in: reader)
    }

    // MARK: - The pattern search
    //
    // One routine serves both users: the filesystem hunt over the whole image, and the
    // blob hunt inside a gap. They differ only in their patterns and their stride.

    /// Where a pattern matched, and which one.
    private struct Hit {
        let offset: Int64
        let patternIndex: Int
    }

    /// Find every occurrence of any of `patterns` in `[from, to)`.
    ///
    /// `stride` is the step between examined positions. Filesystems are searched at
    /// every byte because a real one turns up at an arbitrary offset — the SquashFS in
    /// a firmware file starts wherever the kernel before it happened to end. Blobs are
    /// searched at four-byte alignment, which is true of every header format here and
    /// cuts the chance hits from the short compressed-stream magics by four.
    private static func search(_ reader: ImageReader, patterns: [[UInt8]],
                               from: Int64, to: Int64, stride: Int64,
                               limit: Int) throws -> [Hit] {
        guard !patterns.isEmpty, to > from else { return [] }
        let longest = patterns.map(\.count).max() ?? 0
        guard longest > 0 else { return [] }

        // One lookup per position decides whether any pattern could start there.
        // Without it the inner loop would compare every pattern at every offset, which
        // for twenty patterns over a 64 MB image is a billion comparisons.
        var mayStart = [Bool](repeating: false, count: 256)
        for pattern in patterns {
            mayStart[Int(pattern[0])] = true
        }

        var hits: [Hit] = []
        var chunkStart = from
        while chunkStart < to {
            // Chunks overlap by one pattern's length so a magic straddling the boundary
            // is still found; the de-duplication in the caller removes the double hit.
            let wanted = Int(min(Int64(Limits.scanChunk + longest), to - chunkStart))
            let buffer = try reader.bytes(at: chunkStart, count: wanted)

            try buffer.withUnsafeBufferPointer { raw in
                guard let base = raw.baseAddress, raw.count >= longest else { return }
                // Bounded by the *longest* pattern, so the final few bytes of the span
                // go unexamined even for shorter ones. Harmless rather than overlooked:
                // chunks overlap by that same length, so only the true end of the span
                // is affected, and a filesystem whose magic sits in the last handful of
                // bytes has no room to be a filesystem — `minFilesystemLength` refuses
                // it a moment later anyway.
                let usable = raw.count - longest + 1
                // Keep the stride aligned to absolute file offsets, not to chunk
                // starts, or a pattern at an aligned offset is missed in every chunk
                // whose own start is not aligned.
                var position = Int((stride - chunkStart % stride) % stride)
                while position < usable {
                    defer { position += Int(stride) }
                    guard mayStart[Int(base[position])] else { continue }
                    for (index, pattern) in patterns.enumerated()
                    where matches(base, at: position, pattern) {
                        hits.append(Hit(offset: chunkStart + Int64(position), patternIndex: index))
                        if hits.count > limit {
                            throw ImageError.limitExceeded(limit: "layout scan hits (\(limit))")
                        }
                    }
                }
            }
            chunkStart += Int64(Limits.scanChunk)
        }
        return hits
    }

    private static func matches(_ base: UnsafePointer<UInt8>, at position: Int,
                                _ magic: [UInt8]) -> Bool {
        for (index, byte) in magic.enumerated() where base[position + index] != byte {
            return false
        }
        return true
    }

    // MARK: - Step 1: filesystem candidates

    /// A pattern hit, before anything has been confirmed.
    private struct Candidate {
        let offset: Int64
        /// Index into `DriverRegistry.all`, so ties at one offset resolve in registry
        /// order rather than in whatever order the patterns happened to match.
        let driverIndex: Int
    }

    /// Every signature of every driver, flattened once.
    private struct Pattern {
        let magic: [UInt8]
        let offsetInFilesystem: Int64
        let driverIndex: Int
    }

    private static var patterns: [Pattern] {
        DriverRegistry.all.enumerated().flatMap { index, driver in
            driver.carveSignatures.map {
                Pattern(magic: $0.magic, offsetInFilesystem: $0.offsetInFilesystem,
                        driverIndex: index)
            }
        }
    }

    private static func findCandidates(in reader: ImageReader) throws -> [Candidate] {
        let patterns = self.patterns
        let hits = try search(reader, patterns: patterns.map(\.magic),
                              from: 0, to: scannedSpan(of: reader), stride: 1,
                              limit: Limits.maxCandidates)

        var candidates = hits.compactMap { hit -> Candidate? in
            let pattern = patterns[hit.patternIndex]
            // The match is somewhere *inside* the filesystem — ext's magic is 1080 bytes
            // in, Btrfs's 65600 — so the filesystem starts before it, not at it.
            let start = hit.offset - pattern.offsetInFilesystem
            guard start >= 0 else { return nil }
            return Candidate(offset: start, driverIndex: pattern.driverIndex)
        }

        // Offset order is what the confirmation walk needs; the registry index breaks
        // ties so two formats matching one offset are tried in a defined order.
        candidates.sort { ($0.offset, $0.driverIndex) < ($1.offset, $1.driverIndex) }
        var unique: [Candidate] = []
        for candidate in candidates
        where unique.last.map({ $0.offset != candidate.offset
                                || $0.driverIndex != candidate.driverIndex }) ?? true {
            unique.append(candidate)
        }
        return unique
    }

    // MARK: - Step 2: confirmation

    /// A filesystem that opened, with the extent it turned out to occupy.
    private struct Confirmed {
        let offset: Int64
        /// Nil for a format that records no length — resolved against the next region.
        var length: Int64?
        let driver: any ImageFilesystemDriver
    }

    private static func confirmFilesystems(in reader: ImageReader,
                                           candidates: [Candidate]) throws -> [LayoutRegion] {
        var confirmed: [Confirmed] = []
        /// Where the last accepted filesystem ended, when it recorded a length.
        var cursor: Int64 = 0
        /// The driver of an accepted region whose extent is unknown. Every later
        /// candidate from that same driver is skipped until something else is accepted:
        /// a log-structured filesystem is a run of thousands of nodes, each of which
        /// carries the node magic, so without this one JFFS2 image would be reported as
        /// several thousand overlapping filesystems.
        var openEndedDriver: String?

        for candidate in candidates {
            guard candidate.offset >= cursor else { continue }
            let type = DriverRegistry.all[candidate.driverIndex]
            if let openEndedDriver, type.id == openEndedDriver { continue }

            let remaining = reader.count - candidate.offset
            guard remaining >= Limits.minFilesystemLength else { continue }
            guard let window = try? ImageReader(path: reader.path,
                                                windowOffset: reader.windowOffset + candidate.offset,
                                                windowLength: remaining),
                  type.probe(window) else { continue }

            // Reopen bounded by the declared length so the filesystem cannot read past
            // its own end into whatever follows it in the image.
            let declared = type.byteLength(window).map { min($0, remaining) }
            var opened = window
            if let declared, declared >= Limits.minFilesystemLength, declared < remaining {
                guard let bounded = try? ImageReader(
                    path: reader.path,
                    windowOffset: reader.windowOffset + candidate.offset,
                    windowLength: declared) else { continue }
                opened = bounded
            }
            guard let driver = try? type.init(reader: opened) else { continue }

            let length = declared.flatMap { $0 >= Limits.minFilesystemLength ? $0 : nil }
            confirmed.append(Confirmed(offset: candidate.offset, length: length, driver: driver))
            if let length {
                cursor = candidate.offset + length
                openEndedDriver = nil
            } else {
                // Extent unknown: let other formats be found after it, but not this one.
                cursor = candidate.offset + Limits.minFilesystemLength
                openEndedDriver = type.id
            }
            guard confirmed.count <= Limits.maxRegions else {
                throw ImageError.limitExceeded(limit: "layout regions (\(Limits.maxRegions))")
            }
        }

        // An open-ended region runs to whatever was found next, or to the end of the file.
        return confirmed.enumerated().map { index, region in
            let end = region.length.map { region.offset + $0 }
                ?? (index + 1 < confirmed.count ? confirmed[index + 1].offset : reader.count)
            return LayoutRegion(offset: region.offset, length: max(0, end - region.offset),
                                kind: .filesystem(region.driver))
        }
    }

    // MARK: - Step 3: everything in between

    /// Turn the runs between confirmed filesystems into named blobs and unknown data,
    /// so the returned list covers the image with no holes.
    private static func fillGaps(around filesystems: [LayoutRegion],
                                 in reader: ImageReader) throws -> [LayoutRegion] {
        var result: [LayoutRegion] = []
        var cursor: Int64 = 0
        for region in filesystems {
            if region.offset > cursor {
                result += try describe(reader, from: cursor, to: region.offset)
            }
            result.append(region)
            cursor = region.offset + region.length
        }
        if cursor < reader.count {
            result += try describe(reader, from: cursor, to: reader.count)
        }
        return Array(result.prefix(Limits.maxRegions))
    }

    /// Split one run of unclaimed bytes into the blobs it contains.
    ///
    /// Used for the gaps between carved filesystems and, by `PartitionedDriver`, for the
    /// gaps between partitions — the same question in both cases, and the bootloader is
    /// usually the answer.
    ///
    /// Two rules, and the distinction between them is what keeps this useful rather than
    /// noisy. The structured headers — uImage, device tree, Android boot, TRX, ELF — are
    /// searched for **anywhere** in the run, because a kernel sitting behind a vendor
    /// header of unknown size is the ordinary case and finding it only at the very start
    /// would miss nearly all of them. The bare compressed streams are honoured **only
    /// where a region begins**, because their magics are three and four bytes long, they
    /// occur constantly inside compressed data, and treating every chance hit as a
    /// boundary chops a bootloader into a dozen invented "gzip stream" pieces.
    static func describe(_ reader: ImageReader, from start: Int64,
                         to end: Int64) throws -> [LayoutRegion] {
        // A run longer than the ceiling is not searched for headers at all. It still
        // appears, and still extracts — which is the whole point for a bootloader — but
        // the unallocated tail of a whole-drive dump is not worth twenty minutes to
        // confirm that it holds nothing.
        let anchors = end - start > Limits.maxCarveLength ? [] :
            try search(reader, patterns: BlobSignature.scanPatterns,
                       from: start, to: end, stride: 4,
                       limit: Limits.maxCandidates)
                .map(\.offset).sorted()

        var result: [LayoutRegion] = []
        var cursor = start
        while cursor < end, result.count < Limits.maxRegions {
            /// The next structured header after the cursor — where this region has to
            /// stop even if nothing here declares a length.
            let nextAnchor = anchors.first { $0 > cursor } ?? end

            guard let blob = BlobSignature.identify(reader, at: cursor) else {
                // Nothing recognised here: unknown data up to the next header.
                result.append(LayoutRegion(offset: cursor, length: nextAnchor - cursor,
                                           kind: .unknown))
                cursor = nextAnchor
                continue
            }
            // A declared length is used only when it fits; otherwise the region runs to
            // the next header, which is the most that can be said honestly.
            let length = blob.length.flatMap { $0 > 0 && cursor + $0 <= end ? $0 : nil }
                ?? (nextAnchor - cursor)
            result.append(LayoutRegion(offset: cursor, length: length, kind: .blob(blob)))
            cursor += length
        }
        return result
    }
}
