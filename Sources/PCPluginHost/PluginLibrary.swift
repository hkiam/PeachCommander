// SPDX-License-Identifier: Apache-2.0
// PluginLibrary.swift - dlopen/dlsym symbol resolution + version handshake (I14 T02).
//
// Opens a plugin dylib with RTLD_LOCAL|RTLD_NOW, resolves its required and optional
// exports into a symbol table, and performs the optional PcGetApiVersion handshake.
// Missing required symbols and version mismatches are reported as structured errors.
// The library is dlclose()d on deinit ONLY if the plugin exports PcSafeToUnload
// (TC-like pragmatism: otherwise it stays resident to avoid unload crashes).

import Foundation

public enum PluginLibraryError: Error, Equatable {
    case dlopenFailed(String)
    case missingRequiredSymbols([String])
    case apiVersionMismatch(found: Int, expected: Int)
}

/// The exports required/optional for each plugin type.
public enum PCXSymbols {
    public static let required = [
        "OpenArchive", "ReadHeaderEx", "ProcessFile", "CloseArchive",
        "SetChangeVolProc", "SetProcessDataProc",
    ]
    public static let optional = [
        "PackFiles", "DeleteFiles", "GetPackerCaps", "ConfigurePacker",
        "CanYouHandleThisFile", "PackSetDefaultParams", "PkSetCryptCallback",
        "GetBackgroundFlags", "PcGetApiVersion", "PcSafeToUnload",
    ]
}

/// The exports required/optional for a PDX content plugin (pdx.h).
public enum PDXSymbols {
    public static let required = [
        "ContentGetSupportedField", "ContentGetValue",
    ]
    public static let optional = [
        "ContentSetValue", "ContentCompareFiles",
        "ContentSetDefaultParams", "ContentPluginUnloading", "ContentStopGetValue",
        // The localized column header (F-428). Optional, and listed here because this allow-list is what a
        // plugin's symbols are looked up through — a new export the list does not know about is invisible,
        // which is how the first version of it silently kept the English header.
        "ContentGetSupportedFieldTitle",
        "PcGetApiVersion", "PcSafeToUnload",
    ]
}

/// The exports required/optional for a PLX lister plugin (plx.h).
public enum PLXSymbols {
    public static let required = [
        "ListLoad",
    ]
    public static let optional = [
        "ListLoadNext", "ListCloseWindow", "ListGetDetectString", "ListSearchText",
        "ListSendCommand", "ListPrint", "ListGetPreviewBitmap", "ListSetDefaultParams",
        "PcGetApiVersion", "PcSafeToUnload",
    ]
}

public final class PluginLibrary {
    public let path: String
    private let handle: UnsafeMutableRawPointer
    private var symbols: [String: UnsafeMutableRawPointer]

    private init(handle: UnsafeMutableRawPointer, path: String, symbols: [String: UnsafeMutableRawPointer]) {
        self.handle = handle
        self.path = path
        self.symbols = symbols
    }

    /// Whether the plugin permits dlclose on unload.
    public var canUnload: Bool { symbols["PcSafeToUnload"] != nil }

    /// Resolved symbol names (for tests / diagnostics).
    public var resolvedSymbols: Set<String> { Set(symbols.keys) }

    /// Open `path`, resolve symbols, and run the version handshake.
    public static func open(path: String,
                            required: [String],
                            optional: [String] = [],
                            expectedAPIVersion: Int = PluginManifestParser.currentAPIVersion)
        -> Result<PluginLibrary, PluginLibraryError> {
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let msg = dlerror().map { String(cString: $0) } ?? "unknown dlopen error"
            return .failure(.dlopenFailed(msg))
        }
        var syms: [String: UnsafeMutableRawPointer] = [:]
        var missing: [String] = []
        for name in required {
            if let s = dlsym(handle, name) { syms[name] = s } else { missing.append(name) }
        }
        if !missing.isEmpty {
            dlclose(handle)
            return .failure(.missingRequiredSymbols(missing))
        }
        for name in optional where syms[name] == nil {
            if let s = dlsym(handle, name) { syms[name] = s }
        }
        // Version handshake (optional export).
        if let vptr = syms["PcGetApiVersion"] {
            typealias VersionFn = @convention(c) () -> Int32
            let version = Int(unsafeBitCast(vptr, to: VersionFn.self)())
            if version != expectedAPIVersion {
                dlclose(handle)
                return .failure(.apiVersionMismatch(found: version, expected: expectedAPIVersion))
            }
        }
        return .success(PluginLibrary(handle: handle, path: path, symbols: syms))
    }

    /// The raw pointer for a resolved symbol, or nil.
    public func symbol(_ name: String) -> UnsafeMutableRawPointer? { symbols[name] }

    deinit {
        if canUnload { dlclose(handle) }
    }
}

public extension PluginHost {
    /// Open a discovered plugin's binary, resolving the symbols for its type.
    static func openLibrary(_ plugin: DiscoveredPlugin) -> Result<PluginLibrary, PluginLibraryError> {
        // PCX, PDX and PLX symbol tables exist; PFX resolves its own set later.
        let (required, optional): ([String], [String])
        switch plugin.manifest.type {
        case .pcx: (required, optional) = (PCXSymbols.required, PCXSymbols.optional)
        case .pdx: (required, optional) = (PDXSymbols.required, PDXSymbols.optional)
        case .plx: (required, optional) = (PLXSymbols.required, PLXSymbols.optional)
        case .ptx: (required, optional) = (ContribSymbols.required, ContribSymbols.optional)
        case .pfx: (required, optional) = (PFXSymbols.required, PFXSymbols.optional)
        default: (required, optional) = ([], PCXSymbols.optional)
        }
        return PluginLibrary.open(path: plugin.binaryPath, required: required, optional: optional)
    }

    /// Open a plugin's binary resolving the contribution behavior ABI
    /// (Plugins/SDK/contrib.h), independent of its file-op type. Used for any
    /// plugin that declares `PCContributions`.
    static func openContribLibrary(_ plugin: DiscoveredPlugin) -> Result<PluginLibrary, PluginLibraryError> {
        PluginLibrary.open(path: plugin.binaryPath,
                           required: ContribSymbols.required, optional: ContribSymbols.optional)
    }

    /// Open a plugin's binary resolving the *content* ABI (Plugins/SDK/pdx.h) with
    /// nothing required, so a plugin of any type that happens to export content
    /// fields can be asked for them.
    ///
    /// The same rule contributions already follow. Content fields were the one ABI
    /// still gated on the declared type, and the gate had no reason behind it: a
    /// lister that can turn a .class into text can answer "what is this file's text"
    /// as well, and refusing to ask meant the decompiler could not take part in the
    /// host's own search (F-351). A plugin that exports nothing is skipped, so this
    /// widens what may be asked, not what must be answered.
    static func openContentLibrary(_ plugin: DiscoveredPlugin) -> Result<PluginLibrary, PluginLibraryError> {
        PluginLibrary.open(path: plugin.binaryPath, required: [], optional: PDXSymbols.optional
                            + PDXSymbols.required)
    }
}
