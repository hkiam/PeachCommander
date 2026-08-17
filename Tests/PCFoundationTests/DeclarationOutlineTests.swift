// SPDX-License-Identifier: Apache-2.0
// DeclarationOutlineTests.swift - The symbol outline for languages with no tree-sitter grammar (F-405).
//
// Three properties are worth testing here, and they are the three ways a scanner like this fails:
//
//   1. The offsets. An entry that jumps to the wrong place is worse than no entry, so every name is
//      checked by reading the text back at the location the node recorded — the same discipline
//      StructureOutlineTests applies.
//   2. What is *not* found. A declaration keyword inside a comment or a string must not become an entry;
//      that is what the masking pass is for, and a mask that silently stops working looks like nothing at
//      all until a file full of `// TODO: class Foo` produces junk.
//   3. The nesting. A method has to end up under its type, or the sidebar is a flat list with extra steps.

import XCTest
@testable import PCFoundation

final class DeclarationOutlineTests: XCTestCase {

    /// The source text at a node's recorded location — what clicking the entry would select.
    private func text(_ source: String, at node: SymbolNode) -> String {
        (source as NSString).substring(with: NSRange(location: node.utf16Location, length: node.name.utf16.count))
    }

    /// Assert that every node in the tree points at its own name in the source.
    private func assertOffsetsPointAtNames(_ source: String, _ nodes: [SymbolNode],
                                          file: StaticString = #filePath, line: UInt = #line) {
        for node in nodes {
            XCTAssertEqual(text(source, at: node), node.name,
                           "offset of \(node.kind) \(node.name) does not point at its name",
                           file: file, line: line)
            assertOffsetsPointAtNames(source, node.children, file: file, line: line)
        }
    }

    private func names(_ nodes: [SymbolNode]) -> [String] { nodes.map(\.name) }

    // MARK: - Swift (the language this app is written in, and the one that had no outline)

    private let swiftSource = """
    import Foundation

    public protocol Greeter {
        func greet(_ name: String) -> String
    }

    public struct Machine: Greeter {
        let id: Int
        public init(id: Int) { self.id = id }
        public func greet(_ name: String) -> String { "hi \\(name)" }
        private func secret() {}
    }

    extension Machine: CustomStringConvertible {
        func describeTwice() -> String { "x" }
    }

    enum Mode { case fast, slow }
    actor Counter { func bump() {} }
    typealias Handler = (Int) -> Void
    func topLevel() {}
    """

    func testSwiftTopLevelDeclarations() {
        let roots = DeclarationOutline.parse(swiftSource, ext: "swift")
        XCTAssertEqual(names(roots), ["Greeter", "Machine", "Machine", "Mode", "Counter", "Handler", "topLevel"])
        XCTAssertEqual(roots.map(\.kind),
                       ["protocol", "struct", "extension", "enum", "class", "type", "function"])
        assertOffsetsPointAtNames(swiftSource, roots)
    }

    func testSwiftMembersNestUnderTheirType() {
        let roots = DeclarationOutline.parse(swiftSource, ext: "swift")
        let machine = roots[1]
        XCTAssertEqual(names(machine.children), ["init", "greet", "secret"])
        // Inside a type they are methods, not functions — that is the difference the sidebar's tag shows.
        XCTAssertEqual(machine.children.map(\.kind), ["method", "method", "method"])
        // A one-line body must not swallow the declarations after it: `init(id:)` closes on its own line.
        XCTAssertEqual(names(roots[2].children), ["describeTwice"])
        XCTAssertEqual(roots[0].children.map(\.name), ["greet"])   // a protocol requirement
    }

    func testSwiftFileScopeFunctionIsAFunctionAndNotAMethod() {
        let roots = DeclarationOutline.parse(swiftSource, ext: "swift")
        XCTAssertEqual(roots.last?.kind, "function")
        XCTAssertEqual(roots.last?.name, "topLevel")
    }

    func testSwiftLineNumbersAreOneBased() {
        let roots = DeclarationOutline.parse(swiftSource, ext: "swift")
        XCTAssertEqual(roots[0].line, 3)                  // `public protocol Greeter {`
        XCTAssertEqual(roots[1].children[0].line, 9)      // `public init(id: Int)`
    }

