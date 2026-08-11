// SPDX-License-Identifier: Apache-2.0
// ZipVolumes.swift - The parts of a split zip, addressed as one byte stream (F-382).
//
// A split archive is not a different format, it is the same format cut into files, and the cut is
// allowed to fall in the middle of anything — an entry's compressed bytes routinely span several
// parts. So the parser should not have to know: this presents the parts as one contiguous stream and
// answers where each part begins, which is the only thing the offsets in the headers need.
//
// Two layouts exist and they are not the same thing, which is worth stating because the obvious fix
// for one is wrong for the other:
//
//   * **True multi-disk** (`zip -s`, WinZip): `name.z01`, `name.z02`, …, and `name.zip` LAST, holding
//     the central directory. The archive says so itself — the EOCD's "number of this disk" is the
//     index of the final part — and every offset in it is relative to *its own* disk, not to the
//     whole. `cat`-ing the parts therefore does not produce a readable archive: measured against
//     Info-ZIP's own output, the first part opens with the spanning signature `PK\x07\x08` and the
//     EOCD's central-directory offset was 119 into a 218-byte final part, not 307419 into the join.
//     unzip on the concatenation says "attempting to re-compensate" and then reports an error.
//   * **A plain byte split** (`name.zip.001`, `.002`, …): the parts concatenate back into the exact
//     original file, every offset is already absolute, and there is nothing to translate.
//
// Both end up here as an ordered list of parts; only the offset translation differs, and that is the
// caller's business (see `base(ofDisk:)`).
//
// The parts are memory-mapped rather than read. Splitting is what people do to archives too large to
// move in one piece, so holding the join in memory is exactly the wrong bargain.

import Foundation

/// The bytes of a zip archive that may live in several files, addressed as if they were one.
struct ZipVolumes {
    /// Each part, in disk order. The last one holds the central directory in a true multi-disk set.
    private let parts: [Data]
    /// Where each part starts in the logical stream. One longer than `parts`, so the final element
    /// is the total size and `starts[i + 1] - starts[i]` is part `i`'s length.
    private let starts: [Int]

    init(parts: [Data]) {
        self.parts = parts
        var running = 0
        var bounds = [0]
        bounds.reserveCapacity(parts.count + 1)
        for part in parts {
            running += part.count
            bounds.append(running)
        }
        self.starts = bounds
    }

    /// Total number of bytes across all parts.
    var count: Int { starts[parts.count] }

    /// How many files the archive is spread over. 1 for an ordinary zip.
    var volumeCount: Int { parts.count }

    /// Where disk `disk` begins in the logical stream, or nil when the archive has no such disk —
    /// which is a malformed reference rather than something to clamp, so callers must decide.
    func base(ofDisk disk: Int) -> Int? {
        guard disk >= 0, disk < parts.count else { return nil }
        return starts[disk]
    }

    subscript(index: Int) -> UInt8 {
        let part = partIndex(containing: index)
        let data = parts[part]
        return data[data.startIndex + (index - starts[part])]
    }

    /// The bytes in `range`, copied across part boundaries when it straddles them. A range inside a
    /// single part is a subrange of the mapping and costs nothing beyond the copy `Data` makes.
    func subdata(in range: Range<Int>) -> Data {
        guard !range.isEmpty else { return Data() }
        var out = Data()
        out.reserveCapacity(range.count)
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            let part = partIndex(containing: cursor)
            let data = parts[part]
            let withinPart = cursor - starts[part]
            let take = min(range.upperBound - cursor, data.count - withinPart)
            let from = data.startIndex + withinPart
            out.append(data.subdata(in: from..<(from + take)))
            cursor += take
        }
        return out
    }

    /// Which part holds the byte at `index`. Binary search rather than a scan because the backwards
    /// EOCD hunt asks this once per byte for up to 64 KB.
    private func partIndex(containing index: Int) -> Int {
        var low = 0, high = parts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= index { low = mid } else { high = mid - 1 }
        }
        return low
    }
}

extension ZipVolumes {
    /// Opens `fileURL` together with the other parts of its set, if it has any.
    ///
    /// The archive is asked rather than the file name, wherever it can be: a `.zip` that declares
    /// itself the last disk of a set is one, and a `.zip` sitting next to somebody else's unrelated
    /// `.z01` is not. Only the `name.zip.001` layout has to be recognised by its name, because a plain
    /// byte split leaves nothing in the bytes to recognise — the first part is simply the front of a
    /// file, and its EOCD is in the last part where a lone `.001` cannot see it.
    ///
    /// Returns nil when the file cannot be mapped, or when a part the archive refers to is missing —
    /// a set with a hole is not an archive that can be read, and pretending otherwise would surface as
    /// a puzzling parse error somewhere in the middle.
    static func open(fileURL: URL) -> ZipVolumes? {
        if let numbered = openNumberedSplit(fileURL: fileURL) { return numbered }
        guard let last = map(fileURL) else { return nil }
        let single = ZipVolumes(parts: [last])

        // A true multi-disk set names its final part `.zip` and says which disk that is. Anything
        // else — including an unreadable EOCD, which the parser will report properly — is one file.
        guard let eocd = ZipReader.findEOCD(in: single),
              let finalDisk = numberOfThisDisk(in: single, eocdOffset: eocd), finalDisk > 0 else {
            return single
        }

        let base = fileURL.deletingPathExtension()
        var parts: [Data] = []
        parts.reserveCapacity(finalDisk + 1)
        for disk in 0..<finalDisk {
            // Disk 0 is `.z01`: the suffix is one-based, and zero-padded to two digits only up to
            // `.z99` — a hundredth part is `.z100`, not `.z00`.
            let url = base.appendingPathExtension(String(format: "z%02d", disk + 1))
            guard let part = map(url) else { return nil }
            parts.append(part)
        }
        parts.append(last)
        return ZipVolumes(parts: parts)
    }

    /// `name.zip.001`, `.002`, … — a plain byte split, recognised by the name and concatenated.
    private static func openNumberedSplit(fileURL: URL) -> ZipVolumes? {
        let suffix = fileURL.pathExtension
        guard suffix.count == 3, suffix.allSatisfy(\.isNumber), Int(suffix) == 1 else { return nil }
        let base = fileURL.deletingPathExtension()
        var parts: [Data] = []
        var index = 1
        while let part = map(base.appendingPathExtension(String(format: "%03d", index))) {
            parts.append(part)
            index += 1
        }
        guard !parts.isEmpty else { return nil }
        return ZipVolumes(parts: parts)
    }

    private static func map(_ url: URL) -> Data? {
        try? Data(contentsOf: url, options: [.mappedIfSafe])
    }

    /// The EOCD's "number of this disk" field, which in the final part of a set is the index of that
    /// part — i.e. how many `.zNN` files precede it.
    private static func numberOfThisDisk(in volumes: ZipVolumes, eocdOffset: Int) -> Int? {
        let field = eocdOffset + 4
        guard field + 2 <= volumes.count else { return nil }
        return Int(UInt16(volumes[field]) | (UInt16(volumes[field + 1]) << 8))
    }
}
