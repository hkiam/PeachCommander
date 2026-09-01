// SPDX-License-Identifier: Apache-2.0
// ImplicitWorkBudget.swift - What the app may read without being asked (F-479).
//
// Three surfaces touch a file's *content* because the cursor happens to be on it: the side panel's
// info page, the embedded Quick View, and the gallery's thumbnails. None of them asked the user
// anything, and until now none of them asked how expensive the file was either — the only question
// was whether the path existed. That is the wrong question in three shapes:
//
//   * A mounted SMB/AFP/NFS share is an ordinary local path. Previewing a 200 MB video on one pulls
//     200 MB over the wire because an arrow key moved.
//   * A file iCloud (or any other File Provider) has evicted is a local path on the startup disk
//     whose bytes are not on this machine at all. Touching it starts a full download, silently.
//   * A member inside an archive costs a decompression, and inside a process-per-member format it
//     costs a full re-scan of the archive.
//
// So the decision is made here, once, as a pure function over four inputs, and every implicit
// surface asks it rather than carrying its own ceiling — the same reason `PreviewRoute` exists.
//
// **Bytes are the wrong unit and time is the right one.** 32 MB is 30 ms on an SSD, half a second
// over LAN SMB and half a minute over a VPN'd FTP. Where a throughput measurement exists
// (`TransferRateEstimator`), the limit is derived from it in both directions: a fast share may show
// a large file, a slow one refuses a small one. The byte ceilings below are what applies until
// something has actually been measured.

import Foundation

/// Where a file's bytes really are, as opposed to what its path looks like.
///
/// Deliberately not "is this an archive": an archive on a share is remote, and a dataless file on
/// the startup disk is not fast. See `SourceLocalityProbe` in PCVFS for how one is decided.
public enum SourceLocality: String, Sendable, Equatable, CaseIterable {
    /// An internal or external disk attached to this machine.
    case fast
    /// A mounted network share, or a mount the app itself opened (FTP/SFTP/S3/plugin).
    case remote
    /// Managed by a sync provider and not materialised: reading it downloads it in full.
    case dormant
}

/// The ceilings implicit work is held to. Read from `[Preview]` in the configuration.
public struct ImplicitWorkLimits: Sendable, Equatable {
    /// How long an implicit read may take once throughput is known. 0 = no time limit.
    public var seconds: Double
    /// Ceiling for a file on a local disk. 0 = no limit, which is what ships: reading from an SSD
    /// is what the previews have always done and there is no reason to start refusing it.
    public var localBytes: Int64
    /// Ceiling for a remote file until throughput has been measured for that mount.
    public var remoteBytes: Int64
    /// Ceiling for one member extracted out of an archive (a CPU cost, not a transfer one), applied
    /// on top of the locality's own ceiling.
    public var archiveBytes: Int64
    /// May the cursor pull anything off a remote mount at all?
    public var allowRemote: Bool
    /// May the cursor materialise a dormant file? Off by design — the cost is unbounded and
    /// invisible, and on a metered connection it is also somebody's money.
    public var allowDormant: Bool

    public init(seconds: Double, localBytes: Int64, remoteBytes: Int64, archiveBytes: Int64,
                allowRemote: Bool, allowDormant: Bool) {
        self.seconds = seconds
        self.localBytes = localBytes
        self.remoteBytes = remoteBytes
        self.archiveBytes = archiveBytes
        self.allowRemote = allowRemote
        self.allowDormant = allowDormant
    }

    /// What ships: unrestricted on local disks, cautious everywhere else.
    public static let standard = ImplicitWorkLimits(
        seconds: 1.5,
        localBytes: 0,
        remoteBytes: 4 * 1024 * 1024,
        archiveBytes: 32 * 1024 * 1024,
        allowRemote: true,
        allowDormant: false)

    /// Every ceiling off — what an explicit gesture (Cmd+Y, Enter, F3) is held to, so the same
    /// function can answer for both and only the limits differ.
    public static let unrestricted = ImplicitWorkLimits(
        seconds: 0, localBytes: 0, remoteBytes: 0, archiveBytes: 0,
        allowRemote: true, allowDormant: true)
}

