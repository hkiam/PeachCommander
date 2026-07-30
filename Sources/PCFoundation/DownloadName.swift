// SPDX-License-Identifier: Apache-2.0
// DownloadName.swift - Suggest + sanitize a filename for an HTTP download (F-330).
//
// wget-style: derive a clean, safe filename from the URL (or a server-provided
// Content-Disposition header), so the download dialog can pre-fill a sensible,
// editable name for the target folder.

import Foundation

public enum DownloadName {
    /// A clean filename for downloading `urlString`, preferring the server's
    /// Content-Disposition `filename` when present, else the URL's last path
    /// component. Always returns a non-empty, filesystem-safe name.
    public static func suggested(fromURL urlString: String, contentDisposition: String? = nil) -> String {
        if let cd = contentDisposition, let name = filename(fromContentDisposition: cd) {
            let clean = sanitize(name)
            if !clean.isEmpty { return clean }
        }
        // Last path component of the URL, without query/fragment, percent-decoded.
        let comp = URLComponents(string: urlString)
        let path = comp?.path ?? urlString
        var last = path.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? ""
        last = last.removingPercentEncoding ?? last
        let clean = sanitize(last)
        if !clean.isEmpty { return clean }
        // Fall back to the host, else a generic name.
        if let host = comp?.host, !host.isEmpty { return sanitize(host).isEmpty ? "download" : sanitize(host) }
        return "download"
    }

    /// Make a filename safe for a single filesystem component: strip path
    /// separators / control chars, collapse blanks, trim, and bound the length.
    public static func sanitize(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace path separators (incl. the macOS ":" display separator) + control
        // characters with underscores.
        let scalars = s.unicodeScalars.map { scalar -> Character in
            if scalar == "/" || scalar == ":" || scalar == "\\" { return "_" }
            if scalar.value < 0x20 || scalar.value == 0x7F { return "_" }
            return Character(scalar)
        }
        s = String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
        // A name of only dots ("." / "..") is unusable.
        if s == "." || s == ".." { s = "" }
        // Bound the length (leave room for a ".part" suffix / collision counter).
        if s.utf8.count > 200 { s = String(s.prefix(200)) }
        return s
    }

    /// Extract the filename from a Content-Disposition header value, honoring the
    /// RFC 5987 `filename*=UTF-8''…` form as well as a plain quoted `filename=`.
    public static func filename(fromContentDisposition header: String) -> String? {
        // Prefer the extended `filename*=charset'lang'pct-encoded` form.
        if let range = header.range(of: "filename*=", options: .caseInsensitive) {
            var value = String(header[range.upperBound...])
            value = value.split(separator: ";").first.map(String.init) ?? value
            value = value.trimmingCharacters(in: .whitespaces)
            // Strip the "charset'lang'" prefix, then percent-decode.
            if let tick = value.range(of: "''") { value = String(value[tick.upperBound...]) }
            return (value.removingPercentEncoding ?? value)
        }
        if let range = header.range(of: "filename=", options: .caseInsensitive) {
            var value = String(header[range.upperBound...])
            value = value.split(separator: ";").first.map(String.init) ?? value
            value = value.trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }
}
