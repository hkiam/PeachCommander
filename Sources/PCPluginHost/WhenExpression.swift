// SPDX-License-Identifier: Apache-2.0
// WhenExpression.swift - Small boolean expression language for contribution
// visibility/enablement (SPEC-013 §"when expression language").
//
// Evaluated by the HOST against a context snapshot — never by the plugin — so it
// works for disabled plugins and on every menu-open without any IPC. Pure,
// deterministic, Sendable. Grammar (lowest→highest precedence):
//
//   or   := and ('||' and)*
//   and  := cmp ('&&' cmp)*
//   cmp  := unary (op unary)?        op ∈ == != =~ startswith endswith contains
//                                          > < >= <= | 'in' '(' list ')'
//   unary:= '!' unary | primary
//   primary := '(' or ')' | ident | string | number | true | false
//
// Identifiers resolve against the context; a bare value is truthy when it is a
// true bool, a non-zero number, or a non-empty string.

import Foundation

/// A context value a `when` expression can reference.
public enum WhenValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case absent

    public var truthy: Bool {
        switch self {
        case .string(let s): return !s.isEmpty
        case .int(let i): return i != 0
        case .bool(let b): return b
        case .absent: return false
        }
    }
    public var asString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .bool(let b): return b ? "true" : "false"
        case .absent: return ""
        }
    }
    public var asDouble: Double? {
        switch self {
        case .string(let s): return Double(s)
        case .int(let i): return Double(i)
        case .bool(let b): return b ? 1 : 0
        case .absent: return nil
        }
    }
}

/// A snapshot of state a `when` expression is evaluated against.
public struct ContributionContext: Sendable {
    public var values: [String: WhenValue]
    public init(_ values: [String: WhenValue] = [:]) { self.values = values }
    public subscript(_ key: String) -> WhenValue { values[key] ?? .absent }

    // Ergonomic setters used by the host when building a snapshot.
    public mutating func set(_ key: String, _ v: String?) { values[key] = v.map(WhenValue.string) ?? .absent }
    public mutating func set(_ key: String, _ v: Int) { values[key] = .int(v) }
    public mutating func set(_ key: String, _ v: Bool) { values[key] = .bool(v) }
}

public enum WhenError: Error, Equatable {
    case syntax(String)
}

/// A parsed `when` expression, reusable across evaluations.
public struct WhenExpression: Sendable {
    private let node: Node

    public init(_ source: String) throws {
        var parser = Parser(tokens: try Lexer.lex(source))
        self.node = try parser.parseExpression()
        try parser.expectEnd()
    }

    public func evaluate(_ context: ContributionContext) -> Bool {
        node.eval(context).truthy
    }

    /// Convenience: parse + evaluate; a malformed expression is treated as `false`
    /// (fail-closed) so a broken `when` hides its item rather than always showing.
    public static func evaluate(_ source: String?, context: ContributionContext) -> Bool {
        guard let source, !source.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        guard let expr = try? WhenExpression(source) else { return false }
        return expr.evaluate(context)
    }

    // MARK: - AST

    indirect enum Node {
        case value(WhenValue)
        case ident(String)
        case not(Node)
        case and(Node, Node)
        case or(Node, Node)
        case compare(Node, Token.Op, Node)
        case inList(Node, [Node])

        func eval(_ ctx: ContributionContext) -> WhenValue {
            switch self {
            case .value(let v): return v
            case .ident(let name): return ctx[name]
            case .not(let n): return .bool(!n.eval(ctx).truthy)
            case .and(let a, let b): return .bool(a.eval(ctx).truthy && b.eval(ctx).truthy)
            case .or(let a, let b): return .bool(a.eval(ctx).truthy || b.eval(ctx).truthy)
            case .inList(let lhs, let list):
                let l = lhs.eval(ctx).asString
                return .bool(list.contains { $0.eval(ctx).asString == l })
            case .compare(let a, let op, let b):
                return .bool(Node.compare(a.eval(ctx), op, b.eval(ctx)))
            }
        }

        static func compare(_ l: WhenValue, _ op: Token.Op, _ r: WhenValue) -> Bool {
            switch op {
            case .eq: return l.asString == r.asString
            case .ne: return l.asString != r.asString
            case .regex: return (try? NSRegularExpression(pattern: r.asString))
                .map { $0.firstMatch(in: l.asString, range: NSRange(l.asString.startIndex..., in: l.asString)) != nil } ?? false
            case .startswith: return l.asString.hasPrefix(r.asString)
            case .endswith: return l.asString.hasSuffix(r.asString)
            case .contains: return l.asString.contains(r.asString)
            case .gt, .lt, .ge, .le:
                if let ld = l.asDouble, let rd = r.asDouble {
                    switch op { case .gt: return ld > rd; case .lt: return ld < rd
                                case .ge: return ld >= rd; default: return ld <= rd }
                }
                let c = l.asString.compare(r.asString)
                switch op { case .gt: return c == .orderedDescending; case .lt: return c == .orderedAscending
                            case .ge: return c != .orderedAscending; default: return c != .orderedDescending }
            }
        }
    }

    // MARK: - Tokens

    enum Token: Equatable {
        enum Op: Equatable { case eq, ne, regex, startswith, endswith, contains, gt, lt, ge, le }
        case ident(String)
        case string(String)
        case number(Double)
        case op(Op)
        case andand, oror, bang, lparen, rparen, comma, inKw, trueKw, falseKw
    }

