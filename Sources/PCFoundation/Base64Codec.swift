// SPDX-License-Identifier: Apache-2.0
// Base64Codec.swift - Base64 encode/decode for the Encode/Decode feature (SPEC-016 §5).
//
// Thin, well-defined wrapper over Foundation so callers get a stable API with
// MIME line-wrapping control. Output matches RFC 4648 / the system `base64` tool.

import Foundation

public enum Base64Codec {
    /// Encode bytes to a Base64 string. When `wrap` is true, lines are wrapped at
    /// 76 characters with LF terminators (MIME style, like `base64`).
    public static func encode(_ data: Data, wrap: Bool = true) -> String {
        if wrap {
            return data.base64EncodedString(options: [.lineLength76Characters, .endLineWithLineFeed])
        }
        return data.base64EncodedString()
    }

    /// Decode a Base64 string, ignoring whitespace/newlines. Returns nil if the
    /// input is not valid Base64.
    public static func decode(_ text: String) -> Data? {
        Data(base64Encoded: text, options: .ignoreUnknownCharacters)
    }
}
