import XCTest
@testable import PCNet

// MARK: - Scripted transport (canned-dialog mock, SPEC-011 §7)

/// Feeds pre-canned replies/data to FTPControlConnection and records what was
/// sent, so the command choreography can be verified without a socket.
final class ScriptedControlTransport: FTPControlTransport, @unchecked Sendable {
    private let greeting: FTPReply
    private var replies: [FTPReply]
    private var dataReads: [Data]
    private let lock = NSLock()
    private(set) var sent: [String] = []
    private(set) var dataWritten: [Data] = []
    private(set) var madeDataFor: [(host: String, port: Int)] = []

    init(greeting: FTPReply, replies: [FTPReply], dataReads: [Data] = []) {
        self.greeting = greeting
        self.replies = replies
        self.dataReads = dataReads
    }

    func start() async throws -> FTPReply { greeting }

    func send(_ line: String) async throws {
        lock.lock(); sent.append(line); lock.unlock()
    }

    func readReply() async throws -> FTPReply {
        lock.lock(); defer { lock.unlock() }
        guard !replies.isEmpty else { throw FTPError.connectionLost }
        return replies.removeFirst()
    }

    func makeData(host: String, port: Int) async throws -> FTPDataTransport {
        lock.lock(); defer { lock.unlock() }
        madeDataFor.append((host, port))
        let payload = dataReads.isEmpty ? Data() : dataReads.removeFirst()
        return ScriptedDataTransport(payload: payload) { [weak self] data in
            self?.lock.lock(); self?.dataWritten.append(data); self?.lock.unlock()
        }
    }

    func close() async {}
}

final class ScriptedDataTransport: FTPDataTransport, @unchecked Sendable {
    private let payload: Data
    private let onWrite: (Data) -> Void
    init(payload: Data, onWrite: @escaping (Data) -> Void) { self.payload = payload; self.onWrite = onWrite }
    private var read = false
    func readAll() async throws -> Data { payload }
    func readChunk() async throws -> Data? { if read { return nil }; read = true; return payload }
    func write(_ data: Data) async throws { onWrite(data) }
    func close() async {}
}

private func reply(_ s: String) -> FTPReply { FTPReplyParser.parse(s)! }

// MARK: - Tests

final class FTPSessionTests: XCTestCase {