/// Why implicit work was declined. Rendered into a sentence in PCApp, where the catalogue is.
public enum ImplicitWorkReason: Sendable, Equatable {
    /// Reading it would start a download from a sync provider.
    case dormant
    /// The user switched implicit reads on remote mounts off.
    case remoteDisabled
    /// Every read of this archive re-scans the whole file (`MemberAccessCost.processPerMember`).
    case rescansPerRead
    /// Bigger than the ceiling for its class, and nothing has been measured yet.
    case tooBig(bytes: Int64, limit: Int64)
    /// Measured throughput says it would take longer than the budget.
    case tooSlow(bytes: Int64, seconds: Double, budget: Double)
}

public enum ImplicitWorkDecision: Sendable, Equatable {
    /// Go ahead — the cursor may pull this in.
    case go
    /// Not by itself. The gesture that asks for it explicitly is still allowed; the reason is what
    /// the surface tells the user instead of showing a preview.
    case onRequest(ImplicitWorkReason)

    public var isGo: Bool { self == .go }
    public var reason: ImplicitWorkReason? {
        if case .onRequest(let reason) = self { return reason }
        return nil
    }
}

public enum ImplicitWorkBudget {

    /// May the cursor alone cause `bytes` to be read from a source of this kind?
    ///
    /// The order of the questions is the whole of it, because the cases overlap:
    ///
    ///   * **Dormant first**, before any size question. A dataless 4 KB file is not cheap — it is a
    ///     round trip to a provider and a materialisation on disk — and this is the one answer that
    ///     must not depend on a size the caller read out of a listing.
    ///   * **The remote switch next**, so "off" means off rather than "off above 4 MB".
    ///   * **Re-scanning formats next**, since their cost has nothing to do with the member's size:
    ///     a 2 KB member in a 5,000-member tarball costs a full pass either way.
    ///   * **Measured time, then bytes.** A measurement is better than a guess in both directions,
    ///     so where one exists it replaces the fallback rather than being capped by it.
    ///
    /// - Parameters:
    ///   - bytes: the file's size as the listing reports it; negative or unknown counts as 0, which
    ///     lets a directory-shaped entry through and is harmless — the surfaces skip those anyway.
    ///   - ratePerSecond: measured throughput for this mount, or nil when nothing is known yet.
    ///   - inArchive: the bytes come out of an archive member and cost a decompression.
    ///   - rescansPerRead: the archive backend re-reads the whole file per member.
    public static func decide(locality: SourceLocality,
                              bytes: Int64,
                              ratePerSecond: Double? = nil,
                              inArchive: Bool = false,
                              rescansPerRead: Bool = false,
                              limits: ImplicitWorkLimits) -> ImplicitWorkDecision {
        let size = max(0, bytes)

        if locality == .dormant, !limits.allowDormant { return .onRequest(.dormant) }
        if locality == .remote, !limits.allowRemote { return .onRequest(.remoteDisabled) }
        if rescansPerRead { return .onRequest(.rescansPerRead) }

        // An archive member is capped by the decompression ceiling whatever else applies. Checked
        // before the transfer question so the answer for a member of a local zip does not depend on
        // a throughput measurement that describes the disk rather than the unpacking.
        if inArchive, limits.archiveBytes > 0, size > limits.archiveBytes {
            return .onRequest(.tooBig(bytes: size, limit: limits.archiveBytes))
        }

        switch locality {
        case .fast:
            // A local disk is not measured: a spinning platter is still hundreds of times a VPN, and
            // starting to refuse local previews because one read happened to be slow would be a
            // regression against what the app has always done.
            return within(size, limits.localBytes)
        case .remote, .dormant:
            if let rate = ratePerSecond, rate > 0, limits.seconds > 0 {
                let needed = Double(size) / rate
                guard needed > limits.seconds else { return .go }
                return .onRequest(.tooSlow(bytes: size, seconds: needed, budget: limits.seconds))
            }
            return within(size, limits.remoteBytes)
        }
    }

    /// `limit` of 0 means no limit, in every one of these fields.
    private static func within(_ size: Int64, _ limit: Int64) -> ImplicitWorkDecision {
        guard limit > 0, size > limit else { return .go }
        return .onRequest(.tooBig(bytes: size, limit: limit))
    }
}
