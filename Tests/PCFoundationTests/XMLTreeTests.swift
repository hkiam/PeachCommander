import XCTest
@testable import PCFoundation

final class XMLTreeTests: XCTestCase {
    func testParsesStructure() {
        let root = XMLTreeParser.parse(#"<catalog n="2"><book id="b1"><title>Hi</title></book><book id="b2"/></catalog>"#)
        let r = try? XCTUnwrap(root)
        XCTAssertNotNil(r)
        guard let r else { return }
        XCTAssertEqual(r.name, "catalog")
        XCTAssertEqual(r.attributes.first?.name, "n")
        XCTAssertEqual(r.attributes.first?.value, "2")
        XCTAssertEqual(r.children.count, 2)
        XCTAssertEqual(r.children[0].name, "book")
        XCTAssertEqual(r.children[0].attributes.first?.value, "b1")
        XCTAssertEqual(r.children[0].children.first?.name, "title")
        XCTAssertEqual(r.children[0].children.first?.text, "Hi")   // leaf text
    }

    func testLeafTextOnlyWithoutElementChildren() {
        let root = XMLTreeParser.parse("<a><b>text</b></a>")
        // `a` has an element child → no leaf text; `b` is a leaf with text.
        XCTAssertNil(root?.text)
        XCTAssertEqual(root?.children.first?.text, "text")
    }

    func testLabel() {
        let node = XMLTreeNode(name: "book", attributes: [("id", "b1")], text: "Hi")
        XCTAssertEqual(node.label, #"book id="b1" = Hi"#)
    }

    func testInvalidXML() {
        XCTAssertNil(XMLTreeParser.parse("<a><b></a>"))
        XCTAssertNil(XMLTreeParser.parse("not xml"))
    }

    func testStructuralEquality() {
        let a = XMLTreeParser.parse("<r><x>1</x></r>")!
        let b = XMLTreeParser.parse("<r><x>1</x></r>")!
        let c = XMLTreeParser.parse("<r><x>2</x></r>")!
        XCTAssertTrue(a.structurallyEquals(b))
        XCTAssertFalse(a.structurallyEquals(c))
    }
}
