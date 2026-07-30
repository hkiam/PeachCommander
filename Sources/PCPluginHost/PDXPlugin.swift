// SPDX-License-Identifier: Apache-2.0
// PDXPlugin.swift - PDX content plugin adapter (I16 T03).
//
// Drives a loaded PDX plugin's C ABI (pdx.h via the CPDX module): enumerate the
// fields it offers (ContentGetSupportedField over 0,1,2,… until PC_FT_NOMOREFIELDS)
// and pull a typed value per file (ContentGetValue). This is the external analogue
// of the built-in ContentFieldProvider; PDXContentProvider (below) bridges it into
// the PCVFS content-field registry so plugin fields work as custom columns, search
// criteria, and multi-rename placeholders exactly like the internal ones.

import Foundation
import CPDX
import PCVFS

/// The type of a PDX field, mapped from the C ABI's PC_FT_* codes so callers
/// never touch the raw constants.
public enum PDXFieldKind: Equatable, Sendable {
    case numeric32, numeric64, floating, boolean
    case string, fullText, multipleChoice, dateTime
    case other(Int32)

    init(rawType: Int32) {
        switch Int(rawType) {
        case Int(PC_FT_NUMERIC_32): self = .numeric32
        case Int(PC_FT_NUMERIC_64): self = .numeric64
        case Int(PC_FT_NUMERIC_FLOATING): self = .floating
        case Int(PC_FT_BOOLEAN): self = .boolean
        case Int(PC_FT_STRING): self = .string
        case Int(PC_FT_FULLTEXT): self = .fullText
        case Int(PC_FT_MULTIPLECHOICE): self = .multipleChoice
        case Int(PC_FT_DATETIME): self = .dateTime
        default: self = .other(rawType)
        }
    }
}

public final class PDXPlugin: @unchecked Sendable {
    /// One field advertised by the plugin.
    public struct SupportedField: Equatable, Sendable {
        public let index: Int
        public let name: String
        public let units: [String]   // parsed from the plugin's '|'-separated units
        public let kind: PDXFieldKind
    }

    public enum PDXError: Error, Equatable {
        case missingSymbol(String)
    }

    private let lib: PluginLibrary

    public init(library: PluginLibrary) { self.lib = library }

    // C function-pointer signatures (pdx.h).
    private typealias SupportedFn = @convention(c) (Int32, UnsafeMutablePointer<CChar>?,
                                                    UnsafeMutablePointer<CChar>?, Int32) -> Int32
    private typealias GetValueFn = @convention(c) (UnsafeMutablePointer<CChar>?, Int32, Int32,
                                                   UnsafeMutableRawPointer?, Int32, Int32) -> Int32
    private typealias SetValueFn = @convention(c) (UnsafeMutablePointer<CChar>?, Int32, Int32,
                                                   Int32, UnsafeMutableRawPointer?, Int32) -> Int32
    private typealias CompareFn = @convention(c) (Int32, UnsafeMutablePointer<CChar>?,
                                                  UnsafeMutablePointer<CChar>?, Int32) -> Int32

    /// The buffer size handed to the plugin for names and string values.
    private static let bufferCapacity = 1024

    // MARK: - Public API

    /// Enumerate every field the plugin supports, in declaration order.
    public func supportedFields() throws -> [SupportedField] {
        guard let ptr = lib.symbol("ContentGetSupportedField") else {
            throw PDXError.missingSymbol("ContentGetSupportedField")
        }
        let fn = unsafeBitCast(ptr, to: SupportedFn.self)
        let cap = Self.bufferCapacity
        var out: [SupportedField] = []
        var index: Int32 = 0
        while true {
            var nameBuf = [CChar](repeating: 0, count: cap)
            var unitsBuf = [CChar](repeating: 0, count: cap)
            let type = nameBuf.withUnsafeMutableBufferPointer { nb in
                unitsBuf.withUnsafeMutableBufferPointer { ub in
                    fn(index, nb.baseAddress, ub.baseAddress, Int32(cap))
                }
            }
            if Int(type) == Int(PC_FT_NOMOREFIELDS) { break }
            let unitsStr = String(cString: unitsBuf)
            let units = unitsStr.isEmpty ? [] : unitsStr.split(separator: "|").map(String.init)
            out.append(SupportedField(index: Int(index), name: String(cString: nameBuf),
                                      units: units, kind: PDXFieldKind(rawType: type)))
            index += 1
            if index > 4096 { break }   // runaway-plugin backstop
        }
        return out
    }

    /// Fetch one field's value for a local file, decoded to a `ContentValue`.
    public func value(fileName: String, fieldIndex: Int, unitIndex: Int = 0,
                      flags: Int32 = 0) throws -> ContentValue {
        guard let ptr = lib.symbol("ContentGetValue") else {
            throw PDXError.missingSymbol("ContentGetValue")
        }
        let fn = unsafeBitCast(ptr, to: GetValueFn.self)
        let cap = Self.bufferCapacity
        var buf = [UInt8](repeating: 0, count: cap)
        let rc = fileName.withCString { fp -> Int32 in
            let mutable = UnsafeMutablePointer(mutating: fp)
            return buf.withUnsafeMutableBytes { raw in
                fn(mutable, Int32(fieldIndex), Int32(unitIndex), raw.baseAddress, Int32(cap), flags)
            }
        }
        return Self.decode(type: rc, buffer: buf)
    }

