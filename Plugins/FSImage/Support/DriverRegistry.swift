// SPDX-License-Identifier: Apache-2.0
// DriverRegistry.swift — the contract every filesystem reader implements, and the
// list of readers this plugin ships.
//
// Adding a format is meant to be exactly three things: a type conforming to
// `ImageFilesystemDriver`, one line in `DriverRegistry.all`, and a fixture set.
// Nothing in the PCX entry points, the cache or the host adapter knows a format
// by name, so a new driver cannot be half-wired: either it is in the list and gets
// probed, or it is not there at all.

import Foundation

/// A byte pattern that marks a filesystem, and where in that filesystem it sits.
///
/// Exists so an image can be searched for filesystems at *any* offset, not just at 0
/// and at the partition starts. Router firmware is a concatenation of a vendor header,
/// a bootloader, a kernel and a rootfs at whatever offsets the vendor chose, with no
/// partition table to describe it; the only way in is to look for the filesystems
/// themselves. See `ImageLayout`.
///
/// `offsetInFilesystem` is what makes the pattern usable: ext's magic is 1080 bytes
/// into the filesystem and Btrfs's is 65600, so a match position is not a filesystem
/// start — the start is the match minus this.
struct CarveSignature {
    let magic: [UInt8]
    /// Distance from the filesystem's first byte to `magic`.
    let offsetInFilesystem: Int64

    init(_ magic: [UInt8], at offsetInFilesystem: Int64) {
        self.magic = magic
        self.offsetInFilesystem = offsetInFilesystem
    }

    /// A signature written as text, which most of them are.
    init(_ magic: String, at offsetInFilesystem: Int64) {
        self.init(Array(magic.utf8), at: offsetInFilesystem)
    }
}

/// Multiply a count of units by a unit size, refusing rather than trapping.
///
/// Both operands come out of an image header, so both are attacker-controlled — and `*`
/// on `Int64` traps on overflow instead of wrapping. That is a crash, not a wrong answer:
/// an ext superblock claiming `Int64.max` blocks of 1 KB, and an NTFS boot sector claiming
/// `Int64.max` sectors of 512 bytes, both took the plugin down with SIGTRAP. Both were
/// reachable through the carve path, where `byteLength` is asked *before* anything has
/// validated the superblock — a magic match is the only thing that has happened by then.
///
/// A length that cannot be represented is not a length, so nil is the honest answer, and
/// every caller already handles nil as "this format does not say".
func scaledLength(_ count: Int64, by unit: Int64) -> Int64? {
    guard count > 0, unit > 0 else { return nil }
    return checkedProduct(count, unit)
}

/// `a * b`, or nil when it overflows.
///
/// The same hazard as `scaledLength` in the places where zero is a legitimate answer —
/// a sparse run of no clusters, an empty attribute — so the positivity rule cannot be
/// folded in. Used wherever a number out of an image is scaled by a geometry field:
/// an NTFS cluster number times the cluster size is the canonical case, and a boot
/// sector claiming an MFT at cluster `Int64.max` crashed the plugin through exactly
/// that multiplication, on an image opened at offset 0 with no carving involved.
func checkedProduct(_ a: Int64, _ b: Int64) -> Int64? {
    let (product, overflowed) = a.multipliedReportingOverflow(by: b)
    return overflowed ? nil : product
}

/// A read-only reader for one on-disk filesystem format.
///
/// The shape is "parse everything at open, then answer from memory" rather than
/// "seek on demand". That is not a simplification — it is forced by the host. The
/// PCX ABI has no random-access read: to fetch one file the host reopens the
/// archive and calls `ReadHeaderEx` until the name matches
/// (`PCXArchive.extract`), and `PCXArchiveFS.openRead` does that per read. A
/// driver that re-parsed its metadata on every open would make copying a tree
/// quadratic. So the metadata is parsed once, cached by `ImageCache`, and the
/// entry list is a plain array to walk.
protocol ImageFilesystemDriver: AnyObject {
    /// Stable identifier used in fixtures, tests and error messages ("squashfs").
    static var id: String { get }
    /// Human-readable format name for the user ("SquashFS 4.0, xz").
    var formatDescription: String { get }

    /// Cheap structural check: does this image look like this format? Reads only a
    /// header, never the whole image, and must not throw for a foreign image —
    /// `false` and "not mine" are the same answer.
    static func probe(_ reader: ImageReader) -> Bool

    /// Patterns that mark this format, for finding it at an offset nobody declared.
    ///
    /// Empty means "do not look for me by scanning", which is the right answer for a
    /// format with no distinctive pattern to look for. A signature here is only ever a
    /// *candidate*: `ImageLayout` confirms every hit by opening the filesystem at that
    /// offset, so a short pattern that collides with compressed data costs a probe, not
    /// a wrong answer.
    static var carveSignatures: [CarveSignature] { get }

