// SPDX-License-Identifier: Apache-2.0
// NetworkShare.swift - Normalise a typed network location into a mountable URL (TODOS #36).
//
// Accepts smb/afp/nfs/cifs URLs, Windows UNC paths (\\server\share\dir), //server/share
// and bare server/share, producing a URL the OS can mount. Pure and unit-testable;
// the actual mount is done by the app via NSWorkspace.
//
// It also answers the other half of the question, which the mount URL cannot: *where is that
// share right now*. A typed UNC path whose share is already mounted must not raise a connect
// dialog — it must simply navigate — so `mountedPath(for:)` reverse-maps host + share through
// the live mount table. That lookup is also what turns a finished mount into a directory to
// open: guessing "/Volumes/<share>" is wrong the moment the same share is mounted twice, where
// macOS appends "-1".

import Foundation
import NetFS

public enum NetworkShare {
    private static let schemes: Set<String> = ["smb", "afp", "nfs", "cifs"]

    /// A network location split into the parts a mount is identified by.
    ///
    /// `authority` keeps whatever the user typed in front of the host — `DOMAIN;user@` — because
    /// macOS pre-fills the login from it; `host` is the bare name, because that is what the mount
    /// table can be matched on.
    public struct Location: Equatable, Sendable {
        public let scheme: String
        public let authority: String
        public let host: String
        /// Empty when only a server was named — `smb://srv` is a legitimate mount target, and
        /// macOS then asks which share. Nothing can be reverse-mapped from it, so
        /// `mountedPath(for:)` declines such a location.
        public let share: String
        public let subpath: [String]

        /// The same location without its subpath — the share itself.
        ///
        /// What a mount actually produces: the subfolder underneath may be a typo, and the share
        /// root is then still somewhere useful to land.
        public var shareRoot: Location {
            Location(scheme: scheme, authority: authority, host: host, share: share, subpath: [])
        }

        /// The mountable URL for this location (share and subpath included).
        public var url: URL? {
            let tail = ([share] + subpath).filter { !$0.isEmpty }.joined(separator: "/")
            return URL(string: tail.isEmpty ? "\(scheme)://\(authority)"
                                            : "\(scheme)://\(authority)/\(tail)")
        }
    }

    /// Whether `input` names a network location rather than a local path.
    ///
    /// Deliberately narrower than `location(from:)`, which also accepts a bare `server/share`:
    /// "server/share" is indistinguishable from a relative path, and a caller resolving typed
    /// input must read it as the relative path the user almost certainly meant.
    public static func isNetworkLocation(_ input: String) -> Bool {
        let s = unquoted(input)
        if s.hasPrefix("\\\\") || s.hasPrefix("//") { return true }
        guard let separator = s.range(of: "://") else { return false }
        return schemes.contains(s[s.startIndex..<separator.lowerBound].lowercased())
    }

    /// Convert `input` to a mountable network URL, or nil if it is not a share address.
    public static func url(from input: String) -> URL? {
        location(from: input)?.url
    }

    /// Split `input` into scheme, host, share and subpath, or nil if it is not a share address.
    public static func location(from input: String) -> Location? {
        var s = unquoted(input)
        guard !s.isEmpty else { return nil }

        var scheme = "smb"
        if s.hasPrefix("\\\\") {
            // UNC: \\server\share\dir → smb://server/share/dir
            s = s.dropFirst(2).replacingOccurrences(of: "\\", with: "/")
        } else if s.hasPrefix("//") {
            // //server/share → smb://server/share
            s = String(s.dropFirst(2))
        } else if let split = s.range(of: "://") {
            scheme = String(s[s.startIndex..<split.lowerBound]).lowercased()
            guard schemes.contains(scheme) else { return nil }
            s = String(s[split.upperBound...])
        }
        // else: bare server/share, already in the right shape.

        // A trailing separator is how Explorer copies a folder path; it carries no component.
        let parts = s.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let authority = parts.first, !authority.isEmpty else { return nil }
        let host = bareHost(authority)
        guard !host.isEmpty else { return nil }

        return Location(scheme: scheme, authority: authority, host: host,
                        share: parts.count > 1 ? parts[1] : "",
                        subpath: Array(parts.dropFirst(2)))
    }

