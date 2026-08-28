// SPDX-License-Identifier: Apache-2.0
// The payload of a recorded file operation (F-402), and the one rule it exists to keep (F-478).
//
// A trash, a delete and a rename now carry enough to be turned into a macro step. None of them may
// become repeatable from the history palette by that: pressing Return on a row of a list somebody is
// browsing must never delete anything, and the whole of that guarantee lives in `decode`.

import XCTest

final class HistoryOperationTests: XCTestCase {

    func test_copyAndMoveRoundTrip() throws {
        let payload = HistoryOperation.encode(kind: HistoryOperation.kindCopy,
                                              items: ["/a/one.pdf", "/a/two.pdf"], mask: nil)
        let decoded = try XCTUnwrap(HistoryOperation.decode(payload))
        XCTAssertEqual(decoded.kind, HistoryOperation.kindCopy)
        XCTAssertEqual(decoded.items, ["/a/one.pdf", "/a/two.pdf"])
        XCTAssertNil(decoded.mask)
    }

    func test_theRenameMaskSurvives() throws {
        let payload = HistoryOperation.encode(kind: HistoryOperation.kindMove,
                                              items: ["/a/one.pdf"], mask: "*.bak")
        XCTAssertEqual(HistoryOperation.decode(payload)?.mask, "*.bak")
    }

    /// **The rule.** Every kind added for the macro recorder must stay invisible to `decode`, which is
    /// what the palette asks. If this ever passes for a trash, Return on a history row deletes files.
    func test_onlyCopyAndMoveAreRepeatableFromThePalette() {
        for kind in [HistoryOperation.kindTrash, HistoryOperation.kindDelete,
                     HistoryOperation.kindRename, HistoryOperation.kindMakeDirectory] {
            let payload = HistoryOperation.encode(kind: kind, items: ["/a/one.pdf"], mask: nil)
            XCTAssertNil(HistoryOperation.decode(payload), "“\(kind)” must not be repeatable")
            // …and is still readable by the recorder, or recording it bought nothing.
            XCTAssertEqual(HistoryOperation.decodeAny(payload)?.kind, kind)
        }
    }

    func test_renamePairsRoundTrip() throws {
        let payload = HistoryOperation.encodeRenames([(old: "a.txt", new: "b.txt"),
                                                      (old: "c d.txt", new: "e f.txt")])
        let pairs = try XCTUnwrap(HistoryOperation.decodeRenames(payload))
        XCTAssertEqual(pairs.map(\.old), ["a.txt", "c d.txt"])
        XCTAssertEqual(pairs.map(\.new), ["b.txt", "e f.txt"])
        XCTAssertNil(HistoryOperation.decode(payload), "a rename is not repeatable from the palette")
    }

    /// An odd number of fields is a payload that was truncated or written by something else; pairing it
    /// up would silently rename a file to the name of the next one.
    func test_anUnpairedRenamePayloadIsRefused() {
        let payload = HistoryOperation.encode(kind: HistoryOperation.kindRename,
                                              items: ["a.txt", "b.txt", "c.txt"], mask: nil)
        XCTAssertNil(HistoryOperation.decodeRenames(payload))
    }

    func test_decodeRenamesRefusesAnotherKind() {
        let payload = HistoryOperation.encode(kind: HistoryOperation.kindCopy,
                                              items: ["a.txt", "b.txt"], mask: nil)
        XCTAssertNil(HistoryOperation.decodeRenames(payload))
    }

    func test_emptyAndMalformedPayloadsDecodeToNothing() {
        XCTAssertNil(HistoryOperation.decode(""))
        XCTAssertNil(HistoryOperation.decodeAny(""))
        XCTAssertNil(HistoryOperation.decodeAny("copy"))
        // A kind and a mask but no items: nothing to act on.
        XCTAssertNil(HistoryOperation.decodeAny("copy\u{3}\u{3}"))
    }

    /// The separator is U+0003, which a macOS file name cannot contain — every other candidate can.
    func test_aNameWithSpacesAndPunctuationSurvives() throws {
        let awkward = ["/a/rabatt 20%netto.pdf", "/a/b,c;d.txt", "/a/quote'name\".txt"]
        let payload = HistoryOperation.encode(kind: HistoryOperation.kindMove, items: awkward, mask: nil)
        XCTAssertEqual(HistoryOperation.decode(payload)?.items, awkward)
    }
}
