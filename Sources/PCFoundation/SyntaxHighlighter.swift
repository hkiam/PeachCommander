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
        case "js", "mjs", "ts", "jsx", "tsx":
            return SyntaxLanguage(name: "JavaScript", keywords: jsKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'", "`"])
        case "json", "jsonc", "geojson", "webmanifest", "jsonl", "ndjson":
            // The same lexer as JavaScript — JSON is a subset — but not the same *name*: the status line
            // said "JavaScript" over an open .json file, which is wrong in a window that also offers to
            // validate the document as JSON.
            return SyntaxLanguage(name: "JSON", keywords: jsonKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case "py", "pyw":
            return SyntaxLanguage(name: "Python", keywords: pythonKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        // The languages below had no entry at all, and this function is the app's answer to "is this
        // code?": the viewer only switches to its code representation when it returns something (and
        // only then offers the mode at all), the status line names the language from it, and the editor
        // takes its lexer from it. So a .go file was plain text with a dead "Code" menu item — including
        // for Java, Rust, C# and TypeScript, which tree-sitter here highlights perfectly well.
        case "java":
            return SyntaxLanguage(name: "Java", keywords: javaKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "kt", "kts":
            return SyntaxLanguage(name: "Kotlin", keywords: kotlinKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case "go":
            return SyntaxLanguage(name: "Go", keywords: goKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "`"])
        case "rs":
            return SyntaxLanguage(name: "Rust", keywords: rustKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case "cs":
            return SyntaxLanguage(name: "C#", keywords: csharpKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "scala", "sc":
            return SyntaxLanguage(name: "Scala", keywords: scalaKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\""])
        case "dart":
            return SyntaxLanguage(name: "Dart", keywords: dartKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "rb", "rake", "gemspec":
            return SyntaxLanguage(name: "Ruby", keywords: rubyKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "php", "phtml":
            return SyntaxLanguage(name: "PHP", keywords: phpKeywords,
                                  lineComments: ["//", "#"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "pl", "pm":
            return SyntaxLanguage(name: "Perl", keywords: perlKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "lua":
            // Block comments before line comments matters here and nowhere else: `--[[` starts with
            // `--`. `tokens` tries the block form first for exactly this reason.
            return SyntaxLanguage(name: "Lua", keywords: luaKeywords,
                                  lineComments: ["--"], blockComment: ("--[[", "]]"), stringDelimiters: ["\"", "'"])
        case "ps1", "psm1", "psd1":
            return SyntaxLanguage(name: "PowerShell", keywords: powershellKeywords,
                                  lineComments: ["#"], blockComment: ("<#", "#>"), stringDelimiters: ["\"", "'"])
        case "r", "rscript":
            return SyntaxLanguage(name: "R", keywords: rKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "groovy", "gradle":
            return SyntaxLanguage(name: "Groovy", keywords: groovyKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "hs", "lhs":
            return SyntaxLanguage(name: "Haskell", keywords: haskellKeywords,
                                  lineComments: ["--"], blockComment: ("{-", "-}"), stringDelimiters: ["\""])
        case "ex", "exs":
            return SyntaxLanguage(name: "Elixir", keywords: elixirKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "css":
            // No line comments: `//` is not one in CSS, and treating it as one colours the rest of any
            // line holding a `url(http://…)`.
            return SyntaxLanguage(name: "CSS", keywords: cssKeywords,
                                  lineComments: [], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "scss", "sass", "less":
            return SyntaxLanguage(name: "CSS", keywords: cssKeywords,
                                  lineComments: ["//"], blockComment: ("/*", "*/"), stringDelimiters: ["\"", "'"])
        case "sql", "ddl", "pgsql":
            // Upper- and lower-case spellings both listed: the tokenizer matches whole words literally,
            // and SQL is written both ways, frequently in the same file.
            return SyntaxLanguage(name: "SQL", keywords: sqlKeywords,
                                  lineComments: ["--"], blockComment: ("/*", "*/"), stringDelimiters: ["'"])
        case "xml", "svg", "plist", "xhtml", "html", "htm", "xsd", "xsl", "storyboard", "xib":
            return SyntaxLanguage(name: "XML", keywords: [], lineComments: [],
                                  blockComment: ("<!--", "-->"), stringDelimiters: ["\""])
        case "sh", "bash", "zsh", "ksh":
            return SyntaxLanguage(name: "Shell", keywords: shellKeywords,
                                  lineComments: ["#"], blockComment: nil, stringDelimiters: ["\"", "'"])
        case "yml", "yaml":
            // YAML's "keywords" are its plain scalars for booleans and null (YAML 1.1
            // spellings included, which is what most real files and parsers use).
            // Keys are not coloured: this lexer is line- and token-based, and telling a
            // mapping key from a plain scalar needs indentation context it does not track.
            return SyntaxLanguage(name: "YAML", keywords: yamlKeywords,
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

            // The block form is tried first because one language's block opener *starts with* its line
            // comment: Lua's `--[[ … ]]` begins with `--`, and in the other order every Lua block comment
            // was highlighted as a one-line comment. No other language here is affected — "/*" is not a
            // prefix of "//".
            if let open = blockOpen, let close = blockClose, matches(open, at: i) {
                let start = i
                i += open.count
                while i < n, !matches(close, at: i) { i += 1 }
                if i < n { i += close.count }
                tokens.append(SyntaxToken(range: start..<i, kind: .comment))
                continue
            }

            if let lc = lineComments.first(where: { matches($0, at: i) }) {
                let start = i
                i += lc.count
                while i < n, chars[i] != "\n" { i += 1 }
                tokens.append(SyntaxToken(range: start..<i, kind: .comment))
                continue
            }

            if language.stringDelimiters.contains(c) {
                let start = i
                i += 1
                while i < n {
                    if chars[i] == "\\" { i += Swift.min(2, n - i); continue }
                    if chars[i] == c { i += 1; break }
                    // `isNewline`: a CRLF is one Character and matches neither "\r" nor "\n", so on a
                    // Windows-style file this guard never fired and an unterminated quote coloured the
                    // rest of the document as a string.
                    if chars[i].isNewline { break }  // don't let an unterminated string swallow the file
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
    /// JSON's three literals. Not JavaScript's keyword list: `for` and `class` are not JSON, and
    /// highlighting them inside a string key would be a lie about the format.
    static let jsonKeywords: Set<String> = ["true", "false", "null"]

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
    static let javaKeywords: Set<String> = [
        "abstract", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
        "default", "do", "double", "else", "enum", "extends", "final", "finally", "float", "for", "if",
        "implements", "import", "instanceof", "int", "interface", "long", "new", "package", "private",
        "protected", "public", "record", "return", "short", "static", "super", "switch", "synchronized",
        "this", "throw", "throws", "try", "var", "void", "volatile", "while", "true", "false", "null"
    ]
    static let kotlinKeywords: Set<String> = [
        "package", "import", "class", "interface", "object", "fun", "val", "var", "if", "else", "when",
        "for", "while", "do", "return", "is", "as", "in", "out", "by", "constructor", "init", "companion",
        "data", "sealed", "enum", "open", "override", "abstract", "private", "protected", "internal",
        "public", "suspend", "lateinit", "typealias", "try", "catch", "finally", "throw", "this", "super",
        "true", "false", "null"
    ]
    static let goKeywords: Set<String> = [
        "package", "import", "func", "var", "const", "type", "struct", "interface", "map", "chan",
        "go", "defer", "if", "else", "for", "range", "switch", "case", "default", "select", "return",
        "break", "continue", "fallthrough", "goto", "nil", "true", "false", "make", "new", "len", "cap",
        "append", "string", "int", "int64", "float64", "bool", "byte", "rune", "error"
    ]
    static let rustKeywords: Set<String> = [
        "fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl", "for", "while", "loop",
        "if", "else", "match", "return", "break", "continue", "mod", "use", "pub", "crate", "super",
        "self", "Self", "where", "as", "dyn", "ref", "move", "async", "await", "unsafe", "type", "in",
        "true", "false", "Some", "None", "Ok", "Err"
    ]
    static let csharpKeywords: Set<String> = [
        "using", "namespace", "class", "struct", "interface", "enum", "record", "delegate", "event",
        "public", "private", "protected", "internal", "static", "readonly", "const", "sealed",
        "abstract", "override", "virtual", "partial", "new", "var", "void", "int", "long", "string",
        "bool", "double", "decimal", "object", "if", "else", "switch", "case", "default", "for",
        "foreach", "in", "while", "do", "return", "break", "continue", "try", "catch", "finally",
        "throw", "async", "await", "yield", "this", "base", "true", "false", "null"
    ]
    static let scalaKeywords: Set<String> = [
        "package", "import", "class", "trait", "object", "case", "def", "val", "var", "lazy", "implicit",
        "given", "using", "extends", "with", "override", "abstract", "final", "sealed", "private",
        "protected", "new", "if", "else", "match", "for", "yield", "while", "do", "return", "try",
        "catch", "finally", "throw", "type", "this", "super", "true", "false", "null"
    ]
    static let dartKeywords: Set<String> = [
        "import", "export", "library", "part", "class", "mixin", "extension", "enum", "typedef",
        "abstract", "implements", "extends", "with", "factory", "const", "final", "var", "late", "get",
        "set", "static", "void", "dynamic", "int", "double", "String", "bool", "if", "else", "switch",
        "case", "default", "for", "in", "while", "do", "return", "break", "continue", "try", "catch",
        "finally", "throw", "async", "await", "yield", "this", "super", "true", "false", "null", "new"
    ]
    static let rubyKeywords: Set<String> = [
        "def", "end", "class", "module", "if", "elsif", "else", "unless", "case", "when", "while",
        "until", "for", "in", "do", "begin", "rescue", "ensure", "retry", "yield", "return", "break",
        "next", "then", "self", "super", "require", "require_relative", "include", "extend", "attr_accessor",
        "attr_reader", "attr_writer", "lambda", "proc", "nil", "true", "false", "and", "or", "not", "raise"
    ]
    static let phpKeywords: Set<String> = [
        "namespace", "use", "class", "interface", "trait", "enum", "extends", "implements", "function",
        "fn", "public", "private", "protected", "static", "abstract", "final", "const", "readonly",
        "new", "clone", "echo", "print", "if", "elseif", "else", "endif", "switch", "case", "default",
        "for", "foreach", "as", "while", "do", "return", "break", "continue", "try", "catch", "finally",
        "throw", "match", "yield", "global", "isset", "unset", "empty", "require", "require_once",
        "include", "include_once", "true", "false", "null", "array", "this"
    ]
    static let perlKeywords: Set<String> = [
        "package", "use", "no", "require", "sub", "my", "our", "local", "if", "elsif", "else", "unless",
        "while", "until", "for", "foreach", "do", "last", "next", "redo", "return", "die", "warn",
        "eval", "bless", "ref", "defined", "undef", "shift", "unshift", "push", "pop", "print", "printf",
        "qw", "and", "or", "not"
    ]
    static let luaKeywords: Set<String> = [
        "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in",
        "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "self",
        "require", "pairs", "ipairs"
    ]
    static let powershellKeywords: Set<String> = [
        "function", "filter", "workflow", "class", "enum", "param", "begin", "process", "end", "if",
        "elseif", "else", "switch", "foreach", "for", "while", "do", "until", "break", "continue",
        "return", "try", "catch", "finally", "throw", "trap", "in", "using", "module", "Import-Module",
        "Write-Host", "Write-Output", "Get-ChildItem", "Set-Location", "true", "false", "null"
    ]
    static let rKeywords: Set<String> = [
        "function", "if", "else", "for", "while", "repeat", "break", "next", "return", "in", "library",
        "require", "source", "TRUE", "FALSE", "NULL", "NA", "Inf", "NaN", "setClass", "setMethod",
        "setGeneric", "new", "invisible"
    ]
    static let groovyKeywords: Set<String> = [
        "package", "import", "class", "interface", "trait", "enum", "def", "as", "in", "new", "extends",
        "implements", "public", "private", "protected", "static", "final", "abstract", "if", "else",
        "switch", "case", "default", "for", "while", "do", "return", "break", "continue", "try", "catch",
        "finally", "throw", "assert", "this", "super", "true", "false", "null", "task", "dependencies"
    ]
    static let haskellKeywords: Set<String> = [
        "module", "where", "import", "qualified", "hiding", "as", "data", "newtype", "type", "class",
        "instance", "deriving", "do", "let", "in", "case", "of", "if", "then", "else", "forall",
        "infix", "infixl", "infixr", "True", "False", "Nothing", "Just", "Maybe", "IO"
    ]
    static let elixirKeywords: Set<String> = [
        "defmodule", "def", "defp", "defmacro", "defmacrop", "defstruct", "defprotocol", "defimpl",
        "defdelegate", "defexception", "do", "end", "fn", "case", "cond", "if", "unless", "else",
        "with", "for", "receive", "after", "try", "rescue", "catch", "raise", "throw", "import",
        "alias", "require", "use", "when", "in", "true", "false", "nil"
    ]
    /// CSS at-rules and the words that carry meaning rather than being values. Property names are
    /// deliberately absent: there are hundreds, they change yearly, and colouring `color` while missing
    /// `color-scheme` looks like a bug rather than a short list.
    static let cssKeywords: Set<String> = [
        "important", "media", "import", "use", "forward", "supports", "keyframes", "font-face",
        "charset", "namespace", "layer", "container", "property", "mixin", "include", "extend",
        "function", "return", "if", "else", "each", "for", "while", "from", "to", "and", "or", "not",
        "only", "inherit", "initial", "unset", "revert", "var", "calc", "url"
    ]
    /// SQL in both spellings, because the tokenizer matches whole words literally and real files mix
    /// them. Only the statement and clause words: a data type list would colour column names.
    static let sqlKeywords: Set<String> = {
        let words = [
            "select", "from", "where", "group", "by", "having", "order", "limit", "offset", "insert",
            "into", "values", "update", "set", "delete", "create", "alter", "drop", "truncate", "table",
            "view", "index", "trigger", "function", "procedure", "returns", "begin", "end", "declare",
            "join", "inner", "left", "right", "full", "outer", "cross", "on", "as", "and", "or", "not",
            "null", "is", "in", "exists", "between", "like", "distinct", "union", "all", "case", "when",
            "then", "else", "primary", "foreign", "key", "references", "unique", "default", "check",
            "constraint", "cascade", "grant", "revoke", "commit", "rollback", "transaction", "with",
            "returning", "if", "replace", "temporary", "materialized"
        ]
        return Set(words + words.map { $0.uppercased() })
    }()

    /// YAML plain scalars that carry meaning rather than being free text. Both the
    /// YAML 1.2 core spellings and the 1.1 ones (yes/no/on/off), since real files and
    /// most parsers still treat those as booleans. Capitalised and upper-case variants
    /// are listed because the tokenizer matches whole words literally.
    static let yamlKeywords: Set<String> = [
        "true", "false", "null",
        "True", "False", "Null",
        "TRUE", "FALSE", "NULL",
        "yes", "no", "on", "off",
        "Yes", "No", "On", "Off",
        "YES", "NO", "ON", "OFF"
    ]
}
