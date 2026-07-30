import XCTest
@testable import PCNet

final class FTPProtocolTests: XCTestCase {

    // MARK: - Reply framing

    func testSingleLineReplyComplete() {
        XCTAssertTrue(FTPReplyParser.isComplete("220 Service ready\r\n"))
        let r = FTPReplyParser.parse("220 Service ready\r\n")
        XCTAssertEqual(r?.code, 220)
        XCTAssertEqual(r?.text, "Service ready")
        XCTAssertTrue(r?.isSuccess ?? false)
    }

    func testMultilineReplyFraming() {
        // Not complete until the closing "NNN " line arrives.
        let partial = "211-Features:\r\n MLST\r\n UTF8\r\n"
        XCTAssertFalse(FTPReplyParser.isComplete(partial))
        let full = partial + "211 End\r\n"
        XCTAssertTrue(FTPReplyParser.isComplete(full))
        let r = FTPReplyParser.parse(full)
        XCTAssertEqual(r?.code, 211)
        XCTAssertTrue(r?.text.contains("Features:") ?? false)
        XCTAssertTrue(r?.text.contains("End") ?? false)
    }

    func testMultilineWithEmbeddedCodeLine() {
        // A message line that itself starts with the code but a hyphen keeps going.
        let full = "230-Welcome\r\n230-to the server\r\n230 Login successful\r\n"
        XCTAssertTrue(FTPReplyParser.isComplete(full))
        XCTAssertEqual(FTPReplyParser.parse(full)?.code, 230)
    }

    func testReplyClassification() {
        XCTAssertTrue(FTPReplyParser.parse("331 Password required\r\n")!.isIntermediate)
        XCTAssertTrue(FTPReplyParser.parse("150 Opening data\r\n")!.isPreliminary)
        XCTAssertTrue(FTPReplyParser.parse("550 Not found\r\n")!.isError)
    }

    func testIncompleteBufferNotComplete() {
        XCTAssertFalse(FTPReplyParser.isComplete("220"))
        XCTAssertFalse(FTPReplyParser.isComplete("2"))
    }

    // MARK: - PASV / EPSV

    func testParsePASV() {
        let a = FTPDataAddress.parsePASV("227 Entering Passive Mode (192,168,1,50,195,80).")
        XCTAssertEqual(a?.host, "192.168.1.50")
        XCTAssertEqual(a?.port, 195 * 256 + 80)   // 49920
    }

    func testParsePASVWithoutParens() {
        let a = FTPDataAddress.parsePASV("227 Passive mode 10,0,0,1,4,1")
        XCTAssertEqual(a?.host, "10.0.0.1")
        XCTAssertEqual(a?.port, 4 * 256 + 1)
    }

    func testParsePASVRejectsBadOctets() {
        XCTAssertNil(FTPDataAddress.parsePASV("227 (999,1,1,1,1,1)"))
    }

    func testParseEPSV() {
        XCTAssertEqual(FTPDataAddress.parseEPSV("229 Entering Extended Passive Mode (|||49152|)"), 49152)
    }

    func testParseEPSVInvalid() {
        XCTAssertNil(FTPDataAddress.parseEPSV("229 no address here"))
    }
}
