import XCTest
@testable import PCFoundation

final class ColumnSetTests: XCTestCase {
    private let photos = ColumnSet(name: "Photos", columns: [
        ColumnSpec(fieldID: "builtin.name", title: "Name", width: 220, alignment: .left),
        ColumnSpec(fieldID: "fileinfo.width", title: "W", width: 60, alignment: .right),
        ColumnSpec(fieldID: "fileinfo.height", title: "H", width: 60, alignment: .right)
    ])

    func testRoundTripThroughINI() {
        let text = ColumnSetStore.serialize([photos])
        let parsed = ColumnSetStore.load(from: INIDocument(parsing: text))
        XCTAssertEqual(parsed, [photos])
    }

    func testMultipleSetsPreserveOrder() {
        let details = ColumnSet(name: "Details", columns: [
            ColumnSpec(fieldID: "builtin.name", title: "Name", width: 200),
            ColumnSpec(fieldID: "builtin.size", title: "Size", width: 90, alignment: .right)
        ])
        let text = ColumnSetStore.serialize([photos, details])
        let parsed = ColumnSetStore.load(from: INIDocument(parsing: text))
        XCTAssertEqual(parsed.map(\.name), ["Photos", "Details"])
        XCTAssertEqual(parsed, [photos, details])
    }

    func testDefaultsForMissingKeys() {
        let ini = """
        [ColumnSet.Sparse]
        Count=1
        1.Field=builtin.name
        """
        let parsed = ColumnSetStore.load(from: INIDocument(parsing: ini))
        XCTAssertEqual(parsed.count, 1)
        let col = parsed[0].columns[0]
        XCTAssertEqual(col.fieldID, "builtin.name")
        XCTAssertEqual(col.title, "builtin.name")   // title defaults to the field id
        XCTAssertEqual(col.width, 100)              // default width
        XCTAssertEqual(col.alignment, .left)        // default alignment
    }

    func testEmptySet() {
        let empty = ColumnSet(name: "Empty", columns: [])
        let parsed = ColumnSetStore.load(from: INIDocument(parsing: ColumnSetStore.serialize([empty])))
        XCTAssertEqual(parsed, [empty])
    }

    func testSavePreservesUnrelatedContent() {
        var doc = INIDocument(parsing: """
        [General]
        Theme=dark

        [ColumnSet.Old]
        Count=1
        1.Field=builtin.name
        1.Title=Old Name
        1.Width=50
        1.Align=left
        """)
        // Overwrite "Old" with fewer/renamed columns and confirm no stale keys survive.
        let updated = ColumnSet(name: "Old", columns: [
            ColumnSpec(fieldID: "builtin.size", title: "Size", width: 80, alignment: .right)
        ])
        ColumnSetStore.save([updated], into: &doc)

        XCTAssertEqual(doc.value(section: "General", key: "Theme"), "dark")   // untouched
        let reparsed = ColumnSetStore.load(from: doc)
        XCTAssertEqual(reparsed, [updated])
        XCTAssertNil(doc.value(section: "ColumnSet.Old", key: "1.Title").flatMap { $0 == "Old Name" ? "" : nil })
    }

    func testAllAlignmentsRoundTrip() {
        let set = ColumnSet(name: "Aligns", columns: [
            ColumnSpec(fieldID: "a.l", title: "L", width: 10, alignment: .left),
            ColumnSpec(fieldID: "a.r", title: "R", width: 10, alignment: .right),
            ColumnSpec(fieldID: "a.c", title: "C", width: 10, alignment: .center)
        ])
        let parsed = ColumnSetStore.load(from: INIDocument(parsing: ColumnSetStore.serialize([set])))
        XCTAssertEqual(parsed.first?.columns.map(\.alignment), [.left, .right, .center])
    }
}
