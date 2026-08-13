// SPDX-License-Identifier: Apache-2.0
// SFTPSession.swift - A blocking libssh2 SFTP client, serialized onto a dedicated
// queue and exposed as async methods (F-214). Backs SFTPFileSystem.
//
// Auth order: SSH agent → explicit password → explicit key file → default
// ~/.ssh keys.
//
// Host keys are checked against ~/.ssh/known_hosts — a file **outside this app's own
// configuration**, shared with ssh and everything else that reads it. A MISMATCH
// aborts (possible MITM). A host not on file throws `hostKeyUnknown` carrying the
// fingerprint, so the caller can show it and ask; only a connect told
// `trustingNewHostKey` appends the line. It used to accept and record silently, which
// committed the user to a key they were never shown, and the comment here claimed the
// opposite ("a later refinement") long after the writing had been implemented.
//
// Anything testing against a throwaway SSH server should give that server a stable host
// key, or every restart looks like a different machine at the same address — correctly
// reported as a possible attack.

import Foundation
import Darwin
import CommonCrypto
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
    /// First contact with this host: nothing is on file, and the user has not been asked yet.
    ///
    /// Carries the fingerprint so the caller can show what it is about to trust. Not an error in the
    /// sense of something going wrong — it is the question ssh asks, arriving as a throw because
    /// that is the only way out of a synchronous handshake.
    case hostKeyUnknown(host: String, fingerprint: String)
    /// The connection died under an operation — timed out, or the socket went away.
    ///
    /// Distinct from `notConnected`, which means "there was never a session here". This one means
    /// there was, and it is gone, so the caller can say so and hand the mount back instead of
    /// reporting whatever the operation happened to be doing as a failure of its own.
    case transportLost(String)
}

