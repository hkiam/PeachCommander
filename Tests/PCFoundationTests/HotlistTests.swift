// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class HotlistTests: XCTestCase {
    func testAddAndContains() {
        var h = Hotlist()
        h.add(title: "Tmp", path: "/tmp")
        XCTAssertEqual(h.entries.count, 1)
        XCTAssertTrue(h.contains(path: "/tmp"))
        XCTAssertFalse(h.contains(path: "/usr"))
    }

    func testRemove() {
        var h = Hotlist(entries: [.init(title: "a", path: "/a"), .init(title: "b", path: "/b")])
        h.remove(at: 0)
        XCTAssertEqual(h.entries.map { $0.path }, ["/b"])
        h.remove(at: 5) // out of range → no-op
        XCTAssertEqual(h.entries.count, 1)
    }

    func testMoveRenameAndSetPath() {
        var h = Hotlist(entries: [.init(title: "a", path: "/a"),
                                  .init(title: "b", path: "/b"),
                                  .init(title: "c", path: "/c")])
        h.move(from: 0, to: 2)
        XCTAssertEqual(h.entries.map(\.title), ["b", "c", "a"])
        h.setTitle("Work\\Sub", at: 1)
        XCTAssertEqual(h.entries[1].title, "Work\\Sub")
        h.setPath("/new", at: 1)
        XCTAssertEqual(h.entries[1].path, "/new")
        h.move(from: 0, to: 9)   // out of range → no-op
        XCTAssertEqual(h.entries.map(\.title), ["b", "Work\\Sub", "a"])
    }

    func testSeparatorSurvivesINIRoundTrip() {
        // A "-" entry has an empty path; it must NOT be dropped on reload (F-061).
        let h = Hotlist(entries: [.init(title: "Docs", path: "/docs"),
                                  .init(title: "-", path: ""),
                                  .init(title: "Home", path: "/home")])
        var ini = INIDocument()
        h.write(to: &ini)
        let reloaded = Hotlist(ini: INIDocument(parsing: ini.serialized()))
        XCTAssertEqual(reloaded.entries.map(\.title), ["Docs", "-", "Home"])
    }

    func testINIRoundTrip() {
        var h = Hotlist()
        h.add(title: "Home", path: "/Users/x")
        h.add(title: "Tmp", path: "/tmp")
        var ini = INIDocument()
        h.write(to: &ini)
        let reloaded = Hotlist(ini: INIDocument(parsing: ini.serialized()))
        XCTAssertEqual(reloaded, h)
    }

    func testWriteShrinksAndClearsStaleEntries() {
        var h = Hotlist(entries: [.init(title: "a", path: "/a"), .init(title: "b", path: "/b"), .init(title: "c", path: "/c")])
        var ini = INIDocument()
        h.write(to: &ini)
        h.remove(at: 2)
        h.remove(at: 1)
        h.write(to: &ini)
        XCTAssertEqual(ini.value(section: "Hotlist", key: "Count"), "1")
        XCTAssertNil(ini.value(section: "Hotlist", key: "Entry1Path"))
        XCTAssertNil(ini.value(section: "Hotlist", key: "Entry2Path"))
        let reloaded = Hotlist(ini: ini)
        XCTAssertEqual(reloaded.entries.map { $0.path }, ["/a"])
    }

    func testLoadFromEmptyINI() {
        let h = Hotlist(ini: INIDocument())
        XCTAssertTrue(h.entries.isEmpty)
    }
}