    // MARK: - Lexer

    enum Lexer {
        static func lex(_ s: String) throws -> [Token] {
            var tokens: [Token] = []
            let chars = Array(s)
            var i = 0
            func peek(_ o: Int = 0) -> Character? { i + o < chars.count ? chars[i + o] : nil }
            while i < chars.count {
                let c = chars[i]
                if c.isWhitespace { i += 1; continue }
                switch c {
                case "&": guard peek(1) == "&" else { throw WhenError.syntax("expected &&") }; tokens.append(.andand); i += 2
                case "|": guard peek(1) == "|" else { throw WhenError.syntax("expected ||") }; tokens.append(.oror); i += 2
                case "(": tokens.append(.lparen); i += 1
                case ")": tokens.append(.rparen); i += 1
                case ",": tokens.append(.comma); i += 1
                case "!": if peek(1) == "=" { tokens.append(.op(.ne)); i += 2 } else { tokens.append(.bang); i += 1 }
                case "=":
                    if peek(1) == "=" { tokens.append(.op(.eq)); i += 2 }
                    else if peek(1) == "~" { tokens.append(.op(.regex)); i += 2 }
                    else { throw WhenError.syntax("expected == or =~") }
                case ">": if peek(1) == "=" { tokens.append(.op(.ge)); i += 2 } else { tokens.append(.op(.gt)); i += 1 }
                case "<": if peek(1) == "=" { tokens.append(.op(.le)); i += 2 } else { tokens.append(.op(.lt)); i += 1 }
                case "'", "\"":
                    let quote = c; i += 1; var str = ""
                    while let ch = peek(), ch != quote {
                        if ch == "\\", let n = peek(1) { str.append(n); i += 2 } else { str.append(ch); i += 1 }
                    }
                    guard peek() == quote else { throw WhenError.syntax("unterminated string") }
                    i += 1; tokens.append(.string(str))
                default:
                    if c.isNumber || (c == "-" && (peek(1)?.isNumber ?? false)) {
                        var num = String(c); i += 1
                        while let ch = peek(), ch.isNumber || ch == "." { num.append(ch); i += 1 }
                        guard let d = Double(num) else { throw WhenError.syntax("bad number \(num)") }
                        tokens.append(.number(d))
                    } else if c.isLetter || c == "_" {
                        var id = String(c); i += 1
                        while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" || ch == "." { id.append(ch); i += 1 }
                        switch id {
                        case "startswith": tokens.append(.op(.startswith))
                        case "endswith": tokens.append(.op(.endswith))
                        case "contains": tokens.append(.op(.contains))
                        case "in": tokens.append(.inKw)
                        case "true": tokens.append(.trueKw)
                        case "false": tokens.append(.falseKw)
                        default: tokens.append(.ident(id))
                        }
                    } else {
                        throw WhenError.syntax("unexpected character '\(c)'")
                    }
                }
            }
            return tokens
        }
    }

    // MARK: - Parser (recursive descent)

    struct Parser {
        let tokens: [Token]
        var pos = 0
        init(tokens: [Token]) { self.tokens = tokens }

        func peek() -> Token? { pos < tokens.count ? tokens[pos] : nil }
        mutating func next() -> Token? { defer { pos += 1 }; return peek() }
        mutating func match(_ t: Token) -> Bool { if peek() == t { pos += 1; return true }; return false }
        func expectEnd() throws { if pos != tokens.count { throw WhenError.syntax("trailing tokens") } }

        mutating func parseExpression() throws -> Node { try parseOr() }

        mutating func parseOr() throws -> Node {
            var lhs = try parseAnd()
            while match(.oror) { lhs = .or(lhs, try parseAnd()) }
            return lhs
        }
        mutating func parseAnd() throws -> Node {
            var lhs = try parseCompare()
            while match(.andand) { lhs = .and(lhs, try parseCompare()) }
            return lhs
        }
        mutating func parseCompare() throws -> Node {
            let lhs = try parseUnary()
            if case .op(let op)? = peek() { pos += 1; return .compare(lhs, op, try parseUnary()) }
            if match(.inKw) {
                guard match(.lparen) else { throw WhenError.syntax("expected ( after in") }
                var items: [Node] = []
                if !match(.rparen) {
                    repeat { items.append(try parseUnary()) } while match(.comma)
                    guard match(.rparen) else { throw WhenError.syntax("expected ) to close in-list") }
                }
                return .inList(lhs, items)
            }
            return lhs
        }
        mutating func parseUnary() throws -> Node {
            if match(.bang) { return .not(try parseUnary()) }
            return try parsePrimary()
        }
        mutating func parsePrimary() throws -> Node {
            switch next() {
            case .lparen:
                let e = try parseOr()
                guard match(.rparen) else { throw WhenError.syntax("expected )") }
                return e
            case .ident(let name): return .ident(name)
            case .string(let s): return .value(.string(s))
            case .number(let d): return .value(d == d.rounded() ? .int(Int(d)) : .string(String(d)))
            case .trueKw: return .value(.bool(true))
            case .falseKw: return .value(.bool(false))
            default: throw WhenError.syntax("expected a value")
            }
        }
    }
}
