// SelectionStateTests.swift - Unit tests for SelectionState
//
// Exhaustive tests for every row of SPEC-003 §2/§4 tables, encoding correct
// Total Commander selection semantics.

import XCTest
@testable import PCCommands

@MainActor
final class SelectionStateTests: XCTestCase {
    var state: SelectionState!

    override func setUp() async throws {
        try await super.setUp()
        state = SelectionState()
    }

    override func tearDown() async throws {
        try? await super.tearDown()
        state = nil
        try? await super.tearDown()
    }

    // MARK: - Fixtures

    private func makeEntries() -> [SelectableEntry] {
        [
            SelectableEntry(path: "/dir/a.txt", size: 100, isDirectory: false),
            SelectableEntry(path: "/dir/b.txt", size: 200, isDirectory: false),
            SelectableEntry(path: "/dir/c.c", size: 300, isDirectory: false),
            SelectableEntry(path: "/dir/d.h", size: 400, isDirectory: false),
            SelectableEntry(path: "/dir/e.bak", size: 500, isDirectory: false),
            SelectableEntry(path: "/dir/sub", size: -1, isDirectory: true),
        ]
    }

    // MARK: - setEntries

    func testSetEntriesBasic() async throws {
        await state.setEntries(makeEntries())
        let stats = await state.getStatistics()
        XCTAssertEqual(stats.total, 6)
        XCTAssertEqual(stats.selected, 0)
    }

    func testSetEntriesEmpty() async throws {
        await state.setEntries([])
        let stats = await state.getStatistics()
        XCTAssertEqual(stats.total, 0)
    }

    func testSetEntriesRetainsMarksForSurvivingPaths() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/c.c")