    /// Write a field value back to `fileName` via the plugin's optional
    /// `ContentSetValue` (F-234). Returns the written PC_FT_* type, or nil if the
    /// plugin doesn't export ContentSetValue.
    @discardableResult
    public func setValue(fileName: String, fieldIndex: Int, unitIndex: Int = 0,
                         value: ContentValue, flags: Int32 = 0) -> Int32? {
        guard let ptr = lib.symbol("ContentSetValue") else { return nil }
        let fn = unsafeBitCast(ptr, to: SetValueFn.self)
        var buf = [UInt8](repeating: 0, count: Self.bufferCapacity)
        let type: Int32
        switch value {
        case .string(let s):
            let bytes = Array(s.utf8.prefix(Self.bufferCapacity - 1))
            buf.replaceSubrange(0..<bytes.count, with: bytes)   // NUL already present
            type = Int32(PC_FT_STRING)
        case .integer(let i):
            withUnsafeBytes(of: i.littleEndian) { buf.replaceSubrange(0..<8, with: $0) }
            type = Int32(PC_FT_NUMERIC_64)
        case .none:
            type = Int32(PC_FT_FIELDEMPTY)
        }
        return fileName.withCString { fp -> Int32 in
            let mutable = UnsafeMutablePointer(mutating: fp)
            return buf.withUnsafeMutableBytes { raw in
                fn(mutable, Int32(fieldIndex), Int32(unitIndex), type, raw.baseAddress, flags)
            }
        }
    }

    /// Compare two files by `fieldIndex` via the plugin's optional
    /// `ContentCompareFiles` (F-234). Returns -1/0/1 (PC_CMP_LESS/EQUAL/GREATER),
    /// or nil if the plugin doesn't export it / can't compare (PC_CMP_NOTSUPPORTED).
    public func compareFiles(fieldIndex: Int, file1: String, file2: String, flags: Int32 = 0) -> Int32? {
        guard let ptr = lib.symbol("ContentCompareFiles") else { return nil }
        let fn = unsafeBitCast(ptr, to: CompareFn.self)
        let rc = file1.withCString { f1 in
            file2.withCString { f2 in
                fn(Int32(fieldIndex), UnsafeMutablePointer(mutating: f1),
                   UnsafeMutablePointer(mutating: f2), flags)
            }
        }
        return rc == Int32(PC_CMP_NOTSUPPORTED) ? nil : rc
    }

    // MARK: - Value decoding

    /// Interpret the plugin's out-buffer according to the returned PC_FT_* type.
    static func decode(type: Int32, buffer: [UInt8]) -> ContentValue {
        switch Int(type) {
        case Int(PC_FT_NUMERIC_32), Int(PC_FT_BOOLEAN):
            let v = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
            return .integer(Int64(v))
        case Int(PC_FT_NUMERIC_64), Int(PC_FT_DATETIME):
            let v = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
            return .integer(v)
        case Int(PC_FT_NUMERIC_FLOATING):
            let v = buffer.withUnsafeBytes { $0.loadUnaligned(as: Double.self) }
            return .string(String(v))
        case Int(PC_FT_STRING), Int(PC_FT_FULLTEXT), Int(PC_FT_MULTIPLECHOICE):
            let s = buffer.withUnsafeBytes { raw -> String in
                guard let base = raw.bindMemory(to: CChar.self).baseAddress else { return "" }
                return String(cString: base)
            }
            return .string(s)
        default:
            // Negative status codes (PC_FT_NOSUCHFIELD/FILEERROR/FIELDEMPTY/…) and
            // types we do not surface (DATE/TIME structs) resolve to "no value".
            return .none
        }
    }
}

/// Bridges a loaded PDX plugin into the PCVFS content-field registry so its
/// fields behave like any built-in provider (columns, search, multi-rename).
public struct PDXContentProvider: ContentFieldProvider {
    public let providerName: String
    public let fields: [ContentField]
    private let fieldIndexByID: [String: Int]
    private let plugin: PDXPlugin

    /// Enumerate the plugin's fields up front and map each to a stable field id.
    public init(providerName: String, plugin: PDXPlugin) throws {
        self.providerName = providerName
        self.plugin = plugin
        var fields: [ContentField] = []
        var map: [String: Int] = [:]
        for f in try plugin.supportedFields() {
            let id = Self.fieldID(f.name)
            fields.append(ContentField(id: id, title: f.name, unit: f.units.first))
            map[id] = f.index
        }
        self.fields = fields
        self.fieldIndexByID = map
    }

    public func value(fieldID: String, forFileAt url: URL) async -> ContentValue {
        guard let index = fieldIndexByID[fieldID] else { return .none }
        return (try? plugin.value(fileName: url.path, fieldIndex: index)) ?? .none
    }

    /// A stable, qualified-id-safe slug for a human field name ("Name Length" → "name_length").
    static func fieldID(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }
}
