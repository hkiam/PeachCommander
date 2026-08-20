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

    // The form resent when the on-device model's input guardrail rejects the composed
    // prompt: the paths go (they are what reads as non-natural language), the names stay
    // (they are what the model answers from), and the user's question is untouched.
    func test_stripPaths_dropsFolderPath_keepsSelectionNames() {
        let ctx = ChatContext(folder: "/var/folders/kx/T/6EB7337A-3470-474D-848E-8892DF1A52E5",
                              selection: ["/tmp/bericht.txt"])
        let out = ChatComposer.stripPaths(
            ChatComposer.compose(userText: "um was geht die aktuell markierte Datei?",
                                 context: ctx, attachments: []))
        XCTAssertFalse(out.contains("/var/folders"), "the path must be gone: \(out)")
        XCTAssertFalse(out.contains("6EB7337A"), "no opaque folder name either: \(out)")
        XCTAssertTrue(out.contains("bericht.txt"), "the selected file's name must survive: \(out)")
        XCTAssertTrue(out.hasSuffix("um was geht die aktuell markierte Datei?"))
    }

    func test_stripPaths_reducesAttachmentsToNames() {
        let out = ChatComposer.stripPaths(
            ChatComposer.compose(userText: "check these", context: nil,
                                 attachments: ["/p/one.txt", "/p/deep/two.md"]))
        XCTAssertFalse(out.contains("/p/"))
        XCTAssertTrue(out.contains("one.txt"))
        XCTAssertTrue(out.contains("two.md"))
        XCTAssertTrue(out.hasSuffix("check these"))
    }

    func test_stripPaths_isIdempotent_andLeavesPlainTextAlone() {
        XCTAssertEqual(ChatComposer.stripPaths("just a question"), "just a question")
        let composed = ChatComposer.compose(userText: "hi",
                                            context: ChatContext(folder: "/f/g", selection: ["/f/g/a.txt"]),
                                            attachments: ["/p/one.txt"])
        let once = ChatComposer.stripPaths(composed)
        XCTAssertEqual(ChatComposer.stripPaths(once), once)
    }

    // A multi-line question keeps all of its lines: only the header is rewritten.
    func test_stripPaths_keepsMultiLineUserText() {
        let text = "erste Zeile\nzweite Zeile"
        let out = ChatComposer.stripPaths(
            ChatComposer.compose(userText: text, context: ChatContext(folder: "/f", selection: []),
                                 attachments: ["/p/one"]))
        XCTAssertTrue(out.hasSuffix(text), "got: \(out)")
    }
}
