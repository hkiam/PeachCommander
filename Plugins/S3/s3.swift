// SPDX-License-Identifier: Apache-2.0
// s3.swift — Amazon S3 (and S3-compatible storage) as an external PFX file-system plugin.
//
// The connect facet: an interactive connect, then WFX-style whole-file operations. The path model is
// `/<bucket>/<key…>`, so the root of the mount is the bucket list and a bucket is an ordinary
// directory. That is the shape the panel already has — it carries one path string per panel and asks
// the filesystem what it means — and it is what lets the drive chip, the breadcrumb and "go up" work
// without the host knowing anything about buckets.
//
// S3 has no directories. A "folder" is either a common prefix inferred from the keys under it or a
// zero-byte object whose key ends in "/". Both are presented as directories, and the marker object
// is never also listed as a file: see `S3ListObjectsParser`.
//
// Built into S3.pfxplugin by Tools/build-s3-plugin.sh.

import AppKit

// MARK: - C-string helpers

private func setCString(_ string: String, _ dst: UnsafeMutablePointer<CChar>, _ capacity: Int) {
    string.withCString { _ = strlcpy(dst, $0, capacity) }
}

// MARK: - Path model

/// A mount path split into the bucket and the key inside it.
///
/// `/` is the bucket list, `/photos` is a bucket, `/photos/2006/a.jpg` is an object. A trailing slash
/// is not significant in a path the host hands us — it asks for `/photos/2006` and means the folder.
struct S3Path {
    let bucket: String?
    /// The key, without a leading slash. Empty at the root of a bucket.
    let key: String

    init(_ path: String) {
        var p = path
        while p.hasPrefix("/") { p.removeFirst() }
        while p.hasSuffix("/") { p.removeLast() }
        guard !p.isEmpty else { bucket = nil; key = ""; return }
        if let slash = p.firstIndex(of: "/") {
            bucket = String(p[p.startIndex..<slash])
            key = String(p[p.index(after: slash)...])
        } else {
            bucket = p
            key = ""
        }
    }

    var isRoot: Bool { bucket == nil }
    var isBucketRoot: Bool { bucket != nil && key.isEmpty }
    /// The listing prefix for this directory: a key plus the delimiter, or empty at a bucket root.
    var listPrefix: String { key.isEmpty ? "" : key + "/" }
    var leaf: String {
        if let bucket, key.isEmpty { return bucket }
        return key.split(separator: "/").last.map(String.init) ?? (bucket ?? "/")
    }
}

// MARK: - Handles across the ABI

final class S3Find {
    private let connection: S3Connection
    private let bucket: String?
    private let prefix: String
    private var buffer: [S3Entry]
    private var index = 0
    private var token: String?
    private var exhausted: Bool
    /// Where to leave the column values, and under which directory. Nil for the bucket list, which
    /// has no per-object columns to show.
    private let mount: S3Mount?
    private let directory: String
    private var seen: [String: S3Entry] = [:]

    /// Buckets: one request, no paging — the list is small and S3 does not page it.
    init(buckets: [S3Entry], connection: S3Connection) {
        self.connection = connection
        self.bucket = nil
        self.prefix = ""
        self.buffer = buckets
        self.token = nil
        self.exhausted = true
        self.mount = nil
        self.directory = "/"
    }

    /// Objects: the first page now, the rest fetched lazily as the host asks for entries.
    ///
    /// Lazy on purpose. A bucket with a hundred thousand keys is a hundred pages, and fetching them
    /// all inside `PfxFindFirst` means the panel shows nothing until the last one arrives. The host
    /// yields entries to the panel in batches of 128 and checks for cancellation between them, so
    /// paging here is what makes a large bucket appear progressively and stop early when the user
    /// navigates away.
    init(connection: S3Connection, bucket: String, prefix: String, page: S3ListPage,
         mount: S3Mount?, directory: String) {
        self.connection = connection
        self.bucket = bucket
        self.prefix = prefix
        self.buffer = page.entries
        self.token = page.nextToken
        self.exhausted = !page.isTruncated
        self.mount = mount
        self.directory = directory
    }

