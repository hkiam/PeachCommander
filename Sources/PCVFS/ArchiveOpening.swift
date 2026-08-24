// SPDX-License-Identifier: Apache-2.0
// ArchiveOpening.swift - One authority for "is this an archive, and who opens it" (F-463).
//
// This file names no format. That is the point.
//
// "Is this an archive" used to be answered in eight places that disagreed: the
// search engine's own extension set, the panel's Enter gate, the shell backend's
// list, the write-capability suffixes, the pack formats, a user setting that only
// ever reached the panels, the PCX plugin manifests, and a `hasSuffix(".zip")` in
// the Test-Archive command. A file could therefore be openable with Enter and
// invisible to the search at the same time — which is exactly how a `.tar.gz`
// full of matching text came to be reported as "nothing found".
//
// The duplication was not carelessness, it was a layering rule: PCVFS depends on
// PCFoundation alone, so it cannot see PCArchive's readers or PCPluginHost's
// plugins, and a set of extensions copied into PCVFS was the only way to make the
// engine's gate compile. So the split here is: the *mechanism* lives in PCVFS,
// the *knowledge* lives in whichever module owns the readers, and PCApp — the one
// place that can see both — assembles them. SPEC-012 §2 asked for this registry;
// this is it, one module lower than the spec guessed.

import Foundation

// MARK: - Names

/// The names a backend is willing to look at.
///
/// `compoundSuffixes` exists because `("x.tar.gz" as NSString).pathExtension` is
/// `"gz"` and always will be. Every list in this codebase that keyed on the last
/// extension alone was wrong about the tar family, and the one in the search
/// engine was wrong in a way nobody could see.
public struct ArchiveNameSet: Sendable, Equatable {
    /// Lowercased, without a leading dot.
    public var extensions: Set<String>
    /// Lowercased, *with* the leading dot: ".tar.gz", ".tar.bz2", ...
    public var compoundSuffixes: Set<String>
    /// Stems whose plainly-split first part counts: `name.zip.001` (F-382).
    ///
    /// Splitting is a naming convention rather than a format, which is why it can be
    /// expressed here instead of as a rule buried in one caller. Not simply "001"
    /// among the extensions: a numbered part belongs to whatever was split, and most
    /// of those are not archives — the stem has to say so.
    public var splitFirstPartStems: Set<String>

    public init(extensions: Set<String> = [], compoundSuffixes: Set<String> = [],
                splitFirstPartStems: Set<String> = []) {
        self.extensions = Set(extensions.map { $0.lowercased() })
        self.compoundSuffixes = Set(compoundSuffixes.map { $0.lowercased() })
        self.splitFirstPartStems = Set(splitFirstPartStems.map { $0.lowercased() })
    }

    /// Whether `name` looks like something this set covers.
    ///
    /// Compound suffixes are tested first so `.tar.gz` wins over `.gz`: the two
    /// mean different things (a tar to walk into versus one compressed stream),
    /// and a backend may well claim one and not the other.
    public func matches(name: String) -> Bool {
        let lowered = name.lowercased()
        for suffix in compoundSuffixes where lowered.hasSuffix(suffix) { return true }
        let ext = (lowered as NSString).pathExtension
        guard !ext.isEmpty else { return false }
        if extensions.contains(ext) { return true }
        guard !splitFirstPartStems.isEmpty,
              ext.count == 3, ext.allSatisfy(\.isNumber), Int(ext) == 1 else { return false }
        let stemExt = ((lowered as NSString).deletingPathExtension as NSString).pathExtension
        return splitFirstPartStems.contains(stemExt)
    }

    public func union(_ other: ArchiveNameSet) -> ArchiveNameSet {
        ArchiveNameSet(extensions: extensions.union(other.extensions),
                       compoundSuffixes: compoundSuffixes.union(other.compoundSuffixes),
                       splitFirstPartStems: splitFirstPartStems.union(other.splitFirstPartStems))
    }

