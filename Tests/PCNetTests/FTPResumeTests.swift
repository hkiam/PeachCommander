// SPDX-License-Identifier: Apache-2.0
// FTPResumeTests.swift - Continuing an interrupted download instead of starting over (F-212).
//
// `REST` was in the control connection from the beginning and never called with an offset: the plumbing
// existed, nothing was connected to it, and a 4 GB download that dropped at 99 % began again at zero. The
// same shape as the directory watcher that polled and told nobody.
//
// Driven through the scripted transport, so what is asserted is the command sequence the server would
// see — `REST` before `RETR`, with the byte count the partial file actually has — and the bytes on disk.

import XCTest
@testable import PCNet
@testable import PCVFS

private func reply(_ s: String) -> FTPReply { FTPReplyParser.parse(s)! }

final class FTPResumeTests: XCTestCase {
    private var directory = URL(fileURLWithPath: "/dev/null")

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pc-ftp-resume-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A filesystem whose scripted server answers `replies` in order and hands out `data` per channel.
    private func fs(_ replies: [FTPReply], data: [Data] = [])
        -> (FTPFileSystem, ScriptedControlTransport) {
        let transport = ScriptedControlTransport(greeting: reply("220 ready"), replies: replies,
                                                dataReads: data)
        return (FTPFileSystem(connection: FTPControlConnection(transport: transport,
                                                              controlHost: "10.0.0.1")), transport)
    }

    private func destination(_ name: String) -> URL { directory.appendingPathComponent(name) }

    func testAFreshDownloadSendsNoRestartAndWritesTheFile() async throws {
        let (f, t) = fs([reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("150 opening"), reply("226 done")],
                        data: [Data("hello".utf8)])
        let target = destination("fresh.txt")
        let result = try await f.downloadFile(VFSPath(filesystemId: "ftp", path: "/pub/a.txt"),
                                              to: target, resume: true)
        XCTAssertEqual(result.resumedAt, 0)
        XCTAssertEqual(result.written, 5)
        XCTAssertEqual(try Data(contentsOf: target), Data("hello".utf8))
        XCTAssertFalse(t.sent.contains { $0.hasPrefix("REST") }, "nothing to resume: \(t.sent)")
    }

    func testAPartialFileResumesAtItsLengthAndAppends() async throws {
        let target = destination("partial.txt")
        try Data("hel".utf8).write(to: target)
        // SIZE for the stat, then the data channel: the remote file is longer, so three bytes are already
        // there and the server is asked to restart at three.
        let (f, t) = fs([reply("213 5"),
                         reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("350 restarting at 3"),
                         reply("150 opening"), reply("226 done")],
                        data: [Data("lo".utf8)])
        let result = try await f.downloadFile(VFSPath(filesystemId: "ftp", path: "/pub/a.txt"),
                                              to: target, resume: true)
        XCTAssertEqual(result.resumedAt, 3)
        XCTAssertEqual(result.written, 2, "only the tail should travel")
        XCTAssertEqual(try Data(contentsOf: target), Data("hello".utf8),
                       "the tail must be appended, not written over the start")
        XCTAssertTrue(t.sent.contains("REST 3"), "sent: \(t.sent)")
        XCTAssertLessThan(t.sent.firstIndex(of: "REST 3") ?? .max,
                          t.sent.firstIndex(where: { $0.hasPrefix("RETR") }) ?? 0,
                          "REST must precede RETR")
    }

    func testResumeIsNotAttemptedWhenTheLocalFileIsNotShorter() async throws {
        // Equal or longer means the local file is not a prefix of the remote one; appending would produce
        // a corrupt file that looks complete.
        let target = destination("same.txt")
        try Data("hello".utf8).write(to: target)
        let (f, t) = fs([reply("213 5"),
                         reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("150 opening"), reply("226 done")],
                        data: [Data("hello".utf8)])
        let result = try await f.downloadFile(VFSPath(filesystemId: "ftp", path: "/pub/a.txt"),
                                              to: target, resume: true)
        XCTAssertEqual(result.resumedAt, 0)
        XCTAssertFalse(t.sent.contains { $0.hasPrefix("REST") }, "sent: \(t.sent)")
        XCTAssertEqual(try Data(contentsOf: target), Data("hello".utf8))
    }

    func testASeverRefusingRestartStartsOverInsteadOfFailing() async throws {
        // Not every server supports REST, and FEAT is not always honest about it. The user asked for the
        // file, not for the resume.
        let target = destination("refused.txt")
        try Data("hel".utf8).write(to: target)
        let (f, t) = fs([reply("213 5"),
                         reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("502 command not implemented"),          // REST refused
                         reply("229 Entering Extended Passive Mode (|||50001|)"),
                         reply("150 opening"), reply("226 done")],
                        // One per data channel: the refused attempt opens one before REST is answered,
                        // which is how the leak below came to light.
                        data: [Data(), Data("hello".utf8)])
        let result = try await f.downloadFile(VFSPath(filesystemId: "ftp", path: "/pub/a.txt"),
                                              to: target, resume: true)
        XCTAssertEqual(result.resumedAt, 0, "fell back to a full transfer")
        XCTAssertEqual(result.written, 5)
        XCTAssertEqual(try Data(contentsOf: target), Data("hello".utf8),
                       "the stale three bytes must be gone, not kept in front")
        XCTAssertTrue(t.sent.contains("REST 3"), "it should have tried: \(t.sent)")
    }

    func testResumeOffCopiesFromTheStart() async throws {
        let target = destination("noresume.txt")
        try Data("hel".utf8).write(to: target)
        let (f, t) = fs([reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("150 opening"), reply("226 done")],
                        data: [Data("hello".utf8)])
        let result = try await f.downloadFile(VFSPath(filesystemId: "ftp", path: "/pub/a.txt"),
                                              to: target, resume: false)
        XCTAssertEqual(result.resumedAt, 0)
        XCTAssertEqual(try Data(contentsOf: target), Data("hello".utf8))
        XCTAssertFalse(t.sent.contains { $0.hasPrefix("SIZE") }, "no need to ask: \(t.sent)")
    }
}