    /// Hand the column values over. Called when the enumeration ends, because that is the only moment
    /// the set is complete — a page at a time would leave the panel drawing rows the mount has not
    /// been told about yet.
    private func publishColumns() {
        guard let mount, !seen.isEmpty else { return }
        mount.rememberColumns(directory: directory, entries: seen)
    }

    func next() -> S3Entry? {
        while index >= buffer.count {
            guard !exhausted, let bucket else { publishColumns(); return nil }
            guard let page = S3Operations.listPage(connection, bucket: bucket,
                                                   prefix: prefix, token: token) else {
                // The connection recorded why in `lastError`, and the host asks for it once the
                // enumeration ends — which is the only way a failure between two pages can be told
                // apart from reaching the last one. Without that, a server dying halfway through a
                // large bucket shows a short directory and calls it complete.
                exhausted = true
                publishColumns()
                return nil
            }
            buffer = page.entries
            index = 0
            token = page.nextToken
            exhausted = !page.isTruncated
            // A page can legitimately contain nothing the panel wants — every key in it was the
            // directory's own marker, say — so this loops rather than returning nil on an empty page.
            if buffer.isEmpty, exhausted { publishColumns(); return nil }
        }
        defer { index += 1 }
        let entry = buffer[index]
        if !entry.isDir { seen[entry.name] = entry }
        return entry
    }
}

// MARK: - Operations

enum S3Operations {
    static let maxKeysPerPage = 1000

    /// One page of a directory listing.
    static func listPage(_ c: S3Connection, bucket: String, prefix: String,
                         token: String?) -> S3ListPage? {
        var query: [(String, String)] = [
            ("list-type", "2"),
            ("delimiter", "/"),
            ("max-keys", String(maxKeysPerPage)),
            // Without this a key containing a character that is not valid in XML — and keys may
            // contain almost anything — comes back as a document the parser rejects, so the whole
            // directory reads as empty.
            ("encoding-type", "url"),
        ]
        if !prefix.isEmpty { query.append(("prefix", prefix)) }
        if let token, !token.isEmpty { query.append(("continuation-token", token)) }
        let response = c.send("GET", bucket: bucket, query: query)
        guard response.ok, let data = response.data else { return nil }
        return S3ListObjectsParser.parse(data, selfPrefix: prefix, urlEncoded: true)
    }

    /// The bucket list, which is the root of the mount.
    static func listBuckets(_ c: S3Connection) -> [S3Entry]? {
        let response = c.send("GET")
        guard response.ok, let data = response.data else { return nil }
        return S3BucketListParser.parse(data)
    }

    /// Whether a prefix exists as a directory: does anything at all live under it?
    ///
    /// Asked with `max-keys=1` rather than by fetching the directory, because "does this folder
    /// exist" is a question the panel asks on every navigation and a folder can hold a hundred
    /// thousand keys.
    static func prefixExists(_ c: S3Connection, bucket: String, prefix: String) -> Bool {
        var query: [(String, String)] = [("list-type", "2"), ("max-keys", "1")]
        if !prefix.isEmpty { query.append(("prefix", prefix)) }
        let response = c.send("GET", bucket: bucket, query: query)
        guard response.ok, let data = response.data else { return false }
        let page = S3ListObjectsParser.parse(data, selfPrefix: prefix, urlEncoded: false)
        // `rawCount`, not `entries`. Without a delimiter every key under the prefix comes back with
        // its slashes intact, and the panel-shaped filtering drops exactly those — so a directory
        // full of files answered "empty", and `PfxStat` then called a real folder missing.
        return page.rawCount > 0
    }
}

// MARK: - Connection state shared with the entry points

/// The plugin's own view of a live connection. Held by `Unmanaged` across the ABI.
final class S3Mount {
    let connection: S3Connection
    let label: String

