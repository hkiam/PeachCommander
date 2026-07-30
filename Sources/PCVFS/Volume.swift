// SPDX-License-Identifier: Apache-2.0
// Volume.swift - Volume management for Peach Commander
//
// Provides volume information, free space calculation, and mount/unmount operations

import Foundation
import PCFoundation

/// Represents a mounted volume
public struct Volume: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public let isRemovable: Bool
    public let isEjectable: Bool
    public let isHidden: Bool
    public let capacity: Int64
    public let freeSpace: Int64
    public let fsType: String
    /// Optional drive-chip emoji supplied by a plugin ("" = host default icon).
    public let icon: String
    /// Drive-bar sort priority: >0 pins the chip right after the boot drive
    /// (lower first); 0 = ordinary volume (sorted by name). Plugin-defined.
    public let sortOrder: Int

    public init(
        id: String,
        name: String,
        path: String,
        isRemovable: Bool,
        isEjectable: Bool,
        isHidden: Bool,
        capacity: Int64,
        freeSpace: Int64,
        fsType: String,
        icon: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isRemovable = isRemovable
        self.isEjectable = isEjectable
        self.isHidden = isHidden
        self.capacity = capacity
        self.freeSpace = freeSpace
        self.fsType = fsType
        self.icon = icon
        self.sortOrder = sortOrder
    }

    /// Get the used space
    public var usedSpace: Int64 {
        capacity - freeSpace
    }

    /// Get a formatted string for free space
    public func freeSpaceFormatted() -> String {
        ByteSize(freeSpace).formatted(style: .mb)
    }

    /// Get a formatted string for capacity
    public func capacityFormatted() -> String {
        ByteSize(capacity).formatted(style: .mb)
    }

    /// Get the percentage of free space
    public func freeSpacePercentage() -> Double {
        capacity > 0 ? (Double(freeSpace) / Double(capacity) * 100.0) : 0.0
    }
}

/// Volume manager - provides access to mounted volumes
public actor VolumeManager {
    private let logger = PCFoundationLogger.logger

    public init() {
        logger.info("VolumeManager initialized")
    }

    /// Get all mounted volumes
    public func getVolumes() -> [Volume] {
        // Enumerate the actually-mounted volumes (boot disk, external drives AND
        // mounted DMGs under /Volumes). The previous implementation listed the
        // CONTENTS of "/" instead, which returned one bogus "Macintosh HD" entry per
        // top-level folder and never showed DMGs.
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
            .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsBrowsableKey
        ]
        guard let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys, options: []) else {
            return []
        }

        var volumes: [Volume] = []
        for url in volumeURLs {
            // Skip non-browsable pseudo-volumes (e.g. the hidden system Data volume).
            if let rv = try? url.resourceValues(forKeys: [.volumeIsBrowsableKey]),
               rv.volumeIsBrowsable == false { continue }
            if let volume = createVolume(from: url) {
                volumes.append(volume)
            }
        }

        // Sort volumes: the boot volume ("/") first, then by name.
        volumes.sort { a, b in
            if (a.path == "/") != (b.path == "/") { return a.path == "/" }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        return volumes
    }

    /// Get the volume for a specific path
    public func getVolume(for path: String) -> Volume? {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        // Check if resource values can be obtained
        let _ = try? url.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ])

        return createVolume(from: url)
    }

    /// Get volumes with free space info
    public func getVolumesWithFreeSpace() -> [Volume] {
        getVolumes()
    }

    /// Available cloud providers (iCloud, …) as `Volume`s so they appear in the
    /// drive bar. Free space/capacity come from the underlying local volume.
    public func getCloudVolumes() -> [Volume] {
        CloudProviderRegistry.available().map { provider in
            let rv = try? URL(fileURLWithPath: provider.localPath).resourceValues(
                forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            return Volume(
                id: "cloud:\(provider.id)",
                name: provider.name,
                path: provider.localPath,
                isRemovable: false,
                isEjectable: false,
                isHidden: false,
                capacity: Int64(rv?.volumeTotalCapacity ?? 0),
                freeSpace: Int64(rv?.volumeAvailableCapacity ?? 0),
                fsType: "Cloud"
            )
        }
    }

    /// Mounted volumes plus available cloud providers (for the drive bar).
    public func getVolumesIncludingCloud() -> [Volume] {
        getVolumes() + getCloudVolumes()
    }

    /// Eject a volume by path
    public func ejectVolume(at path: String) async throws {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()

        // Check if volume is ejectable using diskutil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["diskutil", "info", url.path]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "PCVFS", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to get volume info"
            ])
        }

        // Use diskutil to eject
        let ejectProcess = Process()
        ejectProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        ejectProcess.arguments = ["diskutil", "eject", url.path]

        try ejectProcess.run()
        ejectProcess.waitUntilExit()

        if ejectProcess.terminationStatus != 0 {
            throw NSError(domain: "PCVFS", code: Int(ejectProcess.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to eject volume"
            ])
        }
    }

    /// Mount a volume by device path
    public func mountVolume(at devicePath: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["diskutil", "mount", devicePath]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "PCVFS", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "Failed to mount volume"
            ])
        }
    }

    // MARK: - Private Helpers

    private func createVolume(from url: URL) -> Volume? {
        guard let resourceValues = try? url.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeLocalizedFormatDescriptionKey
        ]) else {
            return nil
        }

        let name = resourceValues.volumeName ?? url.lastPathComponent
        let isRemovable = resourceValues.volumeIsRemovable ?? false
        let isEjectable = resourceValues.volumeIsEjectable ?? false
        let capacity = Int64(resourceValues.volumeTotalCapacity ?? 0)
        let freeSpace = Int64(resourceValues.volumeAvailableCapacity ?? 0)
        // Filesystem description from the (free) URL resource value — previously this
        // shelled out to `diskutil info -plist` on EVERY status-bar refresh, forking a
        // subprocess per navigation/selection and serializing it on the actor.
        let fsType = resourceValues.volumeLocalizedFormatDescription ?? ""

        return Volume(
            id: url.path,
            name: name,
            path: url.path,
            isRemovable: isRemovable,
            isEjectable: isEjectable,
            isHidden: false, // We don't check hidden volumes for now
            capacity: capacity,
            freeSpace: freeSpace,
            fsType: fsType
        )
    }
}
