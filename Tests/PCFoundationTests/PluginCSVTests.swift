// SPDX-License-Identifier: Apache-2.0
// PluginCSVTests.swift - Does a delimited file's first line name the columns, or is it data?
//
// The defect: it was always taken as the column titles. A file that starts straight into data lost its
// first record — it became the table's header, where it could not be filtered, sorted or searched, and
// nothing on screen said so or could undo it. There is no marker in the format that answers the
// question, so the parser guesses; these tests pin the guess, and the view lets the reader override it.

import XCTest

final class PluginCSVTests: XCTestCase {

    // MARK: - The guess

    func testAHeaderOfWordsOverNumericDataIsAHeader() {
        let table = PluginCSV.parse("name,count\nalpha,3\nbeta,4")
        XCTAssertTrue(table.usedHeader)
        XCTAssertEqual(table.header, ["name", "count"])
        XCTAssertEqual(table.rows, [["alpha", "3"], ["beta", "4"]])
    }

    /// The case this exists for: no header anywhere, and the first record is data.
    func testANumberInTheFirstLineMeansThereIsNoHeader() {
        let table = PluginCSV.parse("1,2,3\n4,5,6")
        XCTAssertFalse(table.usedHeader)
        XCTAssertEqual(table.header, ["Column 1", "Column 2", "Column 3"])
        XCTAssertEqual(table.rows.count, 2, "the first line must still be a row")
        XCTAssertEqual(table.rows.first, ["1", "2", "3"])
    }

    /// A table of strings only, where header and data look alike — which is why the guess does not
    /// compare the first line's types against the columns below it.
    func testStringsOnlyStillGetsAHeader() {
        let table = PluginCSV.parse("name,city\nJohn,New York\nAnna,Berlin")
        XCTAssertTrue(table.usedHeader)
        XCTAssertEqual(table.header, ["name", "city"])
    }

    func testARepeatedValueInTheFirstLineMeansData() {
        let table = PluginCSV.parse("berlin,berlin\nmunich,hamburg")
        XCTAssertFalse(table.usedHeader)
        XCTAssertEqual(table.rows.count, 2)
    }

    func testAnEmptyCellInTheFirstLineMeansData() {
        let table = PluginCSV.parse("name,,city\na,b,c")
        XCTAssertFalse(table.usedHeader)
    }

    /// A single line has no data rows: as titles it would show an empty table, which is the worse guess.
    func testASingleLineIsData() {
        let table = PluginCSV.parse("alpha,beta,gamma")
        XCTAssertFalse(table.usedHeader)
        XCTAssertEqual(table.rows, [["alpha", "beta", "gamma"]])
    }

    func testEmptyInputIsAnEmptyTable() {
        let table = PluginCSV.parse("")
        XCTAssertEqual(table.header, [])
        XCTAssertEqual(table.rows, [])
    }

    // MARK: - The override

    func testTheReaderCanForceAHeader() {
        let table = PluginCSV.parse("1,2,3\n4,5,6", headerMode: .header)
        XCTAssertTrue(table.usedHeader)
        XCTAssertEqual(table.header, ["1", "2", "3"])
        XCTAssertEqual(table.rows, [["4", "5", "6"]])
    }

    func testTheReaderCanForceNoHeader() {
        let table = PluginCSV.parse("name,count\nalpha,3", headerMode: .noHeader)
        XCTAssertFalse(table.usedHeader)
        XCTAssertEqual(table.header, ["Column 1", "Column 2"])
        XCTAssertEqual(table.rows, [["name", "count"], ["alpha", "3"]])
    }

    /// Without a header row the column count comes from the widest record, or a ragged file would lose
    /// the columns only its later rows have.
    func testColumnCountWithoutAHeaderComesFromTheWidestRow() {
        let table = PluginCSV.parse("1,2\n3,4,5", headerMode: .noHeader)
        XCTAssertEqual(table.header, ["Column 1", "Column 2", "Column 3"])
    }

    // MARK: - What counts as a number

    func testNumberRecognition() {
        for numeric in ["3", "-4", "+5", "3.14", "1,5", "1 000", "0", "007"] {
            XCTAssertTrue(PluginCSV.isNumeric(numeric), "\(numeric) is a number")
        }
        // "nan" and "inf" parse as Double and are not numbers anybody writes as a heading; "Inf" is a
        // place in Switzerland, and a column headed "E5" is not scientific notation.
        for text in ["nan", "inf", "Inf", "1e5", "E5", "count", "", " ", "-", "12a"] {
            XCTAssertFalse(PluginCSV.isNumeric(text), "\(text) is not a number")
        }
    }

    // MARK: - Delimiters and quoting (kept from the view, now testable)

    func testDelimiterDetection() {
        XCTAssertEqual(PluginCSV.parse("a;b;c\n1;2;3").delimiter, ";")
        XCTAssertEqual(PluginCSV.parse("a\tb\tc\n1\t2\t3").delimiter, "\t")
        XCTAssertEqual(PluginCSV.parse("a|b\n1|2").delimiter, "|")
    }

    func testQuotedFieldsAndCRLF() {
        let table = PluginCSV.parse("name,city\r\n\"Smith, John\",\"Berlin\"\r\n", headerMode: .header)
        XCTAssertEqual(table.header, ["name", "city"])
        // The quoted comma is not a field separator this small reader honours — it splits first — but the
        // quotes are stripped, which is what the previous implementation did too. Recorded rather than
        // claimed: a full CSV grammar is not what this plugin is.
        XCTAssertEqual(table.rows.first?.count, 3)
    }

    func testBlankLinesAreDropped() {
        let table = PluginCSV.parse("name,count\n\nalpha,3\n\n")
        XCTAssertEqual(table.rows, [["alpha", "3"]])
    }
}
