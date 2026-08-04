// SPDX-License-Identifier: Apache-2.0
// FTPControlConnection.swift - FTP command choreography (SPEC-011 §3).
//
// Drives a login + the common file operations over an FTPControlTransport. This
// is the error-prone "which command in which order, check which reply code" layer
// and is fully unit-tested against a scripted transport. Listings are decoded by
// FTPListParser; passive addresses by FTPDataAddress.

import Foundation

public actor FTPControlConnection {
    private let transport: FTPControlTransport
    /// Control-connection host, reused for EPSV (which omits the address).
    private let controlHost: String
    private var loggedIn = false
    /// Whether the server advertised MLSD/MLST in its FEAT reply (preferred listing).
    private var supportsMLSD = false
    /// Use active mode (client listens, server connects back via EPRT/PORT) instead
    /// of passive. Off by default; enabled per-site for networks where passive is
    /// blocked (F-212).
    private var activeMode = false
    /// Background NOOP loop that keeps an idle control connection from being
    /// dropped by the server (Options → FTP / per-site keep-alive).
    private var keepAliveTask: Task<Void, Never>?

    public init(transport: FTPControlTransport, controlHost: String) {
        self.transport = transport
        self.controlHost = controlHost
    }

    // MARK: - Low-level helpers

    /// Send a command and read its reply.
    @discardableResult
    private func command(_ line: String) async throws -> FTPReply {
        try await transport.send(line)
        return try await transport.readReply()
    }

    /// Require the reply code to be in `accept`, else throw.
    private func require(_ reply: FTPReply, _ command: String, accept: Range<Int>) throws {
        guard accept.contains(reply.code) else {
            throw FTPError.unexpectedReply(command: command, code: reply.code, text: reply.text)
        }
    }

    // MARK: - Session

    /// Connect, read the greeting, and authenticate (USER/PASS; PASS skipped when
    /// the server accepts USER alone, e.g. anonymous with empty password).
    ///
    /// - Parameter protectData: for FTPS, negotiate a protected data channel
    ///   (`PBSZ 0` + `PROT P`) after login so data connections are encrypted too.
    public func connectAndLogin(user: String, password: String, protectData: Bool = false) async throws {
        let greeting = try await transport.start()
        try require(greeting, "CONNECT", accept: 200..<300)
        let userReply = try await command("USER \(user)")
        if userReply.isIntermediate {                 // 331: needs password
            let passReply = try await command("PASS \(password)")
            try require(passReply, "PASS", accept: 200..<300)
        } else {
            try require(userReply, "USER", accept: 200..<300)
        }
        loggedIn = true
        // Feature detection: prefer MLSD (machine-readable) when the server lists MLST.
        if let feat = try? await command("FEAT"), feat.isSuccess {
            supportsMLSD = feat.text.uppercased().contains("MLST")
        }
        if protectData {
            try require(try await command("PBSZ 0"), "PBSZ", accept: 200..<300)
            try require(try await command("PROT P"), "PROT", accept: 200..<300)
        }
        _ = try? await command("TYPE I")              // binary by default
    }

    // MARK: - Keep-alive

    /// Send a single keep-alive command (default NOOP), swallowing any failure —
    /// keep-alive must never surface an error to the user.
    @discardableResult
    public func sendKeepAlive(_ line: String = "NOOP") async -> Bool {
        guard loggedIn else { return false }
        let cmd = line.isEmpty ? "NOOP" : line
        return (try? await command(cmd)) != nil
    }

    /// Start (or restart) a background loop that sends the keep-alive command every
    /// `intervalSeconds`. A non-positive interval disables it. The loop stops when
    /// the connection is deallocated or `stopKeepAlive()` is called.
    public func startKeepAlive(intervalSeconds: Int, command line: String = "NOOP") {
        stopKeepAlive()
        guard intervalSeconds > 0 else { return }
        let cmd = line.isEmpty ? "NOOP" : line
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
                guard !Task.isCancelled, let self else { break }
                await self.sendKeepAlive(cmd)
            }
        }
    }

    public func stopKeepAlive() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
    }

    deinit { keepAliveTask?.cancel() }

    /// Current remote working directory (from PWD's quoted path).
    public func printWorkingDirectory() async throws -> String {
        let r = try await command("PWD")
        try require(r, "PWD", accept: 200..<300)
        if let open = r.text.firstIndex(of: "\""), let close = r.text.lastIndex(of: "\""), open < close {
            return String(r.text[r.text.index(after: open)..<close])
        }
        return r.text
    }

    public func changeDirectory(_ path: String) async throws {
        try require(try await command("CWD \(path)"), "CWD", accept: 200..<300)
    }

    /// Enable/disable active mode for subsequent data transfers (F-212).
    public func setActiveMode(_ on: Bool) { activeMode = on }

    /// Open a data channel using the configured mode (active or passive).
    private func openData() async throws -> FTPDataTransport {
        activeMode ? try await openActiveData() : try await openPassiveData()
    }

    /// Open a passive-mode data channel (EPSV first, PASV fallback).
    private func openPassiveData() async throws -> FTPDataTransport {
        let epsv = try await command("EPSV")
        if epsv.isSuccess, let port = FTPDataAddress.parseEPSV(epsv.text) {
            return try await transport.makeData(host: controlHost, port: port)
        }
        let pasv = try await command("PASV")
        try require(pasv, "PASV", accept: 200..<300)
        guard let addr = FTPDataAddress.parsePASV(pasv.text) else {
            throw FTPError.badPassiveReply(pasv.text)
        }
        return try await transport.makeData(host: addr.host, port: addr.port)
    }

    /// Open an active-mode data channel: listen locally, advertise the address with
    /// EPRT, and hand back the listening transport (which accepts the server's
    /// inbound connection on first use). Falls back to passive if EPRT is refused (F-212).
    private func openActiveData() async throws -> FTPDataTransport {
        let (data, host, port, isIPv6) = try await transport.makeActiveData()
        let eprt = "EPRT |\(isIPv6 ? 2 : 1)|\(host)|\(port)|"
        let reply = try await command(eprt)
        guard reply.isSuccess else {
            await data.close()
            return try await openPassiveData()   // server rejected EPRT → passive
        }
        return data
    }

    /// List a directory. Uses MLSD when the server advertised it (FEAT), else LIST;
    /// FTPListParser auto-detects the output dialect either way.
    public func list(_ path: String = "", referenceDate: Date = Date()) async throws -> [RemoteFileEntry] {
        let verb = supportsMLSD ? "MLSD" : "LIST"
        let data = try await openData()
        try await transport.send(path.isEmpty ? verb : "\(verb) \(path)")
        let pre = try await transport.readReply()
        try require(pre, verb, accept: 100..<300)
        let bytes = try await data.readAll()
        await data.close()
        try require(try await transport.readReply(), verb, accept: 200..<300)
        return FTPListParser.parse(String(decoding: bytes, as: UTF8.self), referenceDate: referenceDate)
    }

    /// Download a file's bytes (RETR). With `restartAt > 0` the transfer resumes at
    /// that byte offset via REST (F-212); the returned data is the tail from there.
    public func download(_ path: String, restartAt offset: Int64 = 0) async throws -> Data {
        let data = try await openData()
        // The channel is open from here on, so anything that throws has to close it — a server declining
        // REST otherwise leaves a data connection dangling until the control connection goes away (F-212).
        do { try await sendRestartIfNeeded(offset) } catch { await data.close(); throw error }
        try await transport.send("RETR \(path)")
        try require(try await transport.readReply(), "RETR", accept: 100..<300)
        let bytes = try await data.readAll()
        await data.close()
        try require(try await transport.readReply(), "RETR", accept: 200..<300)
        return bytes
    }

    /// Send `REST <offset>` (expecting 350) before a transfer when resuming (F-212).
    private func sendRestartIfNeeded(_ offset: Int64) async throws {
        guard offset > 0 else { return }
        try require(try await command("REST \(offset)"), "REST", accept: 300..<400)
    }

    // MARK: - Streaming transfers (constant memory)

    /// Begin a streaming download: open the data channel and send RETR (reads the
    /// 1xx reply). The caller reads chunks off the returned transport, then MUST call
    /// `finishDownload` to read the final completion reply and close the channel.
    public func beginDownload(_ path: String, restartAt offset: Int64 = 0) async throws -> FTPDataTransport {
        let data = try await openData()
        do {
            // See `download`: from here the channel must be closed on every failure path.
            try await sendRestartIfNeeded(offset)
            try await transport.send("RETR \(path)")
            try require(try await transport.readReply(), "RETR", accept: 100..<300)
        } catch {
            await data.close()
            throw error
        }
        return data
    }

    public func finishDownload(_ data: FTPDataTransport) async throws {
        await data.close()
        try require(try await transport.readReply(), "RETR", accept: 200..<300)
    }

    /// Begin a streaming upload: open the data channel and send STOR (reads the 1xx
    /// reply). The caller writes chunks, then MUST call `finishUpload`.
    public func beginUpload(_ path: String, restartAt offset: Int64 = 0) async throws -> FTPDataTransport {
        let data = try await openData()
        // As with `beginDownload`: the channel is open, so every later failure has to close it, and `REST`
        // before `STOR` is how an interrupted upload continues (F-212).
        do { try await sendRestartIfNeeded(offset) } catch { await data.close(); throw error }
        try await transport.send("STOR \(path)")
        try require(try await transport.readReply(), "STOR", accept: 100..<300)
        return data
    }

    public func finishUpload(_ data: FTPDataTransport) async throws {
        await data.close()
        try require(try await transport.readReply(), "STOR", accept: 200..<300)
    }

    /// Upload bytes to a file (STOR).
    public func upload(_ bytes: Data, to path: String) async throws {
        let data = try await openData()
        try await transport.send("STOR \(path)")
        try require(try await transport.readReply(), "STOR", accept: 100..<300)
        try await data.write(bytes)
        await data.close()
        try require(try await transport.readReply(), "STOR", accept: 200..<300)
    }

    public func delete(_ path: String) async throws {
        try require(try await command("DELE \(path)"), "DELE", accept: 200..<300)
    }

    public func makeDirectory(_ path: String) async throws {
        try require(try await command("MKD \(path)"), "MKD", accept: 200..<300)
    }

    public func removeDirectory(_ path: String) async throws {
        try require(try await command("RMD \(path)"), "RMD", accept: 200..<300)
    }

    /// Rename `from` → `to` (RNFR then RNTO).
    public func rename(_ from: String, to: String) async throws {
        try require(try await command("RNFR \(from)"), "RNFR", accept: 300..<400)
        try require(try await command("RNTO \(to)"), "RNTO", accept: 200..<300)
    }

    /// SIZE of a file in bytes, or nil if the server does not support it.
    public func size(_ path: String) async throws -> Int64? {
        let r = try await command("SIZE \(path)")
        guard r.isSuccess else { return nil }
        return Int64(r.text.trimmingCharacters(in: .whitespaces))
    }

    /// Send an arbitrary command and return its reply (for SITE CHMOD, MDTM, …).
    @discardableResult
    public func rawCommand(_ line: String) async throws -> FTPReply {
        try await command(line)
    }

    public func quit() async {
        try? await transport.send("QUIT")
        await transport.close()
        loggedIn = false
    }
}
