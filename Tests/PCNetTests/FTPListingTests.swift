// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCNet

final class FTPListingTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var comps = DateComponents(); comps.year = y; comps.month = mo; comps.day = d
        comps.hour = h; comps.minute = mi; comps.second = s
        return utc.date(from: comps)!
    }
    /// Fixed "now" so UNIX time-only entries infer a deterministic year.
    private lazy var ref = date(2026, 7, 1, 12, 0, 0)

    // MARK: - MLSD

    func testMLSDFileAndDir() {
        let dir = FTPListParser.parseMLSD("type=dir;sizd=4096;modify=20230115123400;UNIX.mode=0755; folder name")
        XCTAssertEqual(dir?.name, "folder name")
        XCTAssertTrue(dir?.isDirectory ?? false)
        XCTAssertEqual(dir?.modified, date(2023, 1, 15, 12, 34, 0))

        let file = FTPListParser.parseMLSD("type=file;size=123456;modify=20240229080000; report.pdf")
        XCTAssertEqual(file?.name, "report.pdf")
        XCTAssertFalse(file?.isDirectory ?? true)
        XCTAssertEqual(file?.size, 123456)
        XCTAssertEqual(file?.modified, date(2024, 2, 29, 8, 0, 0))
    }

    func testMLSDSkipsDotEntries() {
        XCTAssertNil(FTPListParser.parseMLSD("type=cdir;modify=20230101000000; ."))
        XCTAssertNil(FTPListParser.parseMLSD("type=pdir;modify=20230101000000; .."))
    }

    // MARK: - UNIX

    func testUnixDirectory() {
        let e = FTPListParser.parseUnix("drwxr-xr-x   3 root  wheel   4096 Jan 15  2023 documents", referenceDate: ref)
        XCTAssertEqual(e?.name, "documents")
        XCTAssertTrue(e?.isDirectory ?? false)
        XCTAssertEqual(e?.size, 4096)
        XCTAssertEqual(e?.owner, "root")
        XCTAssertEqual(e?.group, "wheel")
        XCTAssertEqual(e?.permissions, "rwxr-xr-x")
        XCTAssertEqual(e?.modified, date(2023, 1, 15))
    }

    func testUnixFileWithTimeInfersYear() {
        // "Jun 30 08:15" with ref 2026-07-01 → 2026 (just past).
        let e = FTPListParser.parseUnix("-rw-r--r--   1 alice staff  2048 Jun 30 08:15 notes.txt", referenceDate: ref)
        XCTAssertEqual(e?.name, "notes.txt")
        XCTAssertFalse(e?.isDirectory ?? true)
        XCTAssertEqual(e?.size, 2048)
        XCTAssertEqual(e?.modified, date(2026, 6, 30, 8, 15))
    }

    func testUnixTimeInFutureRollsToLastYear() {
        // "Dec 25 00:00" with ref 2026-07-01 is in the future → previous year.
        let e = FTPListParser.parseUnix("-rw-r--r--   1 a b  10 Dec 25 00:00 xmas", referenceDate: ref)
        XCTAssertEqual(e?.modified, date(2025, 12, 25, 0, 0))
    }

    func testUnixFilenameWithSpaces() {
        let e = FTPListParser.parseUnix("-rw-r--r--   1 a b  10 Jan  2  2022 My File Name.txt", referenceDate: ref)
        XCTAssertEqual(e?.name, "My File Name.txt")
        XCTAssertEqual(e?.modified, date(2022, 1, 2))
    }

    func testUnixSymlink() {
        let e = FTPListParser.parseUnix("lrwxrwxrwx   1 a b  7 Jan  1  2020 link -> target", referenceDate: ref)
        XCTAssertEqual(e?.name, "link")
        XCTAssertTrue(e?.isSymlink ?? false)
        XCTAssertEqual(e?.symlinkTarget, "target")
    }

    func testUnixSkipsTotalHeader() {
        XCTAssertNil(FTPListParser.parseUnix("total 42", referenceDate: ref))
    }

    // MARK: - DOS

    func testDOSDirectory() {
        let e = FTPListParser.parseDOS("01-15-23  12:34PM       <DIR>          My Folder")
        XCTAssertEqual(e?.name, "My Folder")
        XCTAssertTrue(e?.isDirectory ?? false)
        XCTAssertEqual(e?.modified, date(2023, 1, 15, 12, 34))
    }

    func testDOSFileWithCommaSize() {
        let e = FTPListParser.parseDOS("03-05-24  09:00AM            1,234,567 archive.zip")
        XCTAssertEqual(e?.name, "archive.zip")
        XCTAssertFalse(e?.isDirectory ?? true)
        XCTAssertEqual(e?.size, 1234567)
        XCTAssertEqual(e?.modified, date(2024, 3, 5, 9, 0))
    }

    func testDOSMidnightNoon() {
        XCTAssertEqual(FTPListParser.parseDOS("01-01-20  12:00AM  5 a")?.modified, date(2020, 1, 1, 0, 0))
        XCTAssertEqual(FTPListParser.parseDOS("01-01-20  12:00PM  5 a")?.modified, date(2020, 1, 1, 12, 0))
    }

    // MARK: - Format detection + whole listings

    func testDetectFormat() {
        XCTAssertEqual(FTPListParser.detectFormat(["type=dir;modify=20230101000000; x"]), .mlsd)
        XCTAssertEqual(FTPListParser.detectFormat(["drwxr-xr-x 2 a b 4096 Jan 1 2023 x"]), .unix)
        XCTAssertEqual(FTPListParser.detectFormat(["01-15-23  12:34PM  <DIR>  x"]), .dos)
        XCTAssertEqual(FTPListParser.detectFormat([""]), .unknown)
    }

    func testParseWholeUnixListing() {
        let text = """
        total 3
        drwxr-xr-x   2 a b   4096 Jan 10  2023 dir
        -rw-r--r--   1 a b    100 Jan 10  2023 file.txt
        lrwxrwxrwx   1 a b      3 Jan 10  2023 ln -> dir
        """
        let entries = FTPListParser.parse(text, referenceDate: ref)
        XCTAssertEqual(entries.map(\.name), ["dir", "file.txt", "ln"])
        XCTAssertTrue(entries[0].isDirectory)
        XCTAssertTrue(entries[2].isSymlink)
    }

    func testParseWholeMLSDListing() {
        let text = "type=cdir; .\r\ntype=pdir; ..\r\ntype=dir;modify=20230101000000; sub\r\ntype=file;size=5;modify=20230101000000; f"
        let entries = FTPListParser.parse(text, referenceDate: ref)
        XCTAssertEqual(entries.map(\.name), ["sub", "f"])
    }

    // MARK: - Shapes real servers emit (F-378)
    //
    // A battery of documented listing formats, run through the parser to see what it makes of each rather
    // than to confirm what it was assumed to do. There is no second parser on this machine to compare
    // against — ftplib does not parse listings and curl needs a server — so these are the shapes
    // themselves: vsftpd, ProFTPD, wu-ftpd, IIS and MLSD per RFC 3659.

    private let reference = ISO8601DateFormatter().date(from: "2026-08-07T12:00:00Z")!

    func testANameWithSeveralSpacesKeepsThem() {
        // Splitting the line into fields and rejoining them with one space turned `two  spaces.txt` into
        // `two spaces.txt` — a name that does not exist on the server, so the file could not be opened or
        // downloaded. The name has to come from the line itself.
        let entry = FTPListParser.parseUnix(
            "-rw-r--r--    1 user     group          10 Mar 03 09:15 two  spaces.txt",
            referenceDate: reference)
        XCTAssertEqual(entry?.name, "two  spaces.txt")
    }

    func testANameWithTrailingSpacesKeepsThem() {
        let entry = FTPListParser.parseUnix(
            "-rw-r--r--    1 user     group          10 Mar 03 09:15  leading.txt",
            referenceDate: reference)
        XCTAssertEqual(entry?.name, " leading.txt")
    }

    func testASizeOverFourGigabytesSurvives() {
        // Not a defect that was found — a defect I briefly believed I had found, because the *probe*
        // printed an Int64 with a 32-bit format. Pinned down so the next reader does not repeat it.
        let entry = FTPListParser.parseUnix(
            "-rw-r--r--    1 user     group  5368709120 Mar 03 09:15 big.iso", referenceDate: reference)
        XCTAssertEqual(entry?.size, 5_368_709_120)
    }

    func testAnACLPlusSignInTheModeIsAccepted() {
        let entry = FTPListParser.parseUnix(
            "-rw-r--r--+   1 user     group         512 Mar 03 09:15 acl.txt", referenceDate: reference)
        XCTAssertEqual(entry?.name, "acl.txt")
        XCTAssertEqual(entry?.size, 512)
    }

    func testANameThatLooksLikeADateIsNotMistakenForOne() {
        let entry = FTPListParser.parseUnix(
            "-rw-r--r--    1 user     group         100 Mar 03 09:15 Mar 03 09:15", referenceDate: reference)
        XCTAssertEqual(entry?.name, "Mar 03 09:15")
    }

    func testMLSDFactNamesAreCaseInsensitive() {
        // RFC 3659 says fact names are case-insensitive, and servers differ on how they write them.
        let entry = FTPListParser.parseMLSD("Type=file;Size=10;Modify=20260101120000; A.txt")
        XCTAssertEqual(entry?.name, "A.txt")
        XCTAssertEqual(entry?.size, 10)
        XCTAssertFalse(entry?.isDirectory ?? true)
    }

    func testMLSDFactsInAnyOrderWithExtraFacts() {
        let entry = FTPListParser.parseMLSD(
            "modify=20260101120000;perm=adfr;type=file;unique=12U1;size=7; b.txt")
        XCTAssertEqual(entry?.size, 7)
        XCTAssertEqual(entry?.name, "b.txt")
    }

    func testMLSDNameMayContainASemicolon() {
        // The name begins after the single space that follows the facts, so a semicolon in it is just a
        // character — splitting the whole line on ";" would lose half the name.
        XCTAssertEqual(FTPListParser.parseMLSD("type=file;size=5; weird;name.txt")?.name,
                       "weird;name.txt")
    }

    func testMLSDSkipsCdirAndPdir() {
        let entries = FTPListParser.parse("type=cdir;modify=20260101120000; /pub\r\n"
                                          + "type=pdir;modify=20260101120000; ..\r\n"
                                          + "type=file;size=1; real.txt\r\n", referenceDate: reference)
        XCTAssertEqual(entries.map(\.name), ["real.txt"])
    }

    func testBlankLinesBetweenEntriesAreIgnored() {
        let entries = FTPListParser.parse(
            "-rw-r--r--    1 user     group         100 Mar 03 09:15 a.txt\r\n\r\n"
            + "-rw-r--r--    1 user     group         100 Mar 03 09:15 b.txt\r\n", referenceDate: reference)
        XCTAssertEqual(entries.map(\.name), ["a.txt", "b.txt"])
    }

    func testATotalHeaderAloneYieldsNothing() {
        XCTAssertTrue(FTPListParser.parse("total 0\r\n", referenceDate: reference).isEmpty)
    }

    func testTheRemainderHelperKeepsInteriorSpacing() {
        XCTAssertEqual(FTPListParser.remainder(of: "a b  c   d", afterFields: 2), " c   d")
        XCTAssertEqual(FTPListParser.remainder(of: "a b", afterFields: 5), "")
        XCTAssertEqual(FTPListParser.remainder(of: "", afterFields: 1), "")
    }
}
