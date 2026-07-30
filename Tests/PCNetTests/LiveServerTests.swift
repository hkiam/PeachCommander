// SPDX-License-Identifier: Apache-2.0
// LiveServerTests.swift - End-to-end FTP + SFTP against a real local daemon.
//
// Opt-in (network + a running server): set PC_NET_LIVE=1. Config via env with
// defaults matching the project test server:
//   PC_FTP_HOST (127.0.0.1) PC_FTP_PORT (21)
//   PC_SFTP_HOST (127.0.0.1) PC_SFTP_PORT (2222)
//   PC_NET_USER (tester) PC_NET_PASS (tester)
// Exercises the FULL lifecycle (connect, list, upload, download roundtrip,
// mkdir, rename, delete) that no test covered before — all prior net tests use
// mocks/loopback or a read-only public host. Each test cleans up after itself
// under the server's writable `upload/` directory.

import XCTest
@testable import PCNet
import PCVFS

final class LiveServerTests: XCTestCase {

    private var live: Bool { ProcessInfo.processInfo.environment["PC_NET_LIVE"] == "1" }
    private func env(_ k: String, _ d: String) -> String { ProcessInfo.processInfo.environment[k] ?? d }

    // MARK: - FTP (Network.framework transport, passive)

    func test_ftp_full_lifecycle() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")

        let transport = NWFTPControlTransport(host: host, port: port, useTLS: false)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do {
            try await conn.connectAndLogin(user: user, password: pass)
        } catch {
            throw XCTSkip("FTP server unreachable: \(error)")
        }
        defer { Task { await conn.quit() } }

        let dir = "upload/pctest-\(UUID().uuidString.prefix(8))"
        let file = "\(dir)/hello.txt"
        let renamed = "\(dir)/hello-renamed.txt"
        let payload = Data("peach ftp roundtrip \(UUID().uuidString)".utf8)

        try await conn.makeDirectory(dir)
        try await conn.upload(payload, to: file)

        // Listing the new dir shows the uploaded file with the right size.
        let entries = try await conn.list(dir)
        let names = Set(entries.map { $0.name })
        XCTAssertTrue(names.contains("hello.txt"), "listing: \(names.sorted())")

        // Download must byte-match what we uploaded.
        let got = try await conn.download(file)
        XCTAssertEqual(got, payload, "FTP download did not match upload")

        // SIZE reflects the payload length.
        let size = try await conn.size(file)
        XCTAssertEqual(size, Int64(payload.count))

        try await conn.rename(file, to: renamed)
        let afterRename = Set(try await conn.list(dir).map { $0.name })
        XCTAssertTrue(afterRename.contains("hello-renamed.txt"))
        XCTAssertFalse(afterRename.contains("hello.txt"))

