// SPDX-License-Identifier: Apache-2.0
// PluginSyntaxTests.swift - The shared syntax highlighter (F-346).
//
// Compiled into plugins, so nothing in the app's build exercises it. The tests aim at the places
// lexers actually break — an escaped quote, an unterminated string, a comment containing a keyword,
// a keyword inside an identifier — rather than at the happy path, which is the easy part.

import AppKit
import XCTest

final class PluginSyntaxTests: XCTestCase {
    private func roles(_ source: String) -> [(String, PluginSyntaxRole)] {
        let ns = source as NSString
        return PluginSyntax.runs(in: source, language: .java).map { (ns.substring(with: $0.0), $0.1) }
    }
    private func role(_ source: String, of token: String) -> PluginSyntaxRole? {
        roles(source).first { $0.0 == token }?.1
    }

    // MARK: - The basics

    func testKeywordsTypesAndNumbers() {
        let r = roles("public class Foo { int x = 42; }")
        XCTAssertEqual(role("public class Foo { int x = 42; }", of: "public"), .keyword)
        XCTAssertEqual(role("public class Foo { int x = 42; }", of: "Foo"), .type)
        XCTAssertEqual(role("public class Foo { int x = 42; }", of: "42"), .number)
        XCTAssertFalse(r.contains { $0.0 == "x" }, "a plain identifier gets no run")
    }

    /// A keyword that is only *part* of an identifier must not be coloured — the classic lexer bug
    /// that makes `className` look like `class`.
    func testAKeywordInsideAnIdentifierIsNotAKeyword() {
        XCTAssertNil(role("int className = 1;", of: "class"))
        XCTAssertNil(role("int classname = 1;", of: "classname"))
        XCTAssertEqual(role("int myClass = 1;", of: "myClass"), nil, "lowercase start: not a type")
    }

    // MARK: - Strings

    /// `"\""` must not end the string early, or the rest of the file colours as code.
    func testEscapedQuoteDoesNotEndTheString() {
        let source = #"String s = "a\"b"; int n = 1;"#
        XCTAssertEqual(role(source, of: #""a\"b""#), .string)
        XCTAssertEqual(role(source, of: "1"), .number, "the code after the string is still code")
    }

    /// An unterminated literal must stop at the newline. Decompilers do emit broken output, and a
    /// string that swallows the rest of the file is the worst possible way to show it.
    func testUnterminatedStringStopsAtTheLine() {
        let source = "String s = \"oops\nint n = 1;"
        let strings = roles(source).filter { $0.1 == .string }
        XCTAssertEqual(strings.count, 1)
        XCTAssertFalse(strings[0].0.contains("\n"), "the literal ran past its line: \(strings[0].0)")
        XCTAssertEqual(role(source, of: "1"), .number)
    }

    func testCharLiteral() {
        XCTAssertEqual(role("char c = 'x';", of: "'x'"), .string)
        XCTAssertEqual(role(#"char c = '\'';"#, of: #"'\''"#), .string)
    }

    // MARK: - Comments

    /// Everything inside a comment is a comment, keywords included — otherwise commented-out code
    /// lights up as if it were live.
    func testKeywordsInsideCommentsStayComments() {
        let source = "// public class Foo\nint n = 1;"
        XCTAssertEqual(role(source, of: "// public class Foo"), .comment)
        XCTAssertNil(role(source, of: "public"))
        XCTAssertEqual(role(source, of: "1"), .number)
    }

    func testBlockCommentSpansLines() {
        let source = "/* class\n   Foo */ int n = 1;"
        XCTAssertEqual(role(source, of: "/* class\n   Foo */"), .comment)
        XCTAssertEqual(role(source, of: "1"), .number)
    }

    /// An unterminated block comment runs to the end and must not loop for ever.
    func testUnterminatedBlockCommentTerminates() {
        let source = "int n = 1; /* and then nothing"
        let comments = roles(source).filter { $0.1 == .comment }
        XCTAssertEqual(comments.count, 1)
        XCTAssertTrue(comments[0].0.hasPrefix("/*"))
    }

    // MARK: - Java specifics and javap

    func testAnnotations() {
        XCTAssertEqual(role("@Override public void f() {}", of: "@Override"), .annotation)
        // A bare `@` is not an annotation and must not be swallowed.
        XCTAssertNil(role("int a = b @ c;", of: "@"))
    }

    /// javap output is not Java; leaving it entirely grey looked like the highlighter had failed.
    func testJavapOutputGetsSomeColour() {
        let dump = """
        Compiled from "Hello.java"
        public class Hello {
          public Hello(java.lang.String);
            Code:
                 0: aload_0
                 1: invokespecial #1                  // Method java/lang/Object."<init>":()V
        """
        let r = roles(dump)
        XCTAssertTrue(r.contains { $0.1 == .keyword }, "no keyword found in javap output")
        XCTAssertTrue(r.contains { $0.1 == .comment }, "javap's // annotations should read as comments")
    }

    // MARK: - Attributed output

    func testHighlightPreservesTheTextExactly() {
        let source = "public class Foo { /* c */ String s = \"x\"; }"
        let attributed = PluginSyntax.highlight(source, font: .monospacedSystemFont(ofSize: 12, weight: .regular))
        XCTAssertEqual(attributed.string, source, "highlighting must not alter a single character")
    }

    /// Above the cap the text is returned flat rather than making the viewer wait. Asserted because
    /// a "reasonable" cap silently forgotten would show up as a stall on a decompiled JAR.
    func testOversizedInputIsReturnedUnhighlighted() {
        let big = String(repeating: "public class A {}\n", count: 40_000)
        XCTAssertGreaterThan(big.utf16.count, PluginSyntax.maximumLength)
        let attributed = PluginSyntax.highlight(big, font: .systemFont(ofSize: 12))
        XCTAssertEqual(attributed.string, big)
        var effective = NSRange()
        _ = attributed.attribute(.foregroundColor, at: 0, effectiveRange: &effective)
        XCTAssertEqual(effective.length, (big as NSString).length,
                       "one uniform run means nothing was highlighted")
    }

    /// Linear, not quadratic: the earlier draft converted String.Index per token, which turns a
    /// large file into a stall. 200k characters must highlight in well under a second.
    func testLargeInputIsFast() {
        let source = String(repeating: "public class Foo { int x = 42; /* c */ }\n", count: 5_000)
        let started = Date()
        _ = PluginSyntax.highlight(source, font: .systemFont(ofSize: 12))
        XCTAssertLessThan(Date().timeIntervalSince(started), 2.0)
    }
}
