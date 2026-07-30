// PosixPermissions.swift - POSIX permission model for Change Attributes (SPEC-016 §2).
//
// Converts between the numeric mode, the symbolic "rwxr-xr-x" form, and octal
// strings, and lets the change-attributes UI toggle individual bits. Pure and
// fully testable; the actual chmod happens through the VFS (AttributeEngine).

import Foundation

public struct PosixPermissions: Equatable, Sendable {
    public enum Who: CaseIterable { case owner, group, other }
    public enum Perm: CaseIterable { case read, write, execute }

    /// The permission bits (low 12 bits: 0o7777, incl. setuid/setgid/sticky).
    public private(set) var mode: UInt16

    public init(mode: UInt16) { self.mode = mode & 0o7777 }

    private static func bit(_ who: Who, _ perm: Perm) -> UInt16 {
        let base: UInt16
        switch who {
        case .owner: base = 0o100
        case .group: base = 0o010
        case .other: base = 0o001
        }
        switch perm {
        case .execute: return base
        case .write: return base << 1
        case .read: return base << 2
        }
    }

    public func has(_ who: Who, _ perm: Perm) -> Bool { mode & Self.bit(who, perm) != 0 }

    public mutating func set(_ who: Who, _ perm: Perm, _ on: Bool) {
        if on { mode |= Self.bit(who, perm) } else { mode &= ~Self.bit(who, perm) }
    }

    /// Symbolic form of the low 9 bits, e.g. "rwxr-xr-x".
    public var symbolic: String {
        var s = ""
        for who in Who.allCases {
            s += has(who, .read) ? "r" : "-"
            s += has(who, .write) ? "w" : "-"
            s += has(who, .execute) ? "x" : "-"
        }
        return s
    }

    /// Octal string of the permission bits (e.g. "755", or "1777" with sticky).
    public var octalString: String {
        let special = (mode >> 9) & 0o7
        let base = String(mode & 0o777, radix: 8)
        let padded = String(repeating: "0", count: Swift.max(0, 3 - base.count)) + base
        return special == 0 ? padded : "\(special)" + padded
    }

    /// Parse an octal permission string ("755", "0644", "1777"). Nil if invalid.
    public static func fromOctal(_ string: String) -> PosixPermissions? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 4,
              trimmed.allSatisfy({ ("0"..."7").contains($0) }),
              let value = UInt16(trimmed, radix: 8) else { return nil }
        return PosixPermissions(mode: value)
    }
}
