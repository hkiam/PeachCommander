// SPDX-License-Identifier: Apache-2.0
// VFSNavigatorTests.swift - Tests for the per-tab (fs, path) navigation
// stack (SPEC-006 §2).

import XCTest
@testable import PCVFS

final class VFSNavigatorTests: XCTestCase {
    /// Stand-ins for the host filesystem and nested (e.g. archive)
    /// filesystems a navigator can push onto its stack. `VFSNavigator`
    /// itself never touches disk, so plain `LocalFS()` instances used only
    /// as distinct object identities are sufficient here.
    private let rootFS = LocalFS()
    private let archiveFS = LocalFS()
    private let nestedArchiveFS = LocalFS()

    private func path(_ raw: String, on fs: VirtualFileSystem) -> VFSPath {
        VFSPath(filesystemId: fs.scheme, path: raw)
    }

    func test_root_depthIsOne() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        XCTAssertEqual(navigator.depth, 1)
    }

    func test_root_displayPathEqualsCurrentPath() {
        let root = path("/Users/x/docs", on: rootFS)
        let navigator = VFSNavigator(fs: rootFS, path: root)
        XCTAssertEqual(navigator.displayPath(), root.path)
    }

    func test_go_replacesPathKeepingSameFSAndDepth() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.go(to: path("/Users/x/sub", on: rootFS))

        XCTAssertEqual(navigator.currentPath.path, "/Users/x/sub")
        XCTAssertTrue(navigator.currentFS === rootFS)
        XCTAssertEqual(navigator.depth, 1)
    }

    func test_push_increasesDepthAndSwitchesCurrentFS() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/", on: archiveFS))

        XCTAssertEqual(navigator.depth, 2)
        XCTAssertTrue(navigator.currentFS === archiveFS)
    }

    func test_push_composesDisplayPath_atNestedRoot() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/", on: archiveFS))

        XCTAssertEqual(navigator.displayPath(), "/Users/x/a.zip")
    }

    func test_push_composesDisplayPath_withInnerPath() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/dir", on: archiveFS))

        XCTAssertEqual(navigator.displayPath(), "/Users/x/a.zip/dir")
    }

    func test_go_withinNestedFrame_updatesComposedDisplayPath() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/", on: archiveFS))
        navigator.go(to: path("/dir/file.txt", on: archiveFS))

        XCTAssertEqual(navigator.displayPath(), "/Users/x/a.zip/dir/file.txt")
    }

    func test_pop_returnsHostDisplayAndDecrementsDepth() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/", on: archiveFS))

        let popped = navigator.pop()

        XCTAssertEqual(popped, "/Users/x/a.zip")
        XCTAssertEqual(navigator.depth, 1)
        XCTAssertTrue(navigator.currentFS === rootFS)
    }

    func test_pop_atRoot_returnsNilAndKeepsDepth() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))

        let popped = navigator.pop()

        XCTAssertNil(popped)
        XCTAssertEqual(navigator.depth, 1)
    }

    func test_nestedPush_composesDisplayPathTwice() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/dir", on: archiveFS))
        let innerHost = navigator.displayPath() + "/nested.zip"
        navigator.push(fs: nestedArchiveFS, at: innerHost, path: path("/", on: nestedArchiveFS))

        XCTAssertEqual(navigator.depth, 3)
        XCTAssertEqual(navigator.displayPath(), "/Users/x/a.zip/dir/nested.zip")
    }

    func test_popAfterNestedPush_returnsToIntermediateDisplayPath() {
        let navigator = VFSNavigator(fs: rootFS, path: path("/Users/x", on: rootFS))
        navigator.push(fs: archiveFS, at: "/Users/x/a.zip", path: path("/dir", on: archiveFS))
        let innerHost = navigator.displayPath() + "/nested.zip"
        navigator.push(fs: nestedArchiveFS, at: innerHost, path: path("/inner", on: nestedArchiveFS))

        let poppedHost = navigator.pop()

        XCTAssertEqual(poppedHost, innerHost)
        XCTAssertEqual(navigator.depth, 2)
        XCTAssertEqual(navigator.displayPath(), "/Users/x/a.zip/dir")
        XCTAssertTrue(navigator.currentFS === archiveFS)
    }
}