    func testEnclosingPathFindsTheMethodAndItsType() {
        // What the breadcrumb in the status line is built from, and it only works if `start`/`end` span
        // the declaration's body rather than just its first line.
        let roots = DeclarationOutline.parse(swiftSource, ext: "swift")
        let secret = roots[1].children[2]
        let path = SymbolTree.enclosingPath(roots, utf16: secret.utf16LocationForTest)
        XCTAssertEqual(path.map(\.name), ["Machine", "secret"])
    }

    // MARK: - Comments and strings (the masking pass)

    func testDeclarationKeywordsInCommentsAndStringsAreIgnored() {
        let source = """
        // class Commented
        /* struct Blocked
           func alsoBlocked() {} */
        let sql = "class InAString"
        let doc = \"\"\"
        class InAMultilineString
        \"\"\"
        func real() {}
        """
        let roots = DeclarationOutline.parse(source, ext: "swift")
        XCTAssertEqual(names(roots), ["real"])
    }

    func testABraceInsideAStringDoesNotShiftTheNesting() {
        // The reason strings are masked and not merely skipped for matching: an unbalanced brace in a
        // string literal would nest everything after it under the wrong parent.
        let source = """
        struct A {
            func opener() { print("{") }
        }
        func after() {}
        """
        let roots = DeclarationOutline.parse(source, ext: "swift")
        XCTAssertEqual(names(roots), ["A", "after"])
        XCTAssertEqual(names(roots[0].children), ["opener"])
    }

    func testAnUnterminatedQuoteDoesNotSwallowTheRestOfTheFile() {
        let source = """
        let broken = "oops
        func stillFound() {}
        """
        XCTAssertEqual(names(DeclarationOutline.parse(source, ext: "swift")), ["stillFound"])
    }

    // MARK: - Go

    func testGoFunctionsMethodsAndTypes() {
        let source = """
        package main

        type Machine struct {
            ID int
        }

        type Greeter interface {
            Greet(name string) string
        }

        func (m *Machine) Greet(name string) string {
            return "hi " + name
        }

        func main() {}
        """
        let roots = DeclarationOutline.parse(source, ext: "go")
        XCTAssertEqual(names(roots), ["Machine", "Greeter", "Greet", "main"])
        XCTAssertEqual(roots.map(\.kind), ["struct", "interface", "method", "function"])
        // The receiver must not be mistaken for the name — the bug the receiver rule exists to avoid.
        XCTAssertFalse(names(roots).contains("m"))
        assertOffsetsPointAtNames(source, roots)
    }

    // MARK: - Ruby (indentation nesting, because counting `end` needs a parser)

    func testRubyNestsByIndentation() {
        let source = """
        module Billing
          class Invoice
            def total
              1
            end

            def self.build
              new
            end
          end
        end

        def helper
        end
        """
        let roots = DeclarationOutline.parse(source, ext: "rb")
        XCTAssertEqual(names(roots), ["Billing", "helper"])
        XCTAssertEqual(names(roots[0].children), ["Invoice"])
        XCTAssertEqual(names(roots[0].children[0].children), ["total", "build"])
        // `def self.build` is the class method — the name shown is the one after the dot.
        XCTAssertEqual(roots[0].children[0].children[1].kind, "method")
        XCTAssertEqual(roots[1].kind, "function")   // top level: a function, not a method
        assertOffsetsPointAtNames(source, roots)
    }

    // MARK: - Shell and SQL (flat by nature)

    func testShellFunctionsBothForms() {
        let source = """
        #!/bin/sh
        # deploy things
        build() {
            echo building
        }

        function publish {
            echo publishing
        }
        """
        let roots = DeclarationOutline.parse(source, ext: "sh")
        XCTAssertEqual(names(roots), ["build", "publish"])
        assertOffsetsPointAtNames(source, roots)
    }

    func testSQLObjectsInEitherCase() {
        let source = """
        -- schema
        CREATE TABLE IF NOT EXISTS users (id INT);
        create or replace view active_users as select * from users;
        CREATE OR REPLACE FUNCTION bump() RETURNS void AS $$ BEGIN END $$;
        """
        let roots = DeclarationOutline.parse(source, ext: "sql")
        XCTAssertEqual(names(roots), ["users", "active_users", "bump"])
        XCTAssertEqual(roots.map(\.kind), ["struct", "type", "function"])
        assertOffsetsPointAtNames(source, roots)
    }

