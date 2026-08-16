// SPDX-License-Identifier: Apache-2.0
// NTFSDriver.swift — NTFS, read-only.
//
// The one format here macOS cannot help with at all: this machine's
// /System/Library/Filesystems/ntfs.fs carries a BootCamp formatter and no mount helper,
// so an NTFS image has no other route on it.
//
// The tree is built by **scanning the MFT**, not by walking directory indexes. Every
// record carries a $FILE_NAME attribute naming its parent, so the parent-child edges are
// all there without touching $INDEX_ROOT or $INDEX_ALLOCATION — those are an
// acceleration structure over the same facts, and a B-tree implementation that only ever
// reproduces what the MFT already said is a large amount of code that can only introduce
// disagreement. Scanning is also what stays useful on a damaged image, where the indexes
// are the first thing to go.
//
// The bootstrap is the one circular part: the MFT's own location is in the boot sector,
// but the MFT is a file and may be fragmented, so record 0 has to be read first and its
// $DATA runs followed to reach the rest of itself.
//
// Compressed files are read: see `LZNT1.swift`, and `extractCompressed` below for the
// compression-unit accounting that decides whether a given unit is compressed at all.
//
// Skipped rather than half-read: encrypted files (unreadable without keys), alternate
// data streams (a *named* $DATA attribute — real, but not a directory entry), and records
// whose attributes spill into an $ATTRIBUTE_LIST, where the data runs live in other
// records and reading only this one would return a fragment of the file as if it were
// the file.

import Foundation

final class NTFSDriver: ImageFilesystemDriver {
    static let id = "ntfs"

    private let reader: ImageReader
    private let bytesPerCluster: Int64
    private let mftRecordSize: Int
    private let volumeSerial: UInt64

    private(set) var entries: [ImageEntry] = []
    private(set) var droppedNames = 0
    /// How to read each regular file, by entry index.
    private var fileData: [Int: FileContents] = [:]

    var formatDescription: String {
        "NTFS, \(bytesPerCluster / 1024) KB clusters, \(mftRecordSize)-byte MFT records"
    }

    private struct FileContents {
        let size: Int64
        /// Resident data lives inside the MFT record itself — the usual case for a file
        /// of a few hundred bytes, which on a config-heavy volume is most of them.
        let resident: [UInt8]?
        let runs: [NTFSRun]
        /// Clusters per compression unit, or 0 when the attribute is not compressed.
        let compressionUnit: Int64
    }

    /// Records below this are NTFS's own metadata ($MFT, $LogFile, $Bitmap and the rest).
    /// Hidden, as every NTFS tool hides them: they are not what somebody opened the image
    /// to see, and listing them makes the root of every volume look alien.
    private static let firstUserRecord = 24
    /// The root directory is always record 5.
    private static let rootRecord: UInt64 = 5

    private static let signature = Array("NTFS    ".utf8)
    private static let fileMagic = Array("FILE".utf8)

    static func probe(_ reader: ImageReader) -> Bool {
        (try? reader.bytes(at: 3, count: 8)) == signature
    }

    /// The OEM name field, three bytes into the boot sector.
    static let carveSignatures = [CarveSignature("NTFS    ", at: 3)]

    static func byteLength(_ reader: ImageReader) -> Int64? {
        guard let sectors = try? reader.u64le(at: 40), sectors > 0, sectors < Int64.max,
              let bytesPerSector = try? reader.u16le(at: 11),
              [512, 1024, 2048, 4096].contains(Int(bytesPerSector)) else { return nil }
        // NTFS records one sector fewer than the volume holds: the backup boot sector
        // sits at the very end and is outside the count.
        return scaledLength(Int64(sectors) + 1, by: Int64(bytesPerSector))
    }

    init(reader: ImageReader) throws {
        self.reader = reader
        guard try reader.bytes(at: 3, count: 8) == Self.signature else { throw ImageError.notThisFormat }

        let bytesPerSector = Int64(try reader.u16le(at: 11))
        let sectorsPerCluster = Int64(try reader.u8(at: 13))
        guard [512, 1024, 2048, 4096].contains(bytesPerSector), sectorsPerCluster > 0 else {
            throw ImageError.damaged(reason: "implausible NTFS geometry")
        }
        bytesPerCluster = bytesPerSector * sectorsPerCluster
        volumeSerial = try reader.u64le(at: 72)

        // A negative `clusters_per_mft_record` is a power-of-two byte count instead —
        // which is the normal case, since a record is 1024 bytes and a cluster is 4096.
        let clustersPerRecord = Int8(bitPattern: try reader.u8(at: 64))
        if clustersPerRecord < 0 {
            let shift = Int(-clustersPerRecord)
            guard shift >= 9, shift <= 16 else {
                throw ImageError.damaged(reason: "implausible MFT record shift \(shift)")
            }
            mftRecordSize = 1 << shift
        } else {
            mftRecordSize = Int(Int64(clustersPerRecord) * bytesPerCluster)
        }
        guard mftRecordSize >= 512, mftRecordSize <= 65536 else {
            throw ImageError.damaged(reason: "implausible MFT record size \(mftRecordSize)")
        }

        let mftLCN = Int64(bitPattern: try reader.u64le(at: 48))
        guard mftLCN > 0 else { throw ImageError.damaged(reason: "the boot sector has no MFT location") }

        let mft = try readMasterFileTable(startingAt: mftLCN * bytesPerCluster)
        try buildTree(from: mft)
    }

