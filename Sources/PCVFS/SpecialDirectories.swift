// SpecialDirectories.swift - Standard "go to" locations for the panel header (TODOS #65).
//
// The common destinations (Home, Desktop, Documents, Downloads, Applications, Root),
// filtered to those that actually exist. Pure aside from existence checks; `home` and
// the FileManager are injectable so it is unit-testable.

import Foundation

public struct SpecialDirectory: Equatable, Sendable {
    public let name: String
    public let path: String
    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public enum SpecialDirectories {
    public static func all(home: String = NSHomeDirectory(),
                           fileManager: FileManager = .default) -> [SpecialDirectory] {
        let candidates: [(String, String)] = [
            ("Home", home),
            ("Desktop", home + "/Desktop"),
            ("Documents", home + "/Documents"),
            ("Downloads", home + "/Downloads"),
            ("Applications", "/Applications"),
            ("Root", "/")
        ]
        return candidates.compactMap { name, path in
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }
            return SpecialDirectory(name: name, path: path)
        }
    }
}
