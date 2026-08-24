// SPDX-License-Identifier: Apache-2.0
// DeclarationOutline.swift - A symbol outline for languages with no tree-sitter grammar.
//
// The sidebar had two sources and a hole between them: tree-sitter tag queries (C, Java, JavaScript,
// Python, Rust, C#, TypeScript) and the JSON/YAML/XML scanner. Everything else got a blank sidebar and a
// disabled toggle — including **Swift**, which is what this app is written in, and Go, Ruby, PHP, Kotlin,
// C++, Objective-C, shell and SQL besides.
//
// Adding grammars would be the higher-fidelity answer and is not free: each vendored grammar here is a
// generated `parser.c` of several megabytes (C# alone is 31 MB) and has to be fetched, checked in and
// kept current. A scanner buys the outline for a dozen languages at once, with no dependency and no
// repository growth, and it is what most editors' "quick outline" is anyway.
//
// What it therefore is *not*: a parser. It matches declarations line by line over a copy of the text
// whose comments and string bodies have been blanked out, and nests them by brace depth (or by
// indentation for the `end`-keyword languages, where counting `end` reliably needs a parser). The
// consequences are worth stating plainly:
//
//   * A declaration split across lines — a Swift `func` whose parameter list wraps — is found by its
//     first line, which is where a reader wants to be taken anyway.
//   * One declaration per line: `object Registry { fun register() {} }` yields the object and not the
//     function. Taking the second match would mean deciding whether it is inside the first, which is the
//     brace bookkeeping this scanner does *between* lines and not within one — and a member sharing a
//     line with its container is a shape real code hardly uses.
//   * A brace inside a raw string that this scanner's masking does not understand (a Swift `#"…"#`, a
//     shell heredoc) can shift the nesting for the rest of the file. Names stay right; indentation of the
//     tree may not.
//   * C++ and Objective-C free functions are recognised by the shape "type name(args) {", which is a
//     heuristic. `catch (...) {` is excluded by keyword; a macro that expands to a signature is not.
//   * Fields, properties and local variables are deliberately skipped. An outline of a Swift file that
//     lists every `let` is a second copy of the file, not a way to navigate it.
//
// A file with a broken brace still gets an outline down to the break, which is when an outline is most
// useful — the same reason StructureOutline is a scanner.

import Foundation

public enum DeclarationOutline {
    /// How many nodes are produced at most, matching `StructureOutline.nodeLimit`: a generated
    /// half-million-line source file must not turn into an outline nobody can read.
    public static let nodeLimit = 5_000

    public static func supports(ext: String) -> Bool {
        let e = ext.lowercased()
        return grammars[e] != nil || MarkdownFileType.extensions.contains(e)
    }


    /// The language name shown for an extension this can outline (for diagnostics and status text).
    public static func displayName(ext: String) -> String? {
        let e = ext.lowercased()
        if MarkdownFileType.extensions.contains(e) { return "Markdown" }
        return grammars[e]?.name
    }

    /// Every extension with an outline, for tests and for reporting coverage.
    public static var supportedExtensions: [String] {
        (Array(grammars.keys) + MarkdownFileType.extensions).sorted()
    }

    public static func parse(_ text: String, ext: String) -> [SymbolNode] {
        // Markdown is not a declaration language and gets its own pass: its "declarations" are headings,
        // its nesting is a number rather than a brace, and its fenced code blocks are full of lines that
        // every rule table here would misread.
        if MarkdownFileType.matches(ext) { return parseMarkdown(text) }
        guard let grammar = grammars[ext.lowercased()] else { return [] }
        return scan(text, grammar: grammar)
    }

    // MARK: - Grammar model

    /// One declaration form. Capture group 1 is the name — the outline entry and the offset jumped to.
    struct Rule {
        let kind: String
        let regex: NSRegularExpression
        init(_ kind: String, _ pattern: String) {
            self.kind = kind
            // Anchored per line by the caller (`.anchorsMatchLines` is not used: each line is matched on
            // its own, so `^` in a pattern means the start of that line).
            regex = try! NSRegularExpression(pattern: pattern, options: [])
        }
    }

