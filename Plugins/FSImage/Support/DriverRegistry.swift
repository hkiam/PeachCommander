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
        BtrfsDriver.self,
        CpioDriver.self,
    ]

    /// The first driver whose probe accepts `reader`, or nil.
    static func driverType(for reader: ImageReader) -> (any ImageFilesystemDriver.Type)? {
        all.first { $0.probe(reader) }
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
