// SPDX-License-Identifier: Apache-2.0
// ImplicitWork.swift - The app's one answer to "may I read this without being asked?" (F-479).
//
// `ImplicitWorkBudget` in PCFoundation is the rule; this is where the window keeps the settings it
// was configured with and turns a refusal into a sentence somebody can act on. Static, for the same
// reason `FilePreviewView.rendersDocumentsInApp` is: the side panel, Quick View and the gallery must
// answer the same way, and the limits are one fact about the installation rather than one per view.

import AppKit
import PCFoundation
import PCVFS

@MainActor
enum ImplicitWork {

    /// Read from `[Preview]` at startup and on every settings change. `.standard` until then, so a
    /// preview built before the configuration arrives is already cautious rather than already wrong.
    static var limits: ImplicitWorkLimits = .standard

    /// May the cursor alone cause this to be read?
    ///
    /// - Parameter rateKey: identifies the mount for the throughput estimate; empty means "not a
    ///   mount we measure", which leaves the byte fallback in charge.
    static func decide(bytes: Int64,
                       locality: SourceLocality,
                       inArchive: Bool = false,
                       rescansPerRead: Bool = false,
                       rateKey: String = "") -> ImplicitWorkDecision {
        ImplicitWorkBudget.decide(locality: locality,
                                  bytes: bytes,
                                  ratePerSecond: rateKey.isEmpty ? nil
                                                 : TransferRateEstimator.shared.rate(for: rateKey),
                                  inArchive: inArchive,
                                  rescansPerRead: rescansPerRead,
                                  limits: limits)
    }

    /// What the preview says instead of showing the file.
    ///
    /// Each one names the cost and the way to pay it anyway, because "no preview" on its own reads as
    /// a broken panel — which is exactly how the missing archive preview was reported in the first
    /// place. Cmd+Y is named rather than described: it is the gesture that always works.
    static func sentence(for reason: ImplicitWorkReason) -> String {
        switch reason {
        case .dormant:
            return String(localized: "Not downloaded from the cloud yet. Press Cmd+Y to fetch and preview it.")
        case .remoteDisabled:
            return String(localized: "Previews on network locations are switched off. Press Cmd+Y to preview this file.")
        case .rescansPerRead:
            return String(localized: "Every file in this archive format has to be unpacked separately. Press Cmd+Y to preview this one.")
        case .tooBig(let bytes, _):
            let size = ByteSize(bytes).formatted(style: .mb)
            return String(localized: "\(size) — too large to preview automatically. Press Cmd+Y to preview it.")
        case .tooSlow(let bytes, let seconds, _):
            let size = ByteSize(bytes).formatted(style: .mb)
            let time = Self.duration(seconds)
            return String(localized: "\(size) over this connection would take about \(time). Press Cmd+Y to preview it.")
        }
    }

    /// A rough duration. Rounded hard on purpose — the estimate behind it is an average of a few
    /// reads, and "8.4 seconds" claims more than it knows.
    ///
    /// Through `Measurement` rather than a catalogue key with a number in it: "%lld seconds" needs
    /// real CLDR plural categories in nineteen languages to come out right, and the formatter
    /// already has them. (F-478 paid that bill once, for a heading that counted steps.)
    private static func duration(_ seconds: Double) -> String {
        let measurement = seconds < 60
            ? Measurement(value: seconds.rounded(), unit: UnitDuration.seconds)
            : Measurement(value: (seconds / 60).rounded(), unit: UnitDuration.minutes)
        return measurement.formatted(.measurement(width: .wide, usage: .asProvided))
    }

    /// A short tag for the harness dump; never shown to anyone.
    static func tag(for decision: ImplicitWorkDecision) -> String {
        switch decision.reason {
        case nil: return "go"
        case .dormant: return "dormant"
        case .remoteDisabled: return "remote-off"
        case .rescansPerRead: return "rescans"
        case .tooBig: return "too-big"
        case .tooSlow: return "too-slow"
        }
    }

    /// The limits as configured, read as one block so a half-applied set cannot exist.
    static func limits(from config: ConfigStore) async -> ImplicitWorkLimits {
        let mb: (Int) -> Int64 = { Int64($0) * 1024 * 1024 }
        return ImplicitWorkLimits(
            seconds: await config.double("Preview", "AutoPreviewSeconds",
                                         default: ImplicitWorkLimits.standard.seconds),
            localBytes: mb(await config.int("Preview", "AutoPreviewLocalMB", default: 0)),
            remoteBytes: mb(await config.int("Preview", "AutoPreviewRemoteMB", default: 4)),
            archiveBytes: mb(await config.int("Preview", "AutoPreviewArchiveMB", default: 32)),
            allowRemote: await config.bool("Preview", "AutoPreviewRemote", default: true),
            allowDormant: await config.bool("Preview", "AutoPreviewDormant", default: false))
    }
}
