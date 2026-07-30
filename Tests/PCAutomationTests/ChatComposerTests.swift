// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCAutomation

final class ChatComposerTests: XCTestCase {
    func test_plainText_whenNoContext() {
        XCTAssertEqual(ChatComposer.compose(userText: "hi", context: nil, attachments: []), "hi")
    }

    func test_includesContext_folderAndSelectionNames() {
        let ctx = ChatContext(folder: "/Users/me/Docs", selection: ["/Users/me/Docs/a.txt", "/Users/me/Docs/b.md"])
        let out = ChatComposer.compose(userText: "summarize these", context: ctx, attachments: [])
        XCTAssertTrue(out.contains("/Users/me/Docs"))
        XCTAssertTrue(out.contains("a.txt"))
        XCTAssertTrue(out.contains("b.md"))
        XCTAssertTrue(out.contains("2 item"))
        XCTAssertTrue(out.hasSuffix("summarize these"))
    }

    func test_selectionNone_whenEmpty() {
        let ctx = ChatContext(folder: "/f", selection: [])
        XCTAssertTrue(ChatComposer.compose(userText: "x", context: ctx, attachments: []).contains("selection: none"))
    }

    func test_includesAttachments() {
        let out = ChatComposer.compose(userText: "check", context: nil, attachments: ["/p/one", "/p/two"])
        XCTAssertTrue(out.contains("/p/one"))
        XCTAssertTrue(out.contains("/p/two"))
        XCTAssertTrue(out.contains("Attached"))
    }
}
