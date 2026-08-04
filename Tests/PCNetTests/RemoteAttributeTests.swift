// SPDX-License-Identifier: Apache-2.0
// RemoteAttributeTests.swift - What a remote filesystem refuses, and says it refuses (F-364).
//
// Both SFTP and FTP used to accept every attribute change and drop it: SFTP's `setAttributes` was an
// empty function, and FTP swallowed the server's reply with `try?`. The dialog then reported success and
// the file was untouched — the worst possible outcome, because the user has no reason to look again.
//
// What is checked here is the refusing half, which needs no server: the guards run before anything is
// sent. That the *applying* half really reaches the server is checked end to end by the
// `sftp-attributes` scenario in Tools/vm/regress.py, where an independent `stat` over ssh reads the mode
// back — and that is not a formality: it caught this implementation using libssh2's STAT constant
// instead of SETSTAT, which returned success and changed nothing.

import XCTest
@testable import PCNet
@testable import PCVFS

final class RemoteAttributeTests: XCTestCase {

    /// An unconnected session: every test here asserts on a guard that runs *before* anything is sent,
    /// which is precisely what makes them worth having without a server.
    private func sftp() -> SFTPFileSystem { SFTPFileSystem(session: SFTPSession()) }

    func testSFTPRefusesAnOwnerChangeInsteadOfIgnoringIt() async {
        // SFTP carries uid/gid as numbers only; a user *name* cannot be resolved over the protocol, so
        // guessing would be worse than refusing.
        let fs = sftp()
        do {
            try await fs.setAttributes(VFSPath(filesystemId: "sftp", path: "/tmp/x"),
                                       attributes: VFSAttributes(ownerName: "root"))
            XCTFail("an owner change must be refused, not silently dropped")
        } catch {
            XCTAssertEqual(error as? VFSError, .unsupported)
        }
    }

    func testSFTPRefusesBSDFlags() async {
        // st_flags is a macOS notion; there is nothing on the far side to set.
        do {
            try await sftp().setAttributes(VFSPath(filesystemId: "sftp", path: "/tmp/x"),
                                          attributes: VFSAttributes(bsdFlags: 2))
            XCTFail("BSD flags must be refused")
        } catch {
            XCTAssertEqual(error as? VFSError, .unsupported)
        }
    }

    func testSFTPDoesNothingAndSucceedsWhenNothingWasAsked() async throws {
        // An empty request must not open a connection to example.invalid — the guard returns first.
        try await sftp().setAttributes(VFSPath(filesystemId: "sftp", path: "/tmp/x"),
                                      attributes: VFSAttributes())
    }

    func testFTPRefusesWhatSITECHMODCannotExpress() async {
        // A scripted transport, as the other FTP tests use: these assertions are about the guards, so no
        // exchange happens at all — and a refusal that reached the wire would show up as an unused reply.
        let transport = ScriptedControlTransport(greeting: FTPReplyParser.parse("220 ready")!,
                                                 replies: [], dataReads: [])
        let fs = FTPFileSystem(connection: FTPControlConnection(transport: transport,
                                                               controlHost: "10.0.0.1"))
        for attributes in [VFSAttributes(ownerName: "root"), VFSAttributes(groupName: "wheel"),
                          VFSAttributes(bsdFlags: 2)] {
            do {
                try await fs.setAttributes(VFSPath(filesystemId: "ftp", path: "/x"),
                                           attributes: attributes)
                XCTFail("FTP has no standard way to set this and must say so")
            } catch {
                XCTAssertEqual(error as? VFSError, .unsupported)
            }
        }
    }
}
