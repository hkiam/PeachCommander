// SPDX-License-Identifier: Apache-2.0
// StructureNavigationTests.swift - Moving and selecting by structure (F-369).

import XCTest
@testable import PCFoundation

final class StructureNavigationTests: XCTestCase {

    private let yaml = """
    services:
      web:
        image: nginx
        ports:
          - "80:80"
      db:
        image: postgres
    volumes:
      data: {}
    """

    private func offset(_ needle: String, in source: String) -> Int {
        let r = (source as NSString).range(of: needle)
        XCTAssertNotEqual(r.location, NSNotFound, "fixture does not contain \(needle)")
        return r.location
    }

    func testTheInnermostNodeAtAnOffset() {
        let roots = StructureOutline.parse(yaml, ext: "yml")
        XCTAssertEqual(StructureNavigation.node(roots, at: offset("image: nginx", in: yaml))?.name, "image")
    }

    func testTheParentIsOneStepOut() {
        let roots = StructureOutline.parse(yaml, ext: "yml")
        let at = offset("image: nginx", in: yaml)
        XCTAssertEqual(StructureNavigation.parent(roots, at: at)?.name, "web")
    }

    func testTheFirstChildIsOneStepIn() {
        let roots = StructureOutline.parse(yaml, ext: "yml")
        XCTAssertEqual(StructureNavigation.firstChild(roots, at: offset("services:", in: yaml))?.name,
                       "web")
    }

    func testSiblingsSkipTheCurrentNodesContents() {
        // From `web` the next sibling is `db`, not `image` — jumping over the block is the point.
        let roots = StructureOutline.parse(yaml, ext: "yml")
        let web = offset("web:", in: yaml)
        XCTAssertEqual(StructureNavigation.sibling(roots, at: web, delta: 1)?.name, "db")
        let db = offset("db:", in: yaml)
        XCTAssertEqual(StructureNavigation.sibling(roots, at: db, delta: -1)?.name, "web")
    }

    func testSiblingNavigationWorksAtTheTopLevelToo() {
        let roots = StructureOutline.parse(yaml, ext: "yml")
        XCTAssertEqual(StructureNavigation.sibling(roots, at: offset("services:", in: yaml),
                                                  delta: 1)?.name, "volumes")
    }

    func testThereIsNoWrapAround() {
        // A beep at the last sibling is honest; jumping back to the first is a bug people report as
        // "it lost my place".
        let roots = StructureOutline.parse(yaml, ext: "yml")
        XCTAssertNil(StructureNavigation.sibling(roots, at: offset("volumes:", in: yaml), delta: 1))
        XCTAssertNil(StructureNavigation.sibling(roots, at: offset("services:", in: yaml), delta: -1))
        XCTAssertNil(StructureNavigation.parent(roots, at: offset("services:", in: yaml)))
    }

    func testSelectingTheEnclosingNodeGrowsOnEachPress() {
        let json = """
        {
          "services": {
            "web": { "image": "nginx" }
          }
        }
        """
        let roots = StructureOutline.parse(json, ext: "json")
        // A caret inside the innermost value selects that key/value pair …
        let caret = offset("nginx", in: json)
        guard let first = StructureNavigation.enclosing(roots, selection: caret..<caret) else {
            return XCTFail("nothing selected")
        }
        XCTAssertEqual(first.name, "image")
        // … and asking again from that selection goes out to the object around it, not to itself.
        guard let second = StructureNavigation.enclosing(roots, selection: first.start..<first.end) else {
            return XCTFail("did not grow")
        }
        XCTAssertEqual(second.name, "web")
        guard let third = StructureNavigation.enclosing(roots, selection: second.start..<second.end) else {
            return XCTFail("did not grow twice")
        }
        XCTAssertEqual(third.name, "services")
        // The outermost node cannot grow any further.
        XCTAssertNil(StructureNavigation.enclosing(roots, selection: third.start..<third.end))
    }

    func testASelectionSpanningSiblingsGrowsToTheirParent() {
        let json = "{\"a\": {\"x\": 1, \"y\": 2}}"
        let roots = StructureOutline.parse(json, ext: "json")
        let from = offset("\"x\"", in: json)
        let to = offset("2", in: json) + 1
        XCTAssertEqual(StructureNavigation.enclosing(roots, selection: from..<to)?.name, "a")
    }

    func testNothingToNavigateInAnEmptyOutline() {
        XCTAssertNil(StructureNavigation.node([], at: 0))
        XCTAssertNil(StructureNavigation.parent([], at: 0))
        XCTAssertNil(StructureNavigation.sibling([], at: 0, delta: 1))
        XCTAssertNil(StructureNavigation.enclosing([], selection: 0..<0))
    }
}
