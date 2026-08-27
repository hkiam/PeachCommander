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
// Appended, never renumbered: a saved column set stores the field id derived from the NAME, but
// ContentGetValue is asked by INDEX, so reordering these would hand the panel the wrong column.
private let fieldKind: Int32 = 2
private let fieldTopic: Int32 = 3
private let fieldDate: Int32 = 4

@_cdecl("PcGetApiVersion") public func PcGetApiVersion() -> Int32 { 1 }

/// The column header, in the reader's language.
///
/// The *names* above stay English on purpose: the host derives a stable field id from them, and
/// that id keys saved column sets — and, here, the `[=ai_column.ai_topic]` rename token. Only the
/// header may change with the interface language (F-428).
///
/// This plugin was the only content plugin not exporting it, and had no Resources at all, so the
/// panel said "AI Summary" in every language while sixteen translated help pages named a
/// translated column that did not exist.
@_cdecl("ContentGetSupportedFieldTitle")
public func ContentGetSupportedFieldTitle(_ fieldIndex: Int32,
                                          _ title: UnsafeMutablePointer<CChar>?,
                                          _ maxlen: Int32) -> Int32 {
    guard let title, maxlen > 0 else { return 0 }
    let text: String
    switch fieldIndex {
    case fieldSummary:  text = L("AI Summary")
    case fieldLanguage: text = L("Language")
    case fieldKind:     text = L("AI Kind")
    case fieldTopic:    text = L("AI Topic")
    case fieldDate:     text = L("AI Date")
    default: return 0
    }
    _ = text.withCString { strlcpy(title, $0, Int(maxlen)) }
    return 1
}

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ fieldIndex: Int32,
                                     _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?,
                                     _ maxlen: Int32) -> Int32 {
    guard let fieldName else { return PC_FT_NOMOREFIELDS }
    let name: String
    // English, always: the host slugs these into the field ids that key saved column sets and the
    // `[=ai_column.ai_topic]` rename token. The header the reader sees comes from
    // ContentGetSupportedFieldTitle above.
    switch fieldIndex {
    case fieldSummary:  name = "AI Summary"
    case fieldLanguage: name = "Language"
    case fieldKind:     name = "AI Kind"
    case fieldTopic:    name = "AI Topic"
    case fieldDate:     name = "AI Date"
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
    case fieldKind:     return factValue(path: path, out: fieldValue, maxlen: maxlen) { $0.kind }
    case fieldTopic:    return factValue(path: path, out: fieldValue, maxlen: maxlen) { $0.topic }
    case fieldDate:     return factValue(path: path, out: fieldValue, maxlen: maxlen) { $0.date }
    default: return PC_FT_NOSUCHFIELD
    }
}

// MARK: - The short facts (kind / topic / date)

/// One record as `FileFactStore` writes it. Decoded rather than linked, for the same reason the
/// summary record is: a content field is a small dylib the panel calls per row, and PCAutomation
/// is not part of that world.
///
/// These three are what make a rename mask like `[=ai_column.ai_topic]-[Y]-[M].[E]` work: the
/// multi-rename engine resolves `[=provider.field]` through the content-field registry, so a value
/// that lands here is a rename token without anything new being built.
private struct StoredFacts: Decodable {
    struct Facts: Decodable { var kind: String; var topic: String; var date: String }
    let facts: Facts
}

private final class FactCache {
    static let shared = FactCache()
    private var records: [String: StoredFacts] = [:]
    private var stamp: Date?
    private let lock = NSLock()

    /// Beside the summaries, under the configuration directory the host is actually using.
    private var url: URL {
        if let root = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root).appendingPathComponent("aichat/facts.json")
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("PeachCommander/aichat/facts.json")
    }

    func facts(path: String, size: Int64, modified: Double) -> StoredFacts.Facts? {
        reloadIfChanged()
        lock.lock(); defer { lock.unlock() }
        return records["\(path)|\(size)|\(modified)"]?.facts
    }

    private func reloadIfChanged() {
        let target = url
        let modified = (try? FileManager.default.attributesOfItem(atPath: target.path)[.modificationDate])
            as? Date
        lock.lock(); defer { lock.unlock() }
        guard modified != stamp else { return }
        stamp = modified
        records = (try? Data(contentsOf: target)).flatMap {
            try? JSONDecoder().decode([String: StoredFacts].self, from: $0)
        } ?? [:]
    }
}

private func factValue(path: String, out: UnsafeMutableRawPointer, maxlen: Int32,
                       _ pick: (StoredFacts.Facts) -> String) -> Int32 {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
          let size = (attributes[.size] as? NSNumber)?.int64Value,
          // Since the REFERENCE date, which is what the writer's fingerprint carries.
          let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate else {
        return PC_FT_FILEERROR
    }
    guard let facts = FactCache.shared.facts(path: path, size: size, modified: modified) else {
        return PC_FT_FIELDEMPTY
    }
    let value = pick(facts)
    guard !value.isEmpty else { return PC_FT_FIELDEMPTY }
    _ = value.withCString { strlcpy(out.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return PC_FT_STRING
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

    /// `aichat/summaries.json` under the configuration directory the host is actually using.
    ///
    /// A content plugin is handed a file name and nothing else — no services table, no host token —
    /// so this used to read the default location and miss an isolated session entirely. The host
    /// now publishes its resolved root as `PEACHCMD_CONFIG_ROOT` (the same variable ConfigPaths
    /// already accepts on the way in), so the two agree; the default remains the fallback for an
    /// older host that publishes nothing.
    private var url: URL {
        if let root = ProcessInfo.processInfo.environment["PEACHCMD_CONFIG_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root).appendingPathComponent("aichat/summaries.json")
        }
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
          // Since the REFERENCE date (2001), because that is what JSONEncoder writes for a Date and
          // therefore what the writer's fingerprint carries. Using the 1970 epoch here meant the two
          // sides differed by 978307200 on every single file, so the column was always empty — and
          // being always empty is indistinguishable from having nothing to show.
          let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate else {
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
