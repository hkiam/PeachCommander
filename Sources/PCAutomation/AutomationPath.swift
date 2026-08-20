// SPDX-License-Identifier: Apache-2.0
// AutomationPath.swift — turning the path a tool was handed into one that means something.
//
// Measured against the on-device model: handed `/var/folders/…/januar.txt` by a search, it calls
// read_file with `var/folders/…/januar.txt` — the leading slash dropped. Taken literally that is a
// path relative to the application's working directory, so the read fails and the assistant reports
// a file that is plainly there as missing. It also uses bare names, meaning "the file in the folder
// I am looking at".
//
// The rules are here, as pure functions over an `exists` probe, because they decide where a write
// lands and that is worth testing rather than reasoning about. The host supplies the environment.

import Foundation

public enum AutomationPath {

    /// Resolve `path` to something that exists, or return it unchanged.
    ///
    /// Order matters and is deliberate: what was asked for, then a dropped leading slash, then
    /// relative to the folder the user is looking at. Nothing is invented — a path that resolves
    /// nowhere comes back as it went in and fails as it would have.
    public static func resolveExisting(_ path: String, activeFolder: String,
                                       exists: (String) -> Bool) -> String {
        // An empty path is not a path. Without this, "" plus the dropped-slash rule below resolves
        // to "/" — which is how `write_file("notes.txt")`, whose parent component is empty, would
        // have written to the root of the disk instead of the folder in front of the user.
        guard !path.isEmpty else { return path }
        if exists(path) { return path }
        if !path.hasPrefix("/"), exists("/" + path) { return "/" + path }
        if !path.hasPrefix("/"), !activeFolder.isEmpty {
            let candidate = (activeFolder as NSString).appendingPathComponent(path)
            if exists(candidate) { return candidate }
        }
        return path
    }

    /// Resolve a path that is about to be *created*, by its parent: a new file belongs beside the
    /// files the neighbouring paths point at. A bare name means the folder the user is looking at.
    public static func resolveForWriting(_ path: String, activeFolder: String,
                                         exists: (String) -> Bool) -> String {
        guard !path.isEmpty else { return path }
        let name = (path as NSString).lastPathComponent
        let parent = (path as NSString).deletingLastPathComponent
        // A bare name: the folder in front of the user, not the process's working directory and
        // certainly not the root of the disk.
        if parent.isEmpty {
            guard !activeFolder.isEmpty else { return path }
            return (activeFolder as NSString).appendingPathComponent(name)
        }
        if exists(parent) { return path }
        let resolved = resolveExisting(parent, activeFolder: activeFolder, exists: exists)
        guard exists(resolved) else { return path }
        return (resolved as NSString).appendingPathComponent(name)
    }
}
