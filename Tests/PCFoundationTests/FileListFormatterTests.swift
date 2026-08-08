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

    // MARK: - Names that break the format (F-092)
    //
    // "Copy file details" puts this on the clipboard to be pasted into a spreadsheet. A row that has
    // silently shifted a column is not obviously wrong there — it is just wrong, and it is read as data.
    // All the names below are ones macOS will let you create.

    private func row(_ name: String) -> FileListRow {
        FileListRow(name: name, ext: "txt", size: 1, modified: Date(timeIntervalSince1970: 0))
    }

    func testACRLFInANameIsQuotedInCSV() {
        // The guard compared each Character against "\n" and "\r"; in Swift a CRLF is one Character
        // equal to neither, so such a name went through unquoted and split the row in two.
        XCTAssertEqual(FileListFormatter.csvQuote("a\r\nb.txt"), "\"a\r\nb.txt\"")
        XCTAssertEqual(FileListFormatter.csvQuote("a\nb.txt"), "\"a\nb.txt\"")
        XCTAssertEqual(FileListFormatter.csvQuote("a\rb.txt"), "\"a\rb.txt\"")
        XCTAssertEqual(FileListFormatter.csvQuote("plain.txt"), "plain.txt", "and nothing else is quoted")
    }

    func testATabInANameDoesNotShiftTheTSVColumns() {
        // TSV has no quoting: a tab *is* the separator. Escaped, so the name is still readable.
        let text = FileListFormatter.format([row("with\ttab.txt")], as: .tsv, header: false)
        let cells = text.trimmingCharacters(in: .newlines).split(separator: "\t", omittingEmptySubsequences: false)
        XCTAssertEqual(cells.count, 4, "four columns, whatever the name contains: \(text)")
        XCTAssertEqual(String(cells[0]), "with\\ttab.txt")
    }

    func testALineBreakInANameDoesNotSplitTheTSVRow() {
        for name in ["with\nnewline.txt", "with\r\ncrlf.txt", "with\rcr.txt"] {
            let text = FileListFormatter.format([row(name)], as: .tsv, header: false)
            let lines = text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            XCTAssertEqual(lines.count, 1, "one file must be one row; \(name) produced \(lines.count)")
        }
    }

    func testABackslashInANameStaysDistinguishableFromAnEscape() {
        // Without escaping the backslash itself, a file really called "a\tb.txt" and one containing a
        // tab would come out identical, and neither could be read back.
        let text = FileListFormatter.format([row("a\\tb.txt")], as: .tsv, header: false)
        XCTAssertTrue(text.hasPrefix("a\\\\tb.txt\t"), "got: \(text)")
    }

    func testSixFilesAreSixRowsInTSV() {
        let names = ["ordinary.txt", "with,comma.txt", "with\"quote.txt",
                     "with\nnewline.txt", "with\r\ncrlf.txt", "with\ttab.txt"]
        let text = FileListFormatter.format(names.map(row), as: .tsv, header: false)
        let lines = text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        XCTAssertEqual(lines.count, 6)
        for line in lines {
            XCTAssertEqual(line.split(separator: "\t", omittingEmptySubsequences: false).count, 4)
        }
    }
}
