// SPDX-License-Identifier: Apache-2.0
// SFTPTimeoutTests.swift - An SFTP session must not be able to wait forever (F-214).
//
// The defect these guard against was measured, not imagined. Against a server that accepted the
// connection and then stopped answering, the session thread sat in `libssh2_sftp_open_ex` →
// `_libssh2_wait_socket` → `select` for 1739 of 1739 samples — `select` with no deadline, because
// nothing ever called `libssh2_session_set_timeout`. Everything else on that session queues behind
// it, `close()` included, so the connection could not even be hung up; and since quitting waits for
// mounts to close, the whole application could no longer be quit.
//
// No SSH server is needed to test this, and deliberately so: a test that depends on one gets skipped
// on the machine that needed it most. A plain TCP listener that accepts and then says nothing is
// exactly the failure being defended against — the client is waiting for a banner that never comes.

import XCTest
import PCVFS
@testable import PCNet

final class SFTPTimeoutTests: XCTestCase {

    private var listener: Int32 = -1
    private var port: UInt16 = 0
    private var savedOperation = 0
    private var savedConnect = 0.0

    override func setUpWithError() throws {
        savedOperation = SFTPSession.operationTimeoutMs
        savedConnect = SFTPSession.connectTimeoutSeconds
        try startSilentListener()
    }

    override func tearDownWithError() throws {
        SFTPSession.operationTimeoutMs = savedOperation
        SFTPSession.connectTimeoutSeconds = savedConnect
        if listener >= 0 { close(listener) }
    }

