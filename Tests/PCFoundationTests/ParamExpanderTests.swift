// SPDX-License-Identifier: Apache-2.0
// ParamExpanderTests - Unit tests for ParamExpander

import XCTest
@testable import PCFoundation

final class ParamExpanderTests: XCTestCase {

    /// Simple reference-type counter used to verify how many times a
    /// `listFile` closure was invoked, since the closure itself is not
    /// escaping past the synchronous `expand` call.
    private final class CallCounter {
        var count = 0
    }

    // MARK: - Individual tokens

    func testExpand_sourceDir_P() {
        let context = ParamContext(sourceDir: "/Users/max/src")
        XCTAssertEqual(ParamExpander.expand("%P", context: context), "/Users/max/src")
    }

    func testExpand_cursorName_N() {
        let context = ParamContext(cursorName: "file.txt")
        XCTAssertEqual(ParamExpander.expand("%N", context: context), "file.txt")
    }

    func testExpand_targetDir_T() {
        let context = ParamContext(targetDir: "/Users/max/dst")
        XCTAssertEqual(ParamExpander.expand("%T", context: context), "/Users/max/dst")
    }

    func testExpand_targetName_M() {
        let context = ParamContext(targetName: "other.txt")
        XCTAssertEqual(ParamExpander.expand("%M", context: context), "other.txt")
    }

    func testExpand_literalPercent() {
        XCTAssertEqual(ParamExpander.expand("%%", context: ParamContext()), "%")
    }

    // MARK: - %S selected names

    func testExpand_selectedNames_S_zero() {
        let context = ParamContext(selectedNames: [])
        XCTAssertEqual(ParamExpander.expand("%S", context: context), "")
    }

    func testExpand_selectedNames_S_single() {
        let context = ParamContext(selectedNames: ["a.txt"])
        XCTAssertEqual(ParamExpander.expand("%S", context: context), "a.txt")
    }

    func testExpand_selectedNames_S_several() {
        let context = ParamContext(selectedNames: ["a.txt", "b.txt", "c.txt"])
        XCTAssertEqual(ParamExpander.expand("%S", context: context), "a.txt b.txt c.txt")
    }

    // MARK: - Quoting when a value contains whitespace

    func testExpand_quotingWhenSingleTokenHasSpaces() {
        let context = ParamContext(sourceDir: "/Users/max/My Documents")
        XCTAssertEqual(ParamExpander.expand("%P", context: context), "\"/Users/max/My Documents\"")
    }

    func testExpand_noQuotingWhenValueHasNoSpaces() {
        let context = ParamContext(cursorName: "file.txt")
        XCTAssertEqual(ParamExpander.expand("%N", context: context), "file.txt")
    }

    func testExpand_selectedNames_S_quotesOnlyNamesWithSpaces() {
        let context = ParamContext(selectedNames: ["a.txt", "b c.txt", "d.txt"])
        XCTAssertEqual(ParamExpander.expand("%S", context: context), "a.txt \"b c.txt\" d.txt")
    }

    // MARK: - Mixed literal templates

    func testExpand_realisticTemplateMixingLiterals() {
        let context = ParamContext(sourceDir: "/src", cursorName: "file.txt", targetDir: "/dst")
        let result = ParamExpander.expand("-flag %P%N -o \"%T\"", context: context)
        XCTAssertEqual(result, "-flag /srcfile.txt -o \"/dst\"")
    }

    func testExpand_percentPercentDone() {
        XCTAssertEqual(ParamExpander.expand("100%%done", context: ParamContext()), "100%done")
    }

    // MARK: - Unknown tokens and end-of-string '%'

    func testExpand_unknownTokenPassedThroughVerbatim() {
        let result = ParamExpander.expand("cmd %X test", context: ParamContext())
        XCTAssertEqual(result, "cmd %X test")
    }

    func testExpand_percentAtEndOfString() {
        XCTAssertEqual(ParamExpander.expand("abc%", context: ParamContext()), "abc%")
    }

    // MARK: - Case-insensitivity

    func testExpand_caseInsensitivity_lowercaseMatchesUppercase() {
        let context = ParamContext(sourceDir: "/Users/max/src")
        let lower = ParamExpander.expand("%p", context: context)
        let upper = ParamExpander.expand("%P", context: context)
        XCTAssertEqual(lower, upper)
        XCTAssertEqual(lower, "/Users/max/src")
    }

    // MARK: - List-file tokens (%L/%F/%D/%W)

    func testExpand_listFileToken_providedClosure_fullPaths() {
        let counter = CallCounter()
        let result = ParamExpander.expand("%L", context: ParamContext()) { kind in
            counter.count += 1
            XCTAssertEqual(kind, .fullPaths)
            return "/tmp/l.txt"
        }
        XCTAssertEqual(result, "/tmp/l.txt")
        XCTAssertEqual(counter.count, 1)
    }

    func testExpand_listFileToken_repeatedTokenIsCached() {
        let counter = CallCounter()
        let result = ParamExpander.expand("%L %L", context: ParamContext()) { _ in
            counter.count += 1
            return "/tmp/l.txt"
        }
        XCTAssertEqual(result, "/tmp/l.txt /tmp/l.txt")
        XCTAssertEqual(counter.count, 1, "the closure should only be invoked once per distinct ListFileKind")
    }

    func testExpand_listFileToken_distinctKindsEachCallOnce() {
        var seenKinds: [ListFileKind] = []
        let result = ParamExpander.expand("%L %F %D %W", context: ParamContext()) { kind in
            seenKinds.append(kind)
            switch kind {
            case .fullPaths: return "/tmp/full.txt"
            case .names: return "/tmp/names.txt"
            case .dosNames: return "/tmp/dos.txt"
            case .withoutPath: return "/tmp/nopath.txt"
            }
        }
        XCTAssertEqual(result, "/tmp/full.txt /tmp/names.txt /tmp/dos.txt /tmp/nopath.txt")
        XCTAssertEqual(seenKinds, [.fullPaths, .names, .dosNames, .withoutPath])
    }

    func testExpand_listFileToken_nilClosureExpandsToEmpty() {
        let result = ParamExpander.expand("[%L]", context: ParamContext(), listFile: nil)
        XCTAssertEqual(result, "[]")
    }

    func testExpand_listFileToken_quotesPathWithSpaces() {
        let result = ParamExpander.expand("%L", context: ParamContext()) { _ in
            "/tmp/my list.txt"
        }
        XCTAssertEqual(result, "\"/tmp/my list.txt\"")
    }
}
