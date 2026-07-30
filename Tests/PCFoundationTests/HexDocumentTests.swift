import XCTest
@testable import PCFoundation

final class HexDocumentTests: XCTestCase {
    func testOverwriteInPlace() {
        let doc = HexDocument([1, 2, 3, 4])
        doc.overwrite(at: 1, with: [9, 9])
        XCTAssertEqual(doc.bytes, [1, 9, 9, 4])
        XCTAssertTrue(doc.isModified)
    }

    func testOverwriteExtendsPastEnd() {
        let doc = HexDocument([1, 2])
        doc.overwrite(at: 1, with: [7, 8, 9])   // replaces index 1 and appends
        XCTAssertEqual(doc.bytes, [1, 7, 8, 9])
    }

    func testInsert() {
        let doc = HexDocument([1, 2, 3])
        doc.insert(at: 1, [8, 8])
        XCTAssertEqual(doc.bytes, [1, 8, 8, 2, 3])
    }

    func testDelete() {
        let doc = HexDocument([1, 2, 3, 4, 5])
        doc.delete(1..<3)
        XCTAssertEqual(doc.bytes, [1, 4, 5])
    }

    func testUndoRedoOverwrite() {
        let doc = HexDocument([1, 2, 3])
        doc.overwrite(at: 0, with: [9])
        XCTAssertEqual(doc.bytes, [9, 2, 3])
        doc.undo()
        XCTAssertEqual(doc.bytes, [1, 2, 3])
        XCTAssertFalse(doc.isModified)
        doc.redo()
        XCTAssertEqual(doc.bytes, [9, 2, 3])
    }

    func testUndoRedoInsertAndDelete() {
        let doc = HexDocument([1, 2, 3])
        doc.insert(at: 3, [4, 5])
        XCTAssertEqual(doc.bytes, [1, 2, 3, 4, 5])
        doc.delete(0..<2)
        XCTAssertEqual(doc.bytes, [3, 4, 5])
        doc.undo()                                  // undo delete
        XCTAssertEqual(doc.bytes, [1, 2, 3, 4, 5])
        doc.undo()                                  // undo insert
        XCTAssertEqual(doc.bytes, [1, 2, 3])
        XCTAssertFalse(doc.canUndo)
    }

    func testNewEditClearsRedo() {
        let doc = HexDocument([1, 2, 3])
        doc.overwrite(at: 0, with: [9])
        doc.undo()
        XCTAssertTrue(doc.canRedo)
        doc.overwrite(at: 2, with: [7])
        XCTAssertFalse(doc.canRedo)                 // a fresh edit discards the redo stack
        XCTAssertEqual(doc.bytes, [1, 2, 7])
    }

    func testNoOpEditNotRecorded() {
        let doc = HexDocument([1, 2, 3])
        doc.overwrite(at: 0, with: [1])             // same value
        XCTAssertFalse(doc.canUndo)
        XCTAssertFalse(doc.isModified)
    }

    func testClampOutOfRange() {
        let doc = HexDocument([1, 2, 3])
        doc.delete(2..<99)                          // clamped to 2..<3
        XCTAssertEqual(doc.bytes, [1, 2])
    }

    func testIsChangedTracksOverwrite() {
        let doc = HexDocument([1, 2, 3, 4])
        XCTAssertFalse(doc.isChanged(at: 1))
        doc.overwrite(at: 1, with: [9])
        XCTAssertTrue(doc.isChanged(at: 1))
        XCTAssertFalse(doc.isChanged(at: 0))
        XCTAssertFalse(doc.isChanged(at: 2))
    }

    func testIsChangedForAppendedBytes() {
        let doc = HexDocument([1, 2])
        doc.overwrite(at: 1, with: [7, 8, 9])       // index 2,3 are beyond original length
        XCTAssertTrue(doc.isChanged(at: 1))         // 2 -> 7
        XCTAssertTrue(doc.isChanged(at: 2))         // appended
        XCTAssertTrue(doc.isChanged(at: 3))         // appended
    }

    func testIsChangedClearsAfterUndo() {
        let doc = HexDocument([1, 2, 3])
        doc.overwrite(at: 0, with: [9])
        XCTAssertTrue(doc.isChanged(at: 0))
        doc.undo()
        XCTAssertFalse(doc.isChanged(at: 0))        // positional compare reflects the undo
    }

    func testMarkSavedResetsBaseline() {
        let doc = HexDocument([1, 2, 3])
        doc.overwrite(at: 0, with: [9])
        XCTAssertTrue(doc.isModified)
        doc.markSaved()
        XCTAssertFalse(doc.isModified)
        XCTAssertFalse(doc.isChanged(at: 0))
    }
}