    // MARK: - Bootstrapping the MFT

    /// Read the whole MFT, following its own $DATA runs.
    ///
    /// Record 0 describes the MFT as a file, so reading it is what makes the rest
    /// reachable — the boot sector only says where the *first* fragment begins, and on a
    /// volume that has been in use the MFT is rarely in one piece.
    private func readMasterFileTable(startingAt offset: Int64) throws -> [UInt8] {
        let first = try NTFSRecord.applyFixups(try reader.bytes(at: offset, count: mftRecordSize),
                                               expectedMagic: Self.fileMagic)
        guard let data = try NTFSRecord.attributes(in: first)
            .first(where: { $0.type == NTFSRecord.AttributeType.data.rawValue }) else {
            throw ImageError.damaged(reason: "the MFT's own record has no $DATA attribute")
        }
        guard data.isNonResident else {
            throw ImageError.damaged(reason: "the MFT cannot be resident in its own record")
        }
        let size = NTFSRecord.nonResidentDataSize(first, data)
        guard size > 0, size <= Int64(ImageLimits.maxInMemoryImage) else {
            throw ImageError.limitExceeded(limit: "MFT of \(size) bytes")
        }

        var mft = [UInt8]()
        mft.reserveCapacity(Int(size))
        for run in try NTFSRecord.dataRuns(first, data) {
            guard let lcn = run.lcn else {
                mft.append(contentsOf: [UInt8](repeating: 0, count: Int(run.clusterCount * bytesPerCluster)))
                continue
            }
            let bytes = Int(run.clusterCount * bytesPerCluster)
            mft.append(contentsOf: try reader.bytes(at: lcn * bytesPerCluster, count: bytes))
            guard mft.count <= ImageLimits.maxInMemoryImage else {
                throw ImageError.limitExceeded(limit: "maxInMemoryImage")
            }
        }
        guard mft.count >= mftRecordSize else {
            throw ImageError.damaged(reason: "the MFT is shorter than one record")
        }
        return mft
    }

    // MARK: - Scanning

    private struct Node {
        var name: String
        var parent: UInt64
        var isDirectory: Bool
        var size: Int64
        var mtime: Int64
        var contents: FileContents?
    }

    private func buildTree(from mft: [UInt8]) throws {
        var nodes: [UInt64: Node] = [:]
        let recordCount = mft.count / mftRecordSize

        for number in Self.firstUserRecord..<recordCount {
            let start = number * mftRecordSize
            let raw = Array(mft[start..<(start + mftRecordSize)])
            guard Array(raw.prefix(4)) == Self.fileMagic else { continue }   // unused slot
            guard let record = try? NTFSRecord.applyFixups(raw, expectedMagic: Self.fileMagic),
                  let attributes = try? NTFSRecord.attributes(in: record) else { continue }

            let flags = NTFSRecord.u16(record, 22)
            guard flags & 0x0001 != 0 else { continue }                       // deleted
            let isDirectory = flags & 0x0002 != 0
            // A base record reference other than zero means this record is an extension
            // of another one and has no identity of its own.
            guard NTFSRecord.u64(record, 32) == 0 else { continue }

            guard let name = bestName(record, attributes) else { continue }
            var node = Node(name: name.name, parent: name.parent, isDirectory: isDirectory,
                            size: 0, mtime: name.mtime, contents: nil)

            if !isDirectory {
                guard !attributes.contains(where: {
                    $0.type == NTFSRecord.AttributeType.attributeList.rawValue
                }) else {
                    // The data runs live in other records; reading only this one would
                    // silently return a fragment of the file.
                    continue
                }
                // The unnamed $DATA attribute is the file. A *named* one is an alternate
                // data stream, which has no place in a directory listing.
                guard let data = attributes.first(where: {
                    $0.type == NTFSRecord.AttributeType.data.rawValue && record[$0.offset + 9] == 0
                }) else { continue }
                guard !data.isEncrypted else { continue }

                if data.isNonResident {
                    let size = NTFSRecord.nonResidentDataSize(record, data)
                    // `compression_unit` is a log2 count of clusters, normally 4 → 16
                    // clusters per unit. It is only meaningful when the attribute says
                    // it is compressed.
                    let shift = Int(record[data.offset + 34])
                    let unit: Int64 = data.isCompressed && shift > 0 && shift < 20 ? 1 << Int64(shift) : 0
                    node.size = size
                    node.contents = FileContents(size: size, resident: nil,
                                                 runs: try NTFSRecord.dataRuns(record, data),
                                                 compressionUnit: unit)
                } else {
                    let value = try NTFSRecord.residentValue(record, data)
                    node.size = Int64(value.count)
                    node.contents = FileContents(size: Int64(value.count), resident: value,
                                                 runs: [], compressionUnit: 0)
                }
            }
            nodes[UInt64(number)] = node
        }

        var children: [UInt64: [UInt64]] = [:]
        for (number, node) in nodes { children[node.parent, default: []].append(number) }

        var collector = EntryCollector()
        var visited = Set<UInt64>()
        try emit(record: Self.rootRecord, path: "", depth: 0, nodes: nodes, children: children,
                 visited: &visited, collector: &collector)
        entries = collector.entries
        droppedNames = collector.droppedNames
    }