    // MARK: - The other brace languages

    func testKotlinClassAndFunctions() {
        let source = """
        package app

        class Machine(val id: Int) {
            fun greet(name: String) = "hi"
        }

        object Registry {
            fun register() {}
        }

        fun main() {}
        """
        let roots = DeclarationOutline.parse(source, ext: "kt")
        XCTAssertEqual(names(roots), ["Machine", "Registry", "main"])
        XCTAssertEqual(names(roots[0].children), ["greet"])
        XCTAssertEqual(roots[1].kind, "object")
        XCTAssertEqual(roots[2].kind, "function")
    }

    func testPHPClassAndFunctions() {
        let source = """
        <?php
        namespace App;

        interface Greeter { public function greet(): string; }

        class Machine implements Greeter {
            public function greet(): string { return "hi"; }
        }

        function helper() {}
        """
        let roots = DeclarationOutline.parse(source, ext: "php")
        XCTAssertEqual(names(roots), ["Greeter", "Machine", "helper"])
        XCTAssertEqual(names(roots[1].children), ["greet"])
    }

    func testObjectiveCInterfaceAndMethods() {
        let source = """
        #import <Foundation/Foundation.h>

        @interface Machine : NSObject
        - (NSString *)greet:(NSString *)name;
        @end

        @implementation Machine
        - (NSString *)greet:(NSString *)name {
            return @"hi";
        }
        @end
        """
        let roots = DeclarationOutline.parse(source, ext: "m")
        // Both halves are the same class; the outline lists them as they appear, as Xcode does.
        XCTAssertEqual(names(roots), ["Machine", "Machine"])
        // `@interface` opens no brace, so brace nesting left every method a sibling of its class. This is
        // what the `@end`-terminated nesting mode exists for.
        XCTAssertEqual(names(roots[0].children), ["greet"])
        XCTAssertEqual(names(roots[1].children), ["greet"])
        XCTAssertEqual(roots[0].children.first?.kind, "method")
    }

    func testCppNamespaceClassAndFunctionsWithoutTheControlKeywords() {
        let source = """
        namespace app {

        class Machine {
        public:
            void greet() {
                if (true) {
                    return;
                }
                for (int i = 0; i < 3; ++i) {}
            }
        };

        int main(int argc, char **argv) {
            while (false) {}
            return 0;
        }

        }
        """
        let roots = DeclarationOutline.parse(source, ext: "cpp")
        XCTAssertEqual(names(roots), ["app"])
        XCTAssertEqual(names(roots[0].children), ["Machine", "main"])
        XCTAssertEqual(names(roots[0].children[0].children), ["greet"])
        // A function in a namespace is a function; only a *type* makes one a method.
        XCTAssertEqual(roots[0].children.map(\.kind), ["class", "function"])
        XCTAssertEqual(roots[0].children[0].children[0].kind, "method")
        // The whole point of the keyword exclusion: no entries called if/for/while.
        let all = roots.flatMap { [$0] + $0.children.flatMap { [$0] + $0.children } }.map(\.name)
        for keyword in ["if", "for", "while", "return"] { XCTAssertFalse(all.contains(keyword)) }
    }

    func testTsxComponentsAndArrowFunctions() {
        let source = """
        interface Props { title: string }

        export const Button = (props: Props) => {
            return <button>{props.title}</button>;
        };

        export function useThing() {}

        type Alias = string;
        """
        let roots = DeclarationOutline.parse(source, ext: "tsx")
        XCTAssertEqual(names(roots), ["Props", "Button", "useThing", "Alias"])
    }

    func testLuaModuleFunctions() {
        let source = """
        local M = {}

        function M.save(path)
        end

        local function helper()
        end

        return M
        """
        let roots = DeclarationOutline.parse(source, ext: "lua")
        XCTAssertEqual(names(roots), ["save", "helper"])
    }

    // MARK: - CSS (the one language whose entries are selectors rather than identifiers)

    func testCssSelectorsAndAtRules() {
        let source = """
        /* theme */
        :root {
            --bg: white;
        }

        .card > .title:hover {
            background: url(http://example.com/x.png);
        }

        @media (max-width: 600px) {
            .card { display: none; }
        }
        """
        let roots = DeclarationOutline.parse(source, ext: "css")
        XCTAssertEqual(names(roots), [":root", ".card > .title:hover", "@media (max-width: 600px)"])
        // An at-rule nests what it contains, in plain CSS as well as in the preprocessors.
        XCTAssertEqual(names(roots[2].children), [".card"])
        XCTAssertEqual(roots[2].kind, "module")
        assertOffsetsPointAtNames(source, roots)
    }

