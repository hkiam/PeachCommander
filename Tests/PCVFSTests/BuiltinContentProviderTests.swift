// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import PCVFS

final class BuiltinContentProviderTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-builtin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testExposesStandardFields() {
        let fields = BuiltinContentProvider().fields.map(\.id)
        XCTAssertEqual(fields, ["name", "size", "extension", "modified"])
    }

    func testNameSizeAndExtension() async throws {
        let file = dir.appendingPathComponent("report.pdf")
        try Data(repeating: 0x2A, count: 1234).write(to: file)
        let p = BuiltinContentProvider()

        let name = await p.value(fieldID: "name", forFileAt: file)
        let size = await p.value(fieldID: "size", forFileAt: file)
        let ext = await p.value(fieldID: "extension", forFileAt: file)
        XCTAssertEqual(name, .string("report.pdf"))
        XCTAssertEqual(size, .integer(1234))
        XCTAssertEqual(ext, .string("pdf"))
    }

    func testExtensionlessFileHasNoExtension() async throws {
        let file = dir.appendingPathComponent("README")
        try Data("x".utf8).write(to: file)
        let ext = await BuiltinContentProvider().value(fieldID: "extension", forFileAt: file)
        XCTAssertEqual(ext, .none)
    }

    func testDirectoryHasNoSize() async throws {
        let sub = dir.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let size = await BuiltinContentProvider().value(fieldID: "size", forFileAt: sub)
        XCTAssertEqual(size, .none)
    }

    func testModifiedIsIso8601() async throws {
        let file = dir.appendingPathComponent("f.txt")
        try Data("x".utf8).write(to: file)
        let modified = await BuiltinContentProvider().value(fieldID: "modified", forFileAt: file)
        guard case .string(let s) = modified else { return XCTFail("expected a string") }
        XCTAssertNotNil(ISO8601DateFormatter().date(from: s), "expected ISO-8601 timestamp, got \(s)")
    }

    func testUnknownFieldIsNone() async throws {
        let file = dir.appendingPathComponent("f.txt")
        try Data("x".utf8).write(to: file)
        let v = await BuiltinContentProvider().value(fieldID: "nope", forFileAt: file)
        XCTAssertEqual(v, .none)
    }

    // Symmetry: the built-in provider participates in the registry + search exactly
    // like any plugin provider.
    func testRegistrySearchBySize() async throws {
        let big = dir.appendingPathComponent("big.bin")
        let small = dir.appendingPathComponent("small.bin")
        try Data(repeating: 0, count: 5000).write(to: big)
        try Data(repeating: 0, count: 100).write(to: small)

        let registry = ContentFieldRegistry()
        registry.register(BuiltinContentProvider())
        let matches = await registry.filter([big, small],
            matching: ContentFieldPredicate(qualifiedID: "builtin.size", op: .greater, value: "1000"))
        XCTAssertEqual(matches, [big])
    }
}
