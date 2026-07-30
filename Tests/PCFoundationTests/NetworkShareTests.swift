// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class NetworkShareTests: XCTestCase {
    private func s(_ input: String) -> String? { NetworkShare.url(from: input)?.absoluteString }

    func testUNCPath() {
        XCTAssertEqual(s(#"\\server\share\dir"#), "smb://server/share/dir")
        XCTAssertEqual(s(#"\\nas\pub"#), "smb://nas/pub")
    }

    func testDoubleSlash() {
        XCTAssertEqual(s("//server/share"), "smb://server/share")
    }

    func testBareServerShare() {
        XCTAssertEqual(s("server/share"), "smb://server/share")
    }

    func testExplicitSchemesPreserved() {
        XCTAssertEqual(s("smb://user@server/share"), "smb://user@server/share")
        XCTAssertEqual(s("afp://server/vol"), "afp://server/vol")
        XCTAssertEqual(NetworkShare.url(from: "afp://server/vol")?.scheme, "afp")
    }

    func testHost() {
        XCTAssertEqual(NetworkShare.url(from: #"\\nas\pub"#)?.host, "nas")
    }

    func testInvalid() {
        XCTAssertNil(NetworkShare.url(from: ""))
        XCTAssertNil(NetworkShare.url(from: "   "))
        XCTAssertNil(NetworkShare.url(from: "http://example.com"))   // not a share scheme
        XCTAssertNil(NetworkShare.url(from: "smb://"))               // no host
    }
}