    // MARK: - Where is it mounted?

    /// One row of the mount table: what was mounted, and where it landed.
    public struct MountEntry: Equatable, Sendable {
        public let from: String        // f_mntfromname, e.g. "//DOMAIN;user@srv/ablage"
        public let mountPoint: String  // f_mntonname, e.g. "/Volumes/ablage"
        public init(from: String, mountPoint: String) {
            self.from = from
            self.mountPoint = mountPoint
        }
    }

    /// The local path `location` currently resolves to, or nil if its share is not mounted.
    ///
    /// `mounts` is a parameter so the matching can be tested against from-names this machine does
    /// not happen to have; callers pass nothing and get the live table.
    public static func mountedPath(for target: Location,
                                   in mounts: [MountEntry]? = nil) -> String? {
        guard !target.share.isEmpty else { return nil }
        // The SHALLOWEST mount that covers the target, and the whole remote path compared — not
        // the first row whose share matches.
        //
        // macOS can mount a *subdirectory* of a share as its own volume, and Finder does exactly
        // that when handed a URL with a path: `\\srv\ablage\a\b\c` became a volume whose root
        // is `c`. So one share appears in the table more than once, at different depths. Matching
        // on host + share alone answered with whichever row came first, which for a lookup of the
        // share root claimed it was mounted at `/Volumes/c` — a path that *exists* and is the
        // wrong folder, so the panel would have gone there in silence.
        //
        // Among the rows that do cover the target, shallowest wins. Every covering mount reaches
        // the same bytes, so the only thing to choose between them is how much of the tree the
        // user can walk afterwards, and the shallowest is the one that still has the folder's
        // parents in it. Deepest was the first answer here and it is the wrong one: with both the
        // share and a submount of it mounted, it sent the panel into the submount — a volume whose
        // root is the target folder, with no way up, which is the very thing this avoids.
        var best: (depth: Int, path: String)?
        for entry in mounts ?? currentMounts() {
            guard let mounted = location(fromMountName: entry.from),
                  sameShare(mounted, target),
                  let rest = remainder(of: target, under: mounted) else { continue }
            guard best == nil || mounted.subpath.count < best!.depth else { continue }
            best = (mounted.subpath.count,
                    rest.reduce(entry.mountPoint) { ($0 as NSString).appendingPathComponent($1) })
        }
        return best?.path
    }

    /// The components of `target` that lie below what `mounted` already covers, or nil when
    /// `mounted` is not an ancestor of `target` at all.
    private static func remainder(of target: Location, under mounted: Location) -> [String]? {
        guard mounted.subpath.count <= target.subpath.count else { return nil }
        for (covered, wanted) in zip(mounted.subpath, target.subpath)
        where covered.caseInsensitiveCompare(wanted) != .orderedSame { return nil }
        return Array(target.subpath.dropFirst(mounted.subpath.count))
    }

