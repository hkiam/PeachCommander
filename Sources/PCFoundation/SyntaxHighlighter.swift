// SPDX-License-Identifier: Apache-2.0
// SyntaxHighlighter.swift - Lightweight source tokenizer for the viewer (TODOS #19).
//
// A single-pass, language-parameterised lexer that emits spans for comments,
// strings, numbers and keywords (everything else is left as plain text). It is not
// a full parser — just enough for readable colouring of common languages, and it is
// pure over a Character array so the token ranges are straightforward to unit-test.
// The viewer maps the spans to colours per visible line.

import Foundation

public enum TokenKind: String, Sendable, Equatable {
    case comment, string, number, keyword
}

public struct SyntaxToken: Equatable, Sendable {
    public let range: Range<Int>   // offsets into Array(text)
    public let kind: TokenKind
    public init(range: Range<Int>, kind: TokenKind) {
        self.range = range
        self.kind = kind
    }
}

public struct SyntaxLanguage: Sendable {
    public let name: String
    public let keywords: Set<String>
    public let lineComments: [String]
    public let blockComment: (open: String, close: String)?
    public let stringDelimiters: [Character]

    public init(name: String, keywords: Set<String>, lineComments: [String],
                blockComment: (open: String, close: String)?, stringDelimiters: [Character]) {
        self.name = name
        self.keywords = keywords
        self.lineComments = lineComments
        self.blockComment = blockComment
        self.stringDelimiters = stringDelimiters
    }
}

