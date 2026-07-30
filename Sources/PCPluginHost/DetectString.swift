// DetectString.swift - Total Commander "detect string" parser + evaluator for Peach Commander
//
// Implements SPEC-012 §6, feature F-238.
//
// A plugin declares a "detect string" - a small boolean expression that decides
// whether the plugin claims a given file. This file provides a self-contained,
// deterministic, IO-free recursive-descent parser and evaluator that is
// TC-compatible.
//
// Grammar (roughly, in EBNF):
//
//   orExpr    = andExpr ( "|" andExpr )*
//   andExpr   = notExpr ( "&" notExpr )*
//   notExpr   = "!" notExpr | primary
//   primary   = "(" orExpr ")"
//             | "FORCE"
//             | "MULTIMEDIA" [ compareOp intValue ]
//             | "EXT" compareOp stringValue
//             | "SIZE" compareOp intValue
//             | "[" number "]" compareOp intValue
//
// Precedence (loosest to tightest): `|`  <  `&`  <  `!`  <  comparison.
//
// A malformed detect string never matches (evaluates to `false`), and
// `isValid` reports whether it parses cleanly.

import Foundation

/// The file facts a detect string is evaluated against.
///
/// This is a pure value type: evaluation reads only from here, never from disk.
public struct DetectContext: Sendable {
    /// Extension without the leading dot; matched case-insensitively.
    public let ext: String

    /// File size in bytes.
    public let size: Int64

    /// The first up-to-8192 bytes of the file, used by `[N]` byte probes.
    public let bytes: [UInt8]

    /// Whether the file is considered a multimedia file (audio/video/image).
    public let isMultimedia: Bool

    public init(ext: String, size: Int64, bytes: [UInt8], isMultimedia: Bool = false) {
        self.ext = ext
        self.size = size
        self.bytes = bytes
        self.isMultimedia = isMultimedia
    }

    /// Byte at `offset`, or `nil` if beyond the available bytes (or negative).
    public func byte(at offset: Int) -> UInt8? {
        guard offset >= 0, offset < bytes.count else { return nil }
        return bytes[offset]
    }
}

public enum DetectString {
    /// Parse and evaluate a detect string against `context`.
    ///
    /// Returns `false` on a parse error (a malformed detect string never matches).
    /// An empty / whitespace-only detect string returns `false`.
    public static func matches(_ detect: String, context: DetectContext) -> Bool {
        guard let expr = try? parse(detect) else { return false }
        return expr.evaluate(context)
    }

    /// Parse only - returns `true` if the detect string is syntactically valid
    /// (useful for the plugin manager to validate user-entered overrides).
    public static func isValid(_ detect: String) -> Bool {
        return (try? parse(detect)) != nil
    }

    // MARK: - Parsing

    /// Parse a detect string into an expression tree, throwing on any error
    /// (including empty input).
    private static func parse(_ detect: String) throws -> Expr {
        var lexer = Lexer(detect)
        let tokens = try lexer.tokenize()
        var parser = Parser(tokens: tokens)
        let expr = try parser.parseExpression()
        // Reject trailing garbage such as `EXT="ZIP" &` or `EXT="A" EXT="B"`.
        guard parser.isAtEnd else { throw ParseError.trailingTokens }
        return expr
    }
}

// MARK: - Errors

private enum ParseError: Error {
    case empty
    case unexpectedCharacter
    case unterminatedString
    case badByteOffset
    case badNumber
    case expectedToken
    case expectedValue
    case trailingTokens
    case typeMismatch
}

// MARK: - AST

/// A comparison operator.
private enum CompareOp {
    case eq, ne, lt, gt, le, ge

    /// Apply to two integers.
    func apply(_ lhs: Int64, _ rhs: Int64) -> Bool {
        switch self {
        case .eq: return lhs == rhs
        case .ne: return lhs != rhs
        case .lt: return lhs < rhs
        case .gt: return lhs > rhs
        case .le: return lhs <= rhs
        case .ge: return lhs >= rhs
        }
    }

    /// Apply to a case-insensitive string ordering result.
    /// `result` is `lhs.compare(rhs)`: .orderedAscending / .same / .descending.
    func apply(_ result: ComparisonResult) -> Bool {
        switch self {
        case .eq: return result == .orderedSame
        case .ne: return result != .orderedSame
        case .lt: return result == .orderedAscending
        case .gt: return result == .orderedDescending
        case .le: return result != .orderedDescending
        case .ge: return result != .orderedAscending
        }
    }
}