    /// How a language says "this block belongs to that declaration".
    enum Nesting {
        /// Curly braces: Swift, Go, C++, PHP, Kotlin, …
        case braces
        /// Leading whitespace, for the `end`-keyword languages. Counting `end` needs to know that
        /// `x = 1 if y` opens nothing, which is a parser's job; indentation is what a reader sees.
        case indent
        /// No nesting at all — shell functions and SQL objects are siblings by nature.
        case flat
        /// A container that runs until a keyword: Objective-C's `@interface … @end`. Braces cannot be
        /// used here at all — an `@interface` opens no block, so brace nesting left every method as a
        /// sibling of the class it belongs to.
        case terminated(by: String)
    }

    struct Grammar {
        let name: String
        let rules: [Rule]
        let nesting: Nesting
        let lineComments: [String]
        let blockComment: (open: String, close: String)?
        /// Delimiters that start a string whose body must be blanked out before matching.
        let strings: [Character]
        /// A triple-quoted string form, when the language has one (Swift, Kotlin, Scala, Python-ish).
        let tripleQuote: String?
    }

    /// Kinds that own the declarations nested inside them.
    private static let containerKinds: Set<String> =
        ["class", "struct", "enum", "union", "interface", "protocol", "trait", "module", "namespace",
         "extension", "object"]

    /// Containers that turn a nested `function` into a `method`, so the sidebar's tag reads "m" inside a
    /// type and "ƒ" at file scope — the distinction the tree-sitter tag queries also make.
    ///
    /// Everything above except `namespace`: a C++ function inside `namespace app` is still a function,
    /// and calling it a method would be wrong about the one thing this distinction says. Ruby's `module`
    /// stays in, because a `def` inside a module really is a method there.
    private static let methodOwners: Set<String> = containerKinds.subtracting(["namespace"])

    // MARK: - Name patterns

    /// An identifier. Deliberately conservative: ASCII plus `_`, and `$` for shell and PHP.
    private static let name = "[A-Za-z_][A-Za-z0-9_]*"

    /// The C-family "type name(args) {" function shape, with the control keywords that share it excluded.
    ///
    /// The negative lookahead is the whole reason this is usable: without it every `if (…) {` and
    /// `switch (…) {` in the file becomes a function called "if".
    private static let cLikeFunction =
        "^[^=;]*?\\b(?!if\\b|for\\b|while\\b|switch\\b|catch\\b|else\\b|do\\b|return\\b|sizeof\\b|new\\b|delete\\b|and\\b|or\\b|not\\b)"
        + "(~?[A-Za-z_][A-Za-z0-9_]*)\\s*\\([^;{]*\\)\\s*(?:const\\b|noexcept\\b|override\\b|final\\b|mutable\\b|async\\b|throws\\b|\\s)*"
        + "(?:->\\s*[^{;]+)?\\{"

    // MARK: - The languages

    private static let grammars: [String: Grammar] = {
        var map: [String: Grammar] = [:]

        // ---- Swift ----------------------------------------------------------------------------------
        // `extension` gets its own kind rather than being merged into the type it extends: Xcode lists
        // them separately, and an extension in another file has no type here to merge with.
        let swift = Grammar(
            name: "Swift",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("class", "\\bactor\\s+(\(name))"),
                Rule("struct", "\\bstruct\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(\(name))"),
                Rule("protocol", "\\bprotocol\\s+(\(name))"),
                // The extended type, dotted names included (`extension Foo.Bar`), first component named.
                Rule("extension", "\\bextension\\s+(\(name))"),
                Rule("type", "\\btypealias\\s+(\(name))"),
                Rule("function", "\\bfunc\\s+(\(name))"),
                // `init`/`deinit`/`subscript` have no name of their own; the keyword *is* the entry.
                Rule("method", "^\\s*(?:[a-z ]*\\s)?(init)\\??\\s*[(<]"),
                Rule("method", "^\\s*(?:[a-z ]*\\s)?(subscript)\\s*[(<]"),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\""], tripleQuote: "\"\"\"")
        map["swift"] = swift

        // ---- Go -------------------------------------------------------------------------------------
        // The receiver form first: `func (m *Machine) Greet()` is a method, and the plain form would
        // otherwise capture the receiver's type as the name.
        let go = Grammar(
            name: "Go",
            rules: [
                Rule("method", "^\\s*func\\s*\\([^)]*\\)\\s*(\(name))"),
                Rule("function", "^\\s*func\\s+(\(name))"),
                Rule("struct", "\\btype\\s+(\(name))\\s+struct\\b"),
                Rule("interface", "\\btype\\s+(\(name))\\s+interface\\b"),
                Rule("type", "\\btype\\s+(\(name))\\s+(?!struct\\b|interface\\b)\\S"),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\"", "`"], tripleQuote: nil)
        map["go"] = go

