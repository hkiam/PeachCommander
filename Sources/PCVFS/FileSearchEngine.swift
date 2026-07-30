// SPDX-License-Identifier: Apache-2.0
// FileSearchEngine.swift - Recursive file search over a `VirtualFileSystem`,
// streaming matches as they are found (SPEC "Find Files" feature).
//
// The engine walks directories through the VFS protocol only (no direct
// filesystem access), so it works against LocalFS, ArchiveFS, or any other
// conforming implementation. Matching is layered: name mask, then size,
// then (optionally) file content - each stage short-circuits the next.

import Foundation
import PCFoundation

/// Parameters for a file search.
public struct SearchQuery: Sendable {
    /// Space-separated name masks, e.g. "*.swift *.txt" (a file matches if
    /// ANY sub-mask matches its name). Empty, "*", or "*.*" match everything.
    public var nameMask: String
    /// Absolute local path to start the walk from.
    public var startDirectory: String
    /// 0 = unlimited depth; 1 = only the start directory itself.
    public var maxDepth: Int
    /// When non-nil, only files whose content contains this text are hits.
    public var contentText: String?
    /// Governs content matching (name masks are always matched
    /// case-insensitively). Defaults to false, matching Commander-style
    /// search conventions.
    public var caseSensitive: Bool
    /// Inclusive lower bound on file size, in bytes.
    public var minSize: Int64?
    /// Inclusive upper bound on file size, in bytes.
    public var maxSize: Int64?
    /// When true, `nameMask` and `contentText` are treated as regular
    /// expressions (ICU / NSRegularExpression) instead of wildcard mask / plain
    /// substring. `caseSensitive` governs both. (F-154)
    public var useRegex: Bool
    /// When non-nil, the search is restricted to exactly these paths: each file
    /// is matched directly, each directory is walked (respecting `maxDepth`).
    /// `startDirectory` is ignored. Used for "search in selected items". (F-153)
    public var scopePaths: [String]?
    /// Plain-text content matches only at word boundaries (ignored in regex/hex
    /// mode — use `\b` in a regex instead).
    public var wholeWord: Bool
    /// When non-empty, content is searched for this exact byte sequence (case-
    /// sensitive, no regex); takes precedence over `contentText`. Feed via
    /// `ByteSearch.parseHex` from a "48 65" style hex string.
    public var hexContent: [UInt8]?
    /// Inclusive lower/upper bounds on the last-modified date.
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    /// When true, directories whose name matches (and that pass the date filter)
    /// are also emitted as hits, not only walked into.
    public var includeDirectories: Bool
    /// When true, file content is decoded with a detected text encoding (UTF-8/16,
    /// Latin-1, …) before matching, so `contentText`/regex find terms in non-UTF-8
    /// files and case folding is Unicode-correct. Ignored for hex search. Slower.
    public var contentEncodingAware: Bool
    /// When true, zip-family archive files (zip/jar/war/…) encountered during the
    /// walk are opened and searched inside too (requires an `archiveOpener` on the
    /// search call). When false, they are treated as opaque files.
    public var searchArchives: Bool
    /// Invert the content match: a file is a hit when it does NOT contain
    /// `contentText`/`hexContent` (TC's "NOT containing this text"). No-op without
    /// a content filter.
    public var contentNotContaining: Bool
    /// Attribute filters (F-152): nil = don't care, true = must be, false = must not be.
    public var requireHidden: Bool?
    public var requireReadOnly: Bool?
    /// Additional start directories walked besides `startDirectory` (F-150).
    public var extraStartDirectories: [String] = []