    func testCssDoesNotTreatADoubleSlashAsAComment() {
        // `//` is not a comment in CSS, and treating it as one eats the rest of any line with a URL in it
        // — including the closing brace, which would then nest everything that follows under this rule.
        let source = """
        .a { background: url(http://example.com/x.png); }
        .b { color: red; }
        """
        XCTAssertEqual(names(DeclarationOutline.parse(source, ext: "css")), [".a", ".b"])
    }

    func testScssNestsSelectorsAndTakesDoubleSlashComments() {
        let source = """
        // nested
        .card {
            &:hover { color: red; }
            .title { font-weight: bold; }
        }
        """
        let roots = DeclarationOutline.parse(source, ext: "scss")
        XCTAssertEqual(names(roots), [".card"])
        XCTAssertEqual(names(roots[0].children), ["&:hover", ".title"])
    }

    // MARK: - Markdown (headings, which is what a long README is navigated by)

    func testMarkdownHeadingsNestByLevel() {
        let source = """
        # PeachCommander

        Intro text.

        ## Building

        ### Requirements

        ## Testing
        """
        let roots = DeclarationOutline.parse(source, ext: "md")
        XCTAssertEqual(names(roots), ["PeachCommander"])
        XCTAssertEqual(names(roots[0].children), ["Building", "Testing"])
        XCTAssertEqual(names(roots[0].children[0].children), ["Requirements"])
        XCTAssertEqual(roots[0].kind, "heading")
        assertOffsetsPointAtNames(source, roots)
    }

    func testMarkdownIgnoresHashesInsideFencedCode() {
        // The case that makes or breaks a Markdown outline: a shell or Python block in a README is full of
        // lines starting with `#`, and every one of them would otherwise be a heading.
        let source = """
        # Title

        ```sh
        # this is a shell comment
        ## and so is this
        ```

        ~~~python
        # nor this
        ~~~

        ## Real Section
        """
        let roots = DeclarationOutline.parse(source, ext: "md")
        XCTAssertEqual(names(roots), ["Title"])
        XCTAssertEqual(names(roots[0].children), ["Real Section"])
    }

    func testMarkdownUnderlinedHeadings() {
        let source = """
        Setext Title
        ============

        Sub
        ---
        """
        let roots = DeclarationOutline.parse(source, ext: "md")
        XCTAssertEqual(names(roots), ["Setext Title"])
        XCTAssertEqual(names(roots[0].children), ["Sub"])
        // The offset must point at the title line, not at the underline.
        XCTAssertEqual(roots[0].line, 1)
        XCTAssertEqual(roots[0].children[0].line, 4)
        assertOffsetsPointAtNames(source, roots)
    }

    func testMarkdownClosedAtxHeadingKeepsNoTrailingHashes() {
        XCTAssertEqual(names(DeclarationOutline.parse("## Title ##", ext: "md")), ["Title"])
    }

    func testMarkdownDoesNotTreatSevenHashesAsAHeading() {
        // Six is the limit; `#######` is a paragraph, and reading it as a heading would nest the document
        // under something a Markdown renderer does not show at all.
        XCTAssertTrue(DeclarationOutline.parse("####### not a heading", ext: "md").isEmpty)
    }

    // MARK: - PowerShell, R, Haskell, Elixir, Groovy

    func testPowerShellFunctionsClassesAndMethods() {
        let source = """
        function Get-Thing {
            param($x)
            if ($x) { return $x }
        }

        class Machine {
            [string] Greet() { return "hi" }
        }

        enum Mode { Fast }
        """
        let roots = DeclarationOutline.parse(source, ext: "ps1")
        XCTAssertEqual(names(roots), ["Get-Thing", "Machine", "Mode"])
        // The hyphen is part of a PowerShell name — a Verb-Noun cut at the hyphen is the wrong name.
        XCTAssertEqual(roots[0].name, "Get-Thing")
        XCTAssertEqual(names(roots[1].children), ["Greet"])
        XCTAssertFalse(names(roots).contains("if"))
        assertOffsetsPointAtNames(source, roots)
    }

