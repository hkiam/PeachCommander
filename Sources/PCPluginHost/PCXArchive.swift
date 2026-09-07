// SPDX-License-Identifier: Apache-2.0
// PCXArchive.swift - PCX packer plugin adapter (I14 T03).
//
// Drives a loaded PCX plugin's C ABI (pcx.h via the CPCX module) to browse and
// extract an archive: OpenArchive → loop ReadHeaderEx (+ ProcessFile skip/extract)
// → CloseArchive. This is the bridge the archive format registry uses for
// plugin-backed formats (before falling back to the built-in zip support).

import Foundation
import CPCX

/// Routes the context-less PCX progress/change-volume C callbacks to the active
/// operation's Swift handlers (F-231). PCX calls are serialized, so a single
/// lock-guarded "current" pair is sufficient.
final class PCXCallbackRouter: @unchecked Sendable {
    static let shared = PCXCallbackRouter()
    private let lock = NSLock()
    private var onProgress: ((String, Int64) -> Bool)?
    private var onChangeVol: ((String, Int32) -> Bool)?

    func set(progress: ((String, Int64) -> Bool)?, changeVol: ((String, Int32) -> Bool)?) {
        lock.lock(); onProgress = progress; onChangeVol = changeVol; lock.unlock()
    }
    func progress(_ name: String, _ size: Int64) -> Bool {
        lock.lock(); let cb = onProgress; lock.unlock()
        return cb?(name, size) ?? true
    }
    func changeVol(_ name: String, _ mode: Int32) -> Bool {
        lock.lock(); let cb = onChangeVol; lock.unlock()
        return cb?(name, mode) ?? true
    }
}

/// Top-level C trampolines (no captures → convertible to @convention(c)). They
/// forward to the shared router; return 1 to continue, 0 to abort (TC convention).
private let pcxProcessDataTrampoline: @convention(c) (UnsafeMutablePointer<CChar>?, Int64) -> Int32 = { namePtr, size in
    let name = namePtr.map { String(cString: $0) } ?? ""
    return PCXCallbackRouter.shared.progress(name, size) ? 1 : 0
}
private let pcxChangeVolTrampoline: @convention(c) (UnsafeMutablePointer<CChar>?, Int32) -> Int32 = { namePtr, mode in
    let name = namePtr.map { String(cString: $0) } ?? ""
    return PCXCallbackRouter.shared.changeVol(name, mode) ? 1 : 0
}

/// `ReadEntryData` (pcx.h, optional): one entry's bytes at an offset, without walking to it.
///
/// At file scope rather than nested in `PCXArchive` like its siblings, because the nested
/// `RandomAccessReader` holds one and Swift will not let a fileprivate initializer take a
/// private type.
typealias PCXReadEntryDataFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?,
                                               Int64, Int64, UnsafeMutableRawPointer?,
                                               UnsafeMutablePointer<Int64>?) -> Int32

public final class PCXArchive {
    public struct Entry: Equatable, Sendable {
        public let path: String
        public let size: Int64
        public let packedSize: Int64
        public let isDirectory: Bool
        public let modified: Date
    }

    public enum PCXError: Error, Equatable {
        case missingSymbol(String)
        case openFailed(Int)
        case readFailed(Int)
        case processFailed(Int)
        case entryNotFound(String)
        case notSupported(String)   // optional export not present
        case packFailed(Int)
        case deleteFailed(Int)
        case crashed                // the plugin crashed and was quarantined (F-230)
    }

    private let lib: PluginLibrary
    /// Identifier used to quarantine this plugin if it crashes (F-230).
    private let pluginID: String
    private let callGuard: PluginGuard

    public init(library: PluginLibrary, pluginID: String = "pcx", guard callGuard: PluginGuard = .shared) {
        self.lib = library
        self.pluginID = pluginID
        self.callGuard = callGuard
    }

    /// Run a plugin operation under the in-process crash guard (F-230): rethrows the
    /// operation's own error, or throws `.crashed` if the plugin faulted (after
    /// which it is quarantined and further calls fail fast).
    private func guarded<T>(_ body: @escaping () throws -> T) throws -> T {
        guard let outcome: Result<T, Error> = callGuard.guarded(pluginID, { Result { try body() } }) else {
            throw PCXError.crashed
        }
        return try outcome.get()
    }

