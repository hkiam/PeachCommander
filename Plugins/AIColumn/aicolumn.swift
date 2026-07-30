// aicolumn.swift — AIColumn.pdxplugin: an on-device ML panel column (KI-05).
//
// A content-field (PDX) plugin that adds an "AI Language" column: for a text file it
// detects the dominant natural language with NaturalLanguage's NLLanguageRecognizer
// (fast, on-device, no LLM — so it's practical per-file in a listing, unlike calling a
// chat model for every row). Non-text/undetectable files show blank.

import Foundation
import NaturalLanguage

private let PC_FT_NOMOREFIELDS: Int32 = 0
private let PC_FT_STRING: Int32 = 8
private let PC_FT_NOSUCHFIELD: Int32 = -1
private let PC_FT_FILEERROR: Int32 = -2
private let PC_FT_FIELDEMPTY: Int32 = -3

@_cdecl("PcGetApiVersion") public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ fieldIndex: Int32,
                                     _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?,
                                     _ maxlen: Int32) -> Int32 {
    guard fieldIndex == 0, let fieldName else { return PC_FT_NOMOREFIELDS }
    _ = "AI Language".withCString { strlcpy(fieldName, $0, Int(maxlen)) }
    if let units { units.pointee = 0 }   // no units
    return PC_FT_STRING
}

@_cdecl("ContentGetValue")
public func ContentGetValue(_ fileName: UnsafeMutablePointer<CChar>?,
                            _ fieldIndex: Int32, _ unitIndex: Int32,
                            _ fieldValue: UnsafeMutableRawPointer?, _ maxlen: Int32,
                            _ flags: Int32) -> Int32 {
    guard let fileName, let fieldValue else { return PC_FT_NOSUCHFIELD }
    guard fieldIndex == 0 else { return PC_FT_NOSUCHFIELD }
    let path = String(cString: fileName)
    guard let fh = FileHandle(forReadingAtPath: path) else { return PC_FT_FILEERROR }
    defer { try? fh.close() }
    let data = (try? fh.read(upToCount: 8192)) ?? Data()
    guard !data.isEmpty, let text = String(data: data, encoding: .utf8),
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return PC_FT_FIELDEMPTY }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let lang = recognizer.dominantLanguage else { return PC_FT_FIELDEMPTY }
    let name = Locale(identifier: "en").localizedString(forIdentifier: lang.rawValue) ?? lang.rawValue
    _ = name.withCString { strlcpy(fieldValue.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return PC_FT_STRING
}