/// An expression node. Evaluation is lazy and pure.
private indirect enum Expr {
    case or(Expr, Expr)
    case and(Expr, Expr)
    case not(Expr)

    /// A bare boolean keyword: FORCE (always true) or MULTIMEDIA (as a boolean).
    case force
    case multimediaBool

    /// EXT compared against a quoted string (case-insensitive).
    case extCompare(CompareOp, String)
    /// SIZE compared against an integer.
    case sizeCompare(CompareOp, Int64)
    /// MULTIMEDIA compared against an integer (0/1).
    case multimediaCompare(CompareOp, Int64)
    /// Byte probe `[N]` compared against an integer.
    case byteCompare(offset: Int, op: CompareOp, value: Int64)

    func evaluate(_ ctx: DetectContext) -> Bool {
        switch self {
        case let .or(l, r):
            return l.evaluate(ctx) || r.evaluate(ctx)
        case let .and(l, r):
            return l.evaluate(ctx) && r.evaluate(ctx)
        case let .not(e):
            return !e.evaluate(ctx)
        case .force:
            return true
        case .multimediaBool:
            return ctx.isMultimedia
        case let .extCompare(op, literal):
            let result = ctx.ext.compare(literal, options: .caseInsensitive)
            return op.apply(result)
        case let .sizeCompare(op, value):
            return op.apply(ctx.size, value)
        case let .multimediaCompare(op, value):
            return op.apply(ctx.isMultimedia ? 1 : 0, value)
        case let .byteCompare(offset, op, value):
            // Beyond the available bytes -> the comparison is false.
            guard let b = ctx.byte(at: offset) else { return false }
            return op.apply(Int64(b), value)
        }
    }
}

// MARK: - Tokens

private enum Token: Equatable {
    case ext
    case size
    case force
    case multimedia
    case byteProbe(Int)      // [N]
    case number(Int64)
    case string(String)
    case op(TokenOp)
    case lparen
    case rparen
}

private enum TokenOp: Equatable {
    case eq, ne, lt, gt, le, ge   // comparisons
    case and, or, not             // booleans

    var asCompareOp: CompareOp? {
        switch self {
        case .eq: return .eq
        case .ne: return .ne
        case .lt: return .lt
        case .gt: return .gt
        case .le: return .le
        case .ge: return .ge
        default: return nil
        }
    }
}

// MARK: - Lexer

private struct Lexer {
    private let scalars: [Character]
    private var pos = 0

    init(_ input: String) {
        self.scalars = Array(input)
    }

    private var isAtEnd: Bool { pos >= scalars.count }

    private func peek() -> Character? {
        isAtEnd ? nil : scalars[pos]
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        while let c = peek() {
            if c.isWhitespace {
                pos += 1
                continue
            }
            switch c {
            case "(":
                tokens.append(.lparen); pos += 1
            case ")":
                tokens.append(.rparen); pos += 1
            case "&":
                tokens.append(.op(.and)); pos += 1
            case "|":
                tokens.append(.op(.or)); pos += 1
            case "=":
                tokens.append(.op(.eq)); pos += 1
            case "!":
                // `!=` (inequality) versus `!` (boolean not).
                if pos + 1 < scalars.count, scalars[pos + 1] == "=" {
                    tokens.append(.op(.ne)); pos += 2
                } else {
                    tokens.append(.op(.not)); pos += 1
                }
            case "<":
                if pos + 1 < scalars.count, scalars[pos + 1] == "=" {
                    tokens.append(.op(.le)); pos += 2
                } else {
                    tokens.append(.op(.lt)); pos += 1
                }
            case ">":
                if pos + 1 < scalars.count, scalars[pos + 1] == "=" {
                    tokens.append(.op(.ge)); pos += 2
                } else {
                    tokens.append(.op(.gt)); pos += 1
                }
            case "\"":
                tokens.append(try lexString())
            case "[":
                tokens.append(try lexByteProbe())
            default:
                if c.isNumber {
                    tokens.append(try lexNumber())
                } else if c.isLetter || c == "_" {
                    tokens.append(try lexIdentifier())
                } else {
                    throw ParseError.unexpectedCharacter
                }
            }
        }
        guard !tokens.isEmpty else { throw ParseError.empty }
        return tokens
    }

    /// Lex a double-quoted string literal (no escape sequences - TC uses none).
    private mutating func lexString() throws -> Token {
        pos += 1 // consume opening quote
        var value = ""
        while let c = peek() {
            if c == "\"" {
                pos += 1 // consume closing quote
                return .string(value)
            }
            value.append(c)
            pos += 1
        }
        throw ParseError.unterminatedString
    }

