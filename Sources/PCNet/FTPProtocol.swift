// FTPProtocol.swift - Pure parsing of FTP control-channel replies (SPEC-011 §3).
//
// The tricky, error-prone parts of an FTP client are reply framing (single vs.
// multiline replies per RFC 959) and decoding passive-mode addresses. These are
// isolated here as pure functions so they can be verified against canned server
// dialogs (SPEC-011 §7) without any socket.

import Foundation

/// A parsed FTP control reply.
public struct FTPReply: Equatable, Sendable {
    public var code: Int
    /// The reply text with the leading codes stripped, lines joined by "\n".
    public var text: String

    public init(code: Int, text: String) { self.code = code; self.text = text }

    /// 1xx positive preliminary.
    public var isPreliminary: Bool { (100..<200).contains(code) }
    /// 2xx success.
    public var isSuccess: Bool { (200..<300).contains(code) }
    /// 3xx positive intermediate (more input needed, e.g. 331 need password).
    public var isIntermediate: Bool { (300..<400).contains(code) }
    /// 4xx/5xx failure (transient / permanent).
    public var isError: Bool { code >= 400 }
}

public enum FTPReplyParser {
    /// Whether `buffer` (raw text received so far) contains a complete reply.
    /// A reply is complete when a line matches `NNN␠…` where NNN is the reply
    /// code from the first line (RFC 959 multiline framing).
    public static func isComplete(_ buffer: String) -> Bool {
        let lines = splitLines(buffer)
        guard let firstCode = replyCode(lines.first ?? "") else { return false }
        // Single-line reply: `NNN␠…` on the first line and it's the only marker.
        for line in lines {
            if line.count >= 4 {
                let idx = line.index(line.startIndex, offsetBy: 3)
                if line[idx] == " ", let c = replyCode(line), c == firstCode {
                    return true
                }
            }
        }
        return false
    }

    /// Parse a complete reply buffer into an `FTPReply`.
    public static func parse(_ buffer: String) -> FTPReply? {
        let lines = splitLines(buffer)
        guard let first = lines.first, let code = replyCode(first) else { return nil }
        var messages: [String] = []
        for line in lines {
            // Strip a leading `NNN` + separator (`-` or ` `) when present.
            if line.count >= 4, replyCode(line) == code {
                let sepIdx = line.index(line.startIndex, offsetBy: 3)
                messages.append(String(line[line.index(after: sepIdx)...]))
            } else {
                messages.append(line)
            }
        }
        return FTPReply(code: code, text: messages.joined(separator: "\n"))
    }

    /// The 3-digit code prefixing a reply line, if any.
    static func replyCode(_ line: String) -> Int? {
        guard line.count >= 3 else { return nil }
        let prefix = line.prefix(3)
        guard prefix.allSatisfy(\.isNumber), let code = Int(prefix) else { return nil }
        // Must be followed by a space or hyphen (or be exactly 3 chars).
        if line.count == 3 { return code }
        let sep = line[line.index(line.startIndex, offsetBy: 3)]
        return (sep == " " || sep == "-") ? code : nil
    }

    private static func splitLines(_ s: String) -> [String] {
        s.replacingOccurrences(of: "\r\n", with: "\n")
         .replacingOccurrences(of: "\r", with: "\n")
         .split(separator: "\n", omittingEmptySubsequences: true)
         .map(String.init)
    }
}

/// Decodes the data-channel address from PASV/EPSV replies.
public enum FTPDataAddress {
    /// `227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)` → ("h1.h2.h3.h4", p1*256+p2).
    public static func parsePASV(_ text: String) -> (host: String, port: Int)? {
        guard let open = text.lastIndex(of: "("), let close = text.lastIndex(of: ")"), open < close else {
            // Some servers omit parentheses; fall back to the last 6-number run.
            return parsePASVNumbers(text)
        }
        let inner = String(text[text.index(after: open)..<close])
        return parsePASVNumbers(inner)
    }

    private static func parsePASVNumbers(_ s: String) -> (host: String, port: Int)? {
        let parts = s.split(whereSeparator: { $0 == "," || $0 == " " }).compactMap { Int($0) }
        guard parts.count >= 6 else { return nil }
        let n = parts.suffix(6)
        let a = Array(n)
        guard a.allSatisfy({ $0 >= 0 && $0 <= 255 }) else { return nil }
        let host = "\(a[0]).\(a[1]).\(a[2]).\(a[3])"
        let port = a[4] * 256 + a[5]
        return (host, port)
    }

    /// `229 Entering Extended Passive Mode (|||port|)` → port (host reused from control).
    public static func parseEPSV(_ text: String) -> Int? {
        guard let open = text.lastIndex(of: "("), let close = text.lastIndex(of: ")"), open < close else { return nil }
        let inner = text[text.index(after: open)..<close]     // e.g. |||49152|
        let fields = inner.split(separator: "|", omittingEmptySubsequences: false)
        // Format is <d><d><d><tcp-port><d>; the port is the last non-empty field.
        for field in fields.reversed() where !field.isEmpty {
            if let p = Int(field) { return p }
        }
        return nil
    }
}
