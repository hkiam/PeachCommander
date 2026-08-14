// SPDX-License-Identifier: Apache-2.0
// PFXFileSystem.swift - VirtualFileSystem backed by a PFX (file-system) plugin.
//
// Adapts a loaded PFX plugin's WFX-style, whole-file C ABI to the host's async
// streaming VirtualFileSystem. Directory enumeration maps to PfxFindFirst/Next
// (metadata only, fast); openRead materialises the whole file to a temp path via
// PfxGetFile and streams from there; openWrite buffers to a temp file uploaded by
// PfxPutFile on close. All blocking C calls run on one dedicated serial queue —
// this keeps network I/O off the Swift concurrency pool and gives the per-
// connection serialization the ABI assumes. Mirrors PCXArchiveFS.

import Foundation
import PCVFS
import CPFX

public enum PFXSymbols {
    public static let required: [String] = []
    public static let optional = [
        "PfxInit", "PfxGetCapabilities",
        "PfxGetVolumeCount", "PfxGetVolumeInfo",
        "PfxGetConnectTitle", "PfxConnect", "PfxConnectionId", "PfxDisconnect",
        "PfxFindFirst", "PfxFindNext", "PfxFindClose", "PfxStat",
        "PfxGetFile", "PfxPutFile", "PfxMkDir", "PfxDelete", "PfxRenMov",
        "PfxContentFieldCount", "PfxContentField", "PfxContentGetRow", "PfxLookup",
        "PfxLastError",
        "PcGetApiVersion", "PcSafeToUnload",
    ]
}

/// A static drive a PFX plugin contributes to the drive bar (e.g. iCloud Drive).
public struct PFXVolume: Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let isLocal: Bool
    public let isRemovable: Bool
    public let icon: String    // emoji for the drive chip ("" = host default)
    public let order: Int      // >0 pins right after the boot drive
}

/// A content column a PFX plugin publishes for its entries (PfxContentField).
public struct PFXContentField: Sendable {
    public let name: String       // field id leaf, e.g. "cpu"
    public let title: String      // column header
    public let type: Int32        // PFX_FT_*
    public let defaultWidth: Int

    /// Numeric/size fields align right; strings and date/time align left. Keeps
    /// the CPFX PFX_FT_* constants inside PCPluginHost (the app need not link C).
    public var isRightAligned: Bool { type == PFX_FT_NUMERIC || type == PFX_FT_SIZE }

    /// Fields whose display strings sort by numeric value, not lexically (so
    /// "10" sorts after "2"). Size/date-time are numeric under the hood too.
    public var isNumericSort: Bool {
        type == PFX_FT_NUMERIC || type == PFX_FT_SIZE || type == PFX_FT_DATETIME
    }
}

/// Typed wrapper over a loaded PFX plugin library (facet probing + calls).
public final class PFXPlugin: @unchecked Sendable {
    let lib: PluginLibrary

    typealias InitFn = @convention(c) (UnsafePointer<PfxHostServices>?) -> Void
    typealias CapsFn = @convention(c) () -> Int32
    typealias VolCountFn = @convention(c) () -> Int32
    typealias VolInfoFn = @convention(c) (Int32, UnsafeMutablePointer<PfxVolumeInfo>?) -> Void
    typealias ConnTitleFn = @convention(c) (UnsafeMutablePointer<CChar>?, Int32) -> Int32
    typealias ConnectFn = @convention(c) (UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer?
    typealias ConnIdFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    typealias DisconnectFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
    typealias FieldCountFn = @convention(c) () -> Int32
    typealias FieldFn = @convention(c) (Int32, UnsafeMutablePointer<PfxFieldInfo>?) -> Void
    typealias ContentRowFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    typealias LookupFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutablePointer<CChar>?, Int32) -> Int32
    typealias LastErrorFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32

    public init(library: PluginLibrary) { self.lib = library }