public enum SyntaxHighlighter {
    /// Resolve a language for a lowercased file extension, or nil if unsupported.
    public static func language(forExtension ext: String) -> SyntaxLanguage? {
        switch ext.lowercased() {
        case "swift":
            return SyntaxLanguage(name: "Swift", keywords: swiftKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case "c", "h", "cpp", "cc", "cxx", "hpp", "hh", "m", "mm":
            return SyntaxLanguage(name: "C", keywords: cKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "js", "mjs", "ts", "jsx", "tsx", "json":
            return SyntaxLanguage(name: "JavaScript", keywords: jsKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'", "`"])
        case "py", "pyw":
            return SyntaxLanguage(name: "Python", keywords: pythonKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "xml", "svg", "plist", "xhtml", "html", "htm", "xsd", "xsl", "storyboard", "xib":
            return SyntaxLanguage(name: "XML", keywords: [], lineComments: [],
                                  blockComment: ("<!--", "-->"), stringDelimiters: ["\""])
        case "sh", "bash", "zsh":
            return SyntaxLanguage(name: "Shell", keywords: shellKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        default:
            return nil
        }
    }

    /// Tokenize `text` under `language`. Offsets index into `Array(text)`.
    public static func tokens(_ text: String, language: SyntaxLanguage) -> [SyntaxToken] {
        if language.name == "XML" { return xmlTokens(text) }
        let chars = Array(text)
        let n = chars.count
        var tokens: [SyntaxToken] = []
        var i = 0

        func matches(_ pattern: [Character], at: Int) -> Bool {
            guard at + pattern.count <= n else { return false }
            for k in 0..<pattern.count where chars[at + k] != pattern[k] { return false }
            return true
        }

        let lineComments = language.lineComments.map(Array.init)
        let blockOpen = language.blockComment.map { Array($0.open) }
        let blockClose = language.blockComment.map { Array($0.close) }

        while i < n {
            let c = chars[i]

            if let lc = lineComments.first(where: { matches($0, at: i) }) {
                let start = i
                i += lc.count
                while i < n, chars[i] != "\n" { i += 1 }
                tokens.append(SyntaxToken(range: start..<i, kind: .comment))
                continue
            }

            if let open = blockOpen, let close = blockClose, matches(open, at: i) {
                let start = i
                i += open.count
                while i < n, !matches(close, at: i) { i += 1 }
                if i < n { i += close.count }
                tokens.append(SyntaxToken(range: start..<i, kind: .comment))
                continue
            }

            if language.stringDelimiters.contains(c) {
                let start = i
                i += 1
                while i < n {
                    if chars[i] == "\\" { i += Swift.min(2, n - i); continue }
                    if chars[i] == c { i += 1; break }
                    if chars[i] == "\n" { break }   // don't let an unterminated string swallow the file
                    i += 1
                }
                tokens.append(SyntaxToken(range: start..<i, kind: .string))
                continue
            }

            if c.isNumber {
                let start = i
                i += 1
                while i < n {
                    let d = chars[i]
                    if d.isHexDigit || d == "." || d == "x" || d == "X" || d == "_" { i += 1 } else { break }
                }
                tokens.append(SyntaxToken(range: start..<i, kind: .number))
                continue
            }

            if c.isLetter || c == "_" {
                let start = i
                i += 1
                while i < n, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" { i += 1 }
                if language.keywords.contains(String(chars[start..<i])) {
                    tokens.append(SyntaxToken(range: start..<i, kind: .keyword))
                }
                continue
            }

            i += 1
        }
        return tokens
    }

    /// XML/HTML tokenizer: tag names as `.keyword`, attribute values as `.string`,
    /// `<!-- -->` as `.comment`.
    static func xmlTokens(_ text: String) -> [SyntaxToken] {
        let chars = Array(text)
        let n = chars.count
        var tokens: [SyntaxToken] = []
        var i = 0
        let open = Array("<!--"), close = Array("-->")
        func matches(_ pattern: [Character], _ at: Int) -> Bool {
            guard at + pattern.count <= n else { return false }
            for k in 0..<pattern.count where chars[at + k] != pattern[k] { return false }
            return true
        }
        func isName(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" || c == ":" || c == "-" || c == "." }

        while i < n {
            if matches(open, i) {
                let start = i; i += open.count
                while i < n, !matches(close, i) { i += 1 }
                if i < n { i += close.count }
                tokens.append(SyntaxToken(range: start..<i, kind: .comment))
                continue
            }
            if chars[i] == "<" {
                i += 1
                var j = i
                if j < n, chars[j] == "/" || chars[j] == "?" || chars[j] == "!" { j += 1 }
                let nameStart = j
                while j < n, isName(chars[j]) { j += 1 }
                if j > nameStart { tokens.append(SyntaxToken(range: nameStart..<j, kind: .keyword)) }
                // Attribute values until the tag closes.
                var k = j
                while k < n, chars[k] != ">" {
                    if chars[k] == "\"" || chars[k] == "'" {
                        let quote = chars[k]; let s = k; k += 1
                        while k < n, chars[k] != quote { k += 1 }
                        if k < n { k += 1 }
                        tokens.append(SyntaxToken(range: s..<k, kind: .string))
                    } else {
                        k += 1
                    }
                }
                if k < n { k += 1 }   // consume '>'
                i = k
                continue
            }
            i += 1
        }
        return tokens
    }

    // MARK: - Keyword sets (representative, not exhaustive)

    static let swiftKeywords: Set<String> = [
        "func", "let", "var", "if", "else", "guard", "return", "for", "while", "in", "switch",
        "case", "default", "struct", "class", "enum", "protocol", "extension", "import", "public",
        "private", "internal", "fileprivate", "static", "self", "init", "deinit", "nil", "true",
        "false", "throws", "try", "catch", "async", "await", "where", "as", "is", "some", "any"
    ]
    static let cKeywords: Set<String> = [
        "int", "char", "long", "short", "float", "double", "void", "unsigned", "signed", "const",
        "static", "struct", "union", "enum", "typedef", "if", "else", "for", "while", "do", "switch",
        "case", "default", "return", "break", "continue", "sizeof", "goto", "extern", "volatile", "inline"
    ]
    static let jsKeywords: Set<String> = [
        "function", "var", "let", "const", "if", "else", "for", "while", "do", "switch", "case",
        "default", "return", "break", "continue", "new", "class", "extends", "import", "export",
        "from", "async", "await", "try", "catch", "finally", "throw", "typeof", "instanceof",
        "true", "false", "null", "undefined", "this"
    ]
    static let pythonKeywords: Set<String> = [
        "def", "class", "if", "elif", "else", "for", "while", "in", "return", "import", "from",
        "as", "try", "except", "finally", "raise", "with", "lambda", "yield", "pass", "break",
        "continue", "and", "or", "not", "is", "None", "True", "False", "self", "async", "await"
    ]
    static let shellKeywords: Set<String> = [
        "if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "in",
        "function", "return", "echo", "export", "local", "read", "exit", "cd", "set"
    ]
}
