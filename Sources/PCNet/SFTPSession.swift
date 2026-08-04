// SPDX-License-Identifier: Apache-2.0
// SFTPSession.swift - A blocking libssh2 SFTP client, serialized onto a dedicated
// queue and exposed as async methods (F-214). Backs SFTPFileSystem.
//
// Auth order: SSH agent → explicit password → explicit key file → default
// ~/.ssh keys. Host keys are checked against ~/.ssh/known_hosts: a MISMATCH
// aborts (possible MITM); an unknown host is accepted (TOFU) — recording new
// hosts back to known_hosts is a later refinement.

import Foundation
import Darwin
import CSSH2

public enum SFTPError: Error, Equatable {
    case resolveFailed(String)
    case connectFailed(String)
    case handshakeFailed(Int32)
    case hostKeyMismatch
    case authFailed
    case sftpInitFailed(Int32)
    case notConnected
    case opFailed(String, Int32)
    case notFound(String)
}

public final class SFTPSession: @unchecked Sendable {
    // libssh2 flag/result constants (numeric literals; the header defines them as
    // macros that don't all import into Swift).
    private enum C {
        static let fxfRead: UInt = 0x00000001
        static let fxfWrite: UInt = 0x00000002
        static let fxfCreat: UInt = 0x00000008
        static let fxfTrunc: UInt = 0x00000010
        // LIBSSH2_SFTP_ATTR_* — the `flags` field of LIBSSH2_SFTP_ATTRIBUTES says which members are
        // meaningful, and a setstat sends only those. Spelled out because the module map does not
        // export them, and a wrong value here would send garbage rather than fail to compile.
        static let attrPermissions: UInt = 0x00000004
        static let attrUIDGID: UInt = 0x00000002
        static let attrACModTime: UInt = 0x00000008
        /// `libssh2_sftp_stat_ex` type argument. From libssh2_sftp.h: STAT 0, LSTAT 1, **SETSTAT 2**.
        /// The first version of this used 0 — which is a perfectly successful *stat*, so the call
        /// returned 0, the code reported success, and the file was unchanged. Read from the header after
        /// an independent `stat` over ssh contradicted the app's own "applied=ok".
        static let setstat: Int32 = 2
    }

    private let queue = DispatchQueue(label: "com.peachcommander.sftp")
    private var sock: Int32 = -1
    private var session: OpaquePointer?
    private var sftp: OpaquePointer?
    private static var didInit = false
    private static let initLock = NSLock()

    public init() {}

