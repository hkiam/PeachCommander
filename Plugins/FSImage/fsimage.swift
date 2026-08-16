// SPDX-License-Identifier: Apache-2.0
// fsimage.swift — read-only Linux filesystem images as a PCX packer plugin.
//
// Opens a filesystem image (SquashFS, ext2/3/4, JFFS2, cramfs, initramfs, Btrfs)
// the way the host opens an archive: Enter on `rootfs.squashfs` in a panel and the
// panel is inside the filesystem. Implements the PCX ABI (OpenArchive →
// ReadHeaderEx/ProcessFile loop → CloseArchive); the host mounts the result
// through PCXArchiveFS, so lister, search and file operations all work on it
// unchanged. Read-only by construction — there is no PackFiles or DeleteFiles.
//
// Format support arrives in stages; `DriverRegistry.all` is the list of what this
// build can actually read. Everything format-specific lives behind
// `ImageFilesystemDriver`, so this file never learns a format's name.
//
// Detection is the one place the ABI does not quite fit. The host picks a packer
// plugin by file extension alone (`PluginManager.packerPlugin(forExtension:)`);
// it does not consult `CanYouHandleThisFile`, although the adapter has the call.
// So the manifest claims a broad set of extensions — including `img` and `bin`,
// which is what firmware is actually named — and OpenArchive fails immediately
// with PC_E_UNKNOWN_FMT when no driver recognises the content. The host then falls
// back to its own readers. The cost of a wrong guess is one header read; the cost
// of not claiming `.bin` is that real firmware does not open at all. The plugin
// ships disabled by default so this breadth is opt-in.

import Foundation

// MARK: - Open archive state (the opaque PC_HANDLE)

/// One open handle. Holds the shared driver plus this handle's own read cursor —
/// the host may have several handles on one image at once (a panel listing while
/// an operation extracts), and a cursor in the driver would make those interfere.
private final class ImageHandle {
    let driver: any ImageFilesystemDriver
    let path: String
    var index = 0

    init(driver: any ImageFilesystemDriver, path: String) {
        self.driver = driver
        self.path = path
    }

    var entries: [ImageEntry] { driver.entries }
}

/// Map a parse failure to the PCX error the host understands.
///
/// The distinction that matters is `.notThisFormat` → PC_E_UNKNOWN_FMT: it means
/// "not mine, try something else", and the host falls back cleanly. Everything
/// else is PC_E_BAD_ARCHIVE, which the host reports rather than silently retries —
/// an image that is genuinely this format but unreadable should say so.
private func pcxError(for error: Error) -> Int32 {
    guard let imageError = error as? ImageError else { return Int32(PC_E_BAD_ARCHIVE) }
    switch imageError {
    case .notThisFormat:            return Int32(PC_E_UNKNOWN_FMT)
    case .cannotOpen:               return Int32(PC_E_EOPEN)
    case .readFailed:               return Int32(PC_E_EREAD)
    case .unsupported:              return Int32(PC_E_NOT_SUPPORTED)
    case .outOfBounds, .damaged:    return Int32(PC_E_BAD_DATA)
    case .limitExceeded:            return Int32(PC_E_TOO_MANY)
    }
}

private func setCString(_ s: String, _ dst: UnsafeMutablePointer<CChar>, _ cap: Int) {
    s.withCString { _ = strlcpy(dst, $0, cap) }
}

// MARK: - PCX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

/// Multiple files, detected by content. No NEW/MODIFY/DELETE: this plugin never
/// writes, and advertising a capability it does not have would put it in the Pack
/// dialog's format list (`MainWindowController.loadPlugins`) offering to create
/// filesystem images it cannot create.
@_cdecl("GetPackerCaps")
public func GetPackerCaps() -> Int32 { PC_CAP_MULTIPLE | PC_CAP_BY_CONTENT }

/// Content detection: the host asks this when a file's extension matched no plugin,
/// which is how `firmware.bin` gets opened at all.
///
/// It answers by **actually opening the image**, not by probing. Probing used to be
/// enough, and stopped being enough when carving arrived: `CarvedDriver` accepts any
/// file large enough to hold a filesystem and decides in its initialiser, because
/// whether an image has a rootfs buried in it cannot be known without looking for one.
/// A probe-based answer therefore became "yes" for every file on the system — and this
/// function's answer is load-bearing, since the host takes it as permission to open.
///
/// The work is not wasted. It goes through `ImageCache`, so a "yes" leaves the parsed
/// driver in the cache and the `OpenArchive` that follows is a dictionary hit. And the
/// host only asks on Enter, for one file the user chose — not while listing a folder.
@_cdecl("CanYouHandleThisFile")
public func CanYouHandleThisFile(_ fileName: UnsafeMutablePointer<CChar>?) -> Int32 {
    guard let fileName else { return 0 }
    return (try? ImageCache.shared.driver(for: String(cString: fileName))) != nil ? 1 : 0
}

@_cdecl("OpenArchive")
public func OpenArchive(_ data: UnsafeMutablePointer<PcOpenArchiveData>?) -> UnsafeMutableRawPointer? {
    guard let data, let arcName = data.pointee.arcName else { return nil }
    let path = String(cString: arcName)
    do {
        let driver = try ImageCache.shared.driver(for: path)
        data.pointee.openResult = Int32(PC_OK)
        return Unmanaged.passRetained(ImageHandle(driver: driver, path: path)).toOpaque()
    } catch {
        data.pointee.openResult = pcxError(for: error)
        return nil
    }
}

