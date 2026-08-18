// SPDX-License-Identifier: Apache-2.0
// WindowsTextFile.swift - Read a text config file that a Windows tool may have written.
//
// Every format this app shares with Total Commander — `.mnu` menu files, `.bar`
// button bars, `usercmd.ini`, `wincmd.ini` — is normally produced on Windows, where
// the file is either ANSI (the user's code page, in practice Windows-1252 for the
// languages TC ships) or UTF-16 with a BOM. Reading such a file as strict UTF-8
// fails on the first umlaut, and `try? String(contentsOf:encoding:.utf8)` turns that
// failure into `nil` — which every caller here reads as "the user has no such file".
// A German `wcmd_deu.mnu` therefore loaded as *no menu file at all*, silently.
//
// The order below is deliberate: a BOM is a statement and is believed; without one,
// valid UTF-8 is UTF-8 (that covers ASCII and everything this app writes itself);
// only bytes that cannot be UTF-8 fall back to the Windows code page. Latin-1 is the
// last resort because it maps all 256 byte values, so decoding never fails and no
// caller has to handle "unreadable" for a file it just found on disk.
//
// Writing stays UTF-8 (see the callers): these files are ours once the user edits
// them here, and every editor on macOS reads UTF-8.

import Foundation

public enum WindowsTextFile {

    /// Decode config-file bytes: BOM first, then UTF-8, then Windows-1252/Latin-1.
    public static func decode(_ data: Data) -> String {
        if data.count >= 3, data[data.startIndex] == 0xEF,
           data[data.index(data.startIndex, offsetBy: 1)] == 0xBB,
           data[data.index(data.startIndex, offsetBy: 2)] == 0xBF {
            return String(decoding: data.dropFirst(3), as: UTF8.self)
        }
        if data.count >= 2, data[data.startIndex] == 0xFF,
           data[data.index(data.startIndex, offsetBy: 1)] == 0xFE {
            return String(data: Data(data.dropFirst(2)), encoding: .utf16LittleEndian) ?? ""
        }
        if data.count >= 2, data[data.startIndex] == 0xFE,
           data[data.index(data.startIndex, offsetBy: 1)] == 0xFF {
            return String(data: Data(data.dropFirst(2)), encoding: .utf16BigEndian) ?? ""
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let cp1252 = String(data: data, encoding: .windowsCP1252) { return cp1252 }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    /// Read and decode `url`, or nil when the bytes cannot be read at all (no such
    /// file, no permission). A file that exists always decodes to *something*, so a
    /// nil here means absence — which is what the callers branch on.
    public static func read(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }
}
