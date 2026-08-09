// SPDX-License-Identifier: Apache-2.0
// ViewMountPlan.swift - What changes when the set of plugin views changes (F-381).
//
// `ViewContainerRegistry.refresh` began with `live.forEach { $0.close() }` and rebuilt every mounted
// plugin view from scratch. That is correct and it is also ruinous, because a refresh happens for
// reasons that have nothing to do with the view being rebuilt: enabling *any* plugin, disabling
// another, a `when` expression flipping somewhere else. Each of those tore down every view in the
// window and made it again.
//
// Nothing visibly suffered while the mounted views were a comment field and a system monitor. A view
// with a *process* behind it is a different matter: `PcCloseView` is how a terminal kills its
// sessions, so toggling an unrelated plugin would restart whatever was running. And moving a view
// between containers — the point of the whole exercise — routes through the same function, so a
// dragged terminal would have restarted `top` on arrival.
//
// So a refresh has to answer "what actually changed" rather than "start again". That question is pure
// arithmetic over two sets and does not need AppKit, a dylib or a running app to be answered, which is
// the only reason it can be tested at all: `ContribPlugin` wraps a real `dlopen`ed library, so the
// registry itself cannot be driven from a test process.
//
// The identity of a mount is **(plugin, view id)** rather than the view id alone. Two plugins may
// legitimately declare the same view id, and treating them as one mount would hand a plugin the other
// one's view.

import Foundation

/// Identifies one mounted plugin view across refreshes.
public struct ViewMountKey: Hashable, Sendable {
    public let pluginId: String
    public let viewId: String
    public init(pluginId: String, viewId: String) {
        self.pluginId = pluginId
        self.viewId = viewId
    }
}

/// The difference between the mounts that exist and the mounts that should exist.
public struct ViewMountPlan: Sendable, Equatable {
    /// Not mounted yet: build these.
    public let create: [ViewMountKey]
    /// Mounted, still wanted, still in the same container: leave them completely alone.
    public let keep: [ViewMountKey]
    /// Mounted and still wanted, but somewhere else now — the view is re-parented, not rebuilt, and
    /// the plugin is told where it ended up. A 26-column sidebar and a 161-column dock are not the
    /// same room, and only the plugin knows what to do about that.
    public let moved: [(key: ViewMountKey, from: String, to: String)]
    /// No longer contributed (plugin disabled, `when` now false): these get `PcCloseView`.
    public let close: [ViewMountKey]

    public static func == (a: ViewMountPlan, b: ViewMountPlan) -> Bool {
        a.create == b.create && a.keep == b.keep && a.close == b.close
            && a.moved.count == b.moved.count
            && zip(a.moved, b.moved).allSatisfy { $0.key == $1.key && $0.from == $1.from && $0.to == $1.to }
    }

    /// Work out the difference.
    ///
    /// - Parameters:
    ///   - live: the mounts that exist right now, and the container each is in.
    ///   - wanted: the mounts the contribution registry says should exist, in the order they should
    ///     appear. Duplicates of the same key are ignored after the first: a manifest that declares
    ///     one view id twice would otherwise produce two mounts sharing an identity, and the second
    ///     would silently take the first one's place on the next refresh.
    public static func plan(live: [ViewMountKey: String],
                            wanted: [(key: ViewMountKey, container: String)]) -> ViewMountPlan {
        var create: [ViewMountKey] = []
        var keep: [ViewMountKey] = []
        var moved: [(key: ViewMountKey, from: String, to: String)] = []
        var seen = Set<ViewMountKey>()

        for entry in wanted {
            guard seen.insert(entry.key).inserted else { continue }
            guard let current = live[entry.key] else {
                create.append(entry.key)
                continue
            }
            if current == entry.container {
                keep.append(entry.key)
            } else {
                moved.append((key: entry.key, from: current, to: entry.container))
            }
        }

        // Deterministic order, because a set's iteration order is not: a plan compared in a test has
        // to be the same plan twice.
        let close = live.keys.filter { !seen.contains($0) }
            .sorted { ($0.pluginId, $0.viewId) < ($1.pluginId, $1.viewId) }

        return ViewMountPlan(create: create, keep: keep, moved: moved, close: close)
    }

    /// Did anything at all change? A refresh that changes nothing should touch nothing.
    public var isEmpty: Bool { create.isEmpty && moved.isEmpty && close.isEmpty }
}
