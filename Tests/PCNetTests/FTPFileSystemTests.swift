import XCTest
@testable import PCNet
import PCVFS

private func reply(_ s: String) -> FTPReply { FTPReplyParser.parse(s)! }

final class FTPFileSystemTests: XCTestCase {
    private func fs(greeting: String = "220 ready", _ replies: [FTPReply], data: [Data] = [])
        -> (FTPFileSystem, ScriptedControlTransport) {
        let t = ScriptedControlTransport(greeting: reply(greeting), replies: replies, dataReads: data)
        let conn = FTPControlConnection(transport: t, controlHost: "10.0.0.1")
        return (FTPFileSystem(connection: conn), t)
    }

    private func collect(_ stream: AsyncThrowingStream<VFSEntryBatch, Error>) async throws -> [VFSEntry] {
        var out: [VFSEntry] = []
        for try await batch in stream { out.append(contentsOf: batch.entries) }
        return out
    }

    func testCapabilities() {
        let (f, _) = fs([])
        XCTAssertTrue(f.capabilities.contains(.read))
        XCTAssertTrue(f.capabilities.contains(.write))
        XCTAssertTrue(f.capabilities.contains(.rename))
        XCTAssertEqual(f.scheme, "ftp")
    }

    func testListMapsToVFSEntries() async throws {
        let listing = "drwxr-xr-x 2 a b 4096 Jan 10  2023 sub\r\n-rw-r--r-- 1 a b 12 Jan 10  2023 readme.txt\r\n"
        let (f, t) = fs([reply("229 Entering Extended Passive Mode (|||50000|)"),
                         reply("150 here"), reply("226 done")], data: [Data(listing.utf8)])
        let entries = try await collect(f.list(VFSPath(filesystemId: "ftp", path: "/pub")))
        XCTAssertEqual(entries.map(\.name), ["sub", "readme.txt"])
        XCTAssertEqual(entries[0].kind, .directory)
        XCTAssertEqual(entries[1].kind, .file)
        XCTAssertEqual(entries[1].ext, "txt")
        XCTAssertEqual(entries[1].size, 12)
        XCTAssertEqual(t.sent, ["EPSV", "LIST /pub"])
    }

    func testOpenReadStreamsBytes() async throws {
        let body = Data(repeating: 0xAB, count: 100_000)   // > one chunk
        let (f, _) = fs([reply("229 Entering Extended Passive Mode (|||51000|)"),
                         reply("150 opening"), reply("226 complete")], data: [body])
        let stream = try await f.openRead(VFSPath(filesystemId: "ftp", path: "/f.bin"))
        var got = Data()
        for try await chunk in stream { got.append(chunk as! Data) }
        try await stream.close()
        XCTAssertEqual(got, body)
    }

    func testOpenWriteUploadsOnClose() async throws {
        let (f, t) = fs([reply("229 Entering Extended Passive Mode (|||52000|)"),
                         reply("150 send it"), reply("226 stored")])
        let w = try await f.openWrite(VFSPath(filesystemId: "ftp", path: "/up.bin"), options: WriteOptions())
        try await w.write(Data("hello ".utf8))
        try await w.write(Data("world".utf8))
        try await w.close()
        XCTAssertEqual(t.sent, ["EPSV", "STOR /up.bin"])
        // Streaming: chunks are written to the data channel as they arrive; their
        // concatenation is the uploaded content.
        XCTAssertEqual(t.dataWritten.reduce(Data(), +), Data("hello world".utf8))
    }

    func testMkdirAndRename() async throws {
        let (f, t) = fs([reply("257 created"), reply("350 ready"), reply("250 ok")])
        try await f.mkdir(VFSPath(filesystemId: "ftp", path: "/new"))
        try await f.rename(VFSPath(filesystemId: "ftp", path: "/a"), to: VFSPath(filesystemId: "ftp", path: "/b"))
        XCTAssertEqual(t.sent, ["MKD /new", "RNFR /a", "RNTO /b"])
    }

    func testDeleteFileStatsThenDELE() async throws {
        let listing = "-rw-r--r-- 1 a b 5 Jan 10  2023 f.txt\r\n"
        let (f, t) = fs([reply("229 Entering Extended Passive Mode (|||53000|)"),
                         reply("150 list"), reply("226 done"), reply("250 deleted")],
                        data: [Data(listing.utf8)])
        try await f.delete(VFSPath(filesystemId: "ftp", path: "/dir/f.txt"))
        XCTAssertEqual(t.sent, ["EPSV", "LIST /dir", "DELE /dir/f.txt"])
    }

    func testMissingFileMapsToNotFound() async throws {
        let (f, _) = fs([reply("229 Entering Extended Passive Mode (|||54000|)"),
                         reply("550 no such file")])
        // openRead is lazy now (streaming): the RETR + error surface on first read.
        do {
            let stream = try await f.openRead(VFSPath(filesystemId: "ftp", path: "/nope"))
            for try await _ in stream {}
            XCTFail("expected notFound")
        } catch VFSError.notFound {
            // expected
        }
    }
}