    public var isEmpty: Bool {
        extensions.isEmpty && compoundSuffixes.isEmpty && splitFirstPartStems.isEmpty
    }
}

// MARK: - Intent, cost, result

/// Why an archive is being opened. A background walk must not behave like a keypress.
public enum ArchiveOpenIntent: Sendable {
    /// Enter, Ctrl+PageDown, unpack: may prompt for a password, no size ceiling.
    case interactive
    /// A search descending into the tree: never prompts, honours the size ceiling.
    case background
}

/// How expensive one member is to read — the search picks its strategy from this.
///
/// A zip is mapped and its central directory is enough to seek to any member, so
/// reading members one at a time is cheap. A tar.gz or a 7z read through a helper
/// process re-scans the whole archive per member, which turns a content search
/// over a 5,000-member tarball into 5,000 full passes. Those formats get read
/// once into a temp tree instead (SPEC-007 §2 asks for the same thing).
public enum MemberAccessCost: Sendable, Equatable {
    case cheapRandomAccess
    case processPerMember
}

/// A mounted archive, plus what the caller must know to clean up after it.
public struct OpenedArchive: Sendable {
    public let fs: VirtualFileSystem
    /// The archive on disk. For a nested archive this is an extraction, not the original.
    public let localURL: URL
    /// True when `localURL` was created for this open and must be disposed of.
    public let isTemporary: Bool
    public let memberAccessCost: MemberAccessCost
    public let backendID: String
    /// Something the caller must pass on even though the open succeeded.
    ///
    /// An encrypted archive is the case this exists for: it opens, its member names are
    /// in clear and still match, and only the content cannot be read. Reporting it as a
    /// skip would be wrong and saying nothing would be worse, so it is neither.
    public let warning: SearchNotice.Reason?

    public init(fs: VirtualFileSystem, localURL: URL, isTemporary: Bool,
                memberAccessCost: MemberAccessCost, backendID: String,
                warning: SearchNotice.Reason? = nil) {
        self.fs = fs
        self.localURL = localURL
        self.isTemporary = isTemporary
        self.memberAccessCost = memberAccessCost
        self.backendID = backendID
        self.warning = warning
    }
}

/// The three honest answers to "open this".
///
/// `notAnArchive` and `skipped` are different on purpose: the first is the
/// ordinary answer for an ordinary file and says nothing to the user, the second
/// means we believed we could open it and did not — which the user must hear.
public enum ArchiveOpenOutcome: Sendable {
    case opened(OpenedArchive, dispose: @Sendable () async -> Void)
    case skipped(SearchNotice.Reason)
    case notAnArchive
}

/// Ceilings that apply to a background open. Zero means "no limit", matching the
/// convention `SearchQuery.maxDepth` already uses.
public struct ArchiveOpenLimits: Sendable, Equatable {
    public var maxBytes: Int64

    public init(maxBytes: Int64 = 0) { self.maxBytes = maxBytes }
}

// MARK: - Backends

/// One source of archive knowledge: the built-in readers, the PCX plugins, or
/// anything added later. A backend owns its formats; the registry owns nothing.
public protocol ArchiveBackend: Sendable {
    var backendID: String { get }

    /// The names this backend claims. Re-read whenever plugins change.
    func nameSet() async -> ArchiveNameSet

    /// The part of `nameSet()` that is knowable without asking anyone — for a
    /// built-in reader, all of it.
    ///
    /// It exists so the registry answers correctly from the moment it is built.
    /// Plugin names only arrive once the plugin host has finished loading, and
    /// during that window Enter on a `.zip` must not fall through to the system
    /// because the answer had not been computed yet.
    var staticNameSet: ArchiveNameSet { get }