    func testLoginSendsUserPassType() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 need password"), reply("230 logged in"), reply("211 no features"), reply("200 type set")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "alice", password: "secret")
        XCTAssertEqual(t.sent, ["USER alice", "PASS secret", "FEAT", "TYPE I"])
    }

    func testSecureLoginNegotiatesDataProtection() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 need password"), reply("230 logged in"), reply("211 no features"),
            reply("200 PBSZ=0"), reply("200 protection set"), reply("200 type set")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "u", password: "p", protectData: true)
        XCTAssertEqual(t.sent, ["USER u", "PASS p", "FEAT", "PBSZ 0", "PROT P", "TYPE I"])
    }

    func testAnonymousLoginWithoutPassword() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("230 anonymous ok"), reply("211 no features"), reply("200 type set")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "anonymous", password: "")
        XCTAssertEqual(t.sent, ["USER anonymous", "FEAT", "TYPE I"])   // no PASS: USER returned 230
    }

    func testFeatEnablesMLSDListing() async throws {
        let mlsd = "type=dir;modify=20230101000000; sub\r\ntype=file;size=9;modify=20230101000000; f.txt\r\n"
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 pw"), reply("230 ok"),
            reply("211-Features:\r\n MLST size*;type*;modify*;\r\n UTF8\r\n211 End"),   // FEAT advertises MLST
            reply("200 type set"),
            reply("229 Entering Extended Passive Mode (|||40000|)"),   // list: EPSV
            reply("150 opening"), reply("226 done")
        ], dataReads: [Data(mlsd.utf8)])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "u", password: "p")
        let entries = try await c.list("/pub")
        XCTAssertEqual(entries.map(\.name), ["sub", "f.txt"])
        XCTAssertTrue(t.sent.contains("MLSD /pub"))     // used MLSD, not LIST
        XCTAssertFalse(t.sent.contains("LIST /pub"))
    }

    func testListUsesLISTWhenNoMLST() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 pw"), reply("230 ok"),
            reply("211-Features:\r\n SIZE\r\n UTF8\r\n211 End"),        // no MLST
            reply("200 type set"),
            reply("229 Entering Extended Passive Mode (|||40001|)"),
            reply("150 opening"), reply("226 done")
        ], dataReads: [Data("drwxr-xr-x 2 a b 4096 Jan 1  2023 d\r\n".utf8)])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "u", password: "p")
        _ = try await c.list("/pub")
        XCTAssertTrue(t.sent.contains("LIST /pub"))
        XCTAssertFalse(t.sent.contains("MLSD /pub"))
    }

    func testListViaEPSVParsesEntries() async throws {
        let listing = "drwxr-xr-x 2 a b 4096 Jan 10  2023 dir\r\n-rw-r--r-- 1 a b 5 Jan 10  2023 f.txt\r\n"
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("229 Entering Extended Passive Mode (|||50000|)"),
            reply("150 opening data"),
            reply("226 transfer complete")
        ], dataReads: [Data(listing.utf8)])
        let c = FTPControlConnection(transport: t, controlHost: "10.0.0.9")
        let entries = try await c.list("/pub")
        XCTAssertEqual(entries.map(\.name), ["dir", "f.txt"])
        XCTAssertEqual(t.sent, ["EPSV", "LIST /pub"])
        XCTAssertEqual(t.madeDataFor.first?.host, "10.0.0.9")     // EPSV reuses control host
        XCTAssertEqual(t.madeDataFor.first?.port, 50000)
    }

    func testListFallsBackToPASVWhenEPSVUnsupported() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("500 unknown command"),                                  // EPSV rejected
            reply("227 Entering Passive Mode (127,0,0,1,196,10)"),         // PASV
            reply("150 here it comes"),
            reply("226 done")
        ], dataReads: [Data("total 0\r\n".utf8)])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        _ = try await c.list()
        XCTAssertEqual(t.sent, ["EPSV", "PASV", "LIST"])
        XCTAssertEqual(t.madeDataFor.first?.host, "127.0.0.1")
        XCTAssertEqual(t.madeDataFor.first?.port, 196 * 256 + 10)
    }

    func testDownloadReturnsBytes() async throws {
        let body = Data("hello world".utf8)
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("229 Entering Extended Passive Mode (|||60000|)"),
            reply("150 opening"),
            reply("226 complete")
        ], dataReads: [body])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        let got = try await c.download("/file.bin")
        XCTAssertEqual(got, body)
        XCTAssertEqual(t.sent, ["EPSV", "RETR /file.bin"])
    }

    func testUploadWritesBytes() async throws {
        let body = Data("payload".utf8)
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("229 Entering Extended Passive Mode (|||60001|)"),
            reply("150 ready to receive"),
            reply("226 stored")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.upload(body, to: "/up.bin")
        XCTAssertEqual(t.sent, ["EPSV", "STOR /up.bin"])
        XCTAssertEqual(t.dataWritten, [body])
    }

    func testRenameSendsRnfrRnto() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("350 ready for RNTO"), reply("250 renamed")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.rename("/a.txt", to: "/b.txt")
        XCTAssertEqual(t.sent, ["RNFR /a.txt", "RNTO /b.txt"])
    }

    func testDeleteMkdRmd() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("250 deleted"), reply("257 created"), reply("250 removed")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.delete("/x")
        try await c.makeDirectory("/d")
        try await c.removeDirectory("/d")
        XCTAssertEqual(t.sent, ["DELE /x", "MKD /d", "RMD /d"])
    }

    func testSizeParsesNumberAndNilOnFailure() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("213 123456"), reply("550 no such file")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        let size = try await c.size("/big.iso")
        XCTAssertEqual(size, 123456)
        let missing = try await c.size("/nope")
        XCTAssertNil(missing)
    }

    func testUnexpectedReplyThrows() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 need password"), reply("530 login incorrect")
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        do {
            try await c.connectAndLogin(user: "u", password: "bad")
            XCTFail("expected login failure")
        } catch let FTPError.unexpectedReply(command, code, _) {
            XCTAssertEqual(command, "PASS")
            XCTAssertEqual(code, 530)
        }
    }

    func testSendKeepAliveSendsNoopWhenLoggedIn() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 pw"), reply("230 in"), reply("211 nofeat"), reply("200 type"),
            reply("200 NOOP ok"),
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "a", password: "b")
        let ok = await c.sendKeepAlive()
        XCTAssertTrue(ok)
        XCTAssertEqual(t.sent.last, "NOOP")
    }

    func testSendKeepAliveUsesCustomCommand() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [
            reply("331 pw"), reply("230 in"), reply("211 nofeat"), reply("200 type"),
            reply("257 \"/\" cwd"),
        ])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        try await c.connectAndLogin(user: "a", password: "b")
        _ = await c.sendKeepAlive("PWD")
        XCTAssertEqual(t.sent.last, "PWD")
    }

    func testKeepAliveBeforeLoginSendsNothing() async throws {
        let t = ScriptedControlTransport(greeting: reply("220 ready"), replies: [])
        let c = FTPControlConnection(transport: t, controlHost: "h")
        let ok = await c.sendKeepAlive()
        XCTAssertFalse(ok)
        XCTAssertTrue(t.sent.isEmpty)
    }
}