    /// Content-column values, by directory and then by entry name.
    ///
    /// Kept from the listing rather than fetched: the storage class and the ETag arrive in every
    /// `ListObjectsV2` answer, so a column that asked the server per row would turn one request into
    /// one per file — on a service that charges per request.
    ///
    /// Two directories, not one and not all. One is wrong because both panels can be on the same
    /// mount, and the second listing would empty the first panel's columns while it is still drawing.
    /// All of them is an unbounded dictionary that grows for as long as the mount is open.
    private var columnRows: [(directory: String, rows: [String: S3Entry])] = []

    init(connection: S3Connection, label: String) {
        self.connection = connection
        self.label = label
    }

    func rememberColumns(directory: String, entries: [String: S3Entry]) {
        columnRows.removeAll { $0.directory == directory }
        columnRows.append((directory, entries))
        if columnRows.count > 2 { columnRows.removeFirst(columnRows.count - 2) }
    }

    /// The entry behind a full mount path, if a recent listing saw it.
    func columnEntry(forPath path: String) -> S3Entry? {
        let leaf = (path as NSString).lastPathComponent
        let directory = (path as NSString).deletingLastPathComponent
        for remembered in columnRows.reversed() where remembered.directory == directory {
            if let entry = remembered.rows[leaf] { return entry }
        }
        return nil
    }
}

/// Host services, kept from `PfxInit` for as long as the plugin is loaded. The ABI permits this
/// explicitly, and it is the only way to reach the Keychain before a connection exists.
private nonisolated(unsafe) var hostServices: PfxHostServices?

// MARK: - PFX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PfxInit")
public func PfxInit(_ services: UnsafePointer<PfxHostServices>?) {
    guard let svc = services?.pointee else { return }
    hostServices = svc
    guard let get = svc.getContext else { return }
    var buf = [CChar](repeating: 0, count: 4096)
    let ok = "configRoot".withCString { key in get(svc.host, key, &buf, 4096) }
    if ok == 1 {
        let root = String(cString: buf)
        if !root.isEmpty { S3Profiles.configRoot = root }
    }
}

@_cdecl("PfxGetCapabilities")
public func PfxGetCapabilities() -> Int32 {
    // Not PC_PFX_CAP_VOLATILE: a bucket does change under you, but it changes on someone else's
    // schedule, and polling every two seconds would be a request per panel per two seconds against a
    // service that charges per request.
    PC_PFX_CAP_READ | PC_PFX_CAP_WRITE | PC_PFX_CAP_RENAME
}

@_cdecl("PfxGetConnectTitle")
public func PfxGetConnectTitle(_ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let out else { return 0 }
    setCString(L("Amazon S3 Connect…"), out, Int(maxlen))
    return 1
}

@_cdecl("PfxGetVolumeCount")
public func PfxGetVolumeCount() -> Int32 {
    Int32(S3Profiles.load().count)
}

@_cdecl("PfxGetVolumeInfo")
public func PfxGetVolumeInfo(_ index: Int32, _ out: UnsafeMutablePointer<PfxVolumeInfo>?) {
    guard let out else { return }
    let profiles = S3Profiles.load()
    guard index >= 0, Int(index) < profiles.count else { return }
    let profile = profiles[Int(index)]
    // No PC_PFX_VOL_LOCAL: there is no local path behind this. The host turns a non-local volume
    // into a chip whose click connects the plugin, which is how a saved profile becomes one keystroke
    // instead of a dialog. Pattern taken from Plugins/TaskManager.
    setCString("s3:\(profile.name)", &out.pointee.id.0, 128)
    setCString(profile.name, &out.pointee.name.0, 256)
    setCString("", &out.pointee.path.0, 1024)
    out.pointee.flags = 0
    setCString("🪣", &out.pointee.icon.0, 64)
    out.pointee.order = 0
}

