// SPDX-License-Identifier: Apache-2.0
// FSEventsWatcher.swift - Directory change watcher using polling
//
// This module provides a directory change watcher that uses periodic polling
// to detect changes. While not as efficient as FSEvents, it's more portable
// and easier to implement without CoreFoundation dependencies.

import Foundation
import PCFoundation

/// File system change event type
public enum FSChangeType: Sendable, CustomStringConvertible {
    case created
    case modified
    case removed
    case renamed

    public var description: String {
        switch self {
        case .created: return "created"
        case .modified: return "modified"
        case .removed: return "removed"
        case .renamed: return "renamed"
        }
    }
}

/// File system change event
public struct FSChangeEvent: Sendable {
    /// Path of the changed item
    public let path: String

    /// Type of change
    public let type: FSChangeType

    public init(path: String, type: FSChangeType) {
        self.path = path
        self.type = type
    }
}

/// Directory watcher - monitors a directory for changes using polling
public actor DirectoryWatcher {
    private let logger = PCFoundationLogger.logger

    /// The path being watched
    private let path: String

    /// Is the watcher running?
    private var isRunning: Bool = false

    /// Last known modification date
    private var lastModificationDate: Date?

    /// Initialize with a path to watch
    public init(path: String) {
        self.path = path
        logger.info("DirectoryWatcher initialized for \(path)")
    }

    /// Start watching the directory
    public func start() async {
        guard !isRunning else {
            logger.warning("DirectoryWatcher already running")
            return
        }

        isRunning = true

        // Get initial modification date
        let fileManager = FileManager.default
        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            lastModificationDate = attrs[.modificationDate] as? Date
        } catch {
            logger.error("Failed to get directory attributes: \(error)")
        }

        logger.info("DirectoryWatcher started for \(self.path)")

        // Start polling
        await startPolling()
    }

    /// Stop watching the directory
    public func stop() async {
        guard isRunning else {
            logger.warning("DirectoryWatcher not running")
            return
        }

        isRunning = false
        logger.info("DirectoryWatcher stopped for \(self.path)")
    }

    /// Start polling for changes
    private func startPolling() async {
        guard isRunning else { return }

        let fileManager = FileManager.default

        while isRunning {
            do {
                let attrs = try fileManager.attributesOfItem(atPath: path)
                let currentModificationDate = attrs[.modificationDate] as? Date

                if let lastMod = lastModificationDate, let currentMod = currentModificationDate {
                    if currentMod > lastMod {
                        // Directory was modified - update modification date
                        logger.info("Directory \(self.path) was modified")
                    }
                }

                lastModificationDate = currentModificationDate
            } catch {
                logger.error("Failed to get directory attributes: \(error)")
            }

            // Poll every 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    /// Check if a specific path is being watched
    public func isWatching(_ path: String) -> Bool {
        self.path == path && isRunning
    }
}