    /// How far this filesystem extends from its own offset 0, read from its
    /// superblock, or nil when the format does not record it.
    ///
    /// Static rather than a property of an opened driver because the caller needs it
    /// *before* opening: knowing the length is what lets a filesystem found mid-image
    /// be opened through a window that ends where it does, so it cannot read into
    /// whatever follows it. Nil is honest for the log-structured formats — JFFS2 and
    /// UBIFS have no total-size field, and a scan reports them as running to whatever
    /// comes next.
    static func byteLength(_ reader: ImageReader) -> Int64?

    /// Parse the image's metadata. Throws `ImageError` for an image that probes as
    /// this format but cannot be read.
    init(reader: ImageReader) throws

    /// Every entry, in the order `ReadHeaderEx` reports them. Parents must precede
    /// their children so the host's tree builder never has to synthesize a
    /// directory it will later be given properly.
    var entries: [ImageEntry] { get }

    /// Entries dropped during parsing because their names could not cross the ABI
    /// (see `EntryPath`). Reported to the user; 0 for a clean image.
    var droppedNames: Int { get }

    /// Write the contents of `entries[index]` to `handle`. Called for regular files only.
    ///
    /// Addressed by index rather than by entry, because the caller already has the
    /// index — `ProcessFile` acts on whatever the last `ReadHeaderEx` returned — and
    /// a driver stores its per-file layout by index too. Passing the entry meant each
    /// driver searched its own array by path to recover a number it had just been
    /// handed: an O(n) string scan per file, so extracting a whole tree was quadratic
    /// on top of the host's own re-listing. It also mis-resolved a damaged image with
    /// two entries of the same path, silently extracting the first for both.
    func extract(at index: Int, to handle: FileHandle) throws
}

extension ImageFilesystemDriver {
    var droppedNames: Int { 0 }
    /// Not scannable unless the driver says otherwise.
    static var carveSignatures: [CarveSignature] { [] }
    /// Length unknown unless the driver says otherwise.
    static func byteLength(_ reader: ImageReader) -> Int64? { nil }
}

enum DriverRegistry {
    /// Every driver this build ships, in probe order.
    ///
    /// Order matters only where two formats could both accept an image; the probes
    /// are magic-based and mutually exclusive today, so this is simply the order
    /// the stages were built. A driver appears here the moment it can read a
    /// fixture — `Tools/check-fsimage-fixtures.py` fails the build if one is listed
    /// without a fixture set and a conformance test.
    static let all: [any ImageFilesystemDriver.Type] = [
        SquashFSDriver.self,
        ExtDriver.self,
        CramFSDriver.self,
        JFFS2Driver.self,
        UBIFSDriver.self,
        BtrfsDriver.self,
        NTFSDriver.self,
        ExFATDriver.self,
        FATDriver.self,
        CpioDriver.self,
        // Last on purpose: a filesystem's own boot sector can end in 0x55AA, so this
        // only ever sees images nothing else claimed.
        PartitionedDriver.self,
        // After even that: carving is the answer for an image with no table and no
        // filesystem at offset 0, which is the one remaining case. Its probe accepts
        // anything and its initialiser does the deciding, so nothing may follow it.
        CarvedDriver.self,
    ]

    /// The first driver whose probe accepts `reader`, or nil.
    ///
    /// `excluding` keeps the partition driver from opening a partition as another disk
    /// image. One level of nesting covers every real image; without the exclusion, a
    /// partition whose first sector happens to end in 0x55AA — which a FAT boot sector
    /// does, by design — would recurse.
    ///
    /// It takes a list because the partition driver has a second one to exclude: the
    /// carving driver accepts anything and decides in its initialiser, so letting it be
    /// chosen here would run a full signature scan over every partition that nothing
    /// else could read, and turn a partition documented as listing empty into one
    /// holding invented entries.
    static func driverType(for reader: ImageReader,
                           excluding: [any ImageFilesystemDriver.Type] = [])
        -> (any ImageFilesystemDriver.Type)? {
        let excludedIDs = Set(excluding.map { $0.id })
        return all.first { !excludedIDs.contains($0.id) && $0.probe(reader) }
    }

    /// Open `path` with whichever driver claims it.
    ///
    /// `.notThisFormat` when nothing claims it is the important case: it is what
    /// the host sees when the plugin was consulted because of a broad extension
    /// match (`.img`, `.bin`) on a file that is not an image at all. The caller
    /// turns it into `PC_E_UNKNOWN_FMT`, the host falls back to its own readers,
    /// and nothing about the file has been damaged or reported wrongly.
    static func open(path: String) throws -> any ImageFilesystemDriver {
        let reader = try ImageReader(path: path)
        guard let type = driverType(for: reader) else { throw ImageError.notThisFormat }
        return try type.init(reader: reader)
    }
}