    public init(
        nameMask: String,
        startDirectory: String,
        maxDepth: Int = 0,
        contentText: String? = nil,
        caseSensitive: Bool = false,
        minSize: Int64? = nil,
        maxSize: Int64? = nil,
        useRegex: Bool = false,
        scopePaths: [String]? = nil,
        wholeWord: Bool = false,
        hexContent: [UInt8]? = nil,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil,
        includeDirectories: Bool = false,
        contentEncodingAware: Bool = false,
        searchArchives: Bool = false,
        contentNotContaining: Bool = false,
        requireHidden: Bool? = nil,
        requireReadOnly: Bool? = nil
    ) {
        self.nameMask = nameMask
        self.startDirectory = startDirectory
        self.maxDepth = maxDepth
        self.contentText = contentText
        self.caseSensitive = caseSensitive
        self.minSize = minSize
        self.maxSize = maxSize
        self.useRegex = useRegex
        self.scopePaths = scopePaths
        self.wholeWord = wholeWord
        self.hexContent = hexContent
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.includeDirectories = includeDirectories
        self.contentEncodingAware = contentEncodingAware
        self.searchArchives = searchArchives
        self.contentNotContaining = contentNotContaining
        self.requireHidden = requireHidden
        self.requireReadOnly = requireReadOnly
    }
}

/// A single matching file, identified by its absolute real path. For content
/// searches, `matchLine`/`matchPreview` carry the first match's 1-based line and
/// that line's text (grep-style); both are nil for name-only matches.
public struct SearchHit: Sendable, Equatable {
    public let path: String
    public let matchLine: Int?
    public let matchPreview: String?

    public init(path: String, matchLine: Int? = nil, matchPreview: String? = nil) {
        self.path = path
        self.matchLine = matchLine
        self.matchPreview = matchPreview
    }
}