    /// The services table handed to `PfxInit`. Allocated once and deliberately never freed.
    ///
    /// The ABI lets the plugin keep this pointer for as long as it is loaded, and the host has no
    /// way to learn when it has stopped using it — there is no "forget your services" call, and
    /// adding one would make every plugin author responsible for a rule they cannot get wrong
    /// safely. Freeing it when *this object* goes away would be tying the lifetime to the wrong
    /// thing anyway: two `PFXPlugin` instances can wrap one library, so the last reference here
    /// dying says nothing about whether the plugin is still loaded. One struct per loaded
    /// file-system plugin, for the life of the process, is the cheap side of that trade.
    private var servicesBox: UnsafeMutablePointer<PfxHostServices>?

    func fn<T>(_ name: String, as type: T.Type) -> T? {
        lib.symbol(name).map { unsafeBitCast($0, to: T.self) }
    }

    /// Hand the plugin its host services once, right after loading (`PfxInit`).
    ///
    /// The ABI says the plugin may retain the pointer for as long as it is loaded, so the table
    /// cannot live on the caller's stack — it is copied to the heap and freed only when this
    /// object goes away, which is when the library does. A stack copy would dangle the instant
    /// this returned, and the symptom would be a callback into freed memory much later, from the
    /// plugin, with nothing in the backtrace pointing here.
    ///
    /// Does nothing when the plugin exports no `PfxInit` — the entry point is optional, and a
    /// plugin that persists nothing has no reason to want it.
    public func initialize(services: PfxHostServices) {
        guard servicesBox == nil, let f = fn("PfxInit", as: InitFn.self) else { return }
        let box = UnsafeMutablePointer<PfxHostServices>.allocate(capacity: 1)
        box.initialize(to: services)
        servicesBox = box
        f(box)
    }

    /// Capabilities the served file system supports (read is always implied).
    public var capabilities: VFSCapabilities {
        var caps: VFSCapabilities = [.read]
        if let f = fn("PfxGetCapabilities", as: CapsFn.self) {
            let bits = f()
            if bits & PC_PFX_CAP_WRITE != 0 { caps.insert(.write) }
            if bits & PC_PFX_CAP_RENAME != 0 { caps.insert(.rename) }
        }
        return caps
    }

    /// True when the served contents change live (host may auto-refresh, F-…).
    public var isVolatile: Bool {
        guard let f = fn("PfxGetCapabilities", as: CapsFn.self) else { return false }
        return f() & PC_PFX_CAP_VOLATILE != 0
    }

    /// Content columns this plugin publishes for its entries (empty = none).
    public func contentFields() -> [PFXContentField] {
        guard let count = fn("PfxContentFieldCount", as: FieldCountFn.self),
              let field = fn("PfxContentField", as: FieldFn.self) else { return [] }
        var out: [PFXContentField] = []
        for i in 0..<count() {
            var raw = PfxFieldInfo()
            field(i, &raw)
            let name = Self.string(&raw.name.0)
            guard !name.isEmpty else { continue }
            out.append(PFXContentField(name: name, title: Self.string(&raw.title.0),
                                       type: raw.type, defaultWidth: Int(raw.defaultWidth)))
        }
        return out
    }

    /// Why the plugin's last call on `conn` failed, or nil when it does not say.
    ///
    /// Only worth asking after a call that answers with a handle has answered NULL — those have no
    /// other channel. `PC_OK` counts as "not tracked" rather than "succeeded": a plugin that does
    /// not implement this returns the same thing as one that has nothing to report, and neither
    /// should be read as a claim about what happened.
    func lastError(_ conn: UnsafeMutableRawPointer) -> Int32? {
        guard let f = fn("PfxLastError", as: LastErrorFn.self) else { return nil }
        let code = f(conn)
        return code == PC_OK ? nil : code
    }

