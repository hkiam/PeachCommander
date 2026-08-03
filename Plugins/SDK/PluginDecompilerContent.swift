// SPDX-License-Identifier: Apache-2.0
// PluginDecompilerContent.swift — let the host's own search look inside a compiled file (F-351).
//
// Searching a .class for a string finds it in the constant pool at best, and says nothing about where
// it is used. What a user means by "find this in these classes" is the *source*, which only a
// decompiler can produce — so the plugin offers the decompiled text as a full-text content field and
// the host's search uses it in place of the file's bytes.
//
// This is the content ABI (Plugins/SDK/pdx.h), whose `PC_FT_FULLTEXT` existed from the start and had
// no consumer. The type gate was the only thing in the way: content fields used to be read from
// declared `pdx` bundles only, which a lister can never be. That gate is gone — a plugin exporting
// these two functions is asked, whatever it calls itself — so this feature added no new ABI at all.
//
// Nothing here is offered as a column: a whole decompiled class in a table cell would be neither
// readable nor cheap, and the host keeps full-text fields out of the column list for that reason.

import Foundation

/// The one field this plugin contributes. Index 0, since there is only one.
private let fieldName = "Decompiled Source"

/// The field's name, written into the host's buffer. Each plugin's `ContentGetSupportedField` is one
/// call to this.
func decompilerContentField(_ fieldIndex: Int32, _ nameOut: UnsafeMutablePointer<CChar>?,
                            _ units: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard fieldIndex == 0, let nameOut, maxlen > 0 else { return 0 }   // PC_FT_NOMOREFIELDS
    _ = fieldName.withCString { strlcpy(nameOut, $0, Int(maxlen)) }
    if let units { units.pointee = 0 }
    return 9   // PC_FT_FULLTEXT
}

func decompilerContentValue(_ fileName: UnsafeMutablePointer<CChar>?, _ fieldIndex: Int32,
                            _ fieldValue: UnsafeMutableRawPointer?, _ maxlen: Int32,
                            profile: PluginDecompilerProfile) -> Int32 {
    guard fieldIndex == 0, let fileName, let fieldValue, maxlen > 0 else { return -1 }  // PC_FT_NOSUCHFIELD
    let path = String(cString: fileName)
    let kind = (path as NSString).pathExtension.lowercased()
    // Only what a decompiler is for, and only what this plugin actually claims — a native .dll has
    // the same extension as a managed one and no source to offer. Claiming every file would make the
    // host ask for the text of everything the search walks.
    guard profile.singleKinds.contains(kind) || profile.treeKinds.contains(kind),
          profile.claims(path) else { return -3 }   // PC_FT_FIELDEMPTY

    let configRoot = configRoot()
    // The plugin's own half of the consent (F-352): the host asks in its search dialog, and this
    // refuses for a machine where a decompiler is too slow to spend on a search at all.
    guard PluginDecompilerOptions.read(configRoot: configRoot, profile: profile.id)
        .allowSearchDecompile else { return -3 }
    guard let source = decompiledSource(path: path, kind: kind, configRoot: configRoot,
                                        profile: profile) else {
        return -3
    }
    // The buffer is the host's; a result longer than it holds is truncated rather than refused, since
    // a hit in the first megabyte of a class is still a hit. The host's own byte search has no such
    // limit, which is a difference worth knowing rather than hiding.
    _ = source.withCString { strlcpy(fieldValue.assumingMemoryBound(to: CChar.self), $0, Int(maxlen)) }
    return 9   // PC_FT_FULLTEXT
}

/// The decompiled source for `path`, from the cache when possible.
///
/// A search touches many files, so the cache is what makes this usable at all: the first search over
/// a tree of classes pays for the engine once per class, and every later one is a file read. Failures
/// are not cached — a missing engine is a condition of the system, and caching it would mean the
/// search kept finding nothing after the engine was installed.
private func decompiledSource(path: String, kind: String, configRoot: String,
                              profile: PluginDecompilerProfile) -> String? {
    let registry = PluginDecompilerRegistry(configRoot: configRoot, profile: profile.id)
    let candidates = registry.engines(for: kind)
    let preferred = PluginDecompilerPreference.read(configRoot: configRoot)[kind]
    let engine = candidates.first { $0.id == preferred && $0.isAvailable }
        ?? candidates.first { $0.isAvailable }
    guard let engine else { return nil }
    if let cached = PluginDecompilerCache.read(path: path, engine: engine, configRoot: configRoot,
                                               profile: profile.id) {
        return cached
    }
    // Only if the user asked for this: the host passes a text provider to its search engine solely
    // when the "search text provided by plugins" option is on, so reaching this line already means
    // somebody accepted that a search may run a decompiler.
    guard case .success(let source) = PluginDecompilerRunner.run(engine, input: path) else { return nil }
    PluginDecompilerCache.write(source, path: path, engine: engine, configRoot: configRoot,
                                profile: profile.id)
    return source
}