@_cdecl("ReadHeaderEx")
public func ReadHeaderEx(_ hArc: UnsafeMutableRawPointer?, _ hdr: UnsafeMutablePointer<PcHeaderDataEx>?) -> Int32 {
    guard let hArc, let hdr else { return Int32(PC_E_BAD_DATA) }
    let handle = Unmanaged<ImageHandle>.fromOpaque(hArc).takeUnretainedValue()
    let entries = handle.entries
    guard handle.index < entries.count else { return Int32(PC_E_END_ARCHIVE) }
    let entry = entries[handle.index]
    handle.index += 1

    setCString(entry.path, &hdr.pointee.fileName.0, 1024)
    hdr.pointee.unpSize = entry.size
    // No packed size is reported. Every format here compresses in shared blocks and
    // fragments, so the bytes "belonging" to one file are not a number the image
    // records; inventing one would put a wrong ratio in front of the user.
    hdr.pointee.packSize = entry.size
    hdr.pointee.fileTime = entry.mtime
    hdr.pointee.fileAttr = attributes(for: entry)
    hdr.pointee.fileCRC = 0
    hdr.pointee.method = 0
    return Int32(PC_OK)
}

private func attributes(for entry: ImageEntry) -> UInt32 {
    switch entry.kind {
    case .directory:  return UInt32(PC_ATTR_DIR)
    case .symlink:    return UInt32(PC_ATTR_SYMLINK)
    case .file, .special: return 0
    }
}

@_cdecl("ProcessFile")
public func ProcessFile(_ hArc: UnsafeMutableRawPointer?, _ operation: Int32,
                        _ destPath: UnsafeMutablePointer<CChar>?,
                        _ destName: UnsafeMutablePointer<CChar>?) -> Int32 {
    guard let hArc else { return Int32(PC_E_BAD_DATA) }
    let handle = Unmanaged<ImageHandle>.fromOpaque(hArc).takeUnretainedValue()
    guard operation == Int32(PC_EXTRACT) else { return Int32(PC_OK) }   // SKIP / TEST

    // ProcessFile acts on the entry the *last* ReadHeaderEx returned.
    let index = handle.index - 1
    let entries = handle.entries
    guard entries.indices.contains(index) else { return Int32(PC_E_BAD_DATA) }
    let entry = entries[index]

    switch entry.kind {
    case .directory, .special:
        return Int32(PC_OK)   // nothing to write
    case .symlink(let target):
        // A symlink inside an image is written out as a text file holding its
        // target. The host has no symlink concept inside an archive, and the
        // alternative — creating a real symlink in the destination — would let an
        // image plant a link to anywhere in the user's filesystem.
        return write(Array(target.utf8), destName: destName)
    case .file:
        guard let destName else { return Int32(PC_E_ECREATE) }
        guard let fileHandle = createFile(at: destName) else { return Int32(PC_E_ECREATE) }
        defer { try? fileHandle.close() }
        do {
            try handle.driver.extract(at: index, to: fileHandle)
            return Int32(PC_OK)
        } catch {
            return pcxError(for: error)
        }
    }
}

/// Create (or truncate) the destination and hand back a handle on it.
///
/// POSIX `open` on the caller's bytes, deliberately, rather than
/// `FileManager.createFile(atPath:)`. Foundation reaches the filesystem through
/// `fileSystemRepresentation`, which canonically *decomposes* the path on macOS: a
/// file the image calls "Grüße.txt" with a precomposed U+00FC came back out as
/// "u" plus a combining diaeresis. Both render identically and APFS treats them as
/// the same name, so nothing looked wrong — but the plugin had rewritten a name on
/// its way through, and for a tool used to audit firmware "the bytes you see are the
/// bytes in the image" is the whole promise. The host tells us exactly where to
/// write; writing anywhere else, by any amount, is not ours to do.
private func createFile(at destName: UnsafeMutablePointer<CChar>) -> FileHandle? {
    let fd = open(destName, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
    guard fd >= 0 else { return nil }
    return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
}

private func write(_ bytes: [UInt8], destName: UnsafeMutablePointer<CChar>?) -> Int32 {
    guard let destName, let handle = createFile(at: destName) else { return Int32(PC_E_ECREATE) }
    defer { try? handle.close() }
    do {
        try handle.write(contentsOf: Data(bytes))
        return Int32(PC_OK)
    } catch {
        return Int32(PC_E_EWRITE)
    }
}

@_cdecl("CloseArchive")
public func CloseArchive(_ hArc: UnsafeMutableRawPointer?) -> Int32 {
    guard let hArc else { return Int32(PC_OK) }
    // Releases the handle only. The parsed driver stays in ImageCache, which is the
    // whole reason reopening this image is cheap.
    Unmanaged<ImageHandle>.fromOpaque(hArc).release()
    return Int32(PC_OK)
}

// Required registrations. Neither callback is used: there are no multi-volume
// images, and extraction of a single entry is fast enough that per-file progress
// would cost more in callbacks than it reports.
@_cdecl("SetChangeVolProc")
public func SetChangeVolProc(_ hArc: UnsafeMutableRawPointer?, _ proc: UnsafeMutableRawPointer?) {}

@_cdecl("SetProcessDataProc")
public func SetProcessDataProc(_ hArc: UnsafeMutableRawPointer?, _ proc: UnsafeMutableRawPointer?) {}
