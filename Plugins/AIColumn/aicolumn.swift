// SPDX-License-Identifier: Apache-2.0
// aicolumn.swift — AIColumn.pdxplugin: two panel columns about a file's content.
//
// "AI Summary" shows what the assistant worked out about a file: `summarize_file` reads a file
// in slices and folds the slice summaries into one, and keeps the result (aichat/summaries.json).
// This column shows it, so a folder the assistant has looked through can be read at a glance
// instead of one chat answer at a time. Files it has not summarised stay blank — the column
// reports work already done and never starts a model itself: a content field is asked for a
// value per row, synchronously, while the panel draws.
//
// "Language" detects the dominant natural language with NLLanguageRecognizer — fast, on-device,
// no model. It used to be called "AI Language", which promised something it did not do; the name
// now says what it is.

import Foundation
import NaturalLanguage

private let PC_FT_NOMOREFIELDS: Int32 = 0
private let PC_FT_STRING: Int32 = 8
private let PC_FT_NOSUCHFIELD: Int32 = -1
private let PC_FT_FILEERROR: Int32 = -2
private let PC_FT_FIELDEMPTY: Int32 = -3

private let fieldSummary: Int32 = 0
private let fieldLanguage: Int32 = 1

@_cdecl("PcGetApiVersion") public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ fieldIndex: Int32,
                                     _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?,
                                     _ maxlen: Int32) -> Int32 {
    guard let fieldName else { return PC_FT_NOMOREFIELDS }
    let name: String
    switch fieldIndex {
    case fieldSummary:  name = "AI Summary"
    case fieldLanguage: name = "Language"
    default: return PC_FT_NOMOREFIELDS
    }
    _ = name.withCString { strlcpy(fieldName, $0, Int(maxlen)) }
    if let units { units.pointee = 0 }   // no units
    return PC_FT_STRING
}

@_cdecl("ContentGetValue")
public func ContentGetValue(_ fileName: UnsafeMutablePointer<CChar>?,
                            _ fieldIndex: Int32, _ unitIndex: Int32,
                            _ fieldValue: UnsafeMutableRawPointer?, _ maxlen: Int32,
                            _ flags: Int32) -> Int32 {
    guard let fileName, let fieldValue else { return PC_FT_NOSUCHFIELD }
    let path = String(cString: fileName)
    switch fieldIndex {
    case fieldSummary:  return summaryValue(path: path, out: fieldValue, maxlen: maxlen)
    case fieldLanguage: return languageValue(path: path, out: fieldValue, maxlen: maxlen)
    default: return PC_FT_NOSUCHFIELD
    }
}

// MARK: - AI Summary

/// One record as `SummaryStore` writes it. Decoded here rather than linked, because a content
/// plugin is a small dylib the panel calls per row and PCAutomation is not part of that world.
private struct StoredSummary: Decodable {
    let path: String
    let summary: String
    let at: Double
}

/// The store, read once and re-read when the file on disk changes. A panel draws hundreds of
/// rows; parsing the whole map for each one would be the column's cost, not the model's.
private final class SummaryCache {
    static let shared = SummaryCache()
    private var records: [String: StoredSummary] = [:]
    private var stamp: Date?
    private let lock = NSLock()

    /// `aichat/summaries.json` under the app's configuration directory.
    ///
    /// The default location, not the running app's `-ConfigRoot`: a content plugin is handed a
    /// file name and nothing else — no services, no host token — so an isolated session's
    /// summaries are not visible here. That only affects test runs, which have none.
    private var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("PeachCommander/aichat/summaries.json")
    }

    func summary(path: String, size: Int64, modified: Double) -> String? {
        reloadIfChanged()
        lock.lock(); defer { lock.unlock() }
        // Keyed by what the file is now, so an edited file does not show a stale summary.
        return records["\(path)|\(size)|\(modified)"]?.summary
    }

    private func reloadIfChanged() {
        let target = url
        let modified = (try? FileManager.default.attributesOfItem(atPath: target.path)[.modificationDate])
            as? Date
        lock.lock(); defer { lock.unlock() }
        guard modified != stamp else { return }
        stamp = modified
        records = (try? Data(contentsOf: target)).flatMap {
            try? JSONDecoder().decode([String: StoredSummary].self, from: $0)
        } ?? [:]
    }
}

private func summaryValue(path: String, out: UnsafeMutableRawPointer, maxlen: Int32) -> Int32 {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let size = (attributes[.size] as? NSNumber)?.int64Value,
          let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 else {
        return PC_FT_FILEERROR
    }
    guard let summary = SummaryCache.shared.summary(path: path, size: size, modified: modified),
          !summary.isEmpty else { return PC_FT_FIELDEMPTY }
    // One line: a column is a line. The whole summary stays in the chat.
    let line = summary.split(whereSeparator: \.isNewline).first.map(String.init) ?? summary
    _ = line.withCString { strlcpy(out.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return PC_FT_STRING
}

// MARK: - Language

private func languageValue(path: String, out: UnsafeMutableRawPointer, maxlen: Int32) -> Int32 {
    guard let handle = FileHandle(forReadingAtPath: path) else { return PC_FT_FILEERROR }
    defer { try? handle.close() }
    let data = (try? handle.read(upToCount: 8192)) ?? Data()
    guard !data.isEmpty, let text = String(data: data, encoding: .utf8),
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return PC_FT_FIELDEMPTY }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let language = recognizer.dominantLanguage else { return PC_FT_FIELDEMPTY }
    let name = Locale(identifier: "en").localizedString(forIdentifier: language.rawValue)
        ?? language.rawValue
    _ = name.withCString { strlcpy(out.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return PC_FT_STRING
}
