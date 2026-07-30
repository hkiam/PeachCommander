// SPDX-License-Identifier: Apache-2.0
// SFTPLiveTests.swift - End-to-end SFTP against the public Rebex test server
// (test.rebex.net, demo/password, read-only). Network-dependent (F-214).

import XCTest
@testable import PCNet

final class SFTPLiveTests: XCTestCase {
    func test_connect_list_read_rebex() async throws {
        let session = SFTPSession()
        do {
            try await session.connect(host: "test.rebex.net", port: 22, user: "demo",
                                      password: "password", keyFile: nil, keyPassphrase: nil)
        } catch {
            throw XCTSkip("SFTP test server unreachable: \(error)")
        }
        defer { Task { await session.close() } }

        // List the root — Rebex exposes readme.txt + a pub/ directory.
        let entries = try await session.listDirectory("/")
        let names = Set(entries.map { $0.name })
        XCTAssertTrue(names.contains("readme.txt"), "root entries: \(names.sorted())")
        XCTAssertTrue(entries.contains { $0.name == "pub" && $0.isDirectory })

        // Download readme.txt and sanity-check its content.
        let data = try await session.read("/readme.txt")
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(data.isEmpty)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("rebex"), "readme did not mention Rebex")
    }
}