    /// Register the progress/change-volume callbacks with the plugin for `handle`
    /// (nil for pack), routing them to this adapter's handlers (F-231). No-op when
    /// no handler is set or the plugin doesn't export the setters.
    private func installCallbacks(handle: UnsafeMutableRawPointer?) {
        guard onProgress != nil || onChangeVolume != nil else { return }
        PCXCallbackRouter.shared.set(
            progress: onProgress.map { cb in { cb(Progress(file: $0, bytes: $1)) } },
            changeVol: onChangeVolume)
        if let ptr = lib.symbol("SetProcessDataProc") {
            unsafeBitCast(ptr, to: SetProcessDataFn.self)(handle, pcxProcessDataTrampoline)
        }
        if let ptr = lib.symbol("SetChangeVolProc") {
            unsafeBitCast(ptr, to: SetChangeVolFn.self)(handle, pcxChangeVolTrampoline)
        }
    }

    private func clearCallbacks() {
        guard onProgress != nil || onChangeVolume != nil else { return }
        PCXCallbackRouter.shared.set(progress: nil, changeVol: nil)
    }

    // C function-pointer signatures (pcx.h).
    private typealias OpenFn = @convention(c) (UnsafeMutablePointer<PcOpenArchiveData>) -> UnsafeMutableRawPointer?
    private typealias ReadFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<PcHeaderDataEx>) -> Int32
    private typealias ProcFn = @convention(c) (UnsafeMutableRawPointer?, Int32,
                                               UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<CChar>?) -> Int32
    private typealias CloseFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
    private typealias PackFn = @convention(c) (UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<CChar>?,
                                               UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias DeleteFn = @convention(c) (UnsafeMutablePointer<CChar>?, UnsafeMutablePointer<CChar>?) -> Int32
    private typealias CapsFn = @convention(c) () -> Int32
    private typealias CanHandleFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Int32
    // Progress + change-volume callbacks (F-231). The C prototypes carry no user
    // context pointer, so the trampolines route through a process-wide router that
    // holds the active operation's handlers (PCX calls are serialized).
    private typealias ProcessDataProc = @convention(c) (UnsafeMutablePointer<CChar>?, Int64) -> Int32
    private typealias ChangeVolProc = @convention(c) (UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias SetProcessDataFn = @convention(c) (UnsafeMutableRawPointer?, ProcessDataProc?) -> Void
    private typealias SetChangeVolFn = @convention(c) (UnsafeMutableRawPointer?, ChangeVolProc?) -> Void

    /// A progress report from a running pack/extract (F-231).
    public struct Progress: Sendable, Equatable {
        public let file: String
        public let bytes: Int64
    }
    /// Called with per-item progress during pack/extract; return false to abort.
    public var onProgress: ((Progress) -> Bool)?
    /// Called when the plugin needs the next volume of a multi-volume archive
    /// (arcName, mode); return false to abort.
    public var onChangeVolume: ((String, Int32) -> Bool)?

    /// The PC_CAP_* bit mask from the plugin's optional GetPackerCaps export, or
    /// nil when the plugin doesn't advertise capabilities (F-231).
    public func packerCaps() -> Int? {
        guard let ptr = lib.symbol("GetPackerCaps") else { return nil }
        return Int(unsafeBitCast(ptr, to: CapsFn.self)())
    }

    /// Whether the loaded plugin can create/modify archives. Prefers the advertised
    /// GetPackerCaps bits (PC_CAP_NEW/PC_CAP_MODIFY); falls back to symbol presence.
    public var canPack: Bool {
        if let caps = packerCaps() { return caps & (Int(PC_CAP_NEW) | Int(PC_CAP_MODIFY)) != 0 }
        return lib.symbol("PackFiles") != nil
    }
    /// Whether the plugin offers to recognise files by content (PC_CAP_BY_CONTENT).
    ///
    /// Opt-in on the plugin's side, and the host consults `canHandle` only for plugins
    /// that say yes here: content detection means reading a header off every file whose
    /// extension matched nothing, so a plugin has to ask for that cost rather than have
    /// it applied on its behalf.
    public var detectsByContent: Bool {
        guard lib.symbol("CanYouHandleThisFile") != nil else { return false }
        guard let caps = packerCaps() else { return false }
        return caps & Int(PC_CAP_BY_CONTENT) != 0
    }

    /// Whether one entry can be reached without walking the archive to it (F-482).
    ///
    /// Both halves are required: the capability bit *and* the export. A plugin that advertises
    /// cheap access without providing a way to take it up would have the host promise the search
    /// engine something it then cannot deliver — and the search picks its whole strategy from
    /// this answer.
    public var supportsRandomAccess: Bool {
        guard lib.symbol("ReadEntryData") != nil else { return false }
        guard let caps = packerCaps() else { return false }
        return caps & Int(PC_CAP_RANDOM_ACCESS) != 0
    }

    /// Whether the loaded plugin can delete entries (PC_CAP_DELETE, else DeleteFiles).
    public var canDelete: Bool {
        if let caps = packerCaps() { return caps & Int(PC_CAP_DELETE) != 0 }
        return lib.symbol("DeleteFiles") != nil
    }

    /// Ask the plugin whether it handles `fileName` via its optional
    /// CanYouHandleThisFile export (F-231). Returns nil when the export is absent
    /// (the host then falls back to extension matching).
    public func canHandle(fileName: String) -> Bool? {
        guard let ptr = lib.symbol("CanYouHandleThisFile") else { return nil }
        let fn = unsafeBitCast(ptr, to: CanHandleFn.self)
        return fileName.withCString { fn(UnsafeMutablePointer(mutating: $0)) != 0 }
    }

    // MARK: - Public API

    /// List all entries in `archivePath`.
    public func list(archivePath: String) throws -> [Entry] {
      try guarded {
        var entries: [Entry] = []
        try self.withArchive(archivePath, mode: Int32(PC_OM_LIST)) { handle, read, proc in
            while true {
                var hdr = PcHeaderDataEx()
                let rc = read(handle, &hdr)
                if Int(rc) == Int(PC_E_END_ARCHIVE) { break }
                guard rc == Int32(PC_OK) else { throw PCXError.readFailed(Int(rc)) }
                entries.append(Self.entry(from: hdr))
                let prc = proc(handle, Int32(PC_SKIP), nil, nil)
                guard prc == Int32(PC_OK) else { throw PCXError.processFailed(Int(prc)) }
            }
        }
        return entries
      }
    }

    /// Extract the entry whose archive path equals `entryPath` to `destinationFile`.
    public func extract(archivePath: String, entryPath: String, to destinationFile: String) throws {
      try guarded {
        var extracted = false
        try self.withArchive(archivePath, mode: Int32(PC_OM_EXTRACT)) { handle, read, proc in
            while true {
                var hdr = PcHeaderDataEx()
                let rc = read(handle, &hdr)
                if Int(rc) == Int(PC_E_END_ARCHIVE) { break }
                guard rc == Int32(PC_OK) else { throw PCXError.readFailed(Int(rc)) }
                let name = Self.fileName(from: hdr)
                let op = (name == entryPath) ? Int32(PC_EXTRACT) : Int32(PC_SKIP)
                let prc: Int32
                if op == Int32(PC_EXTRACT) {
                    prc = destinationFile.withCString { destPtr -> Int32 in
                        // Pass the full destination as destName, empty destPath.
                        let mutable = UnsafeMutablePointer(mutating: destPtr)
                        return proc(handle, op, nil, mutable)
                    }
                    extracted = true
                } else {
                    prc = proc(handle, op, nil, nil)
                }
                guard prc == Int32(PC_OK) else { throw PCXError.processFailed(Int(prc)) }
                if extracted { break }
            }
        }
        if !extracted { throw PCXError.entryNotFound(entryPath) }
      }
    }

    /// A handle held open across many `read` calls on one archive (F-482).
    ///
    /// The point of `ReadEntryData` is not only that the plugin can seek — it is that the archive
    /// stays open between reads. Opening and closing it per chunk would put back most of the cost
    /// the export exists to remove.
    public final class RandomAccessReader: @unchecked Sendable {
        private let owner: PCXArchive
        private let handle: UnsafeMutableRawPointer
        private let read: PCXReadEntryDataFn
        private var closed = false
        /// Serialises calls on this handle, which is a promise the ABI makes and the host has to keep.
        ///
        /// `pcx.h`: *the host serialises calls per open archive HANDLE unless GetPackerCaps reports
        /// PC_CAP_MULTITHREAD.* Every other path in this file kept that for free by opening a fresh
        /// handle per operation. This one deliberately does not — holding the archive open between
        /// reads is half of what `ReadEntryData` buys — so one mount's handle is now shared by every
        /// stream reading out of it, and two panels reading two files at once would have reached the
        /// plugin concurrently. The sample packer seeks and reads a `FILE *`; interleaving those is
        /// not a crash, it is the wrong bytes in the right file.
        private let callLock = NSLock()

        fileprivate init(owner: PCXArchive, handle: UnsafeMutableRawPointer, read: @escaping PCXReadEntryDataFn) {
            self.owner = owner
            self.handle = handle
            self.read = read
        }

        /// Up to `length` bytes of `entryPath` from `offset`. A short result means the end.
        public func read(entryPath: String, offset: Int64, length: Int64) throws -> Data {
            callLock.lock()
            defer { callLock.unlock() }
            guard !closed, length > 0 else { return Data() }
            return try owner.guarded { [handle, read] in
                var buffer = Data(count: Int(length))
                var produced: Int64 = 0
                let rc: Int32 = entryPath.withCString { name in
                    buffer.withUnsafeMutableBytes { raw -> Int32 in
                        read(handle, name, offset, length, raw.baseAddress, &produced)
                    }
                }
                if Int(rc) == Int(PC_E_END_ARCHIVE) { throw PCXError.entryNotFound(entryPath) }
                guard rc == Int32(PC_OK) else { throw PCXError.readFailed(Int(rc)) }
                guard produced > 0 else { return Data() }
                return buffer.prefix(Int(produced))
            }
        }

        public func close() {
            callLock.lock()
            guard !closed else { callLock.unlock(); return }
            closed = true
            callLock.unlock()
            // Outside the lock: CloseArchive is a plugin call like any other, and a read in flight
            // holds the lock until it returns — waiting for it is the point, deadlocking on it is not.
            owner.closeHandle(handle)
        }

        deinit { close() }
    }

    /// Open `archivePath` for random access, or nil when this plugin does not offer it.
    public func openRandomAccess(archivePath: String) -> RandomAccessReader? {
        guard supportsRandomAccess,
              let readPtr = lib.symbol("ReadEntryData"),
              let openPtr = lib.symbol("OpenArchive") else { return nil }
        let outcome: UnsafeMutableRawPointer?? = callGuard.guarded(pluginID) { () -> UnsafeMutableRawPointer? in
            let open = unsafeBitCast(openPtr, to: OpenFn.self)
            return archivePath.withCString { arc -> UnsafeMutableRawPointer? in
                var data = PcOpenArchiveData()
                data.arcName = UnsafeMutablePointer(mutating: arc)
                data.openMode = Int32(PC_OM_EXTRACT)
                return open(&data)
            }
        }
        guard let handle = outcome ?? nil else { return nil }
        return RandomAccessReader(owner: self, handle: handle,
                                  read: unsafeBitCast(readPtr, to: PCXReadEntryDataFn.self))
    }

    /// Close a handle opened by `openRandomAccess`, under the crash guard.
    fileprivate func closeHandle(_ handle: UnsafeMutableRawPointer) {
        guard let closePtr = lib.symbol("CloseArchive") else { return }
        _ = callGuard.guarded(pluginID) { unsafeBitCast(closePtr, to: CloseFn.self)(handle) }
    }

    /// Pack `files` (relative to `sourceDir`) into `archivePath`, creating it if
    /// needed. `subPath` is an optional path prefix stored inside the archive.
    public func pack(archivePath: String, sourceDir: String, files: [String],
                     subPath: String = "", moveFiles: Bool = false) throws {
      try guarded {
        guard let ptr = self.lib.symbol("PackFiles") else { throw PCXError.notSupported("PackFiles") }
        self.installCallbacks(handle: nil)          // progress/change-vol for packing (F-231)
        defer { self.clearCallbacks() }
        let pack = unsafeBitCast(ptr, to: PackFn.self)
        let addList = Self.doubleNulList(files)
        let flags = moveFiles ? Int32(PC_PK_MOVE_FILES) : 0
        let rc = archivePath.withCString { arc in
            subPath.withCString { sub in
                sourceDir.withCString { src in
                    addList.withUnsafeBufferPointer { list in
                        pack(UnsafeMutablePointer(mutating: arc), UnsafeMutablePointer(mutating: sub),
                             UnsafeMutablePointer(mutating: src),
                             UnsafeMutablePointer(mutating: list.baseAddress), flags)
                    }
                }
            }
        }
        guard rc == Int32(PC_OK) else { throw PCXError.packFailed(Int(rc)) }
      }
    }

    /// Delete `entries` (archive-relative paths) from `archivePath`.
    public func delete(archivePath: String, entries: [String]) throws {
      try guarded {
        guard let ptr = self.lib.symbol("DeleteFiles") else { throw PCXError.notSupported("DeleteFiles") }
        let del = unsafeBitCast(ptr, to: DeleteFn.self)
        let list = Self.doubleNulList(entries)
        let rc = archivePath.withCString { arc in
            list.withUnsafeBufferPointer { l in
                del(UnsafeMutablePointer(mutating: arc), UnsafeMutablePointer(mutating: l.baseAddress))
            }
        }
        guard rc == Int32(PC_OK) else { throw PCXError.deleteFailed(Int(rc)) }
      }
    }

    /// Build a NUL-separated, double-NUL-terminated C list from UTF-8 strings.
    private static func doubleNulList(_ items: [String]) -> [CChar] {
        var buf: [CChar] = []
        for item in items {
            buf.append(contentsOf: item.utf8CString)   // includes trailing NUL
        }
        buf.append(0)   // final terminating NUL (double-NUL overall)
        return buf
    }

    // MARK: - Internals

    private func withArchive(_ path: String, mode: Int32,
                             _ body: (UnsafeMutableRawPointer?, ReadFn, ProcFn) throws -> Void) throws {
        guard let openPtr = lib.symbol("OpenArchive") else { throw PCXError.missingSymbol("OpenArchive") }
        guard let readPtr = lib.symbol("ReadHeaderEx") else { throw PCXError.missingSymbol("ReadHeaderEx") }
        guard let procPtr = lib.symbol("ProcessFile") else { throw PCXError.missingSymbol("ProcessFile") }
        guard let closePtr = lib.symbol("CloseArchive") else { throw PCXError.missingSymbol("CloseArchive") }
        let open = unsafeBitCast(openPtr, to: OpenFn.self)
        let read = unsafeBitCast(readPtr, to: ReadFn.self)
        let proc = unsafeBitCast(procPtr, to: ProcFn.self)
        let close = unsafeBitCast(closePtr, to: CloseFn.self)

        let handle: UnsafeMutableRawPointer? = try path.withCString { cpath in
            let mutablePath = UnsafeMutablePointer(mutating: cpath)
            var data = PcOpenArchiveData()
            data.arcName = mutablePath
            data.openMode = mode
            let h = open(&data)
            if h == nil { throw PCXError.openFailed(Int(data.openResult)) }
            return h
        }
        defer { _ = close(handle) }
        installCallbacks(handle: handle)            // progress/change-vol for extract (F-231)
        defer { clearCallbacks() }
        try body(handle, read, proc)
    }

    private static func entry(from hdr: PcHeaderDataEx) -> Entry {
        Entry(path: fileName(from: hdr),
              size: hdr.unpSize,
              packedSize: hdr.packSize,
              isDirectory: (hdr.fileAttr & UInt32(PC_ATTR_DIR)) != 0,
              modified: Date(timeIntervalSince1970: TimeInterval(hdr.fileTime)))
    }

    /// Read the fixed C `char fileName[1024]` (imported as a tuple) into a String.
    private static func fileName(from hdr: PcHeaderDataEx) -> String {
        var hdr = hdr
        return withUnsafePointer(to: &hdr.fileName) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
        }
    }
}
