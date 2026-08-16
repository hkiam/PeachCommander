// SPDX-License-Identifier: Apache-2.0
// NTFSRecord.swift — MFT records, their fixups, attributes and data runs.
//
// Three primitives that everything else in the NTFS driver is built from, and two of
// them are the places NTFS readers go wrong *silently*.
//
// **Fixups.** Every MFT record and index block has the last two bytes of each of its
// sectors replaced by a signature, with the real values kept in an array at the front.
// They exist so a torn write is detectable. A reader that does not undo them gets a
// record that parses — the structures are near the start, so the corruption lands in the
// middle of attribute data — and is wrong two bytes per 512. Nothing about the result
// announces itself.
//
// **Data runs.** A file's clusters are a list of (length, offset) pairs where each
// offset is a *signed delta* from the previous one, and both fields are variable width,
// given by the two nibbles of a header byte. Treating the delta as unsigned works for
// the first run of most files and puts everything after it in the wrong place — the same
// failure shape as an ignored logical block number in ext4, which is how that one was
// found here too.

import Foundation

/// One run of clusters. `lcn == nil` is a sparse hole: no clusters are allocated and it
/// reads as zeros.
struct NTFSRun {
    let lcn: Int64?
    let clusterCount: Int64
}

enum NTFSRecord {
    /// Attribute types this driver acts on.
    enum AttributeType: UInt32 {
        case standardInformation = 0x10
        case attributeList = 0x20
        case fileName = 0x30
        case data = 0x80
        case indexRoot = 0x90
        case indexAllocation = 0xA0
        case bitmap = 0xB0
    }

    /// One attribute inside a record, located but not interpreted.
    struct Attribute {
        let type: UInt32
        let offset: Int          // of the attribute header, within the record
        let length: Int
        let isNonResident: Bool
        let flags: UInt16
        /// True when the attribute's data is stored compressed (LZNT1).
        var isCompressed: Bool { flags & 0x0001 != 0 }
        var isEncrypted: Bool { flags & 0x4000 != 0 }
        var isSparse: Bool { flags & 0x8000 != 0 }
    }

    /// Undo the Update Sequence Array in a record read straight off disk.
    ///
    /// The array's first entry is the signature that was written into every sector's
    /// last two bytes; the rest are the values those bytes originally held. A sector
    /// whose tail does not carry the signature means the record was half-written, and
    /// that is a real failure rather than something to repair — the alternative is
    /// handing back a record built partly from two different versions of itself.
    static func applyFixups(_ record: [UInt8], expectedMagic: [UInt8]) throws -> [UInt8] {
        guard record.count >= 48, Array(record.prefix(4)) == expectedMagic else {
            throw ImageError.damaged(reason: "record does not start with \(String(decoding: expectedMagic, as: UTF8.self))")
        }
        let arrayOffset = Int(u16(record, 4))
        let arrayCount = Int(u16(record, 6))
        guard arrayCount >= 1, arrayOffset >= 42,
              arrayOffset + arrayCount * 2 <= record.count else {
            throw ImageError.damaged(reason: "fixup array at \(arrayOffset) of \(arrayCount) entries")
        }
        let signature = u16(record, arrayOffset)

        var fixed = record
        let sectorSize = 512
        for index in 1..<arrayCount {
            let tail = index * sectorSize - 2
            guard tail + 2 <= record.count else { break }
            guard u16(record, tail) == signature else {
                throw ImageError.damaged(
                    reason: "sector \(index) of the record was not written completely (fixup mismatch)")
            }
            fixed[tail] = record[arrayOffset + index * 2]
            fixed[tail + 1] = record[arrayOffset + index * 2 + 1]
        }
        return fixed
    }

    /// Every attribute in a de-fixed record, in order.
    static func attributes(in record: [UInt8]) throws -> [Attribute] {
        guard record.count >= 24 else { return [] }
        var offset = Int(u16(record, 20))
        var out: [Attribute] = []
        while offset + 4 <= record.count {
            let type = u32(record, offset)
            if type == 0xFFFF_FFFF { break }           // end marker
            guard offset + 16 <= record.count else { break }
            let length = Int(u32(record, offset + 4))
            // A zero or overlong length would loop or walk off the record; both mean the
            // attribute chain is not trustworthy from here on.
            guard length >= 16, offset + length <= record.count else {
                throw ImageError.damaged(reason: "attribute at \(offset) claims \(length) bytes")
            }
            out.append(Attribute(type: type, offset: offset, length: length,
                                 isNonResident: record[offset + 8] != 0,
                                 flags: u16(record, offset + 12)))
            offset += length
            guard out.count <= 256 else {
                throw ImageError.damaged(reason: "record holds more than 256 attributes")
            }
        }
        return out
    }

