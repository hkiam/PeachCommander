import XCTest
@testable import PCFoundation

final class XPathQueryTests: XCTestCase {
    private let doc = """
    <catalog>
      <book id="b1"><title>Swift</title><price>39</price></book>
      <book id="b2"><title>AppKit</title><price>49</price></book>
    </catalog>
    """

    func testSelectElements() throws {
        let titles = try XPathQuery.evaluate(xml: doc, query: "//title")
        XCTAssertEqual(titles, ["<title>Swift</title>", "<title>AppKit</title>"])
    }

    func testSelectTextNodes() throws {
        let prices = try XPathQuery.evaluate(xml: doc, query: "//price/text()")
        XCTAssertEqual(prices, ["39", "49"])
    }

    func testSelectAttribute() throws {
        let ids = try XPathQuery.evaluate(xml: doc, query: "//book/@id")
        XCTAssertEqual(ids, ["b1", "b2"])
    }

    func testPredicate() throws {
        let match = try XPathQuery.evaluate(xml: doc, query: "//book[@id='b2']/title")
        XCTAssertEqual(match, ["<title>AppKit</title>"])
    }

    func testNoMatchIsEmpty() throws {
        XCTAssertEqual(try XPathQuery.evaluate(xml: doc, query: "//nope"), [])
    }

    func testInvalidXMLThrows() {
        XCTAssertThrowsError(try XPathQuery.evaluate(xml: "<a><b></a>", query: "//a")) { error in
            XCTAssertEqual(error as? XPathQuery.QueryError, .invalidXML)
        }
    }

    func testInvalidQueryThrows() {
        XCTAssertThrowsError(try XPathQuery.evaluate(xml: doc, query: "//[[[")) { error in
            XCTAssertEqual(error as? XPathQuery.QueryError, .invalidQuery)
        }
    }
}