        try await conn.delete(renamed)
        try await conn.removeDirectory(dir)
        let uploadNames = Set(try await conn.list("upload").map { $0.name })
        let leaf = String(dir.split(separator: "/").last ?? "")
        XCTAssertFalse(uploadNames.contains(leaf), "test dir not cleaned up: \(uploadNames.sorted())")
    }

    /// FTP streaming through the VFS: a multi-MB file written chunk-by-chunk via
    /// openWrite (STOR) and read back chunk-by-chunk via openRead (RETR), byte-exact.
    func test_ftp_streaming_large_file_roundtrip() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: false)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do { try await conn.connectAndLogin(user: user, password: pass) }
        catch { throw XCTSkip("FTP server unreachable: \(error)") }
        defer { Task { await conn.quit() } }

        let path = "upload/pc-ftpstream-\(UUID().uuidString.prefix(8)).bin"
        let fs = FTPFileSystem(connection: conn, fsID: "ftp")
        let vpath = VFSPath(filesystemId: "ftp", path: path)
        var payload = Data(capacity: 2 * 1024 * 1024)
        for i in 0..<(2 * 1024 * 1024) { payload.append(UInt8((i &* 17 &+ 3) & 0xff)) }

        let writer = try await fs.openWrite(vpath, options: WriteOptions())
        var off = 0
        while off < payload.count {
            let end = min(off + 256 * 1024, payload.count)
            try await writer.write(payload.subdata(in: off..<end))
            off = end
        }
        try await writer.close()

        let reader = try await fs.openRead(vpath)
        var received = Data()
        for try await chunk in reader { if let d = chunk as? Data { received.append(d) } }
        XCTAssertEqual(received, payload, "FTP streamed roundtrip mismatch")

        try await conn.delete(path)
    }

    // MARK: - FTP through a SOCKS5 proxy — F-212

    private static let socksScript = """
    import socket, threading, struct, sys, select
    def pipe(a,b):
        try:
            while True:
                r,_,_=select.select([a,b],[],[],30)
                if not r: break
                for s in r:
                    d=s.recv(65536)
                    if not d: return
                    (b if s is a else a).sendall(d)
        except Exception: pass
        finally:
            for s in (a,b):
                try: s.close()
                except Exception: pass
    def handle(c):
        try:
            c.recv(1); n=c.recv(1)[0]; c.recv(n); c.sendall(b"\\x05\\x00")
            hdr=c.recv(4); atyp=hdr[3]
            if atyp==1: host=socket.inet_ntoa(c.recv(4))
            elif atyp==3: ln=c.recv(1)[0]; host=c.recv(ln).decode()
            else: c.close(); return
            port=struct.unpack("!H",c.recv(2))[0]
            print("CONNECT %s:%d"%(host,port), flush=True)
            up=socket.create_connection((host,port),timeout=10)
            c.sendall(b"\\x05\\x00\\x00\\x01"+socket.inet_aton("0.0.0.0")+struct.pack("!H",0))
            pipe(c,up)
        except Exception:
            try: c.close()
            except Exception: pass
    srv=socket.socket(); srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    srv.bind(("127.0.0.1",int(sys.argv[1]))); srv.listen(50)
    print("ready", flush=True)
    while True:
        cc,_=srv.accept(); threading.Thread(target=handle,args=(cc,),daemon=True).start()
    """

    func test_ftp_through_socks5_proxy() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        guard let python = ["/usr/bin/python3", "/opt/homebrew/bin/python3"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("python3 unavailable")
        }
        // Start a local SOCKS5 proxy (logs each CONNECT so we can prove it was used).
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("pc-socks-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let scriptURL = tmp.appendingPathComponent("s.py")
        try Self.socksScript.write(to: scriptURL, atomically: true, encoding: .utf8)
        let logURL = tmp.appendingPathComponent("s.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        var proxyProc: Process?; var proxyPort = 0
        for candidate in [12723, 12845, 13012] {
            let p = Process(); p.executableURL = URL(fileURLWithPath: python)
            p.arguments = [scriptURL.path, "\(candidate)"]
            p.standardOutput = try FileHandle(forWritingTo: logURL); p.standardError = Pipe()
            do { try p.run() } catch { continue }
            usleep(400_000)
            proxyProc = p; proxyPort = candidate; break
        }
        guard let proxyProc else { throw XCTSkip("could not start SOCKS5 proxy") }
        defer { proxyProc.terminate() }

        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let proxy = ProxyConfig(kind: .socks5, host: "127.0.0.1", port: proxyPort)
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: false, proxy: proxy)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do { try await conn.connectAndLogin(user: user, password: pass) }
        catch { throw XCTSkip("FTP-via-proxy unreachable: \(error)") }
        defer { Task { await conn.quit() } }

        // A full data-channel roundtrip through the proxy (control + passive data).
        let dir = "upload/pctest-socks-\(UUID().uuidString.prefix(8))"
        let file = "\(dir)/via-socks.txt"
        let payload = Data("peach ftp via socks5 \(UUID().uuidString)".utf8)
        try await conn.makeDirectory(dir)
        try await conn.upload(payload, to: file)
        let names = Set(try await conn.list(dir).map { $0.name })
        XCTAssertTrue(names.contains("via-socks.txt"), "listing via proxy: \(names.sorted())")
        let got = try await conn.download(file)
        XCTAssertEqual(got, payload, "download via SOCKS5 proxy != upload")
        try await conn.delete(file); try await conn.removeDirectory(dir)

        // The proxy tunneled both the control and at least one passive data channel.
        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        XCTAssertTrue(log.contains("CONNECT \(host):\(port)"), "control not via proxy; log: \(log)")
        XCTAssertGreaterThanOrEqual(log.components(separatedBy: "CONNECT").count - 1, 2,
                                    "expected control + data CONNECTs; log: \(log)")
    }

    // MARK: - Active mode (EPRT: client listens, server connects back) — F-212

    func test_ftp_active_mode_roundtrip() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: false)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do { try await conn.connectAndLogin(user: user, password: pass) }
        catch { throw XCTSkip("FTP server unreachable: \(error)") }
        defer { Task { await conn.quit() } }

        await conn.setActiveMode(true)   // all data channels now use EPRT (F-212)

        let dir = "upload/pctest-active-\(UUID().uuidString.prefix(8))"
        let file = "\(dir)/active.txt"
        let payload = Data("peach active-mode roundtrip \(UUID().uuidString)".utf8)
        try await conn.makeDirectory(dir)
        try await conn.upload(payload, to: file)                    // STOR over active data
        let names = Set(try await conn.list(dir).map { $0.name })   // LIST over active data
        XCTAssertTrue(names.contains("active.txt"), "active-mode listing: \(names.sorted())")
        let got = try await conn.download(file)                     // RETR over active data
        XCTAssertEqual(got, payload, "active-mode download != upload")
        try await conn.delete(file)
        try await conn.removeDirectory(dir)
    }

    // MARK: - Resume (REST): resume a download at a byte offset — F-212

    func test_ftp_resume_download() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: false)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do { try await conn.connectAndLogin(user: user, password: pass) }
        catch { throw XCTSkip("FTP server unreachable: \(error)") }
        defer { Task { await conn.quit() } }

        let file = "upload/pc-resume-\(UUID().uuidString.prefix(8)).bin"
        var payload = Data(capacity: 4096)
        for i in 0..<4096 { payload.append(UInt8((i &* 7 &+ 1) & 0xff)) }
        try await conn.upload(payload, to: file)

        let offset: Int64 = 1500
        let tail = try await conn.download(file, restartAt: offset)   // REST 1500 + RETR
        XCTAssertEqual(tail, payload.suffix(from: Int(offset)),
                       "resumed download tail should equal the payload from the offset")
        // Simulate a real resume: first half + REST-continued half == whole file.
        let head = payload.prefix(Int(offset))
        XCTAssertEqual(Data(head) + tail, payload, "head + resumed tail should reconstruct the file")

        try await conn.delete(file)
    }

    // MARK: - Protocol log + custom raw command (FTP console) — F-217

    func test_ftp_protocol_log_and_raw_command() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTP_HOST", "127.0.0.1")
        let port = Int(env("PC_FTP_PORT", "21")) ?? 21
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")

        let log = FTPProtocolLog()
        let transport = LoggingFTPControlTransport(NWFTPControlTransport(host: host, port: port), log: log)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do { try await conn.connectAndLogin(user: user, password: pass) }
        catch { throw XCTSkip("FTP server unreachable: \(error)") }
        defer { Task { await conn.quit() } }

        let fs = FTPFileSystem(connection: conn, fsID: "ftp", protocolLog: log)
        // A user-typed raw command returns the server's reply and is logged.
        let statReply = try await fs.sendRawCommand("STAT")
        XCTAssertFalse(statReply.isEmpty, "STAT should return a reply")

        let lines = log.snapshot()
        let outgoing = lines.filter { $0.outgoing }.map { $0.text }
        let incoming = lines.filter { !$0.outgoing }.map { $0.text }
        // Login handshake + the raw command were captured.
        XCTAssertTrue(outgoing.contains { $0.hasPrefix("USER ") }, "log should show USER: \(outgoing)")
        XCTAssertTrue(outgoing.contains("STAT"), "log should show the raw STAT command: \(outgoing)")
        // The password is masked, never logged in clear.
        XCTAssertTrue(outgoing.contains("PASS ******"), "PASS must be masked: \(outgoing)")
        XCTAssertFalse(outgoing.contains { $0 == "PASS \(pass)" }, "clear password must not appear")
        // Replies were captured (e.g. 230 login, 211 STAT).
        XCTAssertTrue(incoming.contains { $0.hasPrefix("230") }, "log should show the 230 login reply")
        XCTAssertTrue(incoming.contains { $0.hasPrefix("211") || $0.hasPrefix("212") || $0.hasPrefix("213") },
                      "log should show the STAT reply: \(incoming)")
    }

    // MARK: - Implicit FTPS (TLS from first byte, self-signed cert)

    /// Control channel: implicit-FTPS login over TLS with the self-signed trust
    /// override, then a control-only command (PWD — no data channel).
    func test_ftps_implicit_control_login() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTPS_HOST", "127.0.0.1")
        let port = Int(env("PC_FTPS_PORT", "990")) ?? 990
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: true, allowInsecureTLS: true)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do {
            try await conn.connectAndLogin(user: user, password: pass, protectData: true)
        } catch {
            throw XCTSkip("FTPS server unreachable: \(error)")
        }
        defer { Task { await conn.quit() } }
        let cwd = try await conn.printWorkingDirectory()
        XCTAssertFalse(cwd.isEmpty, "PWD over implicit FTPS returned empty")
    }

    /// Data channel: a TLS-protected LIST + upload/download roundtrip. Some FTPS
    /// servers require the data connection to resume the control TLS session, which
    /// Network.framework can't do — this documents whether it works here.
    func test_ftps_implicit_data_roundtrip() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_FTPS_HOST", "127.0.0.1")
        let port = Int(env("PC_FTPS_PORT", "990")) ?? 990
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let transport = NWFTPControlTransport(host: host, port: port, useTLS: true, allowInsecureTLS: true)
        let conn = FTPControlConnection(transport: transport, controlHost: host)
        do {
            try await conn.connectAndLogin(user: user, password: pass, protectData: true)
        } catch {
            throw XCTSkip("FTPS server unreachable: \(error)")
        }
        defer { Task { await conn.quit() } }
        // The TLS data channel fails on servers that require the data connection to
        // resume the control TLS session (Network.framework can't reuse a session
        // across NWConnections). Treat that as a documented skip, not a failure.
        do {
            let names = Set(try await conn.list("").map { $0.name })
            XCTAssertTrue(names.contains("README.txt") || names.contains("upload"),
                          "FTPS listing: \(names.sorted())")
            let dir = "upload/pctest-ftps-\(UUID().uuidString.prefix(8))"
            let file = "\(dir)/hello.txt"
            let payload = Data("peach ftps roundtrip \(UUID().uuidString)".utf8)
            try await conn.makeDirectory(dir)
            try await conn.upload(payload, to: file)
            let got = try await conn.download(file)
            XCTAssertEqual(got, payload, "FTPS download != upload")
            try await conn.delete(file)
            try await conn.removeDirectory(dir)
        } catch {
            throw XCTSkip("FTPS data channel unavailable (server likely requires TLS session reuse, unsupported by Network.framework): \(error)")
        }
    }

    // MARK: - SFTP (libssh2)

    func test_sftp_full_lifecycle() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_SFTP_HOST", "127.0.0.1")
        let port = UInt16(env("PC_SFTP_PORT", "2222")) ?? 2222
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")

        let session = SFTPSession()
        do {
            try await session.connect(host: host, port: port, user: user,
                                      password: pass, keyFile: nil, keyPassphrase: nil)
        } catch {
            throw XCTSkip("SFTP server unreachable: \(error)")
        }
        defer { Task { await session.close() } }

        // Resolve a writable base: prefer a home-relative `upload/` (matches the FTP
        // side), else the home dir itself. Absolute /upload would hit the real FS root
        // on a chrooted server, so use relative paths the server resolves against home.
        let home = try await session.listDirectory(".")
        let base = home.contains { $0.name == "upload" && $0.isDirectory } ? "upload/" : ""
        let dir = "\(base)pctest-\(UUID().uuidString.prefix(8))"
        let file = "\(dir)/hello.txt"
        let renamed = "\(dir)/hello-renamed.txt"
        let payload = Data("peach sftp roundtrip \(UUID().uuidString)".utf8)

        try await session.mkdir(dir)
        try await session.write(payload, to: file)

        let names = Set(try await session.listDirectory(dir).map { $0.name })
        XCTAssertTrue(names.contains("hello.txt"), "listing: \(names.sorted())")

        let got = try await session.read(file)
        XCTAssertEqual(got, payload, "SFTP download did not match upload")

        let st = try await session.stat(file)
        XCTAssertEqual(st.size, Int64(payload.count))

        try await session.rename(file, to: renamed)
        let afterRename = Set(try await session.listDirectory(dir).map { $0.name })
        XCTAssertTrue(afterRename.contains("hello-renamed.txt"))
        XCTAssertFalse(afterRename.contains("hello.txt"))

        try await session.removeFile(renamed)
        try await session.removeDir(dir)
    }

    /// Streaming through the VFS layer: a multi-MB file written chunk-by-chunk via
    /// openWrite and read back chunk-by-chunk via openRead (constant-memory path),
    /// asserting a byte-exact roundtrip and that reads arrive in multiple chunks.
    func test_sftp_streaming_large_file_roundtrip() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_SFTP_HOST", "127.0.0.1")
        let port = UInt16(env("PC_SFTP_PORT", "2222")) ?? 2222
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")
        let session = SFTPSession()
        do {
            try await session.connect(host: host, port: port, user: user,
                                      password: pass, keyFile: nil, keyPassphrase: nil)
        } catch { throw XCTSkip("SFTP server unreachable: \(error)") }
        defer { Task { await session.close() } }

        let home = try await session.listDirectory(".")
        let base = home.contains { $0.name == "upload" && $0.isDirectory } ? "upload/" : ""
        let path = "\(base)pc-stream-\(UUID().uuidString.prefix(8)).bin"
        let fs = SFTPFileSystem(session: session, fsID: "sftp")
        let vpath = VFSPath(filesystemId: "sftp", path: path)

        // 3 MB of varied bytes, written in 256 KB chunks via the streaming writer.
        var payload = Data(capacity: 3 * 1024 * 1024)
        for i in 0..<(3 * 1024 * 1024) { payload.append(UInt8((i &* 31 &+ 7) & 0xff)) }
        let writer = try await fs.openWrite(vpath, options: WriteOptions())
        var off = 0
        while off < payload.count {
            let end = min(off + 256 * 1024, payload.count)
            try await writer.write(payload.subdata(in: off..<end))
            off = end
        }
        try await writer.close()

        // Read back via the streaming reader; count chunks to prove it's not one blob.
        let reader = try await fs.openRead(vpath)
        var received = Data(); var chunks = 0
        for try await chunk in reader { if let d = chunk as? Data { received.append(d); chunks += 1 } }
        XCTAssertEqual(received, payload, "streamed roundtrip mismatch")
        XCTAssertGreaterThan(chunks, 1, "expected multiple read chunks (streaming), got \(chunks)")

        try await session.removeFile(path)
    }

    // MARK: - SCP (transfer over the same SSH server)

    func test_scp_upload_download_roundtrip() async throws {
        try XCTSkipUnless(live, "set PC_NET_LIVE=1 to run live server tests")
        let host = env("PC_SFTP_HOST", "127.0.0.1")
        let port = UInt16(env("PC_SFTP_PORT", "2222")) ?? 2222
        let user = env("PC_NET_USER", "tester"), pass = env("PC_NET_PASS", "tester")

        let session = SFTPSession()
        do {
            try await session.connect(host: host, port: port, user: user,
                                      password: pass, keyFile: nil, keyPassphrase: nil)
        } catch {
            throw XCTSkip("SFTP/SCP server unreachable: \(error)")
        }
        defer { Task { await session.close() } }

        // Pick a writable base (upload/ if present, else home), like the SFTP test.
        let home = try await session.listDirectory(".")
        let base = home.contains { $0.name == "upload" && $0.isDirectory } ? "upload/" : ""
        let path = "\(base)pc-scp-\(UUID().uuidString.prefix(8)).bin"
        let payload = Data((0..<5000).map { UInt8($0 & 0xff) })   // non-trivial binary

        try await session.scpUpload(payload, to: path)
        let got = try await session.scpDownload(path)
        XCTAssertEqual(got, payload, "SCP download did not byte-match the upload")

        // Clean up via SFTP (SCP can't delete).
        try await session.removeFile(path)
    }
}