    /// Open `localFile`.
    ///
    /// Returns `.notAnArchive` for "not mine" — the ordinary answer, which says nothing
    /// to anyone — and `.skipped(reason)` for "mine, and I declined", which the user has
    /// to hear. Reporting a refused-because-too-large archive as unreadable would be a
    /// small lie of exactly the kind this whole mechanism exists to remove.
    func open(localFile: URL, intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome

    /// Whether this backend can recognise a file by its content rather than its
    /// name. Kept separate because content probing costs a read per file, which a
    /// recursive search must never pay — only the panel asks.
    var detectsByContent: Bool { get async }

    /// Content-detected open, used only by the panel's speculative Enter.
    func openByContent(localFile: URL) async -> OpenedArchive?
}

public extension ArchiveBackend {
    var detectsByContent: Bool { get async { false } }
    func openByContent(localFile: URL) async -> OpenedArchive? { nil }
    var staticNameSet: ArchiveNameSet { ArchiveNameSet() }
}

// MARK: - The authority

/// What every call site consults: the panel's Enter gate, the search descent,
/// unpack, test-archive and archive reload.
///
/// Two methods rather than one closure, deliberately. A single "open this and
/// tell me if it worked" forces the caller either to keep its own list of what is
/// worth trying — the bug this replaces — or to trial-parse every file it walks
/// past, which for the tar reader means reading and inflating whole files before
/// discovering they were never archives. The cheap name question has to be
/// answerable without touching the disk.
public protocol ArchiveOpening: Sendable {
    /// Cheap, synchronous, no I/O. Safe in a keypress handler and in a walk's inner loop.
    func mightBeArchive(name: String) -> Bool

    func open(fs: VirtualFileSystem, path: String,
              intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome
}

/// Ordered backends plus a cached merged name set.
///
/// Not an actor, and `mightBeArchive` is not async: it sits in `PanelListView`'s
/// keypress path and in the search walk's inner loop, and forcing an `await` into
/// both to protect a set of strings would be a poor trade. A lock over a snapshot
/// is what `VFSRegistry` does for the same reason.
public final class ArchiveRegistry: ArchiveOpening, @unchecked Sendable {
    private let backends: [any ArchiveBackend]
    private let lock = NSLock()
    private var merged = ArchiveNameSet()
    private var extra = ArchiveNameSet()
    private var limits = ArchiveOpenLimits()

    public init(backends: [any ArchiveBackend]) {
        self.backends = backends
        self.merged = backends.reduce(ArchiveNameSet()) { $0.union($1.staticNameSet) }
    }

    /// Re-ask every backend for its names. Call after plugins load or change.
    public func refresh() async {
        var union = ArchiveNameSet()
        for backend in backends {
            union = union.union(await backend.nameSet())
        }
        lock.lock()
        merged = union
        lock.unlock()
    }

    /// Additional extensions the user configured (F-274). Additive, like the
    /// setting itself — removing one needs a restart, which is what the settings
    /// hint already promises.
    public func addExtensions(_ exts: Set<String>) {
        guard !exts.isEmpty else { return }
        lock.lock()
        extra = extra.union(ArchiveNameSet(extensions: exts))
        lock.unlock()
    }

    /// Ceilings for background opens. Set from configuration by the host.
    public func setBackgroundLimits(_ newLimits: ArchiveOpenLimits) {
        lock.lock()
        limits = newLimits
        lock.unlock()
    }

    /// Everything currently recognised — for the panel, which wants the set itself.
    public var nameSet: ArchiveNameSet {
        lock.lock()
        defer { lock.unlock() }
        return merged.union(extra)
    }

    public func mightBeArchive(name: String) -> Bool {
        lock.lock()
        let set = merged.union(extra)
        lock.unlock()
        return set.matches(name: name)
    }