    /// All field values for `path`, tab-split in field order, or nil if absent.
    public func contentRow(_ conn: UnsafeMutableRawPointer, path: String) -> [String]? {
        guard let f = fn("PfxContentGetRow", as: ContentRowFn.self) else { return nil }
        var buf = [CChar](repeating: 0, count: 8192)
        let rc = path.withCString { p in f(conn, p, &buf, Int32(buf.count)) }
        guard rc != 0 else { return nil }
        return String(cString: buf).components(separatedBy: "\t")
    }

    /// Resolve a plugin-defined `query` to an existing entry path, or nil on no
    /// match (e.g. TaskManager "port:8080" → "/nginx (1234)").
    ///
    /// A query may answer with many entries, one per line — "file:<path>" names every
    /// process holding that file open. 64 KiB rather than the 2 KiB a single answer
    /// needs, because a list is what silently loses rows: the plugin fills what it is
    /// given and a small buffer would drop the tail without anyone noticing.
    public func lookup(_ conn: UnsafeMutableRawPointer, query: String) -> String? {
        guard let f = fn("PfxLookup", as: LookupFn.self) else { return nil }
        var buf = [CChar](repeating: 0, count: 64 * 1024)
        let rc = query.withCString { q in f(conn, q, &buf, Int32(buf.count)) }
        guard rc != 0 else { return nil }
        let s = String(cString: buf)
        return s.isEmpty ? nil : s
    }

    /// Static drives this plugin contributes (empty if it has no volumes facet).
    public func volumes() -> [PFXVolume] {
        guard let count = fn("PfxGetVolumeCount", as: VolCountFn.self),
              let info = fn("PfxGetVolumeInfo", as: VolInfoFn.self) else { return [] }
        var out: [PFXVolume] = []
        for i in 0..<count() {
            var raw = PfxVolumeInfo()
            info(i, &raw)
            let id = Self.string(&raw.id.0)
            let path = Self.string(&raw.path.0)
            let isLocal = raw.flags & PC_PFX_VOL_LOCAL != 0
            // Local drives need a real path; a non-local mount volume (e.g.
            // TaskManager) legitimately has none — it connects on click instead.
            guard !id.isEmpty, !path.isEmpty || !isLocal else { continue }
            out.append(PFXVolume(id: id, name: Self.string(&raw.name.0), path: path,
                                 isLocal: isLocal,
                                 isRemovable: raw.flags & PC_PFX_VOL_REMOVABLE != 0,
                                 icon: Self.string(&raw.icon.0), order: Int(raw.order)))
        }
        return out
    }

    /// The interactive connect command's title, or nil if this plugin has no
    /// connect facet.
    public func connectTitle() -> String? {
        guard let f = fn("PfxGetConnectTitle", as: ConnTitleFn.self) else { return nil }
        var buf = [CChar](repeating: 0, count: 512)
        return f(&buf, 512) != 0 ? String(cString: buf) : nil
    }

    /// Run the plugin's connect UI; returns an opaque connection handle or nil.
    public func connect(services: UnsafePointer<PfxHostServices>) -> UnsafeMutableRawPointer? {
        fn("PfxConnect", as: ConnectFn.self)?(services) ?? nil
    }

    /// A short stable id for a connection (mount scheme/title).
    public func connectionId(_ conn: UnsafeMutableRawPointer) -> String {
        guard let f = fn("PfxConnectionId", as: ConnIdFn.self) else { return "pfx" }
        var buf = [CChar](repeating: 0, count: 256)
        return f(conn, &buf, 256) != 0 ? String(cString: buf) : "pfx"
    }

    public func disconnect(_ conn: UnsafeMutableRawPointer) {
        fn("PfxDisconnect", as: DisconnectFn.self)?(conn)
    }

    /// True when this plugin offers a connect facet but exports no `PfxDisconnect`.
    ///
    /// `PFXSymbols.required` is empty and every facet is capability-probed, so such a plugin loads
    /// and works — and then leaks whatever `PfxConnect` allocated, once per connection, silently.
    /// The host has nothing to call and cannot fix it; naming it at load time is the most it can
    /// honestly do, and it is the plugin author who has to see it.
    public var connectsWithoutDisconnect: Bool {
        connectTitle() != nil && fn("PfxDisconnect", as: DisconnectFn.self) == nil
    }