@_cdecl("PfxConnect")
public func PfxConnect(_ services: UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer? {
    let svc = services?.pointee ?? hostServices

    // The environment path exists for the automated tests, which cannot answer a modal dialog — and
    // it is also how someone with credentials already exported in their shell connects without
    // retyping them.
    let chosen: S3ConnectResult?
    if let (profile, secret) = S3Environment.connection() {
        chosen = S3ConnectResult(profile: profile, secret: secret, remember: false)
    } else {
        chosen = S3ConnectDialog(choices: S3ProfileChoice.all()).run()
    }
    guard let result = chosen, !result.profile.host.isEmpty else { return nil }

    var profile = result.profile
    var secret = result.secret

    // Keychain, through the host: load a saved secret when the field was left blank, and save a
    // newly typed one only when the user asked for the connection to be remembered.
    if !profile.anonymous, let svc, let crypt = svc.crypt, !profile.accessKeyID.isEmpty {
        let store = profile.secretStore
        if secret.isEmpty {
            var buf = [CChar](repeating: 0, count: 1024)
            let rc = store.withCString { crypt(svc.host, Int32(PC_CRYPT_COPY_PASSWORD), $0, &buf, 1024) }
            if rc == PC_OK { secret = String(cString: buf) }
        } else if result.remember {
            store.withCString { s in
                _ = secret.withCString { p in
                    crypt(svc.host, Int32(PC_CRYPT_SAVE_PASSWORD), s,
                          UnsafeMutablePointer(mutating: p), 0)
                }
            }
        }
    }

    if secret.isEmpty && !profile.anonymous && profile.accessKeyID.isEmpty {
        // Nothing to sign with and nothing was typed: treat it as the anonymous case rather than
        // sending a half-signed request that fails with a signature error.
        profile.anonymous = true
    }

    if result.remember { S3Profiles.save(profile) }
    return makeMount(profile: profile, secret: secret)
}

/// Build the connection handle for a profile that has already been settled.
///
/// Shared by the dialog path and by `PfxConnectVolume`, which is the point: a chip that connected by a
/// second, similar-looking route would drift from the dialog's — a different session configuration, a
/// different session token, a different idea of what "anonymous" means.
private func makeMount(profile: S3Profile, secret: String) -> UnsafeMutableRawPointer? {
    let credentials = profile.anonymous
        ? S3Credentials.anonymous
        : S3Credentials(accessKeyID: profile.accessKeyID, secretAccessKey: secret,
                        sessionToken: ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"])
    let connection = S3Connection(endpoint: profile.endpoint, credentials: credentials,
                                  displayHost: profile.host)
    let mount = S3Mount(connection: connection,
                        label: profile.name.isEmpty ? profile.host : profile.name)
    return Unmanaged.passRetained(mount).toOpaque()
}

/// Load a saved profile's secret from the Keychain, through the host.
///
/// Returns an empty string for an anonymous profile and for one the Keychain has nothing for — the
/// caller decides what that means. It is not an error here: a profile whose secret has been removed
/// from the Keychain is a real state, and the honest answer to it is a failed connection rather than a
/// crash or a silent anonymous one.
private func savedSecret(for profile: S3Profile, services: PfxHostServices?) -> String {
    guard !profile.anonymous, !profile.accessKeyID.isEmpty,
          let svc = services, let crypt = svc.crypt else { return "" }
    var buf = [CChar](repeating: 0, count: 1024)
    let rc = profile.secretStore.withCString {
        crypt(svc.host, Int32(PC_CRYPT_COPY_PASSWORD), $0, &buf, 1024)
    }
    return rc == PC_OK ? String(cString: buf) : ""
}

/// Connect the drive chip the user clicked, without asking again.
///
/// The whole reason this entry point was added to `pfx.h`: `PfxConnect` takes no argument, so a plugin
/// publishing a chip per saved connection could only fall back to its dialog — the chip promised a
/// shortcut and delivered a form. `volumeId` is the id this plugin published in `PfxGetVolumeInfo`,
/// so nothing has to be guessed.
@_cdecl("PfxConnectVolume")
public func PfxConnectVolume(_ volumeId: UnsafePointer<CChar>?,
                             _ services: UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer? {
    guard let volumeId else { return nil }
    let wanted = String(cString: volumeId)
    let svc = services?.pointee ?? hostServices

    // The id is "s3:<profile name>" — the same string `PfxGetVolumeInfo` writes. An id this plugin
    // does not recognise means a chip from a configuration that has since changed; answering NULL is
    // what tells the host the mount did not happen, and it drops the chip rather than leaving a drive
    // that goes nowhere.
    guard let profile = S3Profiles.load().first(where: { "s3:\($0.name)" == wanted }) else {
        return nil
    }
    let secret = savedSecret(for: profile, services: svc)
    // A profile that needs a secret and has none cannot connect, and must not quietly become an
    // anonymous connection: that would list a public bucket and look like success while the private
    // one the user asked for was never reached.
    if !profile.anonymous, secret.isEmpty {
        if let svc, let present = svc.presentInfo {
            let title = L("Amazon S3")
            let message = String(format:
                L("No saved password was found for “%@”. Connect through the Net menu to enter it again."),
                profile.name)
            title.withCString { t in message.withCString { m in present(svc.host, t, m) } }
        }
        return nil
    }
    return makeMount(profile: profile, secret: secret)
}

@_cdecl("PfxLastError")
public func PfxLastError(_ conn: UnsafeMutableRawPointer?) -> Int32 {
    guard let conn else { return Int32(PC_OK) }
    return Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue().connection.lastError
}

@_cdecl("PfxConnectionId")
public func PfxConnectionId(_ conn: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<CChar>?,
                            _ maxlen: Int32) -> Int32 {
    guard let conn, let out else { return 0 }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    // "s3:<host>" — the host splits this into a chip named after the host with the kind "S3".
    setCString("s3:\(mount.connection.displayHost)", out, Int(maxlen))
    return 1
}

@_cdecl("PfxDisconnect")
public func PfxDisconnect(_ conn: UnsafeMutableRawPointer?) {
    guard let conn else { return }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    // The sessions hold sockets; letting ARC decide when to close them means a "disconnected" mount
    // that still has a connection open to the server.
    mount.connection.invalidate()
    Unmanaged<S3Mount>.fromOpaque(conn).release()
}

@_cdecl("PfxFindFirst")
public func PfxFindFirst(_ conn: UnsafeMutableRawPointer?,
                         _ dir: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let conn, let dir else { return nil }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let path = S3Path(String(cString: dir))

    guard let bucket = path.bucket else {
        guard let buckets = S3Operations.listBuckets(mount.connection) else { return nil }
        return Unmanaged.passRetained(S3Find(buckets: buckets,
                                             connection: mount.connection)).toOpaque()
    }
    guard let page = S3Operations.listPage(mount.connection, bucket: bucket,
                                           prefix: path.listPrefix, token: nil) else { return nil }
    // Nothing at all for a directory below the bucket root means the directory is not there. Asked
    // of `rawCount` rather than `entries`: a prefix that exists only as its own zero-byte marker
    // sends one element and shows zero entries, and that is an empty folder rather than a missing
    // one. At the bucket root an empty answer means an empty bucket, which is ordinary — reporting
    // *that* as missing would tell the user a bucket they just created does not exist.
    if page.rawCount == 0, !page.isTruncated, !path.isBucketRoot {
        mount.connection.lastError = Int32(PC_E_EOPEN)
        return nil
    }
    return Unmanaged.passRetained(S3Find(connection: mount.connection, bucket: bucket,
                                         prefix: path.listPrefix, page: page,
                                         mount: mount,
                                         directory: String(cString: dir))).toOpaque()
}

@_cdecl("PfxFindNext")
public func PfxFindNext(_ find: UnsafeMutableRawPointer?,
                        _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let find, let out else { return 0 }
    let f = Unmanaged<S3Find>.fromOpaque(find).takeUnretainedValue()
    guard let entry = f.next() else { return 0 }
    setCString(entry.name, &out.pointee.name.0, 1024)
    out.pointee.size = entry.isDir ? -1 : entry.size
    out.pointee.mtime = entry.modified
    out.pointee.isDir = entry.isDir ? 1 : 0
    // S3 has no POSIX mode. Zero is the ABI's "unknown", which is the truth.
    out.pointee.mode = 0
    return 1
}

@_cdecl("PfxFindClose")
public func PfxFindClose(_ find: UnsafeMutableRawPointer?) {
    guard let find else { return }
    Unmanaged<S3Find>.fromOpaque(find).release()
}

@_cdecl("PfxStat")
public func PfxStat(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?,
                    _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let conn, let path, let out else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let s3 = S3Path(String(cString: path))

    // The mount's root. There is nothing to ask the server about.
    guard let bucket = s3.bucket else {
        setCString("/", &out.pointee.name.0, 1024)
        out.pointee.size = -1; out.pointee.mtime = 0; out.pointee.isDir = 1; out.pointee.mode = 0
        return Int32(PC_OK)
    }

    if s3.key.isEmpty {
        // A bucket. HEAD on the bucket answers whether it exists and, on a redirect, where it lives.
        let response = mount.connection.send("HEAD", bucket: bucket)
        guard response.ok else {
            var message = ""
            return S3Connection.pcError(response, message: &message)
        }
        setCString(bucket, &out.pointee.name.0, 1024)
        out.pointee.size = -1; out.pointee.mtime = 0; out.pointee.isDir = 1; out.pointee.mode = 0
        return Int32(PC_OK)
    }

    // An object, asked for by HEAD. A 404 here is not the answer yet: the path may be a directory,
    // which has no object of its own unless somebody made a marker for it.
    let response = mount.connection.send("HEAD", bucket: bucket, key: s3.key)
    if response.ok {
        setCString(s3.leaf, &out.pointee.name.0, 1024)
        out.pointee.size = Int64(response.header("Content-Length") ?? "") ?? 0
        out.pointee.mtime = response.header("Last-Modified").map(S3Time.httpDate) ?? 0
        out.pointee.isDir = 0
        out.pointee.mode = 0
        return Int32(PC_OK)
    }
    if response.status == 404 || response.status == 403 {
        // 403 as well as 404: a bucket policy can allow ListBucket and deny HeadObject, and then a
        // real directory answers "denied" to the only question that would have identified it.
        if S3Operations.prefixExists(mount.connection, bucket: bucket, prefix: s3.key + "/") {
            setCString(s3.leaf, &out.pointee.name.0, 1024)
            out.pointee.size = -1; out.pointee.mtime = 0; out.pointee.isDir = 1; out.pointee.mode = 0
            return Int32(PC_OK)
        }
    }
    var message = ""
    return S3Connection.pcError(response, message: &message)
}

@_cdecl("PfxGetFile")
public func PfxGetFile(_ conn: UnsafeMutableRawPointer?, _ remote: UnsafePointer<CChar>?,
                       _ local: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let remote, let local else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let s3 = S3Path(String(cString: remote))
    guard let bucket = s3.bucket, !s3.key.isEmpty else { return Int32(PC_E_EOPEN) }

    attachProgress(mount, name: s3.leaf)
    defer { mount.connection.progress = nil }

    let response = mount.connection.download(bucket: bucket, key: s3.key,
                                             to: URL(fileURLWithPath: String(cString: local)),
                                             name: s3.leaf)
    if response.ok { return Int32(PC_OK) }
    if mount.connection.lastError == Int32(PC_E_EABORTED) { return Int32(PC_E_EABORTED) }
    // status -1 is this plugin's own marker for "the bytes arrived and could not be written here".
    if response.status == -1 { return Int32(PC_E_ECREATE) }
    var message = ""
    return S3Connection.pcError(response, message: &message)
}

/// Route the plugin's transfer progress to the host, and its answer back as an abort.
///
/// The ABI has no other cancellation channel: `PfxGetFile` and `PfxPutFile` block until they are
/// done, and the only question they ask on the way is this one.
private func attachProgress(_ mount: S3Mount, name: String) {
    guard let svc = hostServices, let report = svc.progress else { return }
    mount.connection.progress = { _, pct in
        name.withCString { report(svc.host, $0, Int32(pct)) == PC_CONTINUE }
    }
}

@_cdecl("PfxPutFile")
public func PfxPutFile(_ conn: UnsafeMutableRawPointer?, _ local: UnsafePointer<CChar>?,
                       _ remote: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let local, let remote else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let s3 = S3Path(String(cString: remote))
    // There is no such thing as an object at the root of the mount: the root is the bucket list, and
    // a bucket is made with PfxMkDir, not by writing a file into it.
    guard let bucket = s3.bucket, !s3.key.isEmpty else { return Int32(PC_E_ECREATE) }

    let source = URL(fileURLWithPath: String(cString: local))
    attachProgress(mount, name: s3.leaf)
    defer { mount.connection.progress = nil }

    let response = mount.connection.putObject(bucket: bucket, key: s3.key,
                                              from: source, name: s3.leaf)
    if response.ok { return Int32(PC_OK) }
    if mount.connection.lastError == Int32(PC_E_EABORTED) { return Int32(PC_E_EABORTED) }
    var message = ""
    let code = S3Connection.pcError(response, message: &message)
    return code == Int32(PC_OK) ? Int32(PC_E_EWRITE) : code
}

@_cdecl("PfxMkDir")
public func PfxMkDir(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let path else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let s3 = S3Path(String(cString: path))
    guard let bucket = s3.bucket else { return Int32(PC_E_ECREATE) }

    // At the root of the mount, "new folder" means "new bucket". That is not a liberty: the root IS
    // the bucket list, so there is nothing else it could mean, and refusing it would leave no way to
    // make a bucket at all.
    let response = s3.key.isEmpty
        ? mount.connection.createBucket(bucket)
        : mount.connection.createPrefix(bucket: bucket, prefix: s3.key)
    if response.ok { return Int32(PC_OK) }
    var message = ""
    let code = S3Connection.pcError(response, message: &message)
    return code == Int32(PC_OK) ? Int32(PC_E_ECREATE) : code
}

@_cdecl("PfxDelete")
public func PfxDelete(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let path else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let s3 = S3Path(String(cString: path))
    guard let bucket = s3.bucket else { return Int32(PC_E_NOT_SUPPORTED) }

    if s3.key.isEmpty {
        let response = mount.connection.deleteBucket(bucket)
        if response.ok { return Int32(PC_OK) }
        var message = ""
        let code = S3Connection.pcError(response, message: &message)
        return code == Int32(PC_OK) ? Int32(PC_E_EWRITE) : code
    }

    // Whether this is a folder has to be settled BEFORE deleting anything. A DELETE on a key that
    // does not exist answers 204 — success — so treating a folder as an object would report the
    // folder deleted while every object inside it stayed exactly where it was.
    if S3Operations.prefixExists(mount.connection, bucket: bucket, prefix: s3.key + "/") {
        guard let failed = mount.connection.deletePrefix(bucket: bucket, prefix: s3.key + "/") else {
            let recorded = mount.connection.lastError
            return recorded == Int32(PC_OK) ? Int32(PC_E_EWRITE) : recorded
        }
        // The host has no channel for "most of it went". Naming the count in the plugin's message and
        // failing is the honest answer; reporting success would leave the folder in the panel with no
        // explanation.
        if !failed.isEmpty {
            mount.connection.lastMessage = String(
                format: L("%d object(s) in this folder could not be deleted."), failed.count)
            return Int32(PC_E_EWRITE)
        }
        return Int32(PC_OK)
    }

    let response = mount.connection.deleteObject(bucket: bucket, key: s3.key)
    if response.ok { return Int32(PC_OK) }
    var message = ""
    let code = S3Connection.pcError(response, message: &message)
    return code == Int32(PC_OK) ? Int32(PC_E_EWRITE) : code
}

@_cdecl("PfxRenMov")
public func PfxRenMov(_ conn: UnsafeMutableRawPointer?, _ from: UnsafePointer<CChar>?,
                      _ to: UnsafePointer<CChar>?, _ move: Int32) -> Int32 {
    guard let conn, let from, let to else { return Int32(PC_E_NOT_SUPPORTED) }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    let source = S3Path(String(cString: from))
    let target = S3Path(String(cString: to))

    guard let sourceBucket = source.bucket, let targetBucket = target.bucket else {
        return Int32(PC_E_NOT_SUPPORTED)
    }
    // S3 cannot rename a bucket, and there is no sequence of calls that adds up to one either: it
    // would mean copying every object and deleting the bucket, which is not what the user asked for
    // and is not something to do behind a rename dialog.
    guard !source.key.isEmpty, !target.key.isEmpty else { return Int32(PC_E_NOT_SUPPORTED) }

    if S3Operations.prefixExists(mount.connection, bucket: sourceBucket,
                                 prefix: source.key + "/") {
        return mount.connection.movePrefix(bucket: targetBucket, to: target.key,
                                          sourceBucket: sourceBucket, from: source.key)
    }
    return mount.connection.moveObject(bucket: targetBucket, to: target.key,
                                       sourceBucket: sourceBucket, from: source.key)
}

// MARK: - Content columns

/// The columns this plugin publishes, in the order `PfxContentGetRow` writes them.
///
/// Both come out of the listing that has already happened, which is the reason there are only two.
/// Everything else worth showing — server-side encryption, the restore state of an archived object —
/// needs a HEAD per object, and a column that costs one request per visible row is a column that
/// costs money to scroll.
private let s3ContentFields: [(name: String, title: String, width: Int32)] = [
    ("storageclass", "Storage Class", 110),
    ("etag", "ETag", 220),
]

@_cdecl("PfxContentFieldCount")
public func PfxContentFieldCount() -> Int32 { Int32(s3ContentFields.count) }

@_cdecl("PfxContentField")
public func PfxContentField(_ index: Int32, _ out: UnsafeMutablePointer<PfxFieldInfo>?) {
    guard let out, index >= 0, Int(index) < s3ContentFields.count else { return }
    let field = s3ContentFields[Int(index)]
    setCString(field.name, &out.pointee.name.0, 128)
    setCString(L(field.title), &out.pointee.title.0, 128)
    // Both are strings. The storage class is a word, and an ETag is a hash that only ever wants to be
    // compared — sorting either numerically would order them by nothing.
    out.pointee.type = Int32(PFX_FT_STRING)
    out.pointee.defaultWidth = field.width
}

@_cdecl("PfxContentGetRow")
public func PfxContentGetRow(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?,
                             _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let conn, let path, let out, maxlen > 0 else { return 0 }
    let mount = Unmanaged<S3Mount>.fromOpaque(conn).takeUnretainedValue()
    // Answered only from what a listing already said. A path the plugin has not seen — a bucket, a
    // prefix, or a row from a directory two navigations ago — gets 0, and the host draws an empty
    // cell. Fetching it here instead would be one request per row on a paid service, from the main
    // thread, while the panel is drawing.
    guard let entry = mount.columnEntry(forPath: String(cString: path)) else { return 0 }
    let row = [entry.storageClass, entry.etag].joined(separator: "\t")
    setCString(row, out, Int(maxlen))
    return 1
}