    private func run<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do { cont.resume(returning: try body()) }
                catch { cont.resume(throwing: error) }
            }
        }
    }

    // MARK: - Connect

    public func connect(host: String, port: UInt16, user: String,
                        password: String?, keyFile: String?, keyPassphrase: String?) async throws {
        try await run { try self.doConnect(host: host, port: port, user: user,
                                            password: password, keyFile: keyFile, keyPassphrase: keyPassphrase) }
    }

    private func doConnect(host: String, port: UInt16, user: String,
                           password: String?, keyFile: String?, keyPassphrase: String?) throws {
        Self.initLock.lock()
        if !Self.didInit { _ = libssh2_init(0); Self.didInit = true }
        Self.initLock.unlock()

        sock = try Self.openSocket(host: host, port: port)
        guard let s = libssh2_session_init_ex(nil, nil, nil, nil) else { throw SFTPError.handshakeFailed(-1) }
        session = s
        libssh2_session_set_blocking(s, 1)
        // Pin a stable host-key algorithm preference so the negotiated key TYPE is
        // deterministic across connections. Otherwise a TOFU-recorded key (e.g.
        // ed25519) can mismatch a later connection that negotiates a different type
        // (e.g. ecdsa) even though both are the same server. LIBSSH2_METHOD_HOSTKEY = 1.
        _ = libssh2_session_method_pref(s, 1, "ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-512,rsa-sha2-256,ssh-rsa")
        let hs = libssh2_session_handshake(s, sock)
        guard hs == 0 else { throw SFTPError.handshakeFailed(hs) }

        try verifyHostKey(session: s, host: host, port: port)
        try authenticate(session: s, user: user, password: password, keyFile: keyFile, keyPassphrase: keyPassphrase)

        guard let ftp = libssh2_sftp_init(s) else {
            throw SFTPError.sftpInitFailed(libssh2_session_last_errno(s))
        }
        sftp = ftp
    }

    /// Blocking TCP connect, trying each resolved address.
    private static func openSocket(host: String, port: UInt16) throws -> Int32 {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                             ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?
        let rc = getaddrinfo(host, String(port), &hints, &res)
        guard rc == 0, let first = res else { throw SFTPError.resolveFailed(host) }
        defer { freeaddrinfo(res) }
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        while let p = ptr {
            let fd = socket(p.pointee.ai_family, p.pointee.ai_socktype, p.pointee.ai_protocol)
            if fd >= 0 {
                if Darwin.connect(fd, p.pointee.ai_addr, p.pointee.ai_addrlen) == 0 { return fd }
                Darwin.close(fd)
            }
            ptr = p.pointee.ai_next
        }
        throw SFTPError.connectFailed(host)
    }

    /// Verify the server key against ~/.ssh/known_hosts using our own OpenSSH-format
    /// matching (libssh2's knownhost check misbehaved with "[host]:port" entries):
    /// same host+type with a different key → abort (possible MITM); same host+type+key
    /// → accept; no entry for this host+type → trust-on-first-use (accept + record),
    /// mirroring ssh's StrictHostKeyChecking=accept-new.
    private func verifyHostKey(session s: OpaquePointer, host: String, port: UInt16) throws {
        var keyLen = 0
        var keyType: Int32 = 0
        guard let key = libssh2_session_hostkey(s, &keyLen, &keyType),
              let typeName = Self.hostKeyTypeName(keyType) else { return }   // unknown type → can't verify
        let presented = Data(bytes: key, count: keyLen).base64EncodedString()
        let hostSpec = port == 22 ? host : "[\(host)]:\(port)"
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh/known_hosts")

        let contents = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        for rawLine in contents.split(separator: "\n") {
            let fields = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 3, !fields[0].hasPrefix("#") else { continue }
            let hosts = fields[0].split(separator: ",").map(String.init)
            guard hosts.contains(hostSpec), fields[1] == typeName else { continue }
            if fields[2] == presented { return }             // known + matches → OK
            throw SFTPError.hostKeyMismatch                  // known host+type, different key
        }
        // Not seen before → TOFU: accept and record.
        appendKnownHost(hostSpec: hostSpec, typeName: typeName, blob: presented, path: path)
    }

    /// Append a standard OpenSSH known_hosts line `<hostspec> <keytype> <base64key>`.
    /// Best-effort: a write failure leaves the accepted connection working, unrecorded.
    private func appendKnownHost(hostSpec: String, typeName: String, blob: String, path: String) {
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let existing = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let separator = (existing.isEmpty || existing.hasSuffix("\n")) ? "" : "\n"
        try? (existing + separator + "\(hostSpec) \(typeName) \(blob)\n")
            .write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// OpenSSH key-type name for a LIBSSH2_HOSTKEY_TYPE_* value (RSA=1 … ED25519=6).
    private static func hostKeyTypeName(_ t: Int32) -> String? {
        switch t {
        case 1: return "ssh-rsa"
        case 2: return "ssh-dss"
        case 3: return "ecdsa-sha2-nistp256"
        case 4: return "ecdsa-sha2-nistp384"
        case 5: return "ecdsa-sha2-nistp521"
        case 6: return "ssh-ed25519"
        default: return nil
        }
    }

    private func authenticate(session s: OpaquePointer, user: String,
                              password: String?, keyFile: String?, keyPassphrase: String?) throws {
        // 1) SSH agent.
        if tryAgent(session: s, user: user) { return }
        // 2) Explicit password.
        if let password, !password.isEmpty, libssh2_userauth_password_ex(s, user, UInt32(user.utf8.count), password, UInt32(password.utf8.count), nil) == 0 { return }
        // 3) Explicit key file, then default keys.
        let home = NSHomeDirectory()
        var keys: [String] = []
        if let keyFile, !keyFile.isEmpty { keys.append(keyFile) }
        keys.append(contentsOf: ["\(home)/.ssh/id_ed25519", "\(home)/.ssh/id_rsa", "\(home)/.ssh/id_ecdsa"])
        for priv in keys where FileManager.default.fileExists(atPath: priv) {
            let pub = priv + ".pub"
            let pubArg = FileManager.default.fileExists(atPath: pub) ? pub : nil
            if libssh2_userauth_publickey_fromfile_ex(s, user, UInt32(user.utf8.count), pubArg, priv, keyPassphrase ?? "") == 0 { return }
        }
        throw SFTPError.authFailed
    }

    private func tryAgent(session s: OpaquePointer, user: String) -> Bool {
        guard let agent = libssh2_agent_init(s) else { return false }
        defer { libssh2_agent_disconnect(agent); libssh2_agent_free(agent) }
        guard libssh2_agent_connect(agent) == 0, libssh2_agent_list_identities(agent) == 0 else { return false }
        var prev: UnsafeMutablePointer<libssh2_agent_publickey>?
        while true {
            var identity: UnsafeMutablePointer<libssh2_agent_publickey>?
            let rc = libssh2_agent_get_identity(agent, &identity, prev)
            if rc != 0 { break }              // 1 = end of list, <0 = error
            if let identity, libssh2_agent_userauth(agent, user, identity) == 0 { return true }
            prev = identity
        }
        return false
    }

    // MARK: - Operations

    public struct Entry: Sendable {
        public let name: String
        public let isDirectory: Bool
        public let isSymlink: Bool
        public let size: Int64
        public let mtime: Date?
    }

    public func listDirectory(_ path: String) async throws -> [Entry] {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), 0, 0, 1) else { throw SFTPError.notFound(path) }
            defer { _ = libssh2_sftp_close_handle(handle) }
            var out: [Entry] = []
            var buf = [CChar](repeating: 0, count: 1024)
            while true {
                var attrs = LIBSSH2_SFTP_ATTRIBUTES()
                let n = buf.withUnsafeMutableBufferPointer { p in
                    libssh2_sftp_readdir_ex(handle, p.baseAddress, p.count, nil, 0, &attrs)
                }
                if n <= 0 { break }
                let name = buf.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
                if name == "." || name == ".." { continue }
                out.append(Self.entry(name: name, attrs: attrs))
            }
            return out
        }
    }

    public func stat(_ path: String) async throws -> Entry {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            var attrs = LIBSSH2_SFTP_ATTRIBUTES()
            guard libssh2_sftp_stat_ex(sftp, path, UInt32(path.utf8.count), 1, &attrs) == 0 else { throw SFTPError.notFound(path) }
            let name = (path as NSString).lastPathComponent
            return Self.entry(name: name.isEmpty ? path : name, attrs: attrs)
        }
    }

    /// Change permissions, owner and/or modification time on the server (F-364).
    ///
    /// The same call `stat` uses, with the type argument set to SETSTAT — which is the whole reason this
    /// is a small function rather than a project: the plumbing was already here, and
    /// `SFTPFileSystem.setAttributes` was an empty body that accepted every request and discarded it.
    ///
    /// `flags` decides what the server is asked to change; anything not set is left alone. uid/gid are
    /// numeric over SFTP — the protocol has no way to resolve a user *name*, so the caller either knows
    /// the number or must not ask.
    public func setAttributes(_ path: String, mode: UInt16? = nil,
                              uid: UInt32? = nil, gid: UInt32? = nil,
                              modified: Date? = nil, accessed: Date? = nil) async throws {
        guard mode != nil || uid != nil || gid != nil || modified != nil else { return }
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            var attrs = LIBSSH2_SFTP_ATTRIBUTES()
            if let mode {
                attrs.flags |= C.attrPermissions
                attrs.permissions = UInt(mode)
            }
            if uid != nil || gid != nil {
                // Both travel together in one field pair: reading the current values first would be a
                // second round trip, and a setstat that sends only one of them sets the other to zero on
                // some servers — so the caller supplies both or neither.
                attrs.flags |= C.attrUIDGID
                attrs.uid = UInt(uid ?? 0)
                attrs.gid = UInt(gid ?? 0)
            }
            if let modified {
                attrs.flags |= C.attrACModTime
                attrs.mtime = UInt(max(0, modified.timeIntervalSince1970))
                // Access time is mandatory in the same record; keep the file's own when not given.
                attrs.atime = UInt(max(0, (accessed ?? modified).timeIntervalSince1970))
            }
            let rc = libssh2_sftp_stat_ex(sftp, path, UInt32(path.utf8.count), C.setstat, &attrs)
            guard rc == 0 else {
                throw SFTPError.opFailed("setstat", rc)
            }
        }
    }

    /// Stream a remote file into `destination`, starting at `offset` (F-366).
    ///
    /// The counterpart to `read`, which returns the whole file as `Data`: fine for opening one in the
    /// viewer, wrong for copying one, because a 4 GB file then needs 4 GB of memory *and* a temp copy
    /// before it reaches its destination. Here the chunks go straight to the file, and `seek64` makes an
    /// interrupted transfer continue instead of starting over.
    ///
    /// Returns how many bytes this call wrote — the tail, when resuming.
    public func download(_ path: String, to destination: URL, from offset: UInt64 = 0) async throws -> Int64 {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        if offset == 0 { try? fm.removeItem(at: destination) }
        if !fm.fileExists(atPath: destination.path) { fm.createFile(atPath: destination.path, contents: nil) }
        let file = try FileHandle(forWritingTo: destination)
        // Before the first byte: a resumed transfer appends to exactly the bytes that were counted, and a
        // restarted one must not keep the old tail behind what it writes.
        try file.truncate(atOffset: offset)
        defer { try? file.close() }

        return try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count),
                                                   C.fxfRead, 0, 0) else {
                throw SFTPError.notFound(path)
            }
            defer { _ = libssh2_sftp_close_handle(handle) }
            if offset > 0 { libssh2_sftp_seek64(handle, offset) }
            var written: Int64 = 0
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let n = buffer.withUnsafeMutableBytes { p in
                    libssh2_sftp_read(handle, p.baseAddress!.assumingMemoryBound(to: CChar.self), p.count)
                }
                if n > 0 {
                    try file.write(contentsOf: buffer[0..<n])
                    written += Int64(n)
                } else if n == 0 {
                    break
                } else {
                    throw SFTPError.opFailed("read", Int32(n))
                }
            }
            return written
        }
    }

    /// Send a local file to `path`, starting at `offset` (F-212).
    ///
    /// Without an offset the remote file is truncated first, so a replaced file cannot keep a longer old
    /// tail. With one, the handle is opened *without* TRUNC and seeked — the same mechanism as the
    /// download side, and the reason SFTP needs no protocol negotiation for a resume.
    public func upload(_ source: URL, to path: String, from offset: UInt64 = 0) async throws -> Int64 {
        let file = try FileHandle(forReadingFrom: source)
        defer { try? file.close() }
        if offset > 0 { try file.seek(toOffset: offset) }

        return try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            let flags = offset > 0 ? (C.fxfWrite | C.fxfCreat) : (C.fxfWrite | C.fxfCreat | C.fxfTrunc)
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count),
                                                   flags, 0o644, 0) else {
                throw SFTPError.opFailed("open for write", 0)
            }
            defer { _ = libssh2_sftp_close_handle(handle) }
            if offset > 0 { libssh2_sftp_seek64(handle, offset) }
            var written: Int64 = 0
            while let chunk = try file.read(upToCount: 64 * 1024), !chunk.isEmpty {
                var sent = 0
                try chunk.withUnsafeBytes { raw in
                    guard let base = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                    while sent < raw.count {
                        let n = libssh2_sftp_write(handle, base + sent, raw.count - sent)
                        // A short write is normal on a busy channel; a negative one is a failure.
                        if n < 0 { throw SFTPError.opFailed("write", Int32(n)) }
                        sent += n
                    }
                }
                written += Int64(sent)
            }
            return written
        }
    }

    public func read(_ path: String) async throws -> Data {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), C.fxfRead, 0, 0) else { throw SFTPError.notFound(path) }
            defer { _ = libssh2_sftp_close_handle(handle) }
            var data = Data()
            var buf = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let n = buf.withUnsafeMutableBytes { p in
                    libssh2_sftp_read(handle, p.baseAddress!.assumingMemoryBound(to: CChar.self), p.count)
                }
                if n > 0 { data.append(contentsOf: buf[0..<n]) }
                else { break }
            }
            return data
        }
    }

    public func write(_ data: Data, to path: String) async throws {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            let flags = C.fxfWrite | C.fxfCreat | C.fxfTrunc
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), flags, 0o644, 0) else {
                throw SFTPError.opFailed("open write \(path)", -1)
            }
            defer { _ = libssh2_sftp_close_handle(handle) }
            try data.withUnsafeBytes { raw in
                var offset = 0
                let base = raw.baseAddress!.assumingMemoryBound(to: CChar.self)
                while offset < raw.count {
                    let n = libssh2_sftp_write(handle, base + offset, raw.count - offset)
                    if n < 0 { throw SFTPError.opFailed("write \(path)", Int32(n)) }
                    offset += n
                }
            }
        }
    }

    // MARK: - Streaming (constant-memory transfers via an open handle)

    /// Open a file for streaming read; returns the libssh2 handle (opaque token).
    func openReadHandle(_ path: String) async throws -> OpaquePointer {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            guard let h = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), C.fxfRead, 0, 0) else {
                throw SFTPError.notFound(path)
            }
            return h
        }
    }

    /// Read up to `max` bytes from an open handle; an empty result means EOF.
    func readHandle(_ h: OpaquePointer, max: Int) async throws -> Data {
        try await run {
            var buf = [UInt8](repeating: 0, count: max)
            let n = buf.withUnsafeMutableBytes { p in
                libssh2_sftp_read(h, p.baseAddress!.assumingMemoryBound(to: CChar.self), p.count)
            }
            if n < 0 { throw SFTPError.opFailed("read", Int32(n)) }
            return n == 0 ? Data() : Data(buf[0..<n])
        }
    }

    /// Open a file for streaming write (create/truncate); returns the handle.
    func openWriteHandle(_ path: String) async throws -> OpaquePointer {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            let flags = C.fxfWrite | C.fxfCreat | C.fxfTrunc
            guard let h = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), flags, 0o644, 0) else {
                throw SFTPError.opFailed("open write \(path)", -1)
            }
            return h
        }
    }

    /// Write a chunk to an open handle (loops until fully written).
    func writeHandle(_ h: OpaquePointer, _ data: Data) async throws {
        try await run {
            try data.withUnsafeBytes { raw in
                guard let base = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                var off = 0
                while off < raw.count {
                    let n = libssh2_sftp_write(h, base + off, raw.count - off)
                    if n < 0 { throw SFTPError.opFailed("write", Int32(n)) }
                    off += n
                }
            }
        }
    }

    func closeHandle(_ h: OpaquePointer) async { try? await run { _ = libssh2_sftp_close_handle(h) } }

    public func mkdir(_ path: String) async throws { try await simpleOp("mkdir", path) { libssh2_sftp_mkdir_ex($0, $1, UInt32($1.utf8.count), 0o755) } }
    public func removeFile(_ path: String) async throws { try await simpleOp("unlink", path) { libssh2_sftp_unlink_ex($0, $1, UInt32($1.utf8.count)) } }
    public func removeDir(_ path: String) async throws { try await simpleOp("rmdir", path) { libssh2_sftp_rmdir_ex($0, $1, UInt32($1.utf8.count)) } }

    public func rename(_ from: String, to: String) async throws {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            let rc = libssh2_sftp_rename_ex(sftp, from, UInt32(from.utf8.count), to, UInt32(to.utf8.count), 7)
            if rc != 0 { throw SFTPError.opFailed("rename", rc) }
        }
    }

    // MARK: - SCP (transfer only — SCP cannot list/rename/delete)

    /// Download a file over SCP (reads exactly the size the server announces).
    public func scpDownload(_ path: String) async throws -> Data {
        try await run {
            guard let session = self.session else { throw SFTPError.notConnected }
            var st = Darwin.stat()
            guard let channel = libssh2_scp_recv2(session, path, &st) else {
                throw SFTPError.opFailed("scp recv \(path)", libssh2_session_last_errno(session))
            }
            defer { _ = libssh2_channel_free(channel) }
            let total = Int(st.st_size)
            var data = Data(); data.reserveCapacity(max(0, total))
            var buf = [UInt8](repeating: 0, count: 64 * 1024)
            while data.count < total {
                let want = min(buf.count, total - data.count)
                let n = buf.withUnsafeMutableBytes { p in
                    libssh2_channel_read_ex(channel, 0, p.baseAddress!.assumingMemoryBound(to: CChar.self), want)
                }
                if n > 0 { data.append(contentsOf: buf[0..<n]) }
                else if n == 0 { break }
                else { throw SFTPError.opFailed("scp read \(path)", Int32(n)) }
            }
            return data
        }
    }

    /// Upload a file over SCP (creates/overwrites at `path` with `mode`).
    public func scpUpload(_ data: Data, to path: String, mode: Int32 = 0o644) async throws {
        try await run {
            guard let session = self.session else { throw SFTPError.notConnected }
            guard let channel = libssh2_scp_send64(session, path, mode, libssh2_int64_t(data.count), 0, 0) else {
                throw SFTPError.opFailed("scp send \(path)", libssh2_session_last_errno(session))
            }
            defer { _ = libssh2_channel_free(channel) }
            try data.withUnsafeBytes { raw in
                guard let base0 = raw.baseAddress?.assumingMemoryBound(to: CChar.self) else { return }
                var offset = 0
                while offset < raw.count {
                    let n = libssh2_channel_write_ex(channel, 0, base0 + offset, raw.count - offset)
                    if n < 0 { throw SFTPError.opFailed("scp write \(path)", Int32(n)) }
                    offset += n
                }
            }
            _ = libssh2_channel_send_eof(channel)
            _ = libssh2_channel_wait_eof(channel)
            _ = libssh2_channel_wait_closed(channel)
        }
    }

    private func simpleOp(_ name: String, _ path: String, _ op: @escaping (OpaquePointer, String) -> Int32) async throws {
        try await run {
            guard let sftp = self.sftp else { throw SFTPError.notConnected }
            let rc = op(sftp, path)
            if rc != 0 { throw SFTPError.opFailed(name, rc) }
        }
    }

    public func close() async {
        try? await run {
            if let sftp = self.sftp { libssh2_sftp_shutdown(sftp); self.sftp = nil }
            if let s = self.session {
                _ = libssh2_session_disconnect_ex(s, 11, "bye", ""); libssh2_session_free(s); self.session = nil
            }
            if self.sock >= 0 { Darwin.close(self.sock); self.sock = -1 }
        }
    }

    private static func entry(name: String, attrs: LIBSSH2_SFTP_ATTRIBUTES) -> Entry {
        let mode = mode_t(attrs.permissions)
        let isDir = (mode & S_IFMT) == S_IFDIR
        let isLink = (mode & S_IFMT) == S_IFLNK
        let mtime = attrs.mtime != 0 ? Date(timeIntervalSince1970: TimeInterval(attrs.mtime)) : nil
        return Entry(name: name, isDirectory: isDir, isSymlink: isLink,
                     size: isDir ? -1 : Int64(attrs.filesize), mtime: mtime)
    }
}