    /// Pick the name to show from a record's $FILE_NAME attributes.
    ///
    /// A file usually has two: its real name and an 8.3 alias for old software. Showing
    /// the alias would put `PROGRA~1` in the listing, so Win32 and POSIX names win over
    /// a DOS one — the same choice FAT's long names make, for the same reason.
    private func bestName(_ record: [UInt8],
                          _ attributes: [NTFSRecord.Attribute]) -> (name: String, parent: UInt64, mtime: Int64)? {
        var best: (name: String, parent: UInt64, mtime: Int64, rank: Int)?
        for attribute in attributes
        where attribute.type == NTFSRecord.AttributeType.fileName.rawValue && !attribute.isNonResident {
            guard let value = try? NTFSRecord.residentValue(record, attribute), value.count >= 66 else { continue }
            let parent = NTFSRecord.u64(value, 0) & 0x0000_FFFF_FFFF_FFFF
            let nameLength = Int(value[64])
            let nameType = value[65]
            guard nameLength > 0, 66 + nameLength * 2 <= value.count else { continue }
            var units: [UInt16] = []
            for index in 0..<nameLength {
                units.append(UInt16(value[66 + index * 2]) | UInt16(value[67 + index * 2]) << 8)
            }
            // 2 is the DOS-only alias; everything else is a real name.
            let rank = nameType == 2 ? 0 : 1
            if best == nil || rank > best!.rank {
                best = (String(decoding: units, as: UTF16.self), parent,
                        Self.timestamp(NTFSRecord.u64(value, 24)), rank)
            }
        }
        return best.map { ($0.name, $0.parent, $0.mtime) }
    }

    private func emit(record: UInt64, path: String, depth: Int,
                      nodes: [UInt64: Node], children: [UInt64: [UInt64]],
                      visited: inout Set<UInt64>, collector: inout EntryCollector) throws {
        try EntryCollector.checkDepth(depth)
        guard visited.insert(record).inserted else {
            throw ImageError.damaged(reason: "directory cycle at \(path.isEmpty ? "/" : path)")
        }
        defer { visited.remove(record) }

        for child in (children[record] ?? []).sorted() {
            guard let node = nodes[child] else { continue }
            guard let childPath = EntryPath.make(parent: path, component: node.name) else {
                collector.dropName()
                continue
            }
            let index = collector.entries.count
            if node.isDirectory {
                try collector.add(ImageEntry(path: childPath, size: -1, mtime: node.mtime,
                                             kind: .directory, mode: 0o040755, locator: child))
                try emit(record: child, path: childPath, depth: depth + 1, nodes: nodes,
                         children: children, visited: &visited, collector: &collector)
            } else {
                try collector.add(ImageEntry(path: childPath, size: node.size, mtime: node.mtime,
                                             kind: .file, mode: 0o100644, locator: child))
                if let contents = node.contents { fileData[index] = contents }
            }
        }
    }