    /// The live mount table.
    ///
    /// `getmntinfo` rather than `volumeURLForRemountingKey`: the from-name is the kernel's own
    /// record of what was mounted, is the same shape for smbfs/afpfs/nfs, and is what `mount(8)`
    /// prints — so a mismatch can be read off a terminal instead of guessed at.
    public static func currentMounts() -> [MountEntry] {
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buffer, MNT_NOWAIT)
        guard count > 0, let mounts = buffer else { return [] }
        return (0..<Int(count)).map { i in
            var fs = mounts[i]
            return MountEntry(from: cString(&fs.f_mntfromname),
                              mountPoint: cString(&fs.f_mntonname))
        }
    }

    // MARK: - Mounting

    /// Mount `location`'s SHARE and return where it landed.
    ///
    /// The *share*, never the subdirectory below it. macOS is willing to mount a subdirectory as a
    /// volume of its own, and `NSWorkspace.open` on a URL with a path did exactly that: handed
    /// `\\srv\ablage\a\b\c` it produced a volume whose root is `c`. The panel then sat in the
    /// right folder inside a volume with nothing above it — no way to go up, and a drive chip named
    /// after a folder five levels deep. Mounting the share and navigating to the rest gives the
    /// same destination with the whole tree still reachable.
    ///
    /// `NetFSMountURLSync` rather than `NSWorkspace.open`, which asks *Finder* to do the mount:
    /// Finder mounts it and then opens its own window in the foreground, taking the user out of
    /// the app they asked from. NetFS mounts it directly, hands back the mount point instead of
    /// leaving it to be guessed, and still lets the system put up its authentication sheet.
    ///
    /// Blocking, and it may show that sheet — call it off the main thread.
    ///
    /// - Parameter allowUI: whether the system may ask for credentials. False fails immediately
    ///   instead, which is what a background probe wants.
    /// - Returns: the mount point, e.g. `/Volumes/ablage`.
    public static func mount(_ location: Location, allowUI: Bool = true) throws -> String {
        guard let url = location.shareRoot.url else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL))
        }
        let openOptions: NSMutableDictionary = [
            kNAUIOptionKey: allowUI ? kNAUIOptionAllowUI : kNAUIOptionNoUI
        ]
        // No submounts, for the reason above: this is the one call that could still create one.
        let mountOptions: NSMutableDictionary = [kNetFSAllowSubMountsKey: false]
        var points: Unmanaged<CFArray>?

        let status = NetFSMountURLSync(url as CFURL, nil, nil, nil,
                                       openOptions as CFMutableDictionary,
                                       mountOptions as CFMutableDictionary, &points)
        guard status == 0 else {
            // The system's own errno text: "Authentication error", "No route to host" and
            // "Permission denied" are three different things for the user to do next, and a
            // single "could not mount" would tell them none of them apart.
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: String(cString: strerror(status))
            ])
        }
        // Where it actually landed, which is not always "/Volumes/<share>": mount a share whose
        // name is taken and macOS appends "-1".
        if let list = points?.takeRetainedValue() as? [String], let first = list.first {
            return first
        }
        // Mounted, but it did not say where. The table knows.
        guard let path = mountedPath(for: location.shareRoot) else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT))
        }
        return path
    }

    // MARK: - Helpers

    /// Parse an `f_mntfromname` the same way typed input is parsed, so the two are comparable.
    private static func location(fromMountName name: String) -> Location? {
        // smbfs and afpfs both record "//authority/share"; anything else is not a share mount.
        guard name.hasPrefix("//") else { return nil }
        return location(from: name)
    }

    /// Whether two locations name the same share.
    ///
    /// Share names are case-insensitive on SMB, and the host may be typed short where it was
    /// mounted by FQDN (or the reverse) — "srv-ablage" and "srv-ablage.pdv.lan" are the same
    /// server, and refusing to see that would raise a connect dialog for an open mount. The user
    /// part is ignored on purpose: the same share mounted under any account is still that share.
    private static func sameShare(_ a: Location, _ b: Location) -> Bool {
        guard a.share.caseInsensitiveCompare(b.share) == .orderedSame else { return false }
        if a.host.caseInsensitiveCompare(b.host) == .orderedSame { return true }
        let (x, y) = (firstLabel(a.host), firstLabel(b.host))
        return x.caseInsensitiveCompare(y) == .orderedSame
    }

    private static func firstLabel(_ host: String) -> String {
        String(host.split(separator: ".").first ?? "")
    }

    /// The host inside an authority, without a `DOMAIN;user@` prefix or a `:port` suffix.
    private static func bareHost(_ authority: String) -> String {
        var host = authority
        if let at = host.lastIndex(of: "@") { host = String(host[host.index(after: at)...]) }
        if let colon = host.lastIndex(of: ":") { host = String(host[host.startIndex..<colon]) }
        return host
    }

    /// Trim whitespace and one wrapping pair of quotes — how a path arrives when it was copied
    /// out of a mail or a Windows shell, where quoting is what makes a space survive.
    private static func unquoted(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    /// A fixed-size C char array (imported as a tuple) as a String.
    private static func cString<T>(_ field: inout T) -> String {
        withUnsafePointer(to: &field) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) {
                String(cString: $0)
            }
        }
    }
}