    public func open(fs: VirtualFileSystem, path: String,
                     intent: ArchiveOpenIntent) async -> ArchiveOpenOutcome {
        // A nested archive is not a file yet: extract it, and own what we extracted.
        // The three call sites that used to do this each had their own idea of who
        // deletes it afterwards, and the search's idea was "nobody".
        var localURL: URL
        var isTemporary = false
        if fs is LocalFS {
            localURL = URL(fileURLWithPath: path)
        } else {
            guard let extracted = (try? await fs.localFileIfAvailable(
                VFSPath(filesystemId: fs.scheme, path: path))) ?? nil else {
                return .skipped(.unreadable)
            }
            localURL = extracted
            isTemporary = true
        }

        let dispose = Self.disposer(for: localURL, isTemporary: isTemporary)

        if intent == .background {
            lock.lock()
            let ceiling = limits.maxBytes
            lock.unlock()
            if ceiling > 0, let size = Self.fileSize(localURL), size > ceiling {
                await dispose()
                return .skipped(.tooLarge(size, limit: ceiling))
            }
        }

        // Backend order is the interactive answer: a plugin the user installed for a
        // format wins over the built-in reader, as SPEC-012 §2 requires.
        //
        // A background walk asks a different question. A backend that reads one member
        // per subprocess re-scans the whole archive every time, so a content search over
        // a 5,000-member tarball becomes 5,000 full passes — while a backend that can
        // seek answers each member in place. So for a walk, a process-per-member open is
        // held as the fallback and the remaining backends are given a chance to offer
        // something that seeks. Nothing is lost when none can: the fallback still opens,
        // and formats only a plugin can read are reached exactly as before.
        var fallback: OpenedArchive?
        var declined: SearchNotice.Reason?
        for backend in backends {
            let outcome = await backend.open(localFile: localURL, intent: intent)
            guard case .opened(let opened, _) = outcome else {
                if case .skipped(let reason) = outcome, declined == nil { declined = reason }
                continue
            }
            if intent == .background, opened.memberAccessCost == .processPerMember, fallback == nil {
                fallback = opened
                continue
            }
            return .opened(OpenedArchive(fs: opened.fs, localURL: localURL,
                                         isTemporary: isTemporary,
                                         memberAccessCost: opened.memberAccessCost,
                                         backendID: opened.backendID,
                                         warning: opened.warning),
                           dispose: dispose)
        }
        if let fallback {
            return .opened(OpenedArchive(fs: fallback.fs, localURL: localURL,
                                         isTemporary: isTemporary,
                                         memberAccessCost: fallback.memberAccessCost,
                                         backendID: fallback.backendID,
                                         warning: fallback.warning),
                           dispose: dispose)
        }
        await dispose()
        // A backend that declined for a stated reason gets to say so. Otherwise: a name
        // we recognised and could not open is a skip the user must hear about, and a name
        // we never claimed is just an ordinary file.
        if let declined { return .skipped(declined) }
        return mightBeArchive(name: (path as NSString).lastPathComponent)
            ? .skipped(.unreadable) : .notAnArchive
    }

    /// Content detection, for the panel's speculative Enter only (F-231).
    ///
    /// Never reachable from a search: probing asks each capable backend to read a
    /// header off disk, and doing that for every non-matching name in a recursive
    /// walk is a different feature with a different cost.
    public func probeByContent(localFile: URL) async -> OpenedArchive? {
        for backend in backends where await backend.detectsByContent {
            if let opened = await backend.openByContent(localFile: localFile) { return opened }
        }
        return nil
    }

    // MARK: - Temp ownership

    /// Removes an extraction, and the directory it was put in when that directory
    /// is ours and is now empty. Deleting only the file is what the search engine's
    /// plugin-text path does, and it leaves an empty `PCArchive-<uuid>/` behind
    /// every time.
    private static func disposer(for url: URL, isTemporary: Bool) -> @Sendable () async -> Void {
        guard isTemporary else { return {} }
        let path = url.path
        return {
            let fm = FileManager.default
            try? fm.removeItem(atPath: path)
            let parent = (path as NSString).deletingLastPathComponent
            let tempRoot = fm.temporaryDirectory.resolvingSymlinksInPath().path
            guard parent.hasPrefix(tempRoot),
                  let rest = try? fm.contentsOfDirectory(atPath: parent), rest.isEmpty else { return }
            try? fm.removeItem(atPath: parent)
        }
    }

    private static func fileSize(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int64
    }
}