/// Walks a `VirtualFileSystem` and streams matching files as `SearchHit`s.
public actor FileSearchEngine {
    public init() {}

    /// Opens the archive at `path` on `fs` as a searchable filesystem (the app
    /// supplies this, backed by ArchiveFS — extracting to a temp file first when
    /// the archive itself lives inside another archive). Returns nil if it can't.
    public typealias ArchiveOpener = @Sendable (_ fs: VirtualFileSystem, _ path: String) async -> VirtualFileSystem?

    /// Zip-format extensions searched when `searchArchives` is on — plain zip plus
    /// its many specializations (Java, Android, browser, docs stay excluded here).
    public static let archiveExtensions: Set<String> =
        ["zip", "zipx", "jar", "war", "ear", "apk", "aar", "ipa", "jmod", "xpi", "crx", "epub"]

    /// Cap on nested archive-in-archive descent (guards against zip bombs / cycles).
    private static let maxArchiveDepth = 4

    /// Precompiled matchers derived once per search, threaded through the walk.
    private struct CompiledQuery {
        var tokens: [String]                 // wildcard sub-masks (non-regex path)
        var nameRegex: NSRegularExpression?  // set only in regex mode
        var contentRegex: NSRegularExpression?
    }

    /// Walk `fs` from the query's start directory and stream matching hits.
    ///
    /// Cancellation: when the consuming `Task` is cancelled (or the stream
    /// is terminated by its consumer going away), the underlying walk task
    /// is cancelled via `onTermination`, and the walk loop checks
    /// `Task.isCancelled` between directories and entries so it stops
    /// promptly instead of running to completion in the background.
    public func search(_ query: SearchQuery, fs: VirtualFileSystem,
                       archiveOpener: ArchiveOpener? = nil) -> AsyncStream<SearchHit> {
        AsyncStream { continuation in
            let regexOptions: NSRegularExpression.Options = query.caseSensitive ? [] : [.caseInsensitive]
            let matchesEverything = query.nameMask.isEmpty || query.nameMask == "*" || query.nameMask == "*.*"

            var nameRegex: NSRegularExpression?
            if query.useRegex, !matchesEverything {
                nameRegex = try? NSRegularExpression(pattern: query.nameMask, options: regexOptions)
                if nameRegex == nil { continuation.finish(); return }  // invalid pattern → no matches
            }
            var contentRegex: NSRegularExpression?
            if query.useRegex, let text = query.contentText, !text.isEmpty {
                contentRegex = try? NSRegularExpression(pattern: text, options: regexOptions)
                if contentRegex == nil { continuation.finish(); return }
            }
            let compiled = CompiledQuery(
                tokens: query.useRegex ? [] : Self.maskTokens(query.nameMask),
                nameRegex: nameRegex,
                contentRegex: contentRegex
            )

            let task = Task {
                if let scope = query.scopePaths {
                    // Restrict to the given items: files matched directly, dirs walked.
                    for path in scope {
                        if Task.isCancelled { break }
                        guard let entry = try? await fs.stat(VFSPath(filesystemId: fs.scheme, path: path)) else { continue }
                        if Self.isDirectoryKind(entry.kind) {
                            if query.includeDirectories,
                               Self.nameMatches(entry.name, compiled: compiled),
                               Self.datePasses(entry.modified, query: query) {
                                continuation.yield(SearchHit(path: path))
                            }
                            await self.walkDirectory(path: path, depth: 1, query: query,
                                                     compiled: compiled, fs: fs, continuation: continuation,
                                                     prefix: "", archiveOpener: archiveOpener)
                        } else {
                            await self.consider(entry: entry, path: path, query: query,
                                                compiled: compiled, fs: fs, continuation: continuation, prefix: "")
                            await self.descendArchive(entry: entry, path: path, query: query, compiled: compiled,
                                                      fs: fs, continuation: continuation, prefix: "",
                                                      archiveOpener: archiveOpener, archiveDepth: 0)
                        }
                    }
                } else {
                    // Walk the primary start directory and any extra ones (F-150).
                    for root in [query.startDirectory] + query.extraStartDirectories {
                        if Task.isCancelled { break }
                        await self.walkDirectory(
                            path: root,
                            depth: 1,
                            query: query,
                            compiled: compiled,
                            fs: fs,
                            continuation: continuation,
                            prefix: "",
                            archiveOpener: archiveOpener
                        )
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Lists `path`, recursing into subdirectories (subject to `maxDepth`)
    /// and emitting a hit for every file that passes all filters.
    /// A hit's display path: the fs-internal `path`, prefixed with the containing
    /// archive's display path when searching inside an archive.
    private static func display(_ prefix: String, _ path: String) -> String {
        prefix.isEmpty ? path : prefix + path
    }

    private func walkDirectory(
        path: String,
        depth: Int,
        query: SearchQuery,
        compiled: CompiledQuery,
        fs: VirtualFileSystem,
        continuation: AsyncStream<SearchHit>.Continuation,
        prefix: String,
        archiveOpener: ArchiveOpener?,
        archiveDepth: Int = 0
    ) async {
        if Task.isCancelled { return }

        let dirPath = VFSPath(filesystemId: fs.scheme, path: path)
        var entries: [VFSEntry] = []
        do {
            for try await batch in fs.list(dirPath) {
                if Task.isCancelled { return }
                entries.append(contentsOf: batch.entries)
            }
        } catch {
            // Unreadable directory (permissions, race with deletion, etc.):
            // skip it silently rather than aborting the whole search.
            return
        }

        var files: [(entry: VFSEntry, childPath: String)] = []
        for entry in entries {
            if Task.isCancelled { return }
            let childPath = Self.appending(name: entry.name, to: path)

            switch entry.kind {
            case .symlinkDir:
                // Never descend into a symlinked directory - it may point
                // back up the tree (directly or indirectly) and cause an
                // infinite walk.
                continue

            case .directory, .appBundle, .package:
                if query.includeDirectories,
                   Self.nameMatches(entry.name, compiled: compiled),
                   Self.datePasses(entry.modified, query: query) {
                    continuation.yield(SearchHit(path: Self.display(prefix, childPath)))
                }
                if query.maxDepth == 0 || depth < query.maxDepth {
                    await walkDirectory(
                        path: childPath,
                        depth: depth + 1,
                        query: query,
                        compiled: compiled,
                        fs: fs,
                        continuation: continuation,
                        prefix: prefix,
                        archiveOpener: archiveOpener,
                        archiveDepth: archiveDepth
                    )
                }

            case .file, .symlinkFile:
                files.append((entry, childPath))
            }
        }

        // Content-match the directory's files. Local files with a content filter
        // are scanned concurrently over their memory maps (F-151); everything else
        // sequentially. Order within a directory is not significant for results.
        let hasContentFilter = (query.contentText?.isEmpty == false) || (query.hexContent?.isEmpty == false)
        if fs.scheme == "file", hasContentFilter {
            await matchFilesConcurrently(files, query: query, compiled: compiled,
                                         continuation: continuation, prefix: prefix)
        } else {
            for f in files {
                if Task.isCancelled { return }
                await consider(entry: f.entry, path: f.childPath, query: query, compiled: compiled,
                               fs: fs, continuation: continuation, prefix: prefix)
            }
        }
        // Archive descent (opt-in, sequential; the opener may not be reentrant).
        if query.searchArchives {
            for f in files {
                if Task.isCancelled { return }
                await descendArchive(entry: f.entry, path: f.childPath, query: query, compiled: compiled,
                                     fs: fs, continuation: continuation, prefix: prefix,
                                     archiveOpener: archiveOpener, archiveDepth: archiveDepth)
            }
        }
    }

    /// NSRegularExpression is documented thread-safe; wrap it so the compiled
    /// content regex can cross into the concurrent content-search tasks (F-151).
    private struct SendableRegex: @unchecked Sendable { let regex: NSRegularExpression? }

    /// Content-match `files` concurrently (bounded), one memory-mapped scan per
    /// file off the actor, yielding hits as they complete (F-151).
    private func matchFilesConcurrently(
        _ files: [(entry: VFSEntry, childPath: String)],
        query: SearchQuery, compiled: CompiledQuery,
        continuation: AsyncStream<SearchHit>.Continuation, prefix: String
    ) async {
        let maxConcurrent = 8
        let sregex = SendableRegex(regex: compiled.contentRegex)
        await withTaskGroup(of: SearchHit?.self) { group in
            var active = 0
            for f in files {
                if Task.isCancelled { break }
                guard Self.passesMetaFilters(f.entry, query: query, compiled: compiled) else { continue }
                if active >= maxConcurrent, let result = await group.next() {
                    active -= 1
                    if let hit = result { continuation.yield(hit) }
                }
                let path = f.childPath
                let displayPath = Self.display(prefix, f.childPath)
                group.addTask {
                    Task.isCancelled ? nil
                        : Self.localContentHit(path: path, displayPath: displayPath, query: query, contentRegex: sregex.regex)
                }
                active += 1
            }
            for await result in group {
                if let hit = result { continuation.yield(hit) }
            }
        }
    }

    /// Cheap, content-free filters (name / size / date / attributes), applied on
    /// the actor before spawning a content-match task.
    private static func passesMetaFilters(_ entry: VFSEntry, query: SearchQuery, compiled: CompiledQuery) -> Bool {
        guard nameMatches(entry.name, compiled: compiled) else { return false }
        if let minSize = query.minSize, entry.size < minSize { return false }
        if let maxSize = query.maxSize, entry.size > maxSize { return false }
        guard datePasses(entry.modified, query: query) else { return false }
        return attributesPass(entry, query: query)
    }

    /// Build a hit for a local file's content match (nonisolated so it runs off the
    /// actor). Creates and consumes a FileSlice entirely within this call (F-151).
    private static func localContentHit(path: String, displayPath: String,
                                        query: SearchQuery, contentRegex: NSRegularExpression?) -> SearchHit? {
        let match = FileSlice(path: path).flatMap { matchInSlice($0, query: query, contentRegex: contentRegex) }
        if query.contentNotContaining {
            return match == nil ? SearchHit(path: displayPath) : nil
        }
        guard let match else { return nil }
        return SearchHit(path: displayPath, matchLine: match.line, matchPreview: match.preview)
    }

    /// Applies the name, size, and (optional) content filters to a single
    /// file entry, emitting a hit if all of them pass.
    private func consider(
        entry: VFSEntry,
        path: String,
        query: SearchQuery,
        compiled: CompiledQuery,
        fs: VirtualFileSystem,
        continuation: AsyncStream<SearchHit>.Continuation,
        prefix: String
    ) async {
        guard Self.passesMetaFilters(entry, query: query, compiled: compiled) else { return }

        let hasContentFilter = (query.contentText?.isEmpty == false) || (query.hexContent?.isEmpty == false)
        if hasContentFilter {
            let match = await firstContentMatch(path: path, query: query, contentRegex: compiled.contentRegex, fs: fs)
            if query.contentNotContaining {
                // Hit only when the term is absent (no match line/preview to show).
                guard match == nil else { return }
                continuation.yield(SearchHit(path: Self.display(prefix, path)))
            } else {
                guard let match else { return }
                continuation.yield(SearchHit(path: Self.display(prefix, path), matchLine: match.line, matchPreview: match.preview))
            }
            return
        }

        continuation.yield(SearchHit(path: Self.display(prefix, path)))
    }

    /// If `entry` is a zip-family archive and the query opts in, open it via
    /// `archiveOpener` and search inside, prefixing hits with the archive's path.
    /// Only descends into archives on the real filesystem (not archive-in-archive).
    private func descendArchive(
        entry: VFSEntry,
        path: String,
        query: SearchQuery,
        compiled: CompiledQuery,
        fs: VirtualFileSystem,
        continuation: AsyncStream<SearchHit>.Continuation,
        prefix: String,
        archiveOpener: ArchiveOpener?,
        archiveDepth: Int
    ) async {
        guard query.searchArchives, archiveDepth < Self.maxArchiveDepth, let archiveOpener,
              Self.archiveExtensions.contains((entry.name as NSString).pathExtension.lowercased()),
              let subFS = await archiveOpener(fs, path) else { return }
        // Walk the archive's whole tree ignoring maxDepth/scope (those apply to the
        // outer walk); hits display as "<archive path>/<inner path>". Nested archives
        // recurse (archiveDepth + 1) up to maxArchiveDepth.
        var inner = query
        inner.maxDepth = 0
        inner.scopePaths = nil
        await walkDirectory(path: "/", depth: 1, query: inner, compiled: compiled, fs: subFS,
                            continuation: continuation, prefix: Self.display(prefix, path),
                            archiveOpener: archiveOpener, archiveDepth: archiveDepth + 1)
    }

    /// Whether a modification date falls within the query's date bounds.
    private static func datePasses(_ modified: Date, query: SearchQuery) -> Bool {
        if let after = query.modifiedAfter, modified < after { return false }
        if let before = query.modifiedBefore, modified > before { return false }
        return true
    }

    /// Tri-state attribute filters (F-152): hidden and read-only. `nil` = don't care.
    private static func attributesPass(_ entry: VFSEntry, query: SearchQuery) -> Bool {
        if let want = query.requireHidden, entry.isHidden != want { return false }
        if let want = query.requireReadOnly, isReadOnly(entry) != want { return false }
        return true
    }

    /// A file is "read-only" when the owner write bit is clear or an immutable BSD
    /// flag is set. Entries without a populated mode (some VFS mounts) are treated
    /// as writable so the filter doesn't wrongly exclude them.
    private static func isReadOnly(_ entry: VFSEntry) -> Bool {
        let UF_IMMUTABLE: UInt32 = 0x0000_0002, SF_IMMUTABLE: UInt32 = 0x0002_0000
        if entry.bsdFlags & (UF_IMMUTABLE | SF_IMMUTABLE) != 0 { return true }
        guard entry.posixMode != 0 else { return false }
        return entry.posixMode & 0o200 == 0
    }

    /// Returns the first content match's line number (1-based) + that line's text,
    /// or nil if `path` doesn't match. Local files are searched directly over their
    /// memory map with NO size cap (F-151); other filesystems (archives, network)
    /// stream through the VFS with a cap, since accumulating an unbounded remote
    /// file in memory is unsafe.
    private func firstContentMatch(path: String, query: SearchQuery,
                                   contentRegex: NSRegularExpression?, fs: VirtualFileSystem) async -> (line: Int, preview: String)? {
        if fs.scheme == "file", let slice = FileSlice(path: path) {
            return Self.matchInSlice(slice, query: query, contentRegex: contentRegex)
        }
        return await firstContentMatchStreamed(path: path, query: query, contentRegex: contentRegex, fs: fs)
    }

    /// mmap fast path (F-151): search a local file's whole memory map, uncapped for
    /// byte/substring/whole-word (via ChunkSearcher); regex/encoding-aware modes
    /// decode a bounded prefix (decoding hundreds of MB for a regex is impractical).
    private static func matchInSlice(_ slice: FileSlice, query: SearchQuery,
                                     contentRegex: NSRegularExpression?) -> (line: Int, preview: String)? {
        if let hex = query.hexContent, !hex.isEmpty {
            guard let off = ChunkSearcher.search(hex, in: slice) else { return nil }
            return sliceLineInfo(offset: off, slice: slice)
        }
        if query.contentEncodingAware || contentRegex != nil {
            let cap = 64 * 1024 * 1024
            let bytes = slice.bytes(at: 0, length: Int(min(Int64(cap), slice.count)))
            let text: String
            if query.contentEncodingAware {
                let enc = EncodingDetector.detect(Array(bytes.prefix(64 * 1024)))
                text = String(bytes: bytes, encoding: enc) ?? String(decoding: bytes, as: UTF8.self)
            } else {
                text = String(decoding: bytes, as: UTF8.self)
            }
            return textMatch(text: text, query: query, contentRegex: contentRegex)
        }
        guard let needle = query.contentText, !needle.isEmpty else { return nil }
        let needleBytes = Array(needle.utf8)
        let ci = !query.caseSensitive
        let off = query.wholeWord
            ? firstWholeWordInSlice(needleBytes, slice: slice, caseInsensitive: ci)
            : ChunkSearcher.search(needleBytes, in: slice, caseInsensitive: ci)
        guard let o = off else { return nil }
        return sliceLineInfo(offset: o, slice: slice)
    }

    /// Whole-word search over a FileSlice: the first occurrence whose neighbouring
    /// bytes are non-word characters (F-151).
    private static func firstWholeWordInSlice(_ needle: [UInt8], slice: FileSlice, caseInsensitive: Bool) -> Int64? {
        guard !needle.isEmpty else { return nil }
        var from: Int64 = 0
        while let idx = ChunkSearcher.search(needle, in: slice, from: from, caseInsensitive: caseInsensitive) {
            let before: UInt8? = idx > 0 ? slice.bytes(at: idx - 1, length: 1).first : nil
            let afterOff = idx + Int64(needle.count)
            let after: UInt8? = afterOff < slice.count ? slice.bytes(at: afterOff, length: 1).first : nil
            if !isWordByte(before) && !isWordByte(after) { return idx }
            from = idx + 1
        }
        return nil
    }

    /// Line number (1-based) + preview for a match at `offset`, read from the slice
    /// in bounded windows so no full-file buffer is needed (F-151).
    private static func sliceLineInfo(offset: Int64, slice: FileSlice) -> (line: Int, preview: String) {
        var line = 1
        var pos: Int64 = 0
        let chunkSize: Int64 = 1 << 20
        while pos < offset {
            let len = Int(min(chunkSize, offset - pos))
            for b in slice.bytes(at: pos, length: len) where b == 0x0A { line += 1 }
            pos += Int64(len)
        }
        // Line start: byte after the last \n before offset (search back up to 64 KB).
        let window: Int64 = 64 * 1024
        let backStart = max(0, offset - window)
        let backBytes = slice.bytes(at: backStart, length: Int(offset - backStart))
        let lineStart = backBytes.lastIndex(of: 0x0A).map { backStart + Int64($0) + 1 } ?? backStart
        // Line end: next \n at/after offset (search forward up to 64 KB).
        let fwdBytes = slice.bytes(at: offset, length: Int(min(window, slice.count - offset)))
        let lineEnd = fwdBytes.firstIndex(of: 0x0A).map { offset + Int64($0) } ?? (offset + Int64(fwdBytes.count))
        var previewBytes = slice.bytes(at: lineStart, length: Int(min(lineEnd - lineStart, 400)))
        while let last = previewBytes.last, last == 0x0D || last == 0x0A { previewBytes.removeLast() }
        return (line, String(decoding: previewBytes, as: UTF8.self).trimmingCharacters(in: .whitespaces))
    }

    /// Streamed fallback for non-local filesystems (archives / network): reads up to
    /// 16 MB through `fs.openRead` and matches in memory.
    private func firstContentMatchStreamed(path: String, query: SearchQuery,
                                           contentRegex: NSRegularExpression?, fs: VirtualFileSystem) async -> (line: Int, preview: String)? {
        let sizeLimit = 16 * 1024 * 1024
        let filePath = VFSPath(filesystemId: fs.scheme, path: path)

        var haystack = [UInt8]()
        do {
            let stream = try await fs.openRead(filePath)
            for try await element in stream {
                if Task.isCancelled { try? await stream.close(); return nil }
                guard let chunk = element as? Data else { continue }
                haystack.append(contentsOf: chunk)
                if haystack.count >= sizeLimit { break }
            }
            try? await stream.close()
        } catch {
            return nil
        }
        if haystack.count > sizeLimit { haystack.removeLast(haystack.count - sizeLimit) }

        // Hex byte-sequence mode: exact bytes, always case-sensitive (ignores encoding).
        if let hex = query.hexContent, !hex.isEmpty {
            guard let idx = ByteSearch.firstIndex(of: hex, in: haystack) else { return nil }
            return Self.byteLineInfo(offset: idx, haystack: haystack)
        }

        // Encoding-aware or regex → decode to text and match there.
        if query.contentEncodingAware {
            let enc = EncodingDetector.detect(Array(haystack.prefix(64 * 1024)))
            let text = String(bytes: haystack, encoding: enc) ?? String(decoding: haystack, as: UTF8.self)
            return Self.textMatch(text: text, query: query, contentRegex: contentRegex)
        }
        if contentRegex != nil {
            let text = String(decoding: haystack, as: UTF8.self)
            return Self.textMatch(text: text, query: query, contentRegex: contentRegex)
        }

        // Plain byte substring / whole-word. Search a lowercased copy when
        // case-insensitive, but always build the preview from the original bytes.
        guard let needle = query.contentText, !needle.isEmpty else { return nil }
        var needleBytes = Array(needle.utf8)
        let searchHay: [UInt8]
        if query.caseSensitive {
            searchHay = haystack
        } else {
            searchHay = haystack.map(Self.asciiLowercased)
            needleBytes = needleBytes.map(Self.asciiLowercased)
        }
        let idx = query.wholeWord
            ? Self.firstWholeWord(needleBytes, in: searchHay)
            : ChunkSearcher.firstIndex(of: needleBytes, in: searchHay)
        guard let i = idx else { return nil }
        return Self.byteLineInfo(offset: i, haystack: haystack)
    }

    /// Match against decoded text (encoding-aware / regex); returns line + preview.
    private static func textMatch(text: String, query: SearchQuery, contentRegex: NSRegularExpression?) -> (line: Int, preview: String)? {
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        if let contentRegex {
            guard let m = contentRegex.firstMatch(in: text, options: [], range: full) else { return nil }
            return textLineInfo(utf16Offset: m.range.location, text: text)
        }
        guard let needle = query.contentText, !needle.isEmpty else { return nil }
        if query.wholeWord {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: needle) + "\\b"
            let opts: NSRegularExpression.Options = query.caseSensitive ? [] : [.caseInsensitive]
            guard let re = try? NSRegularExpression(pattern: pattern, options: opts),
                  let m = re.firstMatch(in: text, options: [], range: full) else { return nil }
            return textLineInfo(utf16Offset: m.range.location, text: text)
        }
        guard let r = text.range(of: needle, options: query.caseSensitive ? [] : [.caseInsensitive]) else { return nil }
        return textLineInfo(utf16Offset: NSRange(r, in: text).location, text: text)
    }

    /// Index of the first whole-word occurrence of `needle`, or nil.
    private static func firstWholeWord(_ needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty else { return nil }
        var from = 0
        while let idx = ChunkSearcher.firstIndex(of: needle, in: haystack, from: from) {
            let before: UInt8? = idx > 0 ? haystack[idx - 1] : nil
            let afterIdx = idx + needle.count
            let after: UInt8? = afterIdx < haystack.count ? haystack[afterIdx] : nil
            if !isWordByte(before) && !isWordByte(after) { return idx }
            from = idx + 1
        }
        return nil
    }

    /// Line number (1-based) + the line's text for a byte offset in `haystack`.
    private static func byteLineInfo(offset: Int, haystack: [UInt8]) -> (line: Int, preview: String) {
        var line = 1, lineStart = 0, i = 0
        let bound = min(offset, haystack.count)
        while i < bound { if haystack[i] == 0x0A { line += 1; lineStart = i + 1 }; i += 1 }
        var lineEnd = bound
        while lineEnd < haystack.count, haystack[lineEnd] != 0x0A { lineEnd += 1 }
        if lineEnd > lineStart, haystack[lineEnd - 1] == 0x0D { lineEnd -= 1 }
        let capped = min(lineEnd, lineStart + 400)
        let preview = String(decoding: haystack[lineStart..<capped], as: UTF8.self)
            .trimmingCharacters(in: .whitespaces)
        return (line, preview)
    }

    /// Line number (1-based) + line text for a UTF-16 offset in `text`.
    private static func textLineInfo(utf16Offset: Int, text: String) -> (line: Int, preview: String) {
        let ns = text as NSString
        let loc = max(0, min(utf16Offset, ns.length))
        var line = 1, i = 0
        while i < loc { if ns.character(at: i) == 0x0A { line += 1 }; i += 1 }
        let lineRange = ns.lineRange(for: NSRange(location: loc, length: 0))
        var preview = ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
        if preview.utf16.count > 400 { preview = String(preview.prefix(400)) }
        return (line, preview)
    }

    /// ASCII letter / digit / underscore — a "word" byte for whole-word matching.
    private static func isWordByte(_ b: UInt8?) -> Bool {
        guard let b else { return false }
        return (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || (b >= 0x30 && b <= 0x39) || b == 0x5F
    }

    /// Directory-like kinds that the walk descends into (mirrors walkDirectory).
    private static func isDirectoryKind(_ kind: VFSEntry.Kind) -> Bool {
        switch kind {
        case .directory, .appBundle, .package: return true
        case .file, .symlinkFile, .symlinkDir: return false
        }
    }

    /// Splits a space-separated name mask into its individual sub-masks.
    private static func maskTokens(_ mask: String) -> [String] {
        mask.split(separator: " ").map(String.init)
    }

    /// A file matches if its name matches ANY sub-mask. An empty mask list,
    /// or a sub-mask of "*" / "*.*", matches every name. Note: `WildcardMask`
    /// always matches case-insensitively, so `SearchQuery.caseSensitive`
    /// only governs content matching, not the name mask.
    private static func nameMatches(_ name: String, compiled: CompiledQuery) -> Bool {
        // Regex mode: a nil nameRegex means "match everything" (empty/`*`/`*.*`).
        if let regex = compiled.nameRegex {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            return regex.firstMatch(in: name, options: [], range: range) != nil
        }
        let tokens = compiled.tokens
        guard !tokens.isEmpty else { return true }
        for token in tokens {
            if token == "*" || token == "*.*" { return true }
            if WildcardMask(token).matches(name) { return true }
        }
        return false
    }

    /// Joins a directory path and a child name into a path string, avoiding
    /// a doubled slash when `parent` is the filesystem root.
    private static func appending(name: String, to parent: String) -> String {
        parent.hasSuffix("/") ? parent + name : parent + "/" + name
    }

    /// Lowercases an ASCII A-Z byte; all other bytes pass through unchanged.
    private static func asciiLowercased(_ byte: UInt8) -> UInt8 {
        (byte >= 0x41 && byte <= 0x5A) ? byte + 0x20 : byte
    }
}