    static func string(_ ptr: UnsafePointer<CChar>) -> String { String(cString: ptr) }
}

/// VirtualFileSystem over a PFX connection handle. Not for volumes-only plugins.
///
/// Disconnecting used to be something ARC did whenever it got round to releasing this object:
/// `PfxDisconnect` was called from `deinit`, fire-and-forget. That made the host unable to honour
/// its own commands — `cm_FtpDisconnect` skips anything that is not a `DisconnectableFileSystem`,
/// so it silently did nothing on a plugin mount — and it meant a plugin with anything to flush had
/// no reliable moment to do it, least of all at quit, where `deinit` may never run at all.
///
/// It is now explicit, which is the whole difficulty: a disconnect can arrive while this object is
/// alive and being called, and `PfxDisconnect` frees the plugin's own state. So the handle is
/// *taken* rather than read (exactly-once by construction, no second free from `deinit`), and every
/// call that reaches the plugin goes through `withConnection`, which both refuses to run after the
/// handle is gone and holds it for the duration — which is also the "never two calls on one
/// connection at once" that `pfx.h` has always promised plugins and that content-column reads,
/// coming straight off the main thread, did not honour.
public final class PFXFileSystem: VirtualFileSystem, DisconnectableFileSystem, @unchecked Sendable {
    public let scheme: String
    public let capabilities: VFSCapabilities

    private let plugin: PFXPlugin
    /// The plugin's connection handle, or nil once it has been handed back to `PfxDisconnect`.
    private var conn: UnsafeMutableRawPointer?
    private let connLock = NSLock()
    /// Raised the moment a disconnect is asked for, so an enumeration in flight stops asking for
    /// entries instead of holding the disconnect up until a slow remote directory has been read to
    /// the end. Deliberately *not* guarded by `connLock`: the enumeration holds that lock, so a
    /// flag written under it could never reach the loop that has to see it.
    private let closing = CancelFlag()
    private let fsID: String
    private let retaining: AnyObject?   // keeps the host-services table/bridge alive
    private let queue: DispatchQueue

    /// Content columns this mount publishes, and the qualifier under which the
    /// host exposes them (fieldID = "<qualifier>.<leaf>"). Empty if none.
    public let contentFields: [PFXContentField]
    public let contentQualifier: String
    /// True when the mount's contents change live (host may auto-refresh).
    public let isVolatile: Bool
    /// Per-listing cache of content rows (cleared on each list()).
    private let cacheLock = NSLock()
    private var rowCache: [String: [String]] = [:]

