// SPDX-License-Identifier: Apache-2.0
// TextPipeTests.swift - Sending a selection through a shell command (F-356).
//
// Real commands, not a fake process: the whole feature is "hand it to the tools the user already
// knows", so the interesting failures are the ones a real shell produces — a non-zero exit with a
// message worth showing, output larger than a pipe buffer, and a command that never finishes.

import XCTest
@testable import PCFoundation

final class TextPipeTests: XCTestCase {

    func testAFilterReplacesTheText() {
        XCTAssertEqual(TextPipe.run("sort", over: "c\nb\na\n"), .output("a\nb\nc\n"))
    }

    func testAPipelineIsRunByTheShell() {
        // The point of using a shell: what the user types has to mean what it says.
        XCTAssertEqual(TextPipe.run("tr a-z A-Z | tr -d '\\n'", over: "abc\n"), .output("ABC"))
    }

    func testStderrIsReportedAndNotPastedIntoTheDocument() {
        // The failure mode this guards: a warning on stderr replacing the user's text.
        guard case .failed(let code, let message) =
                TextPipe.run("echo 'something went wrong' >&2; exit 3", over: "keep me") else {
            return XCTFail("a non-zero exit must be reported as a failure")
        }
        XCTAssertEqual(code, 3)
        XCTAssertEqual(message, "something went wrong")
    }

    func testAMissingCommandFails() {
        guard case .failed = TextPipe.run("definitely-not-a-command-xyz", over: "x") else {
            return XCTFail("an unknown command must not look like success")
        }
    }

    func testOutputLargerThanAPipeBufferDoesNotDeadlock() {
        // Writing input and reading output happen concurrently precisely for this case: 512 KB is well
        // past a pipe buffer in both directions.
        let input = String(repeating: "abcdefgh\n", count: 60_000)
        guard case .output(let out) = TextPipe.run("cat", over: input) else {
            return XCTFail("a large round trip must succeed")
        }
        XCTAssertEqual(out.count, input.count)
    }

    func testACommandThatNeverFinishesIsStopped() {
        let started = Date()
        XCTAssertEqual(TextPipe.run("sleep 30", over: "", timeout: 2), .timedOut(seconds: 2))
        // The point is that the editor comes back, so the elapsed time matters, not only the verdict.
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testBinaryOutputIsRefusedRatherThanMangled() {
        guard case .failed(_, let message) =
                TextPipe.run("printf '\\xff\\xfe\\x00'", over: "x") else {
            return XCTFail("output that is not text must be refused")
        }
        XCTAssertTrue(message.contains("not text"), message)
    }

    func testTheWorkingDirectoryIsHonoured() {
        guard case .output(let out) = TextPipe.run("pwd", over: "", workingDirectory: "/usr") else {
            return XCTFail("pwd should succeed")
        }
        // So `wc -l < file` and other relative references resolve next to the edited file.
        XCTAssertEqual(out.trimmingCharacters(in: .whitespacesAndNewlines), "/usr")
    }
}
