// OccupiedSpaceCalculator.swift - "Occupied space" of a selection (SPEC-016 §1, Ctrl+L).
//
// Sums the byte size of a set of local paths: a file contributes its own size, a
// directory contributes the recursive total of the files it contains (via
// DirectorySizeCalculator, which never follows symlinks). Also reports how many
// files and folders were counted, for the summary dialog.

import Foundation
import PCFoundation

public struct OccupiedSpace: Equatable, Sendable {
    public let bytes: Int64
    public let files: Int
    public let folders: Int
    public init(bytes: Int64, files: Int, folders: Int) {
        self.bytes = bytes
        self.files = files
        self.folders = folders
    }
}

public actor OccupiedSpaceCalculator {
    private let sizer = DirectorySizeCalculator()
    public init() {}

    /// Measure the total occupied space of the given local paths.
    public func measure(_ paths: [String]) async -> OccupiedSpace {
        var bytes: Int64 = 0
        var files = 0
        var folders = 0
        let fm = FileManager.default
        for path in paths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                folders += 1
                bytes += await sizer.size(of: path)
            } else {
                files += 1
                if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? Int64 {
                    bytes += size
                }
            }
        }
        return OccupiedSpace(bytes: bytes, files: files, folders: folders)
    }
}