    typealias FindFirstFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?
    typealias FindNextFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutablePointer<PfxFindData>?) -> Int32
    typealias FindCloseFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
    typealias StatFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafeMutablePointer<PfxFindData>?) -> Int32
    typealias XferFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Int32
    typealias PathFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Int32
    typealias RenMovFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UnsafePointer<CChar>?, Int32) -> Int32

    public init(plugin: PFXPlugin, conn: UnsafeMutableRawPointer, fsID: String,
                capabilities: VFSCapabilities, retaining: AnyObject?,
                contentQualifier: String = "") {
        self.plugin = plugin
        self.conn = conn
        self.fsID = fsID
        self.scheme = fsID
        self.capabilities = capabilities
        self.retaining = retaining
        self.contentFields = plugin.contentFields()
        self.contentQualifier = contentQualifier
        self.isVolatile = plugin.isVolatile
        self.queue = DispatchQueue(label: "pcx.pfx.\(fsID)")
    }

    /// Qualified column specs this mount offers (fieldID = "<qualifier>.<leaf>").
    public var qualifiedContentFields: [(qualifiedID: String, field: PFXContentField)] {
        contentFields.map { ("\(contentQualifier).\($0.name)", $0) }
    }

    /// Resolve a qualified content field for the entry at `path` (cached per
    /// listing). Returns nil for a field this mount doesn't own.
    public func contentDisplay(fieldID: String, path: String) -> String? {
        let parts = fieldID.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == contentQualifier,
              let index = contentFields.firstIndex(where: { $0.name == parts[1] }) else { return nil }
        cacheLock.lock()
        var row = rowCache[path]
        cacheLock.unlock()
        if row == nil {
            // `try?` because a column has nowhere to report an error to: a disconnected mount
            // shows an empty cell, which is what it is.
            row = try? withConnection { plugin.contentRow($0, path: path) }
            cacheLock.lock(); rowCache[path] = row ?? []; cacheLock.unlock()
        }
        guard let row, index < row.count else { return nil }
        let value = row[index]
        // PFX_FT_SIZE has meant "bytes — the host renders KB/MB and sorts numerically" since the
        // header was written, and the host only ever did the sorting half: a plugin that followed
        // the documentation showed a raw byte count. Formatting here rather than in the panel
        // because the column, the copy-value menu and the process tree all read through this one
        // call, and a size formatted in only one of them is a column that disagrees with itself.
        guard contentFields[index].type == PFX_FT_SIZE, let bytes = Int64(value) else { return value }
        return Self.formatBytes(bytes)
    }

    /// Bytes as KB/MB/GB, one decimal from MB up — the panel's own size style for a plugin column.
    static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 0 { return "" }
        if bytes < 1024 { return "\(bytes) B" }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes) / 1024, unit = 0
        while value >= 1024, unit + 1 < units.count { value /= 1024; unit += 1 }
        return unit == 0 ? String(format: "%.0f %@", value, units[unit])
                         : String(format: "%.1f %@", value, units[unit])
    }

    /// The value a column SORTS by — what the plugin wrote, before any formatting.
    ///
    /// Separate from `contentDisplay` because formatting destroys order: "9.9 MB" and "1.2 GB"
    /// compare as 9.9 and 1.2, so a size column that reads correctly would sort backwards.
    public func contentSortValue(fieldID: String, path: String) -> String? {
        let parts = fieldID.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2, parts[0] == contentQualifier,
              let index = contentFields.firstIndex(where: { $0.name == parts[1] }) else { return nil }
        cacheLock.lock()
        var row = rowCache[path]
        cacheLock.unlock()
        if row == nil {
            row = try? withConnection { plugin.contentRow($0, path: path) }
            cacheLock.lock(); rowCache[path] = row ?? []; cacheLock.unlock()
        }
        guard let row, index < row.count else { return nil }
        return row[index]
    }

    /// Drop cached content rows (call when the listing is (re)loaded).
    public func invalidateContentCache() {
        cacheLock.lock(); rowCache.removeAll(); cacheLock.unlock()
    }

    /// Resolve a plugin query (e.g. "port:8080") to an existing entry path, or
    /// nil on no match. Used by host "jump to matching entry" features.
    public func lookup(query: String) -> String? {
        (try? withConnection { plugin.lookup($0, query: query) }) ?? nil
    }

    // MARK: - Connection lifetime

    /// Run `body` with the live connection handle.
    ///
    /// Throws `connectionLost` once the handle has been handed back — the mount really is gone and
    /// retrying will not bring it back, which is what tells a caller to stop rather than to wait.
    /// The lock is held across `body`, so an explicit disconnect cannot land between the check and
    /// the call it is guarding: that gap is a use-after-free, and it is the price of making
    /// disconnect something a user can ask for.
    private func withConnection<T>(_ body: (UnsafeMutableRawPointer) throws -> T) throws -> T {
        connLock.lock()
        defer { connLock.unlock() }
        guard !closing.isSet, let conn else { throw VFSError.connectionLost(retryable: false) }
        return try body(conn)
    }

    /// Take the handle, leaving nothing behind. The exactly-once guarantee `pfx.h` gives plugins is
    /// this line: whoever takes it calls `PfxDisconnect`, and everyone after them gets nil.
    private func takeConnection() -> UnsafeMutableRawPointer? {
        connLock.lock()
        defer { connLock.unlock() }
        let handle = conn
        conn = nil
        return handle
    }

    /// Hand the connection back to the plugin and make this mount inert (F-…).
    ///
    /// Awaited, unlike the old `deinit` version: the host asks for this when the user closes the
    /// mount or when the app is quitting, and both want to know it has actually happened before
    /// carrying on. Queued behind any call already running, so a plugin is never freed underneath
    /// one of its own.
    public func disconnect() async {
        closing.set()          // first: an enumeration in flight has to stop before we queue behind it
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [self] in
                if let handle = takeConnection() { plugin.disconnect(handle) }
                cont.resume()
            }
        }
    }

    deinit {
        // Only if nothing asked for it first. `PfxDisconnect` frees the plugin's own state, so a
        // second call is a double free — which is why the handle is taken above rather than read.
        guard let handle = takeConnection() else { return }
        let p = plugin
        queue.async { p.disconnect(handle) }
    }

    // MARK: - Serial off-main execution of blocking C calls

    private func run<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try body()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    private static func vfsError(_ code: Int32, _ path: String) -> VFSError {
        switch code {
        // Before the others, because it is about the mount rather than the file: the host leaves
        // the drive on this one. Retryable in the sense that connecting again works — not that this
        // connection can be used for anything further.
        case PC_E_CONNECTION_LOST: return .connectionLost(retryable: true)
        case PC_E_EOPEN, PC_E_BAD_ARCHIVE: return .notFound(path)
        case PC_E_ECREATE, PC_E_EWRITE: return .permissionDenied(needsElevation: false)
        case PC_E_NOT_SUPPORTED: return .unsupported
        case PC_E_EABORTED: return .cancelled
        default: return .underlying(code: code, message: "PFX error \(code)")
        }
    }

    /// Batch size for streaming directory listings — large/slow (network) PFX
    /// mounts appear incrementally instead of only after full enumeration.
    private static let listBatchSize = 128

    private static func entry(from d: PfxFindData) -> VFSEntry {
        var raw = d
        // Read the fixed 1024-byte name buffer up to the first NUL, but never
        // past the buffer (a plugin that fills all 1024 bytes without a
        // terminator must not cause an out-of-bounds read).
        let name = withUnsafeBytes(of: &raw.name) { buf -> String in
            let bytes = buf.bindMemory(to: UInt8.self)
            let len = bytes.firstIndex(of: 0) ?? bytes.count
            return String(decoding: bytes[..<len], as: UTF8.self)
        }
        let isDir = d.isDir != 0
        let ext: String
        if isDir { ext = "" } else {
            let parts = name.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            ext = parts.count > 1 ? String(parts[1]) : ""
        }
        return VFSEntry(name: name, ext: ext, kind: isDir ? .directory : .file,
                        size: d.size, modified: Date(timeIntervalSince1970: TimeInterval(d.mtime)),
                        posixMode: UInt16(truncatingIfNeeded: d.mode))
    }

    // MARK: - VirtualFileSystem

    public func list(_ dir: VFSPath) -> AsyncThrowingStream<VFSEntryBatch, Error> {
        invalidateContentCache()   // content rows are per-listing (F-…)
        return AsyncThrowingStream { continuation in
            // Abort promptly when the consumer stops iterating (navigated away,
            // task cancelled): the loop below checks this between PfxFindNext
            // calls and closes the find handle early instead of enumerating a
            // whole slow/remote directory to completion.
            let cancelled = CancelFlag()
            continuation.onTermination = { _ in cancelled.set() }
            queue.async { [self] in
                guard let findFirst = plugin.fn("PfxFindFirst", as: FindFirstFn.self),
                      let findNext = plugin.fn("PfxFindNext", as: FindNextFn.self) else {
                    continuation.finish(throwing: VFSError.unsupported); return
                }
                let findClose = plugin.fn("PfxFindClose", as: FindCloseFn.self)
                // The whole enumeration runs inside `withConnection`, not one call at a time: a
                // find handle belongs to its connection, and a plugin is entitled to allocate it
                // out of the connection's own state. Releasing the connection between two
                // `PfxFindNext` calls would leave this loop reading freed memory — so the handle is
                // opened, drained and closed without the connection being takeable in between.
                // What keeps that from holding a disconnect for the length of a slow remote
                // directory is `closing`, checked per entry below.
                do {
                    try withConnection { conn in
                        guard let handle = dir.path.withCString({ findFirst(conn, $0) }) else {
                            // NULL is all `PfxFindFirst` can say, and it says it for a missing
                            // directory and for a connection that has died alike. Assuming the
                            // first told the user their directory was gone whenever a server
                            // dropped mid-listing; `PfxLastError` is the plugin's chance to say
                            // which it was. A plugin that does not export it keeps the old answer.
                            throw Self.vfsError(plugin.lastError(conn) ?? PC_E_EOPEN, dir.path)
                        }
                        defer { findClose?(handle) }
                        var batch: [VFSEntry] = []
                        batch.reserveCapacity(Self.listBatchSize)
                        var d = PfxFindData()
                        while findNext(handle, &d) != 0 {
                            // The consumer stopped reading, or the mount is being closed. Either
                            // way stop asking for entries — and let `defer` close the handle before
                            // the connection can go.
                            if cancelled.isSet || closing.isSet { continuation.finish(); return }
                            let e = Self.entry(from: d)
                            if !e.name.isEmpty, e.name != ".", e.name != ".." { batch.append(e) }
                            if batch.count >= Self.listBatchSize {
                                continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: false))
                                batch.removeAll(keepingCapacity: true)
                            }
                            d = PfxFindData()
                        }
                        // Final batch (empty for an empty directory) closes the listing.
                        continuation.yield(VFSEntryBatch(entries: batch, isLastBatch: true))
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stat(_ path: VFSPath) async throws -> VFSEntry {
        try await run { [self] in
            guard let statFn = plugin.fn("PfxStat", as: StatFn.self) else { throw VFSError.unsupported }
            return try withConnection { conn in
                var d = PfxFindData()
                let rc = path.path.withCString { statFn(conn, $0, &d) }
                guard rc == PC_OK else { throw Self.vfsError(rc, path.path) }
                return Self.entry(from: d)
            }
        }
    }

    public func openRead(_ path: VFSPath) async throws -> VFSReadStream {
        let url = try await downloadToTemp(path)
        let data = (try? Data(contentsOf: url)) ?? Data()
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        return PFXReadStream(data: data)
    }

    public func openWrite(_ path: VFSPath, options: WriteOptions) async throws -> VFSWriteStream {
        guard capabilities.contains(.write) else { throw VFSError.unsupported }
        return PFXWriteStream(path: path) { [self] localURL in
            try await run { [self] in
                guard let put = plugin.fn("PfxPutFile", as: XferFn.self) else { throw VFSError.unsupported }
                try withConnection { conn in
                    let rc = localURL.path.withCString { l in path.path.withCString { r in put(conn, l, r) } }
                    guard rc == PC_OK else { throw Self.vfsError(rc, path.path) }
                }
            }
        }
    }

    public func mkdir(_ path: VFSPath) async throws {
        try await run { [self] in
            guard let f = plugin.fn("PfxMkDir", as: PathFn.self) else { throw VFSError.unsupported }
            try withConnection { conn in
                let rc = path.path.withCString { f(conn, $0) }
                guard rc == PC_OK else { throw Self.vfsError(rc, path.path) }
            }
        }
    }

    public func delete(_ path: VFSPath) async throws {
        try await run { [self] in
            guard let f = plugin.fn("PfxDelete", as: PathFn.self) else { throw VFSError.unsupported }
            try withConnection { conn in
                let rc = path.path.withCString { f(conn, $0) }
                guard rc == PC_OK else { throw Self.vfsError(rc, path.path) }
            }
        }
    }

    public func rename(_ from: VFSPath, to: VFSPath) async throws {
        try await run { [self] in
            guard let f = plugin.fn("PfxRenMov", as: RenMovFn.self) else { throw VFSError.unsupported }
            try withConnection { conn in
                let rc = from.path.withCString { s in to.path.withCString { d in f(conn, s, d, 1) } }
                guard rc == PC_OK else { throw Self.vfsError(rc, from.path) }
            }
        }
    }

    public func setAttributes(_ path: VFSPath, attributes: VFSAttributes) async throws { throw VFSError.unsupported }
    public func watch(_ dir: VFSPath) -> AsyncStream<VFSChangeEvent>? { nil }

    public func localFileIfAvailable(_ path: VFSPath) async throws -> URL? {
        try await downloadToTemp(path)
    }

    // MARK: - Internals

    private func downloadToTemp(_ path: VFSPath) async throws -> URL {
        try await run { [self] in
            guard let get = plugin.fn("PfxGetFile", as: XferFn.self) else { throw VFSError.unsupported }
            let name = path.lastComponent().isEmpty ? "file" : path.lastComponent()
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("PFX-\(fsID)-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let out = dir.appendingPathComponent(name)
            return try withConnection { conn in
                let rc = path.path.withCString { r in out.path.withCString { l in get(conn, r, l) } }
                guard rc == PC_OK else {
                    try? FileManager.default.removeItem(at: dir)
                    throw Self.vfsError(rc, path.path)
                }
                return out
            }
        }
    }
}

/// A thread-safe one-shot cancellation flag: set from the stream's termination
/// handler (any thread), polled by the enumeration loop on the serial queue.
final class CancelFlag: @unchecked Sendable {
    private var flag = false
    private let lock = NSLock()
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set() { lock.lock(); flag = true; lock.unlock() }
}

/// Chunked in-memory read stream (mirrors PCXReadStream).
final class PFXReadStream: VFSReadStream, @unchecked Sendable {
    typealias Element = Data
    private let chunks: [Data]
    private var idx = 0
    private var closed = false

    init(data: Data, chunkSize: Int = 1 << 20) {
        var built: [Data] = []
        var off = data.startIndex
        while off < data.endIndex {
            let end = data.index(off, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            built.append(data.subdata(in: off..<end)); off = end
        }
        self.chunks = built
    }
    func close() async throws { closed = true }
    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(stream: self) }
    fileprivate func readChunk() -> Data? {
        guard !closed, idx < chunks.count else { return nil }
        defer { idx += 1 }
        return chunks[idx]
    }
    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: PFXReadStream
        func next() async -> Data? { stream.readChunk() }
    }
}

/// Buffers writes to a temp file, then uploads via the supplied closure on close.
final class PFXWriteStream: VFSWriteStream, @unchecked Sendable {
    private let localURL: URL
    private let handle: FileHandle
    private let upload: (URL) async throws -> Void
    private var uploaded = false

    init(path: VFSPath, upload: @escaping (URL) async throws -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PFX-put-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.localURL = dir.appendingPathComponent(path.lastComponent().isEmpty ? "file" : path.lastComponent())
        FileManager.default.createFile(atPath: localURL.path, contents: nil)
        self.handle = (try? FileHandle(forWritingTo: localURL)) ?? FileHandle.nullDevice
        self.upload = upload
    }

    func write(_ data: Data) async throws { try handle.write(contentsOf: data) }

    func close() async throws {
        try? handle.close()
        defer { try? FileManager.default.removeItem(at: localURL.deletingLastPathComponent()) }
        guard !uploaded else { return }
        uploaded = true
        try await upload(localURL)
    }
}
