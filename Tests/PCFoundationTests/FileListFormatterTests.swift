// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCFoundation

final class FileListFormatterTests: XCTestCase {
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }
    private lazy var rows = [
        FileListRow(name: "readme.txt", ext: "txt", size: 1234, modified: date(2026, 1, 2, 3, 4, 5)),
        FileListRow(name: "folder", ext: "", size: -1, modified: date(2026, 6, 15, 12, 0, 0))
    ]

    func testTSV() {
        let out = FileListFormatter.format(rows, as: .tsv)
        XCTAssertEqual(out,
            "Name\tExt\tSize\tModified\n" +
            "readme.txt\ttxt\t1234\t2026-01-02 03:04:05\n" +
            "folder\t\t\t2026-06-15 12:00:00\n")   // dir → empty size
    }

    func testPlainNamesOnly() {
        XCTAssertEqual(FileListFormatter.format(rows, as: .plain), "readme.txt\nfolder\n")
    }

    func testCSVQuoting() {
        let r = [FileListRow(name: "a,b \"quoted\".txt", ext: "txt", size: 5, modified: date(2026, 1, 1))]
        let out = FileListFormatter.format(r, as: .csv, header: false)
        XCTAssertEqual(out, "\"a,b \"\"quoted\"\".txt\",txt,5,2026-01-01 00:00:00\n")
    }

    func testHeaderToggle() {
        let out = FileListFormatter.format(rows, as: .tsv, header: false)
        XCTAssertFalse(out.hasPrefix("Name\tExt"))
        XCTAssertTrue(out.hasPrefix("readme.txt"))
    }

    func testEmpty() {
        XCTAssertEqual(FileListFormatter.format([], as: .plain), "")
        XCTAssertEqual(FileListFormatter.format([], as: .tsv, header: false), "")
    }
}
