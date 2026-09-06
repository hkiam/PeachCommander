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

    // MARK: - A filter that stops reading early

    func testAFilterThatExitsBeforeReadingEverythingStillReturnsItsOutput() {
        // `head -1` is not an edge case, it is a filter people use: it takes one line and leaves. The
        // rest of the input then has nowhere to go, and `FileHandle.write(_:)` answers that by raising
        // an Objective-C exception from a background queue — which no `do/catch` at the call site can
        // catch and the process does not survive.
        //
        // Big enough that it cannot fit in a pipe buffer, or the write finishes before the tool exits
        // and the bug hides. 64 KiB is the usual buffer; this is well past it.
        let big = String(repeating: "line of text\n", count: 40_000)
        let result = TextPipe.run("head -1", over: big)
        guard case .output(let text) = result else {
            return XCTFail("expected the first line back, got \(result)")
        }
        XCTAssertEqual(text, "line of text\n")
    }

    func testAFilterThatFailsImmediatelyIsReportedRatherThanCrashing() {
        // The same shape with no output at all: /usr/bin/false exits before reading a byte. This is
        // the test that failed once in CI and never locally, which is exactly what a race looks like.
        let big = String(repeating: "x\n", count: 100_000)
        let result = TextPipe.run("false", over: big)
        guard case .failed(let code, _) = result else {
            return XCTFail("expected a failure, got \(result)")
        }
        XCTAssertNotEqual(code, 0)
    }

    // MARK: - BoundedProcess

    /// The deadline actually fires, which is the whole reason this exists: `ls` and `chmod` on a
    /// stalled network mount never return, and the ACL editor calls them on the main thread.
    func testACommandThatOutlivesTheDeadlineComesBackAsNil() {
        let started = Date()
        XCTAssertNil(BoundedProcess.run("/bin/sleep", ["30"], timeout: 1))
        // And it does not sit out the thirty seconds after giving up on them.
        XCTAssertLessThan(-started.timeIntervalSinceNow, 10)
    }

    func testOutputAndErrorComeBackSeparately() {
        let result = BoundedProcess.run("/bin/sh", ["-c", "echo out; echo err 1>&2"], timeout: 10)
        XCTAssertEqual(result?.out.trimmingCharacters(in: .whitespacesAndNewlines), "out")
        XCTAssertEqual(result?.err.trimmingCharacters(in: .whitespacesAndNewlines), "err")
    }

    /// Nil for "could not start" as well, so a caller cannot read a failure as an empty answer —
    /// which is how an unreadable ACL came to look like a file that has none.
    func testAnExecutableThatIsNotThereComesBackAsNil() {
        XCTAssertNil(BoundedProcess.run("/nonexistent/command", [], timeout: 5))
    }

    /// A path is passed as an argument and never through a shell: this name would be an injection
    /// if it were, and here it has to arrive intact.
    func testAnArgumentWithQuotesArrivesWhole() {
        let result = BoundedProcess.run("/bin/echo", ["a\"; rm -rf /; \"b"], timeout: 5)
        XCTAssertEqual(result?.out.trimmingCharacters(in: .whitespacesAndNewlines), "a\"; rm -rf /; \"b")
    }
}
