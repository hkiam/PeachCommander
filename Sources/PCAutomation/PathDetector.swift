// PathDetector.swift - find absolute file paths in model/tool text so the chat can
// render them as clickable links (reveal / open in the file manager). Pure + testable.

import Foundation

public struct PathMatch: Sendable, Equatable {
    public let path: String
    public let range: NSRange
    public init(path: String, range: NSRange) { self.path = path; self.range = range }
}

public enum PathDetector {
    // A "/" at a token boundary followed by path characters (no whitespace/quotes/brackets).
    private static let regex = try! NSRegularExpression(pattern: #"(?<!\S)/[^\s"'\]\)\}<>]+"#)
    private static let trailingPunctuation = Set(".,;:!?)]}")

    /// Absolute-path substrings in `text`, each with the NSRange (in the trimmed path).
    public static func detect(in text: String) -> [PathMatch] {
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: all).compactMap { m in
            var range = m.range
            var s = ns.substring(with: range)
            while let last = s.last, trailingPunctuation.contains(last) {
                s.removeLast(); range.length -= 1
            }
            guard s.count > 1 else { return nil }   // ignore a lone "/"
            return PathMatch(path: s, range: range)
        }
    }
}
