// SPDX-License-Identifier: Apache-2.0
// TextEncodingChoice.swift - The text encodings the Lister lets the user pick.
//
// The text viewer auto-detects an encoding by default (EncodingDetector); this is
// the explicit override list cycled with `e` in the viewer. Kept as a small ordered
// enum so it is easy to test and to surface in a menu later.

import Foundation

public enum TextEncodingChoice: String, CaseIterable, Sendable {
    case utf8 = "UTF-8"
    case utf16le = "UTF-16 LE"
    case utf16be = "UTF-16 BE"
    case isoLatin1 = "ISO-8859-1"
    case windows1252 = "Windows-1252"
    case macRoman = "Mac Roman"
    case ascii = "ASCII"

    public var encoding: String.Encoding {
        switch self {
        case .utf8: return .utf8
        case .utf16le: return .utf16LittleEndian
        case .utf16be: return .utf16BigEndian
        case .isoLatin1: return .isoLatin1
        case .windows1252: return .windowsCP1252
        case .macRoman: return .macOSRoman
        case .ascii: return .ascii
        }
    }

    public var displayName: String { rawValue }

    /// The choice matching a String.Encoding, if one is listed.
    public static func from(_ encoding: String.Encoding) -> TextEncodingChoice? {
        allCases.first { $0.encoding == encoding }
    }
}