/// A one-way flag: starts open, closes once, and can be read from any thread.
///
/// Small enough to be tempting to do with a plain `var` and no lock — which would be a data race
/// between the queue that closes it and the cancellation handler that reads it, and the kind that
/// tests never catch because it is a torn read of one word.
private final class Latch: @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false
    func close() { lock.lock(); closed = true; lock.unlock() }
    var isClosed: Bool { lock.lock(); defer { lock.unlock() }; return closed }
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

        // libssh2 error codes (libssh2.h). Only the ones that mean "the transport is gone" are
        // listed: everything else is a protocol-level answer from a server that is still there.
        static let errSocketSend: Int32 = -7
        static let errTimeout: Int32 = -9
        static let errSocketDisconnect: Int32 = -13
        static let errSocketTimeout: Int32 = -30
        static let errSFTPProtocol: Int32 = -31
        static let errSocketRecv: Int32 = -43
        /// LIBSSH2_FX_NO_SUCH_FILE — the SFTP status code, not a libssh2 error code.
        static let fxNoSuchFile: UInt = 2
        static let fxPermissionDenied: UInt = 3
    }

    private let queue = DispatchQueue(label: "com.peachcommander.sftp")
    private var sock: Int32 = -1
    private var session: OpaquePointer?
    private var sftp: OpaquePointer?
    private static var didInit = false
    private static let initLock = NSLock()

    /// Guards `sock` across threads. Every other field here is only ever touched on `queue`, but
    /// the socket has to be reachable from outside it — that is the whole point of `interrupt()`,
    /// which exists precisely for the moments when `queue` is the thing that is stuck.
    private let sockLock = NSLock()

    /// How long libssh2 may wait on the socket for one operation.
    ///
    /// Without this it waits forever: `_libssh2_wait_socket` calls `select` with no deadline, so a
    /// server that accepts the connection and then stops answering leaves the queue thread in that
    /// `select` for the life of the process — and every later call on this session, including
    /// `close()`, queues behind it and never runs. Measured, with a deliberately stalled server:
    /// 1739 of 1739 samples inside `__select`, and an app that could not be quit.
    ///
    /// Generous on purpose. This is a backstop against a session that is never coming back, not a
    /// judgement about how quick a server ought to be: a big listing on a loaded server may
    /// legitimately take a while, and cutting that short would break honest work to punish a
    /// hypothetical. Anyone who does not want to wait can navigate away, which now cancels.
    ///
    /// Settable so a test can use a second instead of a minute. A test that had to wait out the real
    /// value would be skipped by whoever ran it next, and a skipped test guards nothing.
    static var operationTimeoutMs: Int = 60_000

    /// How long to wait for the TCP connection itself.
    ///
    /// Separate and much shorter: the operation timeout is about a server that is thinking, this is
    /// about one that is not there. The kernel's own default is around 75 seconds of nothing.
    static var connectTimeoutSeconds: Double = 20

    public init() {}

    /// Run `body` on the session's serial queue.
    ///
    /// Cancellable, which for a blocking C library has to be indirect: nothing can interrupt libssh2
    /// mid-call, so the only lever is the socket underneath it — shut that down and the blocked
    /// `select` returns at once, the call fails, and the queue drains. Draining is the point: the
    /// next thing waiting on that queue is very often `close()`, because the user is trying to hang
    /// up on exactly the connection that is not answering.
    ///
    /// **But not immediately on cancellation**, and that grace period is the whole care in this
    /// function. Cancelling is ordinary here — `TransferQueue` cancels the task when a copy is
    /// cancelled — and a healthy transfer stopped mid-chunk returns within milliseconds all by
    /// itself, because a chunk is 128 KB. Cutting the socket the instant a task is cancelled would
    /// therefore turn "cancel this download" into "drop the connection", which nobody asked for.
    /// So cancellation waits a moment first: a call that comes back on its own keeps the session,
    /// and only one that is genuinely stuck gets the socket pulled out from under it.
    private func run<T>(_ body: @escaping () throws -> T) async throws -> T {
        let settled = Latch()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                queue.async {
                    do {
                        let value = try body()
                        settled.close()
                        cont.resume(returning: value)
                    } catch {
                        settled.close()
                        cont.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !settled.isClosed { self?.interrupt() }
            }
        }
    }

    /// Why the last call failed — asked of libssh2 rather than guessed from the return value.
    ///
    /// `libssh2_sftp_open_ex` answers NULL for "no such file" and for "the socket is gone" alike,
    /// and every one of those call sites used to assume the first. So a connection dying mid-listing
    /// told the user the directory did not exist — a wrong answer that reads as a confident one, and
    /// invites them to go looking for a folder that is right where they left it.
    ///
    /// Only called on the session's queue, where `session`/`sftp` are safe to read.
    private func lastFailure(_ op: String, path: String) -> SFTPError {
        guard let s = session else { return .notConnected }
        let code = libssh2_session_last_errno(s)
        switch code {
        case C.errTimeout, C.errSocketTimeout, C.errSocketSend, C.errSocketRecv, C.errSocketDisconnect:
            return .transportLost(op)
        case C.errSFTPProtocol:
            // The server is there and answered with a status code, so this is about the file.
            guard let ftp = sftp else { return .transportLost(op) }
            let status = libssh2_sftp_last_error(ftp)
            if status == C.fxNoSuchFile { return .notFound(path) }
            if status == C.fxPermissionDenied { return .opFailed(op, Int32(bitPattern: UInt32(status))) }
            return .opFailed(op, Int32(bitPattern: UInt32(status)))
        default:
            return .opFailed(op, code)
        }
    }

    /// Force whatever is blocked on this session to fail, from outside the queue.
    ///
    /// `shutdown`, never `close`: closing frees the descriptor number, and another thread opening a
    /// file at that moment would inherit it — so the next libssh2 read would be talking to whatever
    /// took the number. `shutdown` leaves the descriptor owned and merely refuses further traffic,
    /// which is exactly enough to make the blocked `select` return.
    public func interrupt() {
        sockLock.lock()
        let fd = sock
        sockLock.unlock()
        if fd >= 0 { _ = Darwin.shutdown(fd, SHUT_RDWR) }
    }

    // MARK: - Connect

    /// - Parameter trustingNewHostKey: accept and record a host key that is not on file yet.
    ///   Defaults to false, so a first visit throws `hostKeyUnknown` with the fingerprint instead of
    ///   committing the user to a key they have not seen.
    public func connect(host: String, port: UInt16, user: String,
                        password: String?, keyFile: String?, keyPassphrase: String?,
                        trustingNewHostKey: Bool = false) async throws {
        try await run { try self.doConnect(host: host, port: port, user: user,
                                            password: password, keyFile: keyFile,
                                            keyPassphrase: keyPassphrase,
                                            trustNewHostKey: trustingNewHostKey) }
    }

    private func doConnect(host: String, port: UInt16, user: String,
                           password: String?, keyFile: String?, keyPassphrase: String?,
                           trustNewHostKey: Bool) throws {
        Self.initLock.lock()
        if !Self.didInit { _ = libssh2_init(0); Self.didInit = true }
        Self.initLock.unlock()

        let fd = try Self.openSocket(host: host, port: port)
        sockLock.lock(); sock = fd; sockLock.unlock()
        guard let s = libssh2_session_init_ex(nil, nil, nil, nil) else { throw SFTPError.handshakeFailed(-1) }
        session = s
        libssh2_session_set_blocking(s, 1)
        // Before the handshake, so even that is bounded — a server can stall there just as well as
        // in a listing, and this is the one call every connection makes.
        libssh2_session_set_timeout(s, Self.operationTimeoutMs)
        // Pin a stable host-key algorithm preference so the negotiated key TYPE is
        // deterministic across connections. Otherwise a TOFU-recorded key (e.g.
        // ed25519) can mismatch a later connection that negotiates a different type
        // (e.g. ecdsa) even though both are the same server. LIBSSH2_METHOD_HOSTKEY = 1.
        _ = libssh2_session_method_pref(s, 1, "ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-512,rsa-sha2-256,ssh-rsa")
        let hs = libssh2_session_handshake(s, sock)
        guard hs == 0 else { throw SFTPError.handshakeFailed(hs) }

        try verifyHostKey(session: s, host: host, port: port, trustNewHostKey: trustNewHostKey)
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
                if connectWithTimeout(fd, p.pointee.ai_addr, p.pointee.ai_addrlen) { return fd }
                Darwin.close(fd)
            }
            ptr = p.pointee.ai_next
        }
        throw SFTPError.connectFailed(host)
    }

    /// A TCP connect that gives up after `connectTimeoutSeconds`, leaving `fd` blocking on success.
    ///
    /// A plain blocking `connect` to a host that is simply not answering sits there for something
    /// like 75 seconds — the kernel's default, not ours — and with several resolved addresses that
    /// is paid once per address. The non-blocking dance is the standard way to put a number on it:
    /// start the connect, wait for the socket to become writable, then ask the socket whether it
    /// actually succeeded, because writable alone also means "refused".
    private static func connectWithTimeout(_ fd: Int32, _ addr: UnsafeMutablePointer<sockaddr>,
                                           _ len: socklen_t) -> Bool {
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            return Darwin.connect(fd, addr, len) == 0     // cannot go non-blocking: no worse than before
        }
        defer { _ = fcntl(fd, F_SETFL, flags) }           // libssh2 wants it blocking afterwards

        if Darwin.connect(fd, addr, len) == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let ready = poll(&pfd, 1, Int32(connectTimeoutSeconds * 1000))
        guard ready == 1 else { return false }            // 0 = timed out, -1 = failed outright

        // Writable is not the same as connected: a refused connection reports writable too, and the
        // pending error is the only thing that tells them apart.
        var soError: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &size) == 0, soError == 0 else { return false }
        return true
    }

    /// Verify the server key against ~/.ssh/known_hosts using our own OpenSSH-format
    /// matching (libssh2's knownhost check misbehaved with "[host]:port" entries):
    /// same host+type with a different key → abort (possible MITM); same host+type+key
    /// → accept; no entry for this host+type → trust-on-first-use (accept + record),
    /// mirroring ssh's StrictHostKeyChecking=accept-new.
    private func verifyHostKey(session s: OpaquePointer, host: String, port: UInt16,
                               trustNewHostKey: Bool) throws {
        var keyLen = 0
        var keyType: Int32 = 0
        guard let key = libssh2_session_hostkey(s, &keyLen, &keyType),
              let typeName = Self.hostKeyTypeName(keyType) else { return }   // unknown type → can't verify
        let presented = Data(bytes: key, count: keyLen).base64EncodedString()
        let hostSpec = port == 22 ? host : "[\(host)]:\(port)"
        let path = (NSHomeDirectory() as NSString).appendingPathComponent(".ssh/known_hosts")

        let contents = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        // On *newlines*: a known_hosts that has been through a Windows editor has CRLF, and in Swift
        // "\r\n" is one Character — splitting on "\n" would then see the whole file as a single line and
        // silently fail to recognise a host that *is* known, turning a normal connection into a warning.
        for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let fields = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 3, !fields[0].hasPrefix("#") else { continue }
            let hosts = fields[0].split(separator: ",").map(String.init)
            guard hosts.contains(hostSpec), fields[1] == typeName else { continue }
            if fields[2] == presented { return }             // known + matches → OK
            throw SFTPError.hostKeyMismatch                  // known host+type, different key
        }
        // Never seen before. Accepting it silently — which is what this did — means connecting to a
        // server quietly writes a line into a file outside the app's own configuration, and commits
        // the user to trusting a key they were never shown. ssh asks; so does this now.
        //
        // The decision is not made here. This throws with the fingerprint, the caller shows it, and
        // a connect that is told `trustingNewHostKey` records it. Two connects for a first visit, in
        // exchange for the user having actually seen what they are trusting.
        guard trustNewHostKey else {
            throw SFTPError.hostKeyUnknown(host: hostSpec,
                                           fingerprint: Self.fingerprint(of: Data(bytes: key, count: keyLen)))
        }
        appendKnownHost(hostSpec: hostSpec, typeName: typeName, blob: presented, path: path)
    }

    /// The key's SHA-256 fingerprint, in the `SHA256:base64` form ssh prints.
    ///
    /// Same spelling on purpose: someone checking a server's key will have run `ssh-keygen -lf` or
    /// read it off a provisioning page, and a fingerprint they cannot compare character for
    /// character with what they have is one they will approve without reading.
    static func fingerprint(of key: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(key.count), &digest) }
        // ssh strips the base64 padding.
        let b64 = Data(digest).base64EncodedString().replacingOccurrences(of: "=", with: "")
        return "SHA256:" + b64
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
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), 0, 0, 1) else {
                throw self.lastFailure("open dir", path: path)
            }
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
            guard libssh2_sftp_stat_ex(sftp, path, UInt32(path.utf8.count), 1, &attrs) == 0 else {
                throw self.lastFailure("stat", path: path)
            }
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
                throw self.lastFailure("download", path: path)
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
            guard let handle = libssh2_sftp_open_ex(sftp, path, UInt32(path.utf8.count), C.fxfRead, 0, 0) else {
                throw self.lastFailure("open", path: path)
            }
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
                throw self.lastFailure("open", path: path)
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

    /// Hang up.
    ///
    /// The teardown goes on the same serial queue as everything else, so if the session is stuck it
    /// queues behind the stuck call — which is exactly the case where the user is pressing ⏏, and
    /// exactly the case where waiting is useless. So the goodbye gets a grace period and no more:
    /// long enough for a healthy session to close politely, short enough that a dead one does not
    /// hold the disconnect hostage. After that the socket is cut and the teardown proceeds on the
    /// wreckage, which still frees libssh2's memory and the descriptor.
    public func close() async {
        let teardown = Task { await self.tearDown() }
        let impatience = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self.interrupt()
        }
        await teardown.value
        impatience.cancel()
    }

    private func tearDown() async {
        try? await run {
            if let sftp = self.sftp { libssh2_sftp_shutdown(sftp); self.sftp = nil }
            if let s = self.session {
                _ = libssh2_session_disconnect_ex(s, 11, "bye", ""); libssh2_session_free(s); self.session = nil
            }
            // Under the lock, and cleared before the descriptor is released: `interrupt()` may run on
            // any thread, and a `shutdown` on a number that has already been handed back would be
            // aimed at whatever opened next.
            self.sockLock.lock()
            let fd = self.sock
            self.sock = -1
            self.sockLock.unlock()
            if fd >= 0 { Darwin.close(fd) }
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
