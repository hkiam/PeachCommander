// SPDX-License-Identifier: Apache-2.0
// FileAssociationsTests.swift - Per-extension viewer/editor associations (F-273).

import XCTest
@testable import PCFoundation

final class FileAssociationsTests: XCTestCase {
    func test_parse_resolvesViewerAndEditor() {
        let ini = """
        [Viewer]
        PSD = /Applications/Preview.app
        [Editor]
        swift = /Applications/Visual Studio Code.app
        txt = internal
        """
        let a = FileAssociations.parse(ini)
        XCTAssertEqual(a.viewerApp(forExtension: "psd"), "/Applications/Preview.app")   // case-insensitive
        XCTAssertEqual(a.editorApp(forExtension: "SWIFT"), "/Applications/Visual Studio Code.app")
        XCTAssertNil(a.editorApp(forExtension: "txt"))        // "internal" → built-in
        XCTAssertNil(a.viewerApp(forExtension: "png"))        // unset → built-in
    }

    func test_setAndRemove_roundTrip() {
        var a = FileAssociations()
        a.setViewer("/Applications/Foo.app", forExtension: "Bar")
        a.setEditor("/Applications/Baz.app", forExtension: "qux")
        XCTAssertEqual(a.viewerApp(forExtension: "bar"), "/Applications/Foo.app")
        // Reparse serialized form → identical resolution.
        let b = FileAssociations.parse(a.serialized())
        XCTAssertEqual(b, a)
        // Clearing removes the entry.
        a.setViewer(nil, forExtension: "bar")
        XCTAssertNil(a.viewerApp(forExtension: "bar"))
    }

    func test_rows_expose_union_sortedByExtension() {
        let a = FileAssociations(viewers: ["psd": "/P.app", "gif": "/G.app"],
                                 editors: ["swift": "/C.app", "gif": "/E.app"])
        let rows = a.rows
        XCTAssertEqual(rows.map(\.ext), ["gif", "psd", "swift"])   // union, sorted
        let gif = rows.first { $0.ext == "gif" }!
        XCTAssertEqual(gif.viewer, "/G.app")
        XCTAssertEqual(gif.editor, "/E.app")
        XCTAssertEqual(rows.first { $0.ext == "psd" }!.editor, "")  // no editor mapping
    }

    func test_initFromRows_roundTrips_andDropsBlanks() {
        let rows = [
            FileAssociations.Row(ext: "PSD", viewer: "/P.app", editor: ""),   // uppercase → lowercased
            FileAssociations.Row(ext: "swift", viewer: "", editor: "/C.app"),
            FileAssociations.Row(ext: "  ", viewer: "/X.app"),                // blank ext dropped
            FileAssociations.Row(ext: "md", viewer: "  ", editor: "  ")       // all-blank → no mapping
        ]
        let a = FileAssociations(rows: rows)
        XCTAssertEqual(a.viewerApp(forExtension: "psd"), "/P.app")
        XCTAssertEqual(a.editorApp(forExtension: "swift"), "/C.app")
        XCTAssertNil(a.editorApp(forExtension: "psd"))
        XCTAssertNil(a.viewerApp(forExtension: "md"))
        XCTAssertEqual(a.rows.map(\.ext), ["psd", "swift"])
        // rows → init(rows:) → rows is stable.
        XCTAssertEqual(FileAssociations(rows: a.rows), a)
    }
}
