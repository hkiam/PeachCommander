// DownloadNameTests.swift - filename suggestion + sanitization for downloads (F-330).

import XCTest
@testable import PCFoundation

final class DownloadNameTests: XCTestCase {
    func testFromURLPath() {
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://example.com/files/report.pdf"), "report.pdf")
        XCTAssertEqual(DownloadName.suggested(fromURL: "http://host/a/b/archive.tar.gz"), "archive.tar.gz")
    }

    func testStripsQueryAndFragment() {
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://x.com/dl/file.zip?token=abc&v=2#frag"), "file.zip")
    }

    func testPercentDecoded() {
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://x.com/My%20File%20(1).txt"), "My File (1).txt")
    }

    func testFallbacks() {
        // No path component → host, then generic.
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://example.com/"), "example.com")
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://example.com"), "example.com")
    }

    func testContentDispositionPreferred() {
        let cd = "attachment; filename=\"server-name.bin\""
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://x.com/dl?id=9", contentDisposition: cd), "server-name.bin")
    }

    func testContentDispositionExtendedRFC5987() {
        let cd = "attachment; filename*=UTF-8''na%C3%AFve%20r%C3%A9sum%C3%A9.pdf"
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://x.com/x", contentDisposition: cd), "naïve résumé.pdf")
    }

    func testSanitizeSeparatorsAndControls() {
        XCTAssertEqual(DownloadName.sanitize("a/b:c\\d"), "a_b_c_d")
        XCTAssertEqual(DownloadName.sanitize("  spaced.txt  "), "spaced.txt")
        XCTAssertEqual(DownloadName.sanitize("."), "")
        XCTAssertEqual(DownloadName.sanitize(".."), "")
    }

    func testMaliciousPathTraversalNameIsFlattened() {
        // A Content-Disposition trying to escape the folder is reduced to one component.
        let cd = "attachment; filename=\"../../etc/passwd\""
        XCTAssertEqual(DownloadName.suggested(fromURL: "https://x.com/x", contentDisposition: cd), ".._.._etc_passwd")
    }
}
