// SPDX-License-Identifier: Apache-2.0
// FileProperties.swift - Pure model + reader for the file Properties dialog (I03-T07)
//
// This file is intentionally AppKit-free so it can be unit-tested in isolation
// and reused by any future front-end (AppKit today, maybe something else later).
// See docs/specs/SPEC-003-navigation-selection.md §3 (Alt+Enter) and F-036
// (symlink target display).

import Foundation
import PCFoundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Read-only snapshot of filesystem attributes for a single path, suitable for
/// display in a Properties dialog. Uses lstat semantics: a symbolic link is
/// reported as a link (with its target), never silently resolved.
public struct FileProperties: Sendable, Equatable {
    /// Last path component (display name).
    public let name: String
    /// Full path as given to the reader.
    public let path: String
    /// Human-readable kind, e.g. "Folder", "Document", "Application", "Symbolic Link".
    public let kindDescription: String
    /// Size in bytes, or -1 when unknown/not applicable (directories).
    public let byteSize: Int64
    /// Human-formatted size, e.g. "1.2 KB", or an em dash when unknown.
    public let sizeText: String
    /// Last modification date, if available.
    public let modified: Date?
    /// Creation date, if available.
    public let created: Date?
    /// Raw POSIX permission bits (lower 9 bits meaningful).
    public let posixPermissions: UInt16
    /// 10-character ls-style permissions string, e.g. "drwxr-xr-x".
    public let permissionsText: String
    /// Owning user name, if resolvable.
    public let ownerName: String?
    /// Owning group name, if resolvable.
    public let groupName: String?
    /// Whether the item itself is a symbolic link.
    public let isSymbolicLink: Bool
    /// Resolved target path of the symbolic link, if `isSymbolicLink` is true.
    public let symlinkTarget: String?
    /// Whether the item (or, for a symlink, its target) is a directory.
    public let isDirectory: Bool

    public init(
        name: String,
        path: String,
        kindDescription: String,
        byteSize: Int64,
        sizeText: String,
        modified: Date?,
        created: Date?,
        posixPermissions: UInt16,
        permissionsText: String,
        ownerName: String?,
        groupName: String?,
        isSymbolicLink: Bool,
        symlinkTarget: String?,
        isDirectory: Bool
    ) {
        self.name = name
        self.path = path
        self.kindDescription = kindDescription
        self.byteSize = byteSize
        self.sizeText = sizeText
        self.modified = modified
        self.created = created
        self.posixPermissions = posixPermissions
        self.permissionsText = permissionsText
        self.ownerName = ownerName
        self.groupName = groupName
        self.isSymbolicLink = isSymbolicLink
        self.symlinkTarget = symlinkTarget
        self.isDirectory = isDirectory
    }
}

/// Builds `FileProperties` values from the local filesystem.
public enum FilePropertiesReader {
    /// Placeholder text used for sizes that are unknown or not applicable
    /// (e.g. a directory's size, which is computed separately on demand).
    private static var unknownSizeText: String {
        String(localized: "—", comment: "Placeholder for an unknown/uncalculated file size")
    }

    /// Reads filesystem attributes for the item at `path`.
    ///
    /// Performs synchronous filesystem I/O (`lstat`, `FileManager` attribute
    /// lookups) — callers should invoke this off the main thread for
    /// network-backed or otherwise slow volumes.
    ///
    /// Uses lstat semantics so a symbolic link is reported as a link with its
    /// own target, not the resolved destination (F-036).
    public static func read(path: String) -> FileProperties {
        let fm = FileManager.default
        let name = (path as NSString).lastPathComponent

        var statBuf = stat()
        let lstatResult = path.withCString { lstat($0, &statBuf) }
        let lstatSucceeded = lstatResult == 0

        let isSymbolicLink = lstatSucceeded && (statBuf.st_mode & S_IFMT) == S_IFLNK

        var symlinkTarget: String?
        if isSymbolicLink {
            symlinkTarget = try? fm.destinationOfSymbolicLink(atPath: path)
        }

        // For attributes describing "what this item is" (size, dates, directory-ness)
        // we want the link's own attributes, not the target's — so stick with lstat's
        // stat buffer rather than following the link via `stat(2)`.
        let isDirectory: Bool
        if isSymbolicLink {
            // A symlink to a directory is still reported as a link; but callers that
            // want to know whether it *points at* a directory can inspect the target.
            var targetIsDir: ObjCBool = false
            if let target = symlinkTarget {
                let resolvedPath = (target as NSString).isAbsolutePath
                    ? target
                    : (((path as NSString).deletingLastPathComponent) as NSString).appendingPathComponent(target)
                fm.fileExists(atPath: resolvedPath, isDirectory: &targetIsDir)
            }
            isDirectory = targetIsDir.boolValue
        } else if lstatSucceeded {
            isDirectory = (statBuf.st_mode & S_IFMT) == S_IFDIR
        } else {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: path, isDirectory: &isDir)
            isDirectory = isDir.boolValue
        }