    func testRFunctionsByBothAssignmentOperators() {
        let source = """
        # analysis
        plot.data <- function(df) {
          summary(df)
        }
        helper = function(x) x + 1
        """
        let roots = DeclarationOutline.parse(source, ext: "r")
        // Dots belong to R names: cutting at the dot would report "plot".
        XCTAssertEqual(names(roots), ["plot.data", "helper"])
        assertOffsetsPointAtNames(source, roots)
    }

    func testHaskellModuleTypesAndSignatures() {
        let source = """
        module Billing.Invoice (total) where

        data Invoice = Invoice { total :: Int }
        newtype Cents = Cents Int
        class Payable a where
        instance Payable Invoice where
        render :: Invoice -> String
        render i = show (total i)
        """
        let roots = DeclarationOutline.parse(source, ext: "hs")
        XCTAssertEqual(names(roots), ["Billing.Invoice", "Invoice", "Cents", "Payable", "Payable", "render"])
        XCTAssertEqual(roots.map(\.kind),
                       ["module", "struct", "struct", "interface", "object", "function"])
        // Listed once, by its type signature: the equation below it must not add a second entry.
        XCTAssertEqual(names(roots).filter { $0 == "render" }.count, 1)
        assertOffsetsPointAtNames(source, roots)
    }

    func testElixirModuleAndFunctions() {
        let source = """
        defmodule MyApp.Repo do
          defstruct [:id]

          def all(query) do
            query
          end

          defp helper(x), do: x
        end
        """
        let roots = DeclarationOutline.parse(source, ext: "ex")
        XCTAssertEqual(names(roots), ["MyApp.Repo"])
        // No `defstruct` entry: it has no name of its own.
        XCTAssertEqual(names(roots[0].children), ["all", "helper"])
        XCTAssertEqual(roots[0].children.map(\.kind), ["method", "method"])
        assertOffsetsPointAtNames(source, roots)
    }

    func testGroovyClassAndMethods() {
        let source = """
        class Build {
            def run(String name) {
                println name
            }
        }
        """
        let roots = DeclarationOutline.parse(source, ext: "gradle")
        XCTAssertEqual(names(roots), ["Build"])
        XCTAssertEqual(names(roots[0].children), ["run"])
    }

    // MARK: - Coverage and limits

    func testTheLanguagesThatWereMissingAreAllCovered() {
        // The list is the feature. If an extension is dropped from the table, the sidebar silently goes
        // blank again for that language — which is exactly how this defect went unnoticed for Swift.
        for ext in ["swift", "go", "kt", "kts", "scala", "dart", "cpp", "hpp", "cc", "m", "mm",
                    "php", "rb", "pl", "pm", "lua", "sh", "bash", "zsh", "sql", "tsx",
                    "css", "scss", "sass", "less",
                    "ps1", "psm1", "r", "groovy", "gradle", "hs", "ex", "exs",
                    "md", "markdown", "mdx"] {
            XCTAssertTrue(DeclarationOutline.supports(ext: ext), "no outline for .\(ext)")
        }
        // Not ours: these have tree-sitter grammars with tag queries, and taking them over would replace
        // a parser's answer with a scanner's.
        for ext in ["c", "h", "java", "js", "py", "rs", "cs", "ts", "json", "yaml", "xml"] {
            XCTAssertFalse(DeclarationOutline.supports(ext: ext), ".\(ext) must stay with its parser")
        }
    }

    func testAnUnknownExtensionYieldsNothingRatherThanGuessing() {
        XCTAssertTrue(DeclarationOutline.parse("func x() {}", ext: "bin").isEmpty)
    }

    func testTheNodeCountIsCapped() {
        // A generated file must not turn into an outline nobody can read out of memory nobody has.
        let source = (0..<(DeclarationOutline.nodeLimit + 500)).map { "func f\($0)() {}" }.joined(separator: "\n")
        let roots = DeclarationOutline.parse(source, ext: "swift")
        XCTAssertEqual(roots.count, DeclarationOutline.nodeLimit)
    }
}

private extension SymbolNode {
    /// The offset a caret would sit at inside this declaration — its name, which `enclosingPath` must
    /// resolve to this node.
    var utf16LocationForTest: Int { utf16Location }
}
