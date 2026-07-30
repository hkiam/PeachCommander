// CustomOperationTests.swift - The .custom OperationKind runs app-supplied work
// through the transfer queue (F-138: background pack/unpack).

import XCTest
@testable import PCOperations

final class CustomOperationTests: XCTestCase {
    func test_custom_runsAndReturnsResult() async throws {
        let out = try await TransferQueue().runToCompletion(.custom(run: { _, progress in
            progress(OpProgress(filesTotal: 2, filesDone: 2, currentItem: "x", bytesPerSecond: 0))
            return ["a", "b"]
        }))
        XCTAssertEqual(out, ["a", "b"])
    }

    func test_custom_propagatesCancellation() async {
        do {
            _ = try await TransferQueue().runToCompletion(.custom(run: { _, _ in
                throw OperationError.cancelled
            }))
            XCTFail("expected cancellation to throw")
        } catch let e as OperationError {
            XCTAssertEqual(e, .cancelled)
        } catch { XCTFail("unexpected error: \(error)") }
    }
}
