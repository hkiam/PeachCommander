import XCTest
@testable import PCFoundation

final class SplitInfoTests: XCTestCase {
    func testRoundTrip() {
        let info = SplitInfo(filename: "movie.avi", size: 734_003_200, crc32: 0x1A2B3C4D)
        let parsed = SplitInfo.parse(info.serialized())
        XCTAssertEqual(parsed, info)
    }

    func testSerializedFormat() {
        let info = SplitInfo(filename: "a.bin", size: 10, crc32: 0xCBF43926)
        XCTAssertEqual(info.serialized(), "filename=a.bin\nsize=10\ncrc32=CBF43926\n")
    }

    func testParseIgnoresOrderAndWhitespace() {
        let text = "crc32=cbf43926\n size = 10 \nfilename = a.bin \n"
        XCTAssertEqual(SplitInfo.parse(text), SplitInfo(filename: "a.bin", size: 10, crc32: 0xCBF43926))
    }

    func testParseRejectsMissingKeys() {
        XCTAssertNil(SplitInfo.parse("filename=a\nsize=10\n"))   // no crc32
    }

    func testPartName() {
        XCTAssertEqual(SplitInfo.partName("movie.avi", index: 1), "movie.avi.001")
        XCTAssertEqual(SplitInfo.partName("x", index: 42), "x.042")
        XCTAssertEqual(SplitInfo.partName("x", index: 1234), "x.1234")
    }

    func testPartCount() {
        XCTAssertEqual(SplitInfo.partCount(size: 1000, partSize: 300), 4)   // 300+300+300+100
        XCTAssertEqual(SplitInfo.partCount(size: 900, partSize: 300), 3)
        XCTAssertEqual(SplitInfo.partCount(size: 0, partSize: 300), 0)
        XCTAssertEqual(SplitInfo.partCount(size: 50, partSize: 0), 1)
    }
}