    /// Lex a byte probe `[N]` where N is 0...8191.
    private mutating func lexByteProbe() throws -> Token {
        pos += 1 // consume '['
        var digits = ""
        while let c = peek(), c.isNumber {
            digits.append(c)
            pos += 1
        }
        guard peek() == "]" else { throw ParseError.badByteOffset }
        pos += 1 // consume ']'
        guard !digits.isEmpty, let n = Int(digits), n >= 0, n <= 8191 else {
            throw ParseError.badByteOffset
        }
        return .byteProbe(n)
    }

    /// Lex a decimal integer.
    private mutating func lexNumber() throws -> Token {
        var digits = ""
        while let c = peek(), c.isNumber {
            digits.append(c)
            pos += 1
        }
        guard let value = Int64(digits) else { throw ParseError.badNumber }
        return .number(value)
    }

    /// Lex a keyword identifier (EXT / SIZE / FORCE / MULTIMEDIA), case-insensitively.
    private mutating func lexIdentifier() throws -> Token {
        var name = ""
        while let c = peek(), c.isLetter || c.isNumber || c == "_" {
            name.append(c)
            pos += 1
        }
        switch name.uppercased() {
        case "EXT": return .ext
        case "SIZE": return .size
        case "FORCE": return .force
        case "MULTIMEDIA": return .multimedia
        default: throw ParseError.unexpectedCharacter
        }
    }
}

// MARK: - Parser

private struct Parser {
    private let tokens: [Token]
    private var pos = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    var isAtEnd: Bool { pos >= tokens.count }

    private func peek() -> Token? {
        isAtEnd ? nil : tokens[pos]
    }

    private mutating func advance() -> Token? {
        guard !isAtEnd else { return nil }
        defer { pos += 1 }
        return tokens[pos]
    }

    /// Parse the top-level expression (an OR-expression).
    mutating func parseExpression() throws -> Expr {
        return try parseOr()
    }

    // orExpr = andExpr ( "|" andExpr )*
    private mutating func parseOr() throws -> Expr {
        var left = try parseAnd()
        while case .op(.or)? = peek() {
            _ = advance()
            let right = try parseAnd()
            left = .or(left, right)
        }
        return left
    }

    // andExpr = notExpr ( "&" notExpr )*
    private mutating func parseAnd() throws -> Expr {
        var left = try parseNot()
        while case .op(.and)? = peek() {
            _ = advance()
            let right = try parseNot()
            left = .and(left, right)
        }
        return left
    }

    // notExpr = "!" notExpr | primary
    private mutating func parseNot() throws -> Expr {
        if case .op(.not)? = peek() {
            _ = advance()
            return .not(try parseNot())
        }
        return try parsePrimary()
    }

    // primary = "(" orExpr ")" | field-term
    private mutating func parsePrimary() throws -> Expr {
        guard let token = peek() else { throw ParseError.expectedToken }

        switch token {
        case .lparen:
            _ = advance()
            let inner = try parseOr()
            guard case .rparen? = peek() else { throw ParseError.expectedToken }
            _ = advance()
            return inner

        case .force:
            _ = advance()
            return .force

        case .multimedia:
            _ = advance()
            // MULTIMEDIA may be a bare boolean or a numeric comparison.
            if let op = pendingCompareOp() {
                _ = advance()
                let value = try parseIntValue()
                return .multimediaCompare(op, value)
            }
            return .multimediaBool

        case .ext:
            _ = advance()
            let op = try consumeCompareOp()
            let literal = try parseStringValue()
            return .extCompare(op, literal)

        case .size:
            _ = advance()
            let op = try consumeCompareOp()
            let value = try parseIntValue()
            return .sizeCompare(op, value)

        case let .byteProbe(offset):
            _ = advance()
            let op = try consumeCompareOp()
            let value = try parseIntValue()
            return .byteCompare(offset: offset, op: op, value: value)

        default:
            throw ParseError.expectedToken
        }
    }

    /// Peek at a comparison operator without consuming it, or `nil` if the next
    /// token is not a comparison operator.
    private func pendingCompareOp() -> CompareOp? {
        if case let .op(tokenOp)? = peek() {
            return tokenOp.asCompareOp
        }
        return nil
    }

    /// Consume a required comparison operator.
    private mutating func consumeCompareOp() throws -> CompareOp {
        guard case let .op(tokenOp)? = peek(), let op = tokenOp.asCompareOp else {
            throw ParseError.expectedToken
        }
        _ = advance()
        return op
    }

    /// Consume a required integer value.
    private mutating func parseIntValue() throws -> Int64 {
        guard case let .number(value)? = peek() else { throw ParseError.expectedValue }
        _ = advance()
        return value
    }

    /// Consume a required quoted-string value.
    private mutating func parseStringValue() throws -> String {
        guard case let .string(value)? = peek() else { throw ParseError.expectedValue }
        _ = advance()
        return value
    }
}