        // Re-set entries: b.txt is gone, a.txt and c.c remain, new file added
        let newEntries = [
            SelectableEntry(path: "/dir/a.txt", size: 100, isDirectory: false),
            SelectableEntry(path: "/dir/c.c", size: 300, isDirectory: false),
            SelectableEntry(path: "/dir/new.txt", size: 50, isDirectory: false),
        ]
        await state.setEntries(newEntries)

        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedC = await state.isSelected("/dir/c.c")
        let selectedNew = await state.isSelected("/dir/new.txt")
        XCTAssertTrue(selectedA)
        XCTAssertTrue(selectedC)
        XCTAssertFalse(selectedNew)
    }

    func testSetEntriesDropsMarksForRemovedPaths() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/b.txt")

        await state.setEntries([
            SelectableEntry(path: "/dir/a.txt", size: 100, isDirectory: false)
        ])

        let paths = await state.getSelectedPaths()
        XCTAssertTrue(paths.isEmpty)
    }

    func testSetEntriesClampsCursorWhenShrinking() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(5)
        await state.setEntries([
            SelectableEntry(path: "/dir/a.txt", size: 100, isDirectory: false),
            SelectableEntry(path: "/dir/b.txt", size: 200, isDirectory: false),
        ])
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 1) // clamped to last valid index
    }

    func testSetEntriesClampsCursorToRootWhenEmptied() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(3)
        await state.setEntries([])
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testSetEntriesKeepsCursorOnRootAcrossReset() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        await state.setEntries([
            SelectableEntry(path: "/dir/a.txt", size: 100, isDirectory: false)
        ])
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    // MARK: - Cursor Management

    func testInitialCursorIndex() async throws {
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 0)
    }

    func testSetCursorIndexValid() async throws {
        await state.setEntries(makeEntries())
        let result = await state.setCursorIndex(5)
        XCTAssertTrue(result)
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 5)
    }

    func testSetCursorIndexOnRoot() async throws {
        await state.setEntries(makeEntries())
        let result = await state.setCursorIndex(-1)
        XCTAssertTrue(result)
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testSetCursorIndexOutOfBounds() async throws {
        await state.setEntries(makeEntries())
        let result1 = await state.setCursorIndex(-2)
        let result2 = await state.setCursorIndex(6)
        XCTAssertFalse(result1)
        XCTAssertFalse(result2)
    }

    func testSetCursorIndexOutOfBoundsWhenEmpty() async throws {
        await state.setEntries([])
        let result = await state.setCursorIndex(0)
        XCTAssertFalse(result)
        let resultRoot = await state.setCursorIndex(-1)
        XCTAssertTrue(resultRoot)
    }

    func testMoveCursorUp() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(5)
        await state.moveCursorUp()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 4)
    }

    func testMoveCursorUpAtRoot() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        await state.moveCursorUp()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1) // cannot go above `..`
    }

    func testMoveCursorUpFromZeroReachesRoot() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(0)
        await state.moveCursorUp()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testMoveCursorDown() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(3)
        await state.moveCursorDown()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 4)
    }

    func testMoveCursorDownAtBottom() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(5)
        await state.moveCursorDown()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 5) // stays at bottom
    }

    func testMoveCursorTop() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(4)
        await state.moveCursorTop()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 0)
    }

    func testMoveCursorTopWhenEmpty() async throws {
        await state.setEntries([])
        await state.moveCursorTop()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testMoveCursorBottom() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(0)
        await state.moveCursorBottom()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 5)
    }

    func testMoveCursorBottomWhenEmpty() async throws {
        await state.setEntries([])
        await state.moveCursorBottom()
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testMoveCursorTo() async throws {
        await state.setEntries(makeEntries())
        await state.moveCursorTo(3)
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 3)
    }

    func testMoveCursorToNegativeClampsToRoot() async throws {
        await state.setEntries(makeEntries())
        await state.moveCursorTo(-5)
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, -1)
    }

    func testMoveCursorToBeyondCountClampsToLast() async throws {
        await state.setEntries(makeEntries())
        await state.moveCursorTo(100)
        let idx = await state.getCursorIndex()
        XCTAssertEqual(idx, 5)
    }

    func testIsCursorOnRoot() async throws {
        await state.setEntries(makeEntries())
        let result1 = await state.isCursorOnRoot()
        XCTAssertFalse(result1)
        let _ = await state.setCursorIndex(-1)
        let result2 = await state.isCursorOnRoot()
        XCTAssertTrue(result2)
    }

    // MARK: - getCursorPath

    func testGetCursorPathOnEntry() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(2)
        let path = await state.getCursorPath()
        XCTAssertEqual(path, "/dir/c.c")
    }

    func testGetCursorPathOnRoot() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        let path = await state.getCursorPath()
        XCTAssertNil(path)
    }

    func testGetCursorPathWhenEmpty() async throws {
        await state.setEntries([])
        let path = await state.getCursorPath()
        XCTAssertNil(path)
    }

    // MARK: - select / unselect / toggle

    func testIsSelectedEmpty() async throws {
        let result = await state.isSelected("/path/to/file")
        XCTAssertFalse(result)
    }

    func testSelectFile() async throws {
        await state.setEntries(makeEntries())
        let result = await state.select("/dir/a.txt")
        XCTAssertTrue(result)
        let selected = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(selected)
    }

    func testSelectDuplicateReturnsFalse() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let result = await state.select("/dir/a.txt")
        XCTAssertFalse(result)
    }

    func testUnselectFile() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let result = await state.unselect("/dir/a.txt")
        XCTAssertTrue(result)
        let selected = await state.isSelected("/dir/a.txt")
        XCTAssertFalse(selected)
    }

    func testUnselectNotSelectedReturnsFalse() async throws {
        await state.setEntries(makeEntries())
        let result = await state.unselect("/dir/a.txt")
        XCTAssertFalse(result)
    }

    func testToggleSelect() async throws {
        await state.setEntries(makeEntries())
        let result = await state.toggleSelection("/dir/a.txt")
        XCTAssertTrue(result)
        let selected = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(selected)
    }

    func testToggleUnselect() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.toggleSelection("/dir/a.txt")
        let result = await state.toggleSelection("/dir/a.txt")
        XCTAssertTrue(result)
        let selected = await state.isSelected("/dir/a.txt")
        XCTAssertFalse(selected)
    }

    func testSelectDotDotAlwaysRefused() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(2) // cursor NOT on root
        let result = await state.select("..")
        XCTAssertFalse(result)
        let selected = await state.isSelected("..")
        XCTAssertFalse(selected)
    }

    func testSelectDotDotRefusedWhileOnRoot() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        let result = await state.select("..")
        XCTAssertFalse(result)
    }

    func testToggleDotDotAlwaysRefused() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        let result = await state.toggleSelection("..")
        XCTAssertFalse(result)
        let selected = await state.isSelected("..")
        XCTAssertFalse(selected)
    }

    func testSelectRealPathWhileCursorOnRootIsAllowed() async throws {
        // Cursor being on `..` must not block operating on real paths by path.
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        let result = await state.select("/dir/a.txt")
        XCTAssertTrue(result)
        let selected = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(selected)
    }

    func testGetSelectedPaths() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/b.txt")
        let paths = await state.getSelectedPaths()
        XCTAssertTrue(paths.contains("/dir/a.txt"))
        XCTAssertTrue(paths.contains("/dir/b.txt"))
        XCTAssertEqual(paths.count, 2)
    }

    func testGetSelectedPathListIsInEntryOrder() async throws {
        await state.setEntries(makeEntries())
        // Select out of order
        let _ = await state.select("/dir/e.bak")
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/c.c")
        let list = await state.getSelectedPathList()
        XCTAssertEqual(list, ["/dir/a.txt", "/dir/c.c", "/dir/e.bak"])
    }

    // MARK: - selectAll

    func testSelectAllMarksAllRealPaths() async throws {
        let entries = makeEntries()
        await state.setEntries(entries)
        let result = await state.selectAll()
        XCTAssertTrue(result)
        let paths = await state.getSelectedPaths()
        XCTAssertEqual(paths, Set(entries.map { $0.path }))
    }

    func testSelectAllIncludesDirectories() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.selectAll()
        let selected = await state.isSelected("/dir/sub")
        XCTAssertTrue(selected)
    }

    func testSelectAllOnEmptyReturnsFalse() async throws {
        await state.setEntries([])
        let result = await state.selectAll()
        XCTAssertFalse(result)
    }

    func testSelectAllWhenAlreadyAllSelectedReturnsFalse() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.selectAll()
        let result = await state.selectAll()
        XCTAssertFalse(result)
    }

    // MARK: - clearSelection

    func testClearSelection() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/b.txt")
        let result = await state.clearSelection()
        XCTAssertTrue(result)
        let paths = await state.getSelectedPaths()
        XCTAssertEqual(paths.count, 0)
    }

    func testClearSelectionEmptyReturnsFalse() async throws {
        await state.setEntries(makeEntries())
        let result = await state.clearSelection()
        XCTAssertFalse(result)
    }

    // MARK: - invertSelection

    func testInvertSelectionTogglesMarkedToUnmarked() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/b.txt")
        let result = await state.invertSelection()
        XCTAssertTrue(result)
        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedB = await state.isSelected("/dir/b.txt")
        XCTAssertFalse(selectedA)
        XCTAssertFalse(selectedB)
    }

    func testInvertSelectionTogglesUnmarkedToMarked() async throws {
        let entries = makeEntries()
        await state.setEntries(entries)
        let _ = await state.select("/dir/a.txt")
        let _ = await state.invertSelection()
        let paths = await state.getSelectedPaths()
        let expected = Set(entries.map { $0.path }).subtracting(["/dir/a.txt"])
        XCTAssertEqual(paths, expected)
    }

    func testInvertSelectionOnEmptySelectionMarksEverything() async throws {
        let entries = makeEntries()
        await state.setEntries(entries)
        let result = await state.invertSelection()
        XCTAssertTrue(result)
        let paths = await state.getSelectedPaths()
        XCTAssertEqual(paths, Set(entries.map { $0.path }))
    }

    func testInvertSelectionExcludingDirectoriesLeavesDirMarkUntouched() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/sub") // mark the directory
        let result = await state.invertSelection(includingDirectories: false)
        XCTAssertTrue(result) // files still got toggled
        let dirStillSelected = await state.isSelected("/dir/sub")
        XCTAssertTrue(dirStillSelected) // untouched, not inverted
        // all files should now be selected (were unselected before)
        let selectedA = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(selectedA)
    }

    func testInvertSelectionExcludingDirectoriesDoesNotMarkUnmarkedDir() async throws {
        await state.setEntries(makeEntries())
        let result = await state.invertSelection(includingDirectories: false)
        XCTAssertTrue(result)
        let dirSelected = await state.isSelected("/dir/sub")
        XCTAssertFalse(dirSelected)
        let fileSelected = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(fileSelected)
    }

    func testInvertSelectionOnEmptyEntriesReturnsFalse() async throws {
        await state.setEntries([])
        let result = await state.invertSelection()
        XCTAssertFalse(result)
    }

    // MARK: - selectByMask

    func testSelectByMaskTxt() async throws {
        await state.setEntries(makeEntries())
        let count = await state.selectByMask("*.txt", includeDirectories: false)
        XCTAssertEqual(count, 2)
        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedB = await state.isSelected("/dir/b.txt")
        XCTAssertTrue(selectedA)
        XCTAssertTrue(selectedB)
    }

    func testSelectByMaskMultiPattern() async throws {
        await state.setEntries(makeEntries())
        let count = await state.selectByMask("*.c;*.h", includeDirectories: false)
        XCTAssertEqual(count, 2)
        let selectedC = await state.isSelected("/dir/c.c")
        let selectedH = await state.isSelected("/dir/d.h")
        XCTAssertTrue(selectedC)
        XCTAssertTrue(selectedH)
    }

    func testSelectByMaskExcludePattern() async throws {
        await state.setEntries(makeEntries())
        // All files except .bak
        let count = await state.selectByMask("*.*|*.bak", includeDirectories: false)
        XCTAssertEqual(count, 4) // a.txt, b.txt, c.c, d.h (not e.bak, not the dir)
        let bakSelected = await state.isSelected("/dir/e.bak")
        XCTAssertFalse(bakSelected)
        let txtSelected = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(txtSelected)
    }

    func testSelectByMaskDoesNotDoubleCount() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let count = await state.selectByMask("*.txt", includeDirectories: false)
        XCTAssertEqual(count, 1) // only b.txt newly marked
    }

    func testSelectByMaskIncludeDirectoriesTrue() async throws {
        await state.setEntries(makeEntries())
        let count = await state.selectByMask("*", includeDirectories: true)
        XCTAssertEqual(count, 6)
        let dirSelected = await state.isSelected("/dir/sub")
        XCTAssertTrue(dirSelected)
    }

    func testSelectByMaskIncludeDirectoriesFalseExcludesDir() async throws {
        await state.setEntries(makeEntries())
        let count = await state.selectByMask("*", includeDirectories: false)
        XCTAssertEqual(count, 5)
        let dirSelected = await state.isSelected("/dir/sub")
        XCTAssertFalse(dirSelected)
    }

    func testSelectByMaskNoMatches() async throws {
        await state.setEntries(makeEntries())
        let count = await state.selectByMask("*.zip", includeDirectories: false)
        XCTAssertEqual(count, 0)
    }

    // MARK: - unselectByMask

    func testUnselectByMask() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/c.c")
        let count = await state.unselectByMask("*.txt", includeDirectories: false)
        XCTAssertEqual(count, 1)
        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedC = await state.isSelected("/dir/c.c")
        XCTAssertFalse(selectedA)
        XCTAssertTrue(selectedC)
    }

    func testUnselectByMaskOnlyUnmarksAlreadyMarked() async throws {
        await state.setEntries(makeEntries())
        // b.txt not selected; only a.txt is
        let _ = await state.select("/dir/a.txt")
        let count = await state.unselectByMask("*.txt", includeDirectories: false)
        XCTAssertEqual(count, 1) // b.txt matched mask but was never marked
    }

    func testUnselectByMaskExcludePattern() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.selectAll()
        let count = await state.unselectByMask("*.*|*.bak", includeDirectories: false)
        XCTAssertEqual(count, 4)
        let bakStillSelected = await state.isSelected("/dir/e.bak")
        XCTAssertTrue(bakStillSelected)
    }

    func testUnselectByMaskIncludeDirectoriesTrue() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.selectAll()
        let count = await state.unselectByMask("*", includeDirectories: true)
        XCTAssertEqual(count, 6)
        let dirSelected = await state.isSelected("/dir/sub")
        XCTAssertFalse(dirSelected)
    }

    func testUnselectByMaskIncludeDirectoriesFalseKeepsDirMarked() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.selectAll()
        let count = await state.unselectByMask("*", includeDirectories: false)
        XCTAssertEqual(count, 5)
        let dirSelected = await state.isSelected("/dir/sub")
        XCTAssertTrue(dirSelected)
    }

    // MARK: - selectSameExtension

    func testSelectSameExtensionFromCursorFile() async throws {
        let entries = [
            SelectableEntry(path: "/dir/a.txt", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/b.txt", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/c.c", size: 1, isDirectory: false),
        ]
        await state.setEntries(entries)
        let _ = await state.setCursorIndex(0) // a.txt
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 2) // a.txt + b.txt
        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedB = await state.isSelected("/dir/b.txt")
        let selectedC = await state.isSelected("/dir/c.c")
        XCTAssertTrue(selectedA)
        XCTAssertTrue(selectedB)
        XCTAssertFalse(selectedC)
    }

    func testSelectSameExtensionDoesNotMatchDirectories() async throws {
        let entries = [
            SelectableEntry(path: "/dir/a.txt", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/sub.txt", size: -1, isDirectory: true),
        ]
        await state.setEntries(entries)
        let _ = await state.setCursorIndex(0)
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 1) // only a.txt, directory never matches
        let dirSelected = await state.isSelected("/dir/sub.txt")
        XCTAssertFalse(dirSelected)
    }

    func testSelectSameExtensionEmptyExtensionMatchesExtensionlessFiles() async throws {
        let entries = [
            SelectableEntry(path: "/dir/README", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/LICENSE", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/a.txt", size: 1, isDirectory: false),
        ]
        await state.setEntries(entries)
        let _ = await state.setCursorIndex(0) // README, no extension
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 2) // README + LICENSE
        let selectedTxt = await state.isSelected("/dir/a.txt")
        XCTAssertFalse(selectedTxt)
    }

    func testSelectSameExtensionNoOpWhenCursorOnRoot() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(-1)
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 0)
    }

    func testSelectSameExtensionNoOpWhenCursorOnDirectory() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.setCursorIndex(5) // /dir/sub, a directory
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 0)
    }

    func testSelectSameExtensionDoesNotDoubleCountAlreadyMarked() async throws {
        let entries = [
            SelectableEntry(path: "/dir/a.txt", size: 1, isDirectory: false),
            SelectableEntry(path: "/dir/b.txt", size: 1, isDirectory: false),
        ]
        await state.setEntries(entries)
        let _ = await state.select("/dir/b.txt")
        let _ = await state.setCursorIndex(0)
        let count = await state.selectSameExtension()
        XCTAssertEqual(count, 1) // only a.txt newly marked
    }

    // MARK: - Statistics

    func testGetStatistics() async throws {
        await state.setEntries(makeEntries())
        let stats = await state.getStatistics()
        XCTAssertEqual(stats.total, 6)
        XCTAssertEqual(stats.selected, 0)

        let _ = await state.select("/dir/a.txt")
        let stats2 = await state.getStatistics()
        XCTAssertEqual(stats2.selected, 1)
        XCTAssertEqual(stats2.total, 6)
    }

    func testGetStatisticsEmpty() async throws {
        let stats = await state.getStatistics()
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.selected, 0)
    }

    // MARK: - Sizes

    func testGetSelectedSizeSumsMarkedEntriesOnly() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt") // 100
        let _ = await state.select("/dir/c.c")   // 300
        let size = await state.getSelectedSize()
        XCTAssertEqual(size, 400)
    }

    func testGetSelectedSizeSkipsUnknownSizes() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt") // 100
        let _ = await state.select("/dir/sub")   // -1, unknown, skipped
        let size = await state.getSelectedSize()
        XCTAssertEqual(size, 100)
    }

    func testGetSelectedSizeEmptySelection() async throws {
        await state.setEntries(makeEntries())
        let size = await state.getSelectedSize()
        XCTAssertEqual(size, 0)
    }

    func testGetTotalSizeSumsAllKnownSizes() async throws {
        await state.setEntries(makeEntries())
        // 100 + 200 + 300 + 400 + 500 = 1500, sub (-1) skipped
        let size = await state.getTotalSize()
        XCTAssertEqual(size, 1500)
    }

    func testGetTotalSizeEmptyEntries() async throws {
        let size = await state.getTotalSize()
        XCTAssertEqual(size, 0)
    }

    func testGetTotalSizeAllUnknown() async throws {
        await state.setEntries([
            SelectableEntry(path: "/dir/sub1", size: -1, isDirectory: true),
            SelectableEntry(path: "/dir/sub2", size: -1, isDirectory: true),
        ])
        let size = await state.getTotalSize()
        XCTAssertEqual(size, 0)
    }

    // MARK: - unmarkCompleted

    func testUnmarkCompletedRemovesOnlyGivenPaths() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        let _ = await state.select("/dir/b.txt")
        let _ = await state.select("/dir/c.c")

        await state.unmarkCompleted(["/dir/a.txt", "/dir/c.c"])

        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedB = await state.isSelected("/dir/b.txt")
        let selectedC = await state.isSelected("/dir/c.c")
        XCTAssertFalse(selectedA)
        XCTAssertTrue(selectedB) // not passed, stays marked (e.g. it failed)
        XCTAssertFalse(selectedC)
    }

    func testUnmarkCompletedIgnoresUnmarkedPaths() async throws {
        await state.setEntries(makeEntries())
        // /dir/b.txt was never marked; should be a no-op for it
        await state.unmarkCompleted(["/dir/b.txt"])
        let selectedB = await state.isSelected("/dir/b.txt")
        XCTAssertFalse(selectedB)
    }

    func testUnmarkCompletedEmptyListChangesNothing() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        await state.unmarkCompleted([])
        let selectedA = await state.isSelected("/dir/a.txt")
        XCTAssertTrue(selectedA)
    }

    // MARK: - Selection History

    func testSaveAndRestoreSelectionFromHistory() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        await state.saveSelectionToHistory()
        let _ = await state.select("/dir/b.txt")

        let result = await state.restoreSelectionFromHistory()
        XCTAssertTrue(result)
        let selectedA = await state.isSelected("/dir/a.txt")
        let selectedB = await state.isSelected("/dir/b.txt")
        XCTAssertTrue(selectedA)
        XCTAssertFalse(selectedB) // restored to pre-save state
    }

    func testRestoreSelectionFromHistoryEmptyReturnsFalse() async throws {
        let result = await state.restoreSelectionFromHistory()
        XCTAssertFalse(result)
    }

    func testMultipleHistoryLevelsRestoreInLIFOOrder() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        await state.saveSelectionToHistory()
        let _ = await state.select("/dir/b.txt")
        await state.saveSelectionToHistory()
        let _ = await state.select("/dir/c.c")
        await state.saveSelectionToHistory()
        let _ = await state.select("/dir/d.h")

        let selectedD = await state.isSelected("/dir/d.h")
        XCTAssertTrue(selectedD)

        let _ = await state.restoreSelectionFromHistory()
        // restores set as of third save: {a, b, c}
        let afterFirstRestore = await state.getSelectedPaths()
        XCTAssertEqual(afterFirstRestore, ["/dir/a.txt", "/dir/b.txt", "/dir/c.c"])

        let _ = await state.restoreSelectionFromHistory()
        // restores set as of second save: {a, b}
        let afterSecondRestore = await state.getSelectedPaths()
        XCTAssertEqual(afterSecondRestore, ["/dir/a.txt", "/dir/b.txt"])

        let _ = await state.restoreSelectionFromHistory()
        // restores set as of first save: {a}
        let afterThirdRestore = await state.getSelectedPaths()
        XCTAssertEqual(afterThirdRestore, ["/dir/a.txt"])
    }

    func testMaxHistoryDepthBoundedAt50() async throws {
        await state.setEntries(makeEntries())
        for i in 0..<60 {
            let _ = await state.select("/dir/extra_\(i)")
            await state.saveSelectionToHistory()
        }
        // The oldest saves (before the 10th) should have been evicted;
        // we should still be able to pop exactly 50 times successfully.
        var successCount = 0
        while await state.restoreSelectionFromHistory() {
            successCount += 1
        }
        XCTAssertEqual(successCount, 50)
    }

    func testClearHistory() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        await state.saveSelectionToHistory()
        await state.clearHistory()
        let result = await state.restoreSelectionFromHistory()
        XCTAssertFalse(result)
    }

    func testRestoreSelectionReplacesRatherThanMerges() async throws {
        await state.setEntries(makeEntries())
        let _ = await state.select("/dir/a.txt")
        await state.saveSelectionToHistory() // saved: {a}
        let _ = await state.unselect("/dir/a.txt")
        let _ = await state.select("/dir/b.txt")
        let _ = await state.select("/dir/c.c")

        let _ = await state.restoreSelectionFromHistory()
        let paths = await state.getSelectedPaths()
        XCTAssertEqual(paths, ["/dir/a.txt"]) // b.txt/c.c from before restore are gone
    }
}