    /// A socket that accepts connections and then never writes a byte.
    ///
    /// The backlog does the accepting, so no thread is needed: a connect succeeds, and the client
    /// then waits for an SSH banner that is never coming — which is precisely the state a loaded
    /// server leaves it in.
    private func startSilentListener() throws {
        listener = socket(AF_INET, SOCK_STREAM, 0)
        try XCTSkipUnless(listener >= 0, "could not create a socket")
        var yes: Int32 = 1
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        try XCTSkipUnless(bound == 0 && Darwin.listen(listener, 8) == 0, "could not listen")
        var out = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &out) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &len) }
        }
        port = UInt16(bigEndian: out.sin_port)
    }

    private func connectToSilentServer(_ session: SFTPSession) async throws {
        try await session.connect(host: "127.0.0.1", port: port, user: "u",
                                  password: "p", keyFile: nil, keyPassphrase: nil)
    }

    // MARK: - Tests

    func test_aServerThatNeverAnswersGivesUpRatherThanWaitingForever() async throws {
        SFTPSession.operationTimeoutMs = 1_000
        let session = SFTPSession()
        let start = Date()
        do {
            try await connectToSilentServer(session)
            XCTFail("connected to a server that never sent a banner")
        } catch {
            // Which error it is does not matter — that it *arrives* does.
            XCTAssertLessThan(Date().timeIntervalSince(start), 20,
                              "the handshake was still waiting long after its timeout")
        }
        await session.close()
    }

    func test_interruptEndsAWaitThatIsAlreadyUnderway() async throws {
        // What makes ⏏ work on a stuck mount, and what lets the app quit. libssh2 cannot be
        // interrupted mid-call, so the socket is shut down under it; the blocked `select` returns at
        // once and the call fails instead of hanging.
        SFTPSession.operationTimeoutMs = 60_000          // long enough that only interrupt can end it
        let session = SFTPSession()
        let connecting = Task { try await self.connectToSilentServer(session) }

        // Let it get as far as the banner wait before pulling the socket out.
        try? await Task.sleep(nanoseconds: 400_000_000)
        let start = Date()
        session.interrupt()

        do {
            _ = try await connecting.value
            XCTFail("an interrupted connect reported success")
        } catch {
            XCTAssertLessThan(Date().timeIntervalSince(start), 10,
                              "interrupt did not unblock the session")
        }
        await session.close()
    }

    func test_closeReturnsEvenWhenTheSessionIsStuck() async throws {
        // The disconnect must not queue behind the stuck call for ever — that was the bug that made
        // quitting impossible. `close()` gives the polite goodbye a grace period and then cuts.
        SFTPSession.operationTimeoutMs = 60_000
        let session = SFTPSession()
        let connecting = Task { try? await self.connectToSilentServer(session) }
        try? await Task.sleep(nanoseconds: 400_000_000)

        let start = Date()
        await session.close()
        XCTAssertLessThan(Date().timeIntervalSince(start), 10, "close() waited on a dead session")
        _ = await connecting.result
    }

    // MARK: - Telling a dead connection from a missing file

    func test_aLostTransportIsReportedAsALostConnection() {
        // Not as "not found", which is what every one of these call sites used to say.
        // `libssh2_sftp_open_ex` answers NULL for both, so a connection dying during a listing told
        // the user the directory did not exist — and sent them looking for a folder that is exactly
        // where they left it. The app keys its whole recovery off this distinction: `connectionLost`
        // is what makes the panel leave the dead mount and the drive chip disappear.
        let mapped = SFTPFileSystem.mapError(SFTPError.transportLost("open dir"))
        guard case VFSError.connectionLost = mapped else {
            return XCTFail("a lost transport was reported as \(mapped)")
        }
    }

    func test_aMissingFileIsStillAMissingFile() {
        // The other side of the same distinction: widening "connection lost" until it swallows an
        // ordinary missing file would throw away a working mount every time someone opened a stale
        // bookmark.
        let mapped = SFTPFileSystem.mapError(SFTPError.notFound("/gone.txt"))
        guard case VFSError.notFound(let p) = mapped, p == "/gone.txt" else {
            return XCTFail("a missing file was reported as \(mapped)")
        }
    }

    func test_aRefusedPortFailsPromptly() async throws {
        // The other kind of unreachable: nothing is listening at all. Bounded by the connect timeout
        // rather than the kernel's own, which is around 75 seconds of nothing per address.
        SFTPSession.connectTimeoutSeconds = 1
        close(listener)                                   // free the port, then aim at it
        listener = -1
        let session = SFTPSession()
        let start = Date()
        do {
            try await connectToSilentServer(session)
            XCTFail("connected to a port with nothing behind it")
        } catch {
            XCTAssertLessThan(Date().timeIntervalSince(start), 20)
        }
    }
    // MARK: - Host-key fingerprints

    func test_theFingerprintMatchesWhatSshItselfPrints() throws {
        // A fingerprint the user cannot compare character for character with the one the server's
        // operator published is one they will approve without reading. So the format is not "some
        // hash of the key" — it is exactly ssh's, and this checks it against ssh's own answer
        // rather than against our own idea of it.
        //
        // Both constants came out of OpenSSH, not out of this code: the blob is the RSA host key
        // `ssh-keyscan` reported for a test server, and the fingerprint is what `ssh-keygen -lf`
        // printed for that very line.
        let key = try XCTUnwrap(Data(base64Encoded: Self.sampleHostKey))
        XCTAssertEqual(SFTPSession.fingerprint(of: key), "SHA256:ekoXCyU8CQ4iieFFwOKSEKr4VtPavRv6dvCxjuMIlZw")
    }

    func test_theFingerprintCarriesNoBase64Padding() throws {
        // ssh strips it. A padded one differs from the published fingerprint in its last two
        // characters — visible, confusing, and exactly where attention has run out.
        let key = try XCTUnwrap(Data(base64Encoded: Self.sampleHostKey))
        XCTAssertFalse(SFTPSession.fingerprint(of: key).hasSuffix("="))
    }

    /// An RSA host key blob, as `ssh-keyscan` prints it. Public by nature; nothing secret here.
    private static let sampleHostKey = "AAAAB3NzaC1yc2EAAAADAQABAAABAQC6OBveUHLKnkNxhjTGKTnyPElZYhR7ee6IcWsAnbFsnrwot9fKZvqXivLdp8SEvPgCGxQXBxC0cwI+IYEdgpgknZeEBvZb/9XlBrPXGHJhhm/dPOluKd8u3xjuA47oDzB3np4d4g4t0ke/MrchhYtaVaktd/PoV0GHK62o49HiIyO3++RsrzD0Fllubvf2yF3ehHyc5rz8fFLSKswt2ihQwJJmm04DSOwI30qS9yPP+gWYhDZU45wrhN3CsvSLrYH+/XxMfZkzmkiwmawOMRI7bqgGhnUI95t0Tw7UEjOii4BPo0GLmxC1fnABEHpmDhoFZugzY2KaTMF3OEfcSKKJ"
}
