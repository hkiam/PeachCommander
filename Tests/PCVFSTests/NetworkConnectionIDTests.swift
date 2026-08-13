// SPDX-License-Identifier: Apache-2.0
// NetworkConnectionIDTests.swift - The name a plugin's connection wears on its drive chip.
//
// The id is the plugin's to choose, so what matters here is the ids that are not the shape the
// host hopes for. Each case below would otherwise reach the drive bar as an unclickable chip, a
// truncated host name, or the word "webdav" printed twice.

import XCTest
@testable import PCVFS

final class NetworkConnectionIDTests: XCTestCase {

    func testTheSchemeBecomesTheKindAndTheRestBecomesTheName() {
        let split = NetworkConnectionID.split("webdav:files.example.org")
        XCTAssertEqual(split.name, "files.example.org")
        XCTAssertEqual(split.kind, "WebDAV")
    }

    func testTheSchemeIsSplitOffOnlyOnce() {
        // A port, or a path with a colon in it, belongs to the name. Splitting on every colon
        // would put a chip on the bar labelled "host" for a connection to host:8080/pub, and two
        // such connections would then be one chip.
        let split = NetworkConnectionID.split("webdav:host:8080/pub")
        XCTAssertEqual(split.name, "host:8080/pub")
        XCTAssertEqual(split.kind, "WebDAV")
    }

    func testAnIdWithNoSchemeIsItsOwnName() {
        // Nothing to strip, and nothing to call it — the caller supplies its own wording rather
        // than being handed a guess.
        let split = NetworkConnectionID.split("files.example.org")
        XCTAssertEqual(split.name, "files.example.org")
        XCTAssertNil(split.kind)
    }

    func testAnIdThatIsOnlyASchemeKeepsIt() {
        // Stripping would leave an empty chip: nothing to click, nothing to read, and
        // indistinguishable from the next one.
        for id in ["webdav:", ":host", ":"] {
            let split = NetworkConnectionID.split(id)
            XCTAssertEqual(split.name, id, "\(id) has nothing that can be split off")
            XCTAssertNil(split.kind)
        }
    }

    func testAcronymsAreShoutedAndNamesAreNot() {
        // These end up next to each other in one bar, so they should look like they were written
        // by the same hand: FTP is an acronym, WebDAV and iCloud are names.
        XCTAssertEqual(NetworkConnectionID.split("ftp:example.org").kind, "FTP")
        XCTAssertEqual(NetworkConnectionID.split("sftp:example.org").kind, "SFTP")
        XCTAssertEqual(NetworkConnectionID.split("WebDav:example.org").kind, "WebDAV")
        XCTAssertEqual(NetworkConnectionID.split("icloud:example.org").kind, "iCloud")
    }
}