    /// A resident attribute's value.
    static func residentValue(_ record: [UInt8], _ attribute: Attribute) throws -> [UInt8] {
        guard !attribute.isNonResident else {
            throw ImageError.damaged(reason: "attribute 0x\(String(attribute.type, radix: 16)) is not resident")
        }
        let valueLength = Int(u32(record, attribute.offset + 16))
        let valueOffset = attribute.offset + Int(u16(record, attribute.offset + 20))
        guard valueLength >= 0, valueOffset >= 0,
              valueOffset + valueLength <= attribute.offset + attribute.length,
              valueOffset + valueLength <= record.count else {
            throw ImageError.damaged(reason: "resident value runs past its attribute")
        }
        return Array(record[valueOffset..<(valueOffset + valueLength)])
    }

    /// The real size of a non-resident attribute's data.
    static func nonResidentDataSize(_ record: [UInt8], _ attribute: Attribute) -> Int64 {
        Int64(bitPattern: u64(record, attribute.offset + 48))
    }

    /// Decode a non-resident attribute's mapping pairs into runs.
    ///
    /// Each pair starts with a header byte whose low nibble is the width of the length
    /// field and whose high nibble is the width of the offset field. The offset is a
    /// **signed** delta from the previous run's start; a width of zero means the run is
    /// sparse and occupies no clusters at all.
    static func dataRuns(_ record: [UInt8], _ attribute: Attribute) throws -> [NTFSRun] {
        guard attribute.isNonResident else { return [] }
        var offset = attribute.offset + Int(u16(record, attribute.offset + 32))
        let end = min(attribute.offset + attribute.length, record.count)
        var runs: [NTFSRun] = []
        var lcn: Int64 = 0

        while offset < end {
            let header = record[offset]
            offset += 1
            if header == 0 { break }                   // end of the list
            let lengthWidth = Int(header & 0x0F)
            let offsetWidth = Int(header >> 4)
            guard lengthWidth > 0, lengthWidth <= 8, offsetWidth <= 8,
                  offset + lengthWidth + offsetWidth <= end else {
                throw ImageError.damaged(reason: "malformed data run header 0x\(String(header, radix: 16))")
            }

            var clusterCount: Int64 = 0
            for byte in (0..<lengthWidth).reversed() {
                clusterCount = clusterCount << 8 | Int64(record[offset + byte])
            }
            offset += lengthWidth
            guard clusterCount > 0, clusterCount <= 1 << 40 else {
                throw ImageError.damaged(reason: "data run of \(clusterCount) clusters")
            }

            if offsetWidth == 0 {
                runs.append(NTFSRun(lcn: nil, clusterCount: clusterCount))   // sparse
            } else {
                // Sign-extend from the field's own width: the delta is signed, and a
                // file whose next fragment lies *earlier* on disk is entirely ordinary.
                var delta: Int64 = 0
                for byte in (0..<offsetWidth).reversed() {
                    delta = delta << 8 | Int64(record[offset + byte])
                }
                let signBit: Int64 = 1 << (offsetWidth * 8 - 1)
                if delta & signBit != 0 { delta -= signBit << 1 }
                offset += offsetWidth
                lcn += delta
                guard lcn >= 0 else {
                    throw ImageError.damaged(reason: "data run points at negative cluster \(lcn)")
                }
                runs.append(NTFSRun(lcn: lcn, clusterCount: clusterCount))
            }
            guard runs.count <= 1 << 20 else {
                throw ImageError.limitExceeded(limit: "data run count")
            }
        }
        return runs
    }

    // MARK: - Little-endian helpers

    static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }
    static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
    static func u64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        UInt64(u32(bytes, offset)) | UInt64(u32(bytes, offset + 4)) << 32
    }
}
