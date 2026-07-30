// SPDX-License-Identifier: Apache-2.0
// HostEvent.swift - the unified host event bus payload.
//
// Peach Commander has no single event bus today (only scattered AsyncStreams in
// ConfigStore/TransferQueue/operations and the view-only PcNotifyView). The
// Automation Core introduces one typed stream so an automation session can react
// while long tasks run (e.g. wait for a copy to finish) and keep its context
// snapshot fresh. Existing per-subsystem streams feed into it.

import Foundation

/// A typed event the host emits. Codable so it can cross the MCP boundary and be
/// logged for auditing.
public enum HostEvent: Codable, Sendable, Equatable {
    /// The active panel changed folder. `path` is the new folder.
    case panelChanged(side: PanelSide, path: String)
    /// The selection in a panel changed. `count` items are selected.
    case selectionChanged(side: PanelSide, count: Int)
    /// The cursor moved onto a different entry.
    case cursorChanged(side: PanelSide, path: String?)
    /// Tabs changed (opened/closed/reordered) in a panel.
    case tabsChanged(side: PanelSide)
    /// A background operation made progress.
    case operationProgress(id: String, fraction: Double)
    /// A background operation finished (`ok` false = failed/cancelled).
    case operationFinished(id: String, ok: Bool)
    /// A configuration value changed.
    case configChanged(key: String)
    /// A search produced (more) results.
    case searchResults(count: Int)

    public enum PanelSide: String, Codable, Sendable { case left, right }
}