        // ---- Kotlin ---------------------------------------------------------------------------------
        let kotlin = Grammar(
            name: "Kotlin",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("interface", "\\binterface\\s+(\(name))"),
                Rule("object", "\\bobject\\s+(\(name))"),
                Rule("function", "\\bfun\\s+(?:<[^>]*>\\s*)?(?:\(name)\\.)?(\(name))"),
                Rule("type", "\\btypealias\\s+(\(name))"),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\""], tripleQuote: "\"\"\"")
        map["kt"] = kotlin
        map["kts"] = kotlin

        // ---- Scala ----------------------------------------------------------------------------------
        let scala = Grammar(
            name: "Scala",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("trait", "\\btrait\\s+(\(name))"),
                Rule("object", "\\bobject\\s+(\(name))"),
                Rule("function", "\\bdef\\s+(\(name))"),
                Rule("type", "\\btype\\s+(\(name))"),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\""], tripleQuote: "\"\"\"")
        map["scala"] = scala
        map["sc"] = scala

        // ---- C++ / Objective-C ----------------------------------------------------------------------
        // `.c` and `.h` stay with the tree-sitter C grammar, which parses them properly. These are the
        // extensions that grammar cannot do: C++ has templates and namespaces, Objective-C has `@`
        // declarations and bracketed method syntax.
        let cpp = Grammar(
            name: "C++",
            rules: [
                Rule("namespace", "\\bnamespace\\s+(\(name))"),
                Rule("class", "\\bclass\\s+(\(name))\\s*(?::|\\{|$)"),
                Rule("struct", "\\bstruct\\s+(\(name))\\s*(?::|\\{|$)"),
                Rule("union", "\\bunion\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(?:class\\s+|struct\\s+)?(\(name))"),
                Rule("function", cLikeFunction),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\""], tripleQuote: nil)
        for e in ["cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "ipp", "inl"] { map[e] = cpp }

        let objc = Grammar(
            name: "Objective-C",
            rules: [
                Rule("class", "^\\s*@(?:interface|implementation)\\s+(\(name))"),
                Rule("protocol", "^\\s*@protocol\\s+(\(name))"),
                // `- (void)doThing:(id)x` — the first selector piece is the name people search for.
                Rule("method", "^\\s*[-+]\\s*\\([^)]*\\)\\s*(\(name))"),
                Rule("function", cLikeFunction),
            ],
            nesting: .terminated(by: "@end"), lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\""], tripleQuote: nil)
        map["m"] = objc
        map["mm"] = objc

        // ---- PHP ------------------------------------------------------------------------------------
        let php = Grammar(
            name: "PHP",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("interface", "\\binterface\\s+(\(name))"),
                Rule("trait", "\\btrait\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(\(name))"),
                Rule("function", "\\bfunction\\s+&?\\s*(\(name))"),
            ],
            nesting: .braces, lineComments: ["//", "#"], blockComment: ("/*", "*/"),
            strings: ["\"", "'"], tripleQuote: nil)
        map["php"] = php
        map["phtml"] = php

        // ---- Dart -----------------------------------------------------------------------------------
        let dart = Grammar(
            name: "Dart",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("trait", "\\bmixin\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(\(name))"),
                Rule("extension", "\\bextension\\s+(\(name))"),
                Rule("type", "\\btypedef\\s+(\(name))"),
                Rule("function", cLikeFunction),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\"", "'"], tripleQuote: "'''")
        map["dart"] = dart

        // ---- Ruby -----------------------------------------------------------------------------------
        let ruby = Grammar(
            name: "Ruby",
            rules: [
                Rule("class", "^\\s*class\\s+(\(name))"),
                Rule("module", "^\\s*module\\s+(\(name))"),
                // `def self.build` is a class method; the name after the dot is the one to show.
                Rule("function", "^\\s*def\\s+(?:self\\.)?(\(name))"),
            ],
            nesting: .indent, lineComments: ["#"], blockComment: nil,
            strings: ["\"", "'"], tripleQuote: nil)
        map["rb"] = ruby
        map["rake"] = ruby
        map["gemspec"] = ruby

        // ---- Perl -----------------------------------------------------------------------------------
        let perl = Grammar(
            name: "Perl",
            rules: [
                Rule("module", "^\\s*package\\s+([A-Za-z_][A-Za-z0-9_:]*)"),
                Rule("function", "^\\s*sub\\s+(\(name))"),
            ],
            nesting: .flat, lineComments: ["#"], blockComment: nil,
            strings: ["\"", "'"], tripleQuote: nil)
        map["pl"] = perl
        map["pm"] = perl

        // ---- Lua ------------------------------------------------------------------------------------
        // `function M.save(…)` and `function M:save(…)` are the module-table forms every Lua codebase
        // uses; the part after the separator is the name, and the table name is left out of it because
        // the outline already shows where it sits.
        let lua = Grammar(
            name: "Lua",
            rules: [
                Rule("function", "^\\s*(?:local\\s+)?function\\s+(?:[A-Za-z_][A-Za-z0-9_.]*[.:])?(\(name))"),
                Rule("function", "^\\s*(?:local\\s+)?(\(name))\\s*=\\s*function\\b"),
            ],
            nesting: .indent, lineComments: ["--"], blockComment: ("--[[", "]]"),
            strings: ["\"", "'"], tripleQuote: nil)
        map["lua"] = lua

        // ---- Shell ----------------------------------------------------------------------------------
        // Both forms POSIX and bash allow. Flat on purpose: a function defined inside another is rare
        // enough that guessing at nesting would cost more than it gains.
        let shell = Grammar(
            name: "Shell",
            rules: [
                Rule("function", "^\\s*function\\s+([A-Za-z_][A-Za-z0-9_-]*)"),
                Rule("function", "^\\s*([A-Za-z_][A-Za-z0-9_-]*)\\s*\\(\\s*\\)\\s*\\{"),
            ],
            nesting: .flat, lineComments: ["#"], blockComment: nil,
            strings: ["\"", "'"], tripleQuote: nil)
        for e in ["sh", "bash", "zsh", "ksh"] { map[e] = shell }

        // ---- SQL ------------------------------------------------------------------------------------
        // Case-insensitive because SQL is written both ways, often in the same file.
        let sql = Grammar(
            name: "SQL",
            rules: [
                Rule("struct", "(?i)\\bcreate\\s+(?:or\\s+replace\\s+)?(?:temp(?:orary)?\\s+)?table\\s+(?:if\\s+not\\s+exists\\s+)?[\"`\\[]?([A-Za-z_][A-Za-z0-9_.]*)"),
                Rule("type", "(?i)\\bcreate\\s+(?:or\\s+replace\\s+)?(?:materialized\\s+)?view\\s+(?:if\\s+not\\s+exists\\s+)?[\"`\\[]?([A-Za-z_][A-Za-z0-9_.]*)"),
                Rule("function", "(?i)\\bcreate\\s+(?:or\\s+replace\\s+)?(?:function|procedure|trigger)\\s+[\"`\\[]?([A-Za-z_][A-Za-z0-9_.]*)"),
            ],
            nesting: .flat, lineComments: ["--"], blockComment: ("/*", "*/"),
            strings: ["'"], tripleQuote: nil)
        map["sql"] = sql
        map["ddl"] = sql
        map["pgsql"] = sql

        // ---- PowerShell -----------------------------------------------------------------------------
        // Verb-Noun names contain a hyphen, which is why this cannot reuse the shared identifier pattern.
        let powershell = Grammar(
            name: "PowerShell",
            rules: [
                Rule("class", "(?i)^\\s*class\\s+([A-Za-z_][A-Za-z0-9_]*)"),
                Rule("enum", "(?i)^\\s*enum\\s+([A-Za-z_][A-Za-z0-9_]*)"),
                Rule("function", "(?i)^\\s*(?:function|filter|workflow)\\s+([A-Za-z_][A-Za-z0-9_-]*)"),
                // A method inside a `class` has no keyword at all — `[string] Greet() {` is the whole
                // declaration — so it is found by the C-family shape, which also excludes `if (…) {`.
                Rule("function", cLikeFunction),
            ],
            nesting: .braces, lineComments: ["#"], blockComment: ("<#", "#>"),
            strings: ["\"", "'"], tripleQuote: nil)
        for e in ["ps1", "psm1", "psd1"] { map[e] = powershell }

        // ---- R --------------------------------------------------------------------------------------
        // R has no declaration keyword at all: a function is a value assigned to a name, by either of two
        // assignment operators. Dots are part of names there (`plot.data`), which is why the pattern
        // spells its own identifier out.
        //
        // S4 registrations (`setClass("Machine", …)`) are deliberately absent. Their name lives inside a
        // string literal, and string bodies are blanked before matching — the pass that stops a `#` in a
        // URL from being a comment. Reading names out of strings would need that masking undone for
        // selected rules, which trades a real protection for a niche construct.
        let r = Grammar(
            name: "R",
            rules: [
                Rule("function", "^\\s*([A-Za-z._][A-Za-z0-9._]*)\\s*(?:<-|=)\\s*function\\b"),
            ],
            nesting: .braces, lineComments: ["#"], blockComment: nil,
            strings: ["\"", "'"], tripleQuote: nil)
        map["r"] = r
        map["rscript"] = r

        // ---- Groovy / Gradle ------------------------------------------------------------------------
        let groovy = Grammar(
            name: "Groovy",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("interface", "\\binterface\\s+(\(name))"),
                Rule("trait", "\\btrait\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(\(name))"),
                Rule("function", "\\bdef\\s+(\(name))\\s*\\("),
                Rule("function", cLikeFunction),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\"", "'"], tripleQuote: "\"\"\"")
        map["groovy"] = groovy
        map["gradle"] = groovy

        // ---- Haskell --------------------------------------------------------------------------------
        // Flat, because Haskell's top-level declarations all start at column 0 and its `where` blocks are
        // local detail rather than structure. A function is listed by its *type signature*, which is the
        // line a Haskell reader looks for and the only one that names the function exactly once.
        let haskell = Grammar(
            name: "Haskell",
            rules: [
                Rule("module", "^module\\s+([A-Z][A-Za-z0-9_.']*)"),
                Rule("struct", "^data\\s+([A-Z][A-Za-z0-9_']*)"),
                Rule("struct", "^newtype\\s+([A-Z][A-Za-z0-9_']*)"),
                Rule("type", "^type\\s+([A-Z][A-Za-z0-9_']*)"),
                Rule("interface", "^class\\s+(?:.*=>\\s*)?([A-Z][A-Za-z0-9_']*)"),
                Rule("object", "^instance\\s+(?:.*=>\\s*)?([A-Z][A-Za-z0-9_']*)"),
                Rule("function", "^([a-z_][A-Za-z0-9_']*)\\s*::"),
            ],
            nesting: .flat, lineComments: ["--"], blockComment: ("{-", "-}"),
            strings: ["\""], tripleQuote: nil)
        map["hs"] = haskell
        map["lhs"] = haskell

        // ---- Elixir ---------------------------------------------------------------------------------
        // Indentation, for the same reason as Ruby: the blocks end with `end`, and knowing which `end`
        // belongs to a `do` needs a parser. Module names are dotted (`MyApp.Repo`) and shown whole.
        let elixir = Grammar(
            name: "Elixir",
            rules: [
                Rule("module", "^\\s*defmodule\\s+([A-Z][A-Za-z0-9_.]*)"),
                Rule("protocol", "^\\s*defprotocol\\s+([A-Z][A-Za-z0-9_.]*)"),
                Rule("object", "^\\s*defimpl\\s+([A-Z][A-Za-z0-9_.]*)"),
                // No `defstruct`: it declares the enclosing module's shape and has no name of its own, so
                // the entry would read "defstruct" and say nothing the module entry above it does not.
                // `def name(args)`, `def name do`, `defp`, and the macro forms.
                Rule("function", "^\\s*def(?:p|macro|macrop|guard|guardp)?\\s+([a-z_][A-Za-z0-9_?!]*)"),
            ],
            nesting: .indent, lineComments: ["#"], blockComment: nil,
            strings: ["\""], tripleQuote: "\"\"\"")
        map["ex"] = elixir
        map["exs"] = elixir

        // ---- CSS and its preprocessors --------------------------------------------------------------
        // The only language here whose "declarations" are not identifiers: the entry *is* the selector,
        // taken as written, because that is what a stylesheet is navigated by. At-rules come first so
        // `@media (max-width: 600px) {` is not read as a selector called "@media (max-width: 600px)".
        //
        // Nested by braces, which is what SCSS and LESS need and plain CSS gets for free inside `@media`.
        let cssRules = [
            Rule("module", "^\\s*(@[a-zA-Z-]+[^{};]*?)\\s*\\{"),
            Rule("type", "^\\s*([.#&:\\[a-zA-Z*][^{};]*?)\\s*\\{"),
        ]
        map["css"] = Grammar(name: "CSS", rules: cssRules, nesting: .braces,
                             lineComments: [], blockComment: ("/*", "*/"),
                             strings: ["\"", "'"], tripleQuote: nil)
        // `//` is a comment in the preprocessors and not in CSS, where it would swallow the rest of a
        // `url(http://…)` line.
        for e in ["scss", "sass", "less"] {
            map[e] = Grammar(name: "CSS", rules: cssRules, nesting: .braces,
                             lineComments: ["//"], blockComment: ("/*", "*/"),
                             strings: ["\"", "'"], tripleQuote: nil)
        }

        // ---- TSX ------------------------------------------------------------------------------------
        // `.tsx` has no grammar here (the TypeScript one does not take JSX and the tsx grammar is a
        // separate vendoring job), so React components written in it had no outline at all.
        let tsx = Grammar(
            name: "TypeScript",
            rules: [
                Rule("class", "\\bclass\\s+(\(name))"),
                Rule("interface", "\\binterface\\s+(\(name))"),
                Rule("enum", "\\benum\\s+(\(name))"),
                Rule("type", "\\btype\\s+(\(name))\\s*="),
                Rule("function", "\\bfunction\\s+(\(name))"),
                // `const Button = (props) => {` and `const load = async () => {` — how most components
                // and hooks are actually written.
                Rule("function", "^\\s*(?:export\\s+)?(?:const|let|var)\\s+(\(name))\\s*(?::[^=]+)?=\\s*(?:async\\s*)?(?:\\([^)]*\\)|\(name))\\s*=>"),
            ],
            nesting: .braces, lineComments: ["//"], blockComment: ("/*", "*/"),
            strings: ["\"", "'", "`"], tripleQuote: nil)
        map["tsx"] = tsx

        return map
    }()

    // MARK: - Markdown

    /// Headings, nested by level: the table of contents a long README is navigated by.
    ///
    /// Both spellings are read — `## Title` and a title underlined with `===` or `---` — and fenced code
    /// blocks are skipped whole. That last part is not a nicety: a shell or Python block inside a README
    /// is full of lines starting with `#`, and every one of them would otherwise become a heading.
    ///
    /// A level that skips a step (an `h4` under an `h2`) nests under whatever is open, which is what every
    /// table of contents does with such a document.
    static func parseMarkdown(_ text: String) -> [SymbolNode] {
        let source = text as NSString
        var roots: [SymbolNode] = []
        var stack: [(node: SymbolNode, level: Int)] = []
        var count = 0
        var fence: String?          // the ``` or ~~~ run that opened the current code block
        var previous: Line?         // for the underlined form, whose text is on the line before

        func close(to level: Int, at offset: Int) {
            while let top = stack.last, top.level >= level {
                top.node.end = offset
                stack.removeLast()
            }
        }
        func add(name: String, level: Int, line: Line, nameRange: NSRange) {
            close(to: level, at: line.range.location)
            let node = SymbolNode(name: name, kind: "heading", line: line.number,
                                  utf16Location: nameRange.location,
                                  start: line.range.location, end: source.length)
            if let parent = stack.last?.node { parent.children.append(node) } else { roots.append(node) }
            stack.append((node, level))
            count += 1
        }

        for line in lines(of: source) {
            if count >= nodeLimit { break }
            let raw = source.substring(with: line.range)
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Fences: everything between them is code, including its `#` lines.
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                previous = nil
                continue
            }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                fence = String(trimmed.prefix(3))
                previous = nil
                continue
            }

            // `### Title` — up to three leading spaces, per CommonMark.
            let indent = raw.prefix(while: { $0 == " " }).count
            if indent <= 3, trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                let after = trimmed.dropFirst(hashes)
                if hashes <= 6, after.first == nil || after.first == " " || after.first == "\t" {
                    let title = after.trimmingCharacters(in: .whitespaces)
                        // A closed ATX heading (`## Title ##`) keeps no trailing hashes in its name.
                        .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                    let found = title.isEmpty ? NSRange(location: NSNotFound, length: 0)
                                             : source.range(of: title, options: [], range: line.range)
                    if found.location != NSNotFound {
                        add(name: title, level: hashes, line: line, nameRange: found)
                        previous = nil
                        continue
                    }
                }
            }

            // `Title` followed by `===` (level 1) or `---` (level 2).
            if let above = previous, trimmed.count >= 2,
               trimmed.allSatisfy({ $0 == "=" }) || trimmed.allSatisfy({ $0 == "-" }) {
                let title = source.substring(with: above.range).trimmingCharacters(in: .whitespaces)
                let found = title.isEmpty ? NSRange(location: NSNotFound, length: 0)
                                         : source.range(of: title, options: [], range: above.range)
                if found.location != NSNotFound {
                    add(name: title, level: trimmed.first == "=" ? 1 : 2, line: above, nameRange: found)
                    previous = nil
                    continue
                }
            }
            previous = trimmed.isEmpty ? nil : line
        }
        return roots
    }

    // MARK: - The scan

    private static func scan(_ text: String, grammar: Grammar) -> [SymbolNode] {
        let masked = mask(text, grammar: grammar)
        let source = text as NSString
        let maskedString = masked as NSString

        var roots: [SymbolNode] = []
        /// Open declarations, with the brace depth (or indentation) they were found at.
        var stack: [(node: SymbolNode, level: Int)] = []
        var count = 0
        var depth = 0

        for line in lines(of: maskedString) {
            if count >= nodeLimit { break }
            let lineText = maskedString.substring(with: line.range)

            // `@end` closes what `@interface` opened, before anything else on the line is considered.
            if case .terminated(let terminator) = grammar.nesting,
               lineText.trimmingCharacters(in: .whitespaces).hasPrefix(terminator) {
                while let top = stack.popLast() { top.node.end = NSMaxRange(line.range) }
            }

            // The level a declaration on this line belongs to, read *before* this line's braces are
            // counted: `class Foo {` is a declaration at the outer level that opens an inner one.
            let level: Int
            switch grammar.nesting {
            case .braces: level = depth
            case .indent: level = indentation(of: lineText)
            case .flat, .terminated: level = 0
            }

            if let hit = firstMatch(in: lineText, rules: grammar.rules) {
                let nameRange = NSRange(location: line.range.location + hit.range.location,
                                        length: hit.range.length)
                // From the original text, not the masked copy: identical for a declaration, and reading
                // the source is what makes a wrong mask visible as a wrong name rather than as silence.
                let displayName = source.substring(with: nameRange)
                switch grammar.nesting {
                case .braces, .indent:
                    while let top = stack.last, top.level >= level {
                        top.node.end = line.range.location
                        stack.removeLast()
                    }
                case .terminated:
                    // One container at a time: a new `@interface` ends the previous one even when the
                    // file forgot its `@end`.
                    if containerKinds.contains(hit.kind) {
                        while let top = stack.popLast() { top.node.end = line.range.location }
                    }
                case .flat:
                    break
                }
                let parent = stack.last?.node
                let kind = (hit.kind == "function" && methodOwners.contains(parent?.kind ?? ""))
                    ? "method" : hit.kind
                let node = SymbolNode(name: displayName, kind: kind, line: line.number,
                                      utf16Location: nameRange.location,
                                      start: line.range.location, end: source.length)
                if let parent { parent.children.append(node) } else { roots.append(node) }
                switch grammar.nesting {
                case .braces, .indent: stack.append((node, level))
                case .terminated: if containerKinds.contains(kind) { stack.append((node, 0)) }
                case .flat: break
                }
                count += 1
            }

            guard case .braces = grammar.nesting else { continue }
            // Now the braces, closing whatever this line ends. Done after the match so a one-liner
            // (`func f() { 1 }`) is still nested under what contains it and closed immediately.
            for (offset, unit) in units(of: maskedString, in: line.range) {
                if unit == UInt16(UInt8(ascii: "{")) {
                    depth += 1
                } else if unit == UInt16(UInt8(ascii: "}")) {
                    depth = max(0, depth - 1)
                    while let top = stack.last, top.level >= depth {
                        top.node.end = offset + 1
                        stack.removeLast()
                    }
                }
            }
        }
        return roots
    }

    /// The first rule that matches, with the name capture's range within the line.
    private static func firstMatch(in line: String, rules: [Rule]) -> (kind: String, range: NSRange)? {
        let full = NSRange(location: 0, length: (line as NSString).length)
        for rule in rules {
            guard let match = rule.regex.firstMatch(in: line, options: [], range: full),
                  match.numberOfRanges > 1 else { continue }
            let range = match.range(at: 1)
            guard range.location != NSNotFound, range.length > 0 else { continue }
            return (rule.kind, range)
        }
        return nil
    }

    private static func indentation(of line: String) -> Int {
        var n = 0
        for c in line {
            if c == " " { n += 1 } else if c == "\t" { n += 8 } else { break }
        }
        return n
    }

    // MARK: - Masking

    /// A copy of `text` with comment bodies and string contents replaced by spaces, newlines kept.
    ///
    /// Same length in UTF-16 units as the original, which is what makes the offsets interchangeable: the
    /// regexes run on this copy so that a `func` inside a comment or a `{` inside a string cannot be
    /// mistaken for code, and every location recorded still points into the real text.
    static func mask(_ text: String, grammar: Grammar) -> String {
        var units = Array(text.utf16)
        let n = units.count
        let space = UInt16(UInt8(ascii: " "))
        let newline = UInt16(UInt8(ascii: "\n"))
        let backslash = UInt16(UInt8(ascii: "\\"))

        func matchesAscii(_ s: String, at i: Int) -> Bool {
            let pattern = Array(s.utf16)
            guard i + pattern.count <= n else { return false }
            for k in 0..<pattern.count where units[i + k] != pattern[k] { return false }
            return true
        }

        let lineComments = grammar.lineComments
        var i = 0
        while i < n {
            // Line comment: blank to the end of the line.
            if let lc = lineComments.first(where: { matchesAscii($0, at: i) }) {
                var j = i
                while j < n, units[j] != newline { units[j] = space; j += 1 }
                i = j
                continue
            }
            // Block comment: blank through the closing delimiter, newlines preserved.
            if let block = grammar.blockComment, matchesAscii(block.open, at: i) {
                var j = i
                while j < n, !matchesAscii(block.close, at: j) {
                    if units[j] != newline { units[j] = space }
                    j += 1
                }
                let closeLength = Array(block.close.utf16).count
                let stop = min(n, j + closeLength)
                while j < stop { if units[j] != newline { units[j] = space }; j += 1 }
                i = j
                continue
            }
            // Triple-quoted string: the multi-line form, taken before the single-quote form so its own
            // delimiters are not read as an empty string followed by a quote.
            if let triple = grammar.tripleQuote, matchesAscii(triple, at: i) {
                let length = Array(triple.utf16).count
                var j = i + length
                while j < n, !matchesAscii(triple, at: j) {
                    if units[j] != newline { units[j] = space }
                    j += 1
                }
                let stop = min(n, j + length)
                var k = i
                while k < stop { if units[k] != newline { units[k] = space }; k += 1 }
                i = stop
                continue
            }
            if let delimiter = grammar.strings.first(where: { units[i] == UInt16($0.unicodeScalars.first!.value) }) {
                let quote = UInt16(delimiter.unicodeScalars.first!.value)
                units[i] = space
                var j = i + 1
                while j < n {
                    if units[j] == backslash {
                        units[j] = space
                        if j + 1 < n, units[j + 1] != newline { units[j + 1] = space }
                        j += 2
                        continue
                    }
                    // An unterminated quote must not swallow the file: stop at the line end. Go and TSX
                    // backticks legitimately span lines, and for those the delimiter is the only end.
                    if units[j] == newline, quote != UInt16(UInt8(ascii: "`")) { break }
                    let closing = units[j] == quote
                    if units[j] != newline { units[j] = space }
                    j += 1
                    if closing { break }
                }
                i = j
                continue
            }
            i += 1
        }
        return String(decoding: units, as: UTF16.self)
    }

    // MARK: - Line and unit helpers

    private struct Line { let number: Int; let range: NSRange }

    /// The lines of `text` as 1-based numbers plus their UTF-16 ranges (terminator excluded).
    private static func lines(of text: NSString) -> [Line] {
        var result: [Line] = []
        var start = 0
        var number = 1
        let newline = UInt16(UInt8(ascii: "\n"))
        for i in 0..<text.length where text.character(at: i) == newline {
            result.append(Line(number: number, range: NSRange(location: start, length: i - start)))
            number += 1
            start = i + 1
        }
        if start <= text.length {
            result.append(Line(number: number, range: NSRange(location: start, length: text.length - start)))
        }
        return result
    }

    /// The UTF-16 units of a range, with their absolute offsets.
    private static func units(of text: NSString, in range: NSRange) -> [(Int, UInt16)] {
        (range.location..<NSMaxRange(range)).map { ($0, text.character(at: $0)) }
    }
}