        let posixPermissions: UInt16 = lstatSucceeded
            ? UInt16(statBuf.st_mode & 0o7777)
            : 0

        let typeChar: Character
        if isSymbolicLink {
            typeChar = "l"
        } else if isDirectory {
            typeChar = "d"
        } else {
            typeChar = "-"
        }
        let permissionsText = String(typeChar) + rwxString(from: posixPermissions)

        let attributes = try? fm.attributesOfItem(atPath: path)
        let modified = attributes?[.modificationDate] as? Date
        let created = attributes?[.creationDate] as? Date
        let ownerName = attributes?[.ownerAccountName] as? String
        let groupName = attributes?[.groupOwnerAccountName] as? String

        let byteSize: Int64
        let sizeText: String
        if isSymbolicLink {
            // Report the link's own size (length of the target string on disk),
            // not the target's size.
            byteSize = lstatSucceeded ? Int64(statBuf.st_size) : -1
            sizeText = byteSize >= 0
                ? ByteSize(byteSize).formatted(style: .kb)
                : unknownSizeText
        } else if isDirectory {
            byteSize = -1
            sizeText = unknownSizeText
        } else {
            let fileSize = (attributes?[.size] as? NSNumber)?.int64Value
            byteSize = fileSize ?? (lstatSucceeded ? Int64(statBuf.st_size) : -1)
            sizeText = byteSize >= 0
                ? ByteSize(byteSize).formatted(style: .kb)
                : unknownSizeText
        }

        let kindDescription = describeKind(
            path: path,
            name: name,
            isDirectory: isDirectory,
            isSymbolicLink: isSymbolicLink
        )

        return FileProperties(
            name: name,
            path: path,
            kindDescription: kindDescription,
            byteSize: byteSize,
            sizeText: sizeText,
            modified: modified,
            created: created,
            posixPermissions: posixPermissions,
            permissionsText: permissionsText,
            ownerName: ownerName,
            groupName: groupName,
            isSymbolicLink: isSymbolicLink,
            symlinkTarget: symlinkTarget,
            isDirectory: isDirectory
        )
    }

    /// Builds the 9-character `rwxrwxrwx` portion from POSIX permission bits.
    private static func rwxString(from mode: UInt16) -> String {
        let flags: [(UInt16, Character)] = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x"),
        ]
        var result = ""
        result.reserveCapacity(9)
        for (bit, char) in flags {
            result.append((mode & bit) != 0 ? char : "-")
        }
        return result
    }

    /// Produces a short, localized human description of an item's kind.
    private static func describeKind(
        path: String,
        name: String,
        isDirectory: Bool,
        isSymbolicLink: Bool
    ) -> String {
        if isSymbolicLink {
            return String(localized: "Symbolic Link", comment: "Properties dialog kind: a symlink")
        }

        let ext = (name as NSString).pathExtension.lowercased()

        if isDirectory {
            if ext == "app" {
                return String(localized: "Application", comment: "Properties dialog kind: an app bundle")
            }
            return String(localized: "Folder", comment: "Properties dialog kind: a directory")
        }

        #if canImport(UniformTypeIdentifiers)
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .application) {
                return String(localized: "Application", comment: "Properties dialog kind: an executable")
            }
            if let description = type.localizedDescription, !description.isEmpty {
                return description
            }
        }
        #endif

        if ext.isEmpty {
            return String(localized: "Document", comment: "Properties dialog kind: generic file with no extension")
        }
        return ext.uppercased() + " " + String(localized: "File", comment: "Properties dialog kind: fallback suffix after an extension")
    }
}