    /// Write a compressed attribute, one compression unit at a time.
    ///
    /// NTFS does not compress an attribute as a whole. It divides it into fixed units —
    /// 16 clusters is the universal choice — and compresses each independently, then
    /// stores the result in *fewer* clusters than the unit occupies. So the number of
    /// clusters a unit actually uses is what says whether it is compressed at all:
    ///
    ///   * none allocated  → the unit is a hole and reads as zeros
    ///   * a full unit     → it did not compress and is stored verbatim
    ///   * fewer than full → the allocated clusters hold an LZNT1 run for the unit
    ///
    /// Decompressing everything, or nothing, gets a file that is mostly right and wrong
    /// in patches — which is why the allocation count has to drive it rather than the
    /// attribute's compressed flag alone.
    private func extractCompressed(_ contents: FileContents, to handle: FileHandle) throws {
        let unit = contents.compressionUnit
        let unitBytes = unit * bytesPerCluster

        // Flatten the runs into a cluster-per-VCN map so a unit's clusters can be looked
        // up regardless of how the runs happen to be split.
        var clusters: [Int64?] = []
        for run in contents.runs {
            guard run.clusterCount <= 1 << 24 else {
                throw ImageError.limitExceeded(limit: "run of \(run.clusterCount) clusters")
            }
            for index in 0..<run.clusterCount {
                clusters.append(run.lcn.map { $0 + index })
            }
            guard clusters.count <= 1 << 24 else {
                throw ImageError.limitExceeded(limit: "cluster map length")
            }
        }

        var written: Int64 = 0
        var vcn: Int64 = 0
        while written < contents.size {
            let wanted = min(unitBytes, contents.size - written)
            let start = Int(vcn)
            let end = min(start + Int(unit), clusters.count)
            let inUnit = start < end ? Array(clusters[start..<end]) : []
            let allocated = inUnit.compactMap { $0 }

            if allocated.isEmpty {
                var left = wanted
                while left > 0 {
                    let chunk = Int(min(left, Int64(ImageLimits.copyChunkSize)))
                    try handle.write(contentsOf: Data(count: chunk))
                    left -= Int64(chunk)
                }
            } else if Int64(allocated.count) == unit {
                var left = wanted
                for lcn in allocated where left > 0 {
                    let take = min(left, bytesPerCluster)
                    try reader.copy(at: lcn * bytesPerCluster, count: take, to: handle)
                    left -= take
                }
            } else {
                var compressed = [UInt8]()
                for lcn in allocated {
                    compressed.append(contentsOf: try reader.bytes(at: lcn * bytesPerCluster,
                                                                   count: Int(bytesPerCluster)))
                }
                let expanded = try LZNT1.decompress(compressed, maxSize: Int(unitBytes))
                guard Int64(expanded.count) >= wanted else {
                    throw ImageError.damaged(
                        reason: "a compression unit decoded to \(expanded.count) bytes, needed \(wanted)")
                }
                try handle.write(contentsOf: Data(expanded.prefix(Int(wanted))))
            }
            written += wanted
            vcn += unit
        }
    }

    /// Windows records time as 100-nanosecond ticks since 1601. The offset to the Unix
    /// epoch is a constant, not a calculation worth repeating.
    private static func timestamp(_ ticks: UInt64) -> Int64 {
        guard ticks > 0 else { return 0 }
        let ticksToUnixEpoch: UInt64 = 116_444_736_000_000_000
        guard ticks > ticksToUnixEpoch else { return 0 }
        return Int64((ticks - ticksToUnixEpoch) / 10_000_000)
    }

    // MARK: - Extraction

    func extract(at index: Int, to handle: FileHandle) throws {
        guard entries.indices.contains(index), let contents = fileData[index] else {
            throw ImageError.damaged(reason: "no file data for entry \(index)")
        }
        if let resident = contents.resident {
            try handle.write(contentsOf: Data(resident.prefix(Int(contents.size))))
            return
        }

        if contents.compressionUnit > 0 {
            try extractCompressed(contents, to: handle)
            return
        }

        var remaining = contents.size
        for run in contents.runs {
            guard remaining > 0 else { break }
            let runBytes = min(remaining, run.clusterCount * bytesPerCluster)
            guard let lcn = run.lcn else {
                // Sparse. Real on NTFS, and the zeros are the file's contents.
                var left = runBytes
                while left > 0 {
                    let chunk = Int(min(left, Int64(ImageLimits.copyChunkSize)))
                    try handle.write(contentsOf: Data(count: chunk))
                    left -= Int64(chunk)
                }
                remaining -= runBytes
                continue
            }
            try reader.copy(at: lcn * bytesPerCluster, count: runBytes, to: handle)
            remaining -= runBytes
        }
        guard remaining == 0 else {
            throw ImageError.damaged(
                reason: "\(entries[index].path): the run list ends \(remaining) bytes early")
        }
    }
}
