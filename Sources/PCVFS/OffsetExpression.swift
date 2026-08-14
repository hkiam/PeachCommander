// SPDX-License-Identifier: Apache-2.0
// OffsetExpression.swift - Arithmetic over mixed number bases for "Go to offset" (F-400).
//
// The viewer's Go To used to take exactly one number, which is the wrong unit of work for the
// question people actually have in front of a hex dump: a structure begins at 0x1000, the field is
// sixteen bytes in, the length prefix is one more. Typing `0x1000 + 15 + 1` says that; 4112 is the
// answer to a sum the reader had to do in their head, and getting it wrong is silent.
//
// Grammar (recursive descent, left-associative):
//
//     expr    := term (('+' | '-') term)*
//     term    := factor (('*' | '/') factor)*
//     factor  := ('+' | '-')* primary
//     primary := number | '(' expr ')'
//
// A number carries its own base, so bases may be mixed freely inside one expression: `0x1000 + 16`,
// `$ff * 2`, `1000h - 0b1010`. Underscores group digits (`0x1000_0000`) and are ignored.
//
// Intermediate values may go negative — `0x10 - 5 - 20 + 10` is a legitimate way to arrive at 1 — but
// the *result* is an offset, so a negative or overflowing one is refused rather than clamped: a
// silently clamped 0 looks exactly like a deliberate jump to the start of the file. Pure and IO-free,
// so the whole grammar is unit-testable without a window.

import Foundation

public enum OffsetExpression {

    /// Evaluate `input` to a non-negative offset, or nil if it is not a well-formed expression.
    ///
    /// A single number is the degenerate case and keeps the exact behaviour of the plain parser:
    /// `HexAddress.parse` is this function, so every caller gained arithmetic at once.
    public static func evaluate(_ input: String) -> Int64? {
        guard let tokens = tokenize(input) else { return nil }
        var parser = Parser(tokens: tokens)
        guard let value = parser.parseExpression(), parser.isAtEnd else { return nil }
        guard value >= 0 else { return nil }
        return value
    }

    // MARK: - Tokens

    private enum Token: Equatable {
        case number(Int64)
        case plus, minus, times, divide
        case openParen, closeParen
    }

    private static func tokenize(_ input: String) -> [Token]? {
        var tokens: [Token] = []
        var chars = Array(input)
        var i = 0
        // `$` is a base marker rather than part of the digit run, so it is peeled off here and the run
        // behind it read as hex — "$ff" and "0xff" then take the same path.
        while i < chars.count {
            let ch = chars[i]
            if ch.isWhitespace { i += 1; continue }
            switch ch {
            case "+": tokens.append(.plus); i += 1; continue
            case "-": tokens.append(.minus); i += 1; continue
            case "*": tokens.append(.times); i += 1; continue
            case "/": tokens.append(.divide); i += 1; continue
            case "(": tokens.append(.openParen); i += 1; continue
            case ")": tokens.append(.closeParen); i += 1; continue
            case "$":
                i += 1
                let run = readRun(chars, &i)
                guard let value = parseDigits(run, radix: 16) else { return nil }
                tokens.append(.number(value))
                continue
            default:
                guard ch.isHexDigit || ch.isLetter || ch == "_" else { return nil }
                let run = readRun(chars, &i)
                guard let value = number(from: run) else { return nil }
                tokens.append(.number(value))
                continue
            }
        }
        return tokens.isEmpty ? nil : tokens
    }

    /// Read one alphanumeric run (the widest thing that could be a number in some base).
    private static func readRun(_ chars: [Character], _ i: inout Int) -> String {
        var run = ""
        while i < chars.count, chars[i].isLetter || chars[i].isNumber || chars[i] == "_" {
            run.append(chars[i])
            i += 1
        }
        return run
    }

    /// Classify one digit run and convert it. The `h` suffix is tested first: "0b1h" is the hex number
    /// 0xB1 and not a binary literal with something stuck to it.
    private static func number(from run: String) -> Int64? {
        let s = run.replacingOccurrences(of: "_", with: "").lowercased()
        guard !s.isEmpty else { return nil }
        if s.hasSuffix("h") {
            return parseDigits(String(s.dropLast()), radix: 16)
        }
        if s.hasPrefix("0x") { return parseDigits(String(s.dropFirst(2)), radix: 16) }
        if s.hasPrefix("0b") { return parseDigits(String(s.dropFirst(2)), radix: 2) }
        if s.hasPrefix("0o") { return parseDigits(String(s.dropFirst(2)), radix: 8) }
        return parseDigits(s, radix: 10)
    }

    private static func parseDigits(_ digits: String, radix: Int) -> Int64? {
        guard !digits.isEmpty, let value = Int64(digits, radix: radix) else { return nil }
        return value
    }

    // MARK: - Parser

    private struct Parser {
        let tokens: [Token]
        var pos = 0

        var isAtEnd: Bool { pos >= tokens.count }

        private func peek() -> Token? { pos < tokens.count ? tokens[pos] : nil }

        mutating func parseExpression() -> Int64? {
            guard var value = parseTerm() else { return nil }
            while let op = peek(), op == .plus || op == .minus {
                pos += 1
                guard let rhs = parseTerm() else { return nil }
                let result = op == .plus ? value.addingReportingOverflow(rhs)
                                         : value.subtractingReportingOverflow(rhs)
                guard !result.overflow else { return nil }
                value = result.partialValue
            }
            return value
        }

        private mutating func parseTerm() -> Int64? {
            guard var value = parseFactor() else { return nil }
            while let op = peek(), op == .times || op == .divide {
                pos += 1
                guard let rhs = parseFactor() else { return nil }
                if op == .times {
                    let result = value.multipliedReportingOverflow(by: rhs)
                    guard !result.overflow else { return nil }
                    value = result.partialValue
                } else {
                    guard rhs != 0 else { return nil }
                    let result = value.dividedReportingOverflow(by: rhs)
                    guard !result.overflow else { return nil }
                    value = result.partialValue
                }
            }
            return value
        }

        private mutating func parseFactor() -> Int64? {
            guard let token = peek() else { return nil }
            if token == .plus {
                pos += 1
                return parseFactor()
            }
            if token == .minus {
                pos += 1
                guard let value = parseFactor() else { return nil }
                let result = Int64(0).subtractingReportingOverflow(value)
                return result.overflow ? nil : result.partialValue
            }
            return parsePrimary()
        }

        private mutating func parsePrimary() -> Int64? {
            switch peek() {
            case .number(let value):
                pos += 1
                return value
            case .openParen:
                pos += 1
                guard let value = parseExpression(), peek() == .closeParen else { return nil }
                pos += 1
                return value
            default:
                return nil
            }
        }
    }
}
