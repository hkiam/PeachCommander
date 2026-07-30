// SPDX-License-Identifier: Apache-2.0
// ContentFieldPredicate.swift - Search by content-plugin field (SPEC-012 §5, F-157).
//
// A single "field OP value" condition (e.g. `fileinfo.width > 1000`) plus a helper
// that filters files by resolving the field through a ContentFieldRegistry. Pure
// comparison logic (numeric when both sides are integers, else string), so it is
// unit-testable; the Find-Files dialog rows compose these later.

import Foundation

public enum ContentOperator: String, Sendable, CaseIterable {
    case equals = "="
    case notEquals = "!="
    case greater = ">"
    case less = "<"
    case greaterEqual = ">="
    case lessEqual = "<="
    case contains = "~"
}

public struct ContentFieldPredicate: Sendable, Equatable {
    public let qualifiedID: String
    public let op: ContentOperator
    public let value: String

    public init(qualifiedID: String, op: ContentOperator, value: String) {
        self.qualifiedID = qualifiedID
        self.op = op
        self.value = value
    }

    /// Parse a `field OP value` expression (e.g. `fileinfo.width > 1000` or
    /// `media.duration >= 10min`) into a predicate, or nil if it does not parse.
    /// Operators are matched longest-first so `>=`/`<=`/`!=` win over `>`/`<`/`=`.
    public static func parse(_ text: String) -> ContentFieldPredicate? {
        // Longest operators first so ">=" isn't mis-split as ">".
        let ops: [ContentOperator] = [.greaterEqual, .lessEqual, .notEquals, .equals, .greater, .less, .contains]
        for op in ops {
            guard let r = text.range(of: op.rawValue) else { continue }
            let lhs = String(text[text.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rhs = String(text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !lhs.isEmpty, !rhs.isEmpty else { return nil }
            return ContentFieldPredicate(qualifiedID: lhs, op: op, value: rhs)
        }
        return nil
    }

    /// Evaluate this predicate against a resolved field value. `.none` never matches.
    public func evaluate(_ v: ContentValue) -> Bool {
        if case .none = v { return false }
        let rhsTrimmed = value.trimmingCharacters(in: .whitespaces)
        switch op {
        case .greater, .less, .greaterEqual, .lessEqual:
            guard let lhs = Self.numeric(v), let rhs = Self.parseQuantity(rhsTrimmed) else { return false }
            switch op {
            case .greater: return lhs > rhs
            case .less: return lhs < rhs
            case .greaterEqual: return lhs >= rhs
            case .lessEqual: return lhs <= rhs
            default: return false
            }
        case .equals, .notEquals:
            let eq: Bool
            if let lhs = Self.numeric(v), let rhs = Self.parseQuantity(rhsTrimmed) {
                eq = lhs == rhs
            } else {
                eq = v.display.caseInsensitiveCompare(rhsTrimmed) == .orderedSame
            }
            return op == .equals ? eq : !eq
        case .contains:
            return v.display.range(of: value, options: .caseInsensitive) != nil
        }
    }

    private static func numeric(_ v: ContentValue) -> Int64? {
        switch v {
        case .integer(let i): return i
        case .string(let s): return Int64(s.trimmingCharacters(in: .whitespaces))
        case .none: return nil
        }
    }

    /// Parse a numeric RHS with an optional unit suffix (F-157): plain integers,
    /// time (`s`/`sec`/`min`/`h` → seconds) or size (`b`/`kb`/`mb`/`gb` → bytes,
    /// 1024-based). Case-insensitive; nil if it isn't a quantity.
    static func parseQuantity(_ s: String) -> Int64? {
        let lower = s.lowercased()
        if let plain = Int64(lower) { return plain }
        // Split leading digits from a trailing unit.
        let digits = lower.prefix { $0.isNumber }
        guard !digits.isEmpty, let n = Int64(digits) else { return nil }
        let unit = lower[digits.endIndex...].trimmingCharacters(in: .whitespaces)
        switch unit {
        case "s", "sec": return n
        case "min", "m": return n * 60
        case "h": return n * 3600
        case "b": return n
        case "kb", "k": return n * 1024
        case "mb": return n * 1024 * 1024
        case "gb": return n * 1024 * 1024 * 1024
        default: return nil
        }
    }
}

public extension ContentFieldRegistry {
    /// Return the files (by URL) whose resolved field satisfies `predicate`.
    func filter(_ urls: [URL], matching predicate: ContentFieldPredicate) async -> [URL] {
        var out: [URL] = []
        for url in urls {
            let v = await value(qualifiedID: predicate.qualifiedID, forFileAt: url)
            if predicate.evaluate(v) { out.append(url) }
        }
        return out
    }
}
