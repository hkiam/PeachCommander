// SPDX-License-Identifier: Apache-2.0
// SymbolTreeTests.swift - Unit tests for the tree-sitter-independent symbol-outline
// logic (nesting, same-name merge, filter, enclosing path, find, dedup).

import XCTest
@testable import PCFoundation

final class SymbolTreeTests: XCTestCase {
    private func def(_ name: String, _ kind: String, line: Int = 1, loc: Int = 0,
                     _ start: Int, _ end: Int) -> SymbolTree.Def {
        SymbolTree.Def(name: name, kind: kind, line: line, utf16Location: loc, start: start, end: end)
    }

    /// Demo(module) ⊃ Calc(class) ⊃ {Add, Sum}; main(function) is a sibling of Demo.
    private func sampleRoots() -> [SymbolNode] {
        SymbolTree.build([
            def("Demo", "module", 0, 100),
            def("Calc", "class", 10, 90),
            def("Add", "method", 20, 30),
            def("Sum", "method", 40, 60),
            def("main", "function", 200, 250),
        ])
    }

    func test_build_nestsByContainment() {
        let roots = sampleRoots()
        XCTAssertEqual(roots.map(\.name), ["Demo", "main"])
        XCTAssertEqual(roots[0].children.map(\.name), ["Calc"])
        XCTAssertEqual(roots[0].children[0].children.map(\.name), ["Add", "Sum"])
    }

    func test_build_mergesSameNameContainers() {
        // Rust struct Point + impl Point → one node with the impl's methods.
        let roots = SymbolTree.build([
            def("Point", "class", 0, 20),      // struct, no members
            def("Point", "class", 30, 80),     // impl block
            def("new", "method", 40, 50),
            def("norm", "method", 55, 75),
        ])
        XCTAssertEqual(roots.map(\.name), ["Point"])
        XCTAssertEqual(roots[0].children.map(\.name), ["new", "norm"])
    }

    func test_build_dedupsSameStartAndName() {
        let roots = SymbolTree.build([
            def("A", "function", 0, 10),
            def("A", "function", 0, 10),
        ])
        XCTAssertEqual(roots.count, 1)
    }

    func test_filter_keepsMatchesAndAncestors() {
        let filtered = SymbolTree.filter(sampleRoots(), query: "sum")
        XCTAssertEqual(filtered.map(\.name), ["Demo"])
        XCTAssertEqual(filtered[0].children.map(\.name), ["Calc"])
        XCTAssertEqual(filtered[0].children[0].children.map(\.name), ["Sum"])
    }

    func test_filter_emptyQueryReturnsAll() {
        XCTAssertEqual(SymbolTree.filter(sampleRoots(), query: "  ").map(\.name), ["Demo", "main"])
    }

    func test_enclosingPath_outerToInner() {
        let path = SymbolTree.enclosingPath(sampleRoots(), utf16: 45)   // inside Sum (40–60)
        XCTAssertEqual(path.map(\.name), ["Demo", "Calc", "Sum"])
    }

    func test_enclosingPath_outsideAny_isEmpty() {
        XCTAssertTrue(SymbolTree.enclosingPath(sampleRoots(), utf16: 300).isEmpty)
    }

    func test_find_depthFirst() {
        let roots = sampleRoots()
        XCTAssertEqual(SymbolTree.find(roots, named: "Add")?.name, "Add")
        XCTAssertEqual(SymbolTree.find(roots, named: "Demo")?.name, "Demo")
        XCTAssertNil(SymbolTree.find(roots, named: "Nope"))
    }
}
