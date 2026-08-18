// SPDX-License-Identifier: Apache-2.0
// git.swift — "Git Status" / "Branch" columns and the Git commands, as an external PDX plugin.
//
// Implements the PDX content C-ABI (ContentGetSupportedField / ContentGetValue) plus contribution
// commands on top of the system git. The host shows the two fields as extra panel columns and fetches
// values lazily per file; the parsing and the "which git" policy live in Plugins/SDK/PluginGit.swift,
// where they are unit-tested.
//
// Phase 0 of docs/analysis/git-plugin-plan.md fixed four things here (F-415):
//
//   * **Which git.** `/usr/bin/git` was hardcoded, and on macOS that is a Command Line Tools *shim*:
//     without the tools installed, running it opens the installer — triggered by scrolling a folder,
//     because a column value invokes it. Resolution is now setting → Homebrew → toolchain → shim, and
//     the shim only when the toolchain is really there.
//   * **Which thread.** `ContributionRegistry` is @MainActor, so every command ran on the main thread —
//     `push` and `pull` froze the whole application for the duration of a network operation, with no
//     way to cancel. Commands now collect their input on the main thread, run git on a queue, and report
//     back on the main thread. (A *progress* surface needs host work; see the plan's §6.)
//   * **Which paths.** `status --porcelain` (v1) quotes anything outside ASCII, so the column was empty
//     for every file with an umlaut in its name. `--porcelain=v2 -z` reports raw bytes.
//   * **Which cache.** It was keyed by the file's parent directory (a thousand entries for a thousand
//     directories, each holding the whole repository) and invalidated only by the plugin's own commands,
//     so a commit made in a terminal left the column stale indefinitely. It is keyed by repository root
//     now and invalidated by `.git/index`'s mtime plus a short TTL for working-tree edits.

import AppKit

// MARK: - Which git

private let gitLock = NSLock()
private var resolvedGit: String??           // nil = not looked for yet; .some(nil) = looked, not found

/// The git to use, resolved once. `PCGitExecutable` in the environment overrides everything, which is
/// what the tests and the automation harness set.
private func gitExecutable() -> String? {
    gitLock.lock()
    if let cached = resolvedGit { gitLock.unlock(); return cached }
    gitLock.unlock()
    let manager = FileManager.default
    let found = PluginGit.resolveExecutable(
        setting: ProcessInfo.processInfo.environment["PCGitExecutable"],
        isExecutable: { manager.isExecutableFile(atPath: $0) },
        exists: { manager.fileExists(atPath: $0) })
    gitLock.lock(); resolvedGit = .some(found); gitLock.unlock()
    if found == nil {
        NSLog("[git plugin] no usable git found — the columns stay empty and the commands report it")
    }
    return found
}

// MARK: - Running git

/// Run git, capturing stdout (and stderr when `combined`, because git says useful things there).
///
/// `GIT_TERMINAL_PROMPT=0` is the important one: a `push` that wants a password must fail and say so
/// rather than wait forever on a terminal this process does not have.
private func runGit(_ arguments: [String], combined: Bool = false) -> (out: String, ok: Bool) {
    guard let executable = gitExecutable() else { return (L("Git was not found on this Mac."), false) }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment["GIT_TERMINAL_PROMPT"] = "0"
    environment["GIT_OPTIONAL_LOCKS"] = "0"
    process.environment = environment
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = combined ? pipe : FileHandle.nullDevice
    do { try process.run() } catch { return (L("Git could not be started."), false) }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), process.terminationStatus == 0)
}

// MARK: - Repository lookup and cache

private struct CacheEntry {
    let status: PluginGit.RepoStatus
    let indexMTime: Date?
    let cachedAt: Date
}

private let cacheLock = NSLock()
/// directory -> (repo root, the directory's repo-relative prefix); nil = not a repository
private var locationByDirectory: [String: (root: String, prefix: String)?] = [:]
private var statusByRoot: [String: CacheEntry] = [:]

private func indexMTime(root: String) -> Date? {
    let path = (root as NSString).appendingPathComponent(".git/index")
    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
    return attributes?[.modificationDate] as? Date
}

/// The repository a directory belongs to and where inside it that directory sits, cached. One
/// `rev-parse` per directory, not per file — and it answers both questions in the same call.
private func location(forDirectory directory: String) -> (root: String, prefix: String)? {
    cacheLock.lock()
    if let cached = locationByDirectory[directory] { cacheLock.unlock(); return cached }
    cacheLock.unlock()
    let result = runGit(["-C", directory] + PluginGit.locateArguments)
    let location = result.ok ? PluginGit.parseLocate(result.out) : nil
    cacheLock.lock()
    if locationByDirectory.count > 4096 { locationByDirectory.removeAll() }
    locationByDirectory[directory] = location
    cacheLock.unlock()
    return location
}

/// The repository's status, cached per root and refreshed when the index moved or the entry aged out.
private func status(forRoot root: String) -> PluginGit.RepoStatus? {
    let mtime = indexMTime(root: root)
    cacheLock.lock()
    if let entry = statusByRoot[root],
       PluginGit.cacheIsFresh(cachedIndexMTime: entry.indexMTime, currentIndexMTime: mtime,
                              cachedAt: entry.cachedAt, now: Date()) {
        cacheLock.unlock()
        return entry.status
    }
    cacheLock.unlock()
    let result = runGit(["-C", root] + PluginGit.statusArguments)
    guard result.ok else { return nil }
    let parsed = PluginGit.parseStatus(result.out)
    cacheLock.lock()
    if statusByRoot.count > 64 { statusByRoot.removeAll() }   // many repositories open: keep it bounded
    statusByRoot[root] = CacheEntry(status: parsed, indexMTime: mtime, cachedAt: Date())
    cacheLock.unlock()
    return parsed
}

private func invalidateCaches() {
    cacheLock.lock(); statusByRoot.removeAll(); locationByDirectory.removeAll(); cacheLock.unlock()
}

/// Repository root plus the item's repository-relative path, from git's own prefix.
///
/// No comparing of paths: git answers with `/private/tmp/r` where the host says `/tmp/r`, and
/// `resolvingSymlinksInPath` maps `/private/tmp` back to `/tmp`, so neither prefixes the other (see
/// `PluginGit.relativePath`).
private func locate(_ path: String) -> (root: String, relative: String)? {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    let isDir = exists && isDirectory.boolValue
    let directory = isDir ? path : (path as NSString).deletingLastPathComponent
    guard let location = location(forDirectory: directory) else { return nil }
    let relative = isDir
        ? PluginGit.relativePath(directoryPrefix: location.prefix)
        : PluginGit.relativePath(prefix: location.prefix, name: (path as NSString).lastPathComponent)
    return (location.root, relative)
}

/// The label a status gets in the column. Localized here; `PluginGit` stays free of user-facing text.
private func label(for change: PluginGit.Change) -> String {
    switch change {
    case .unchanged:   return ""
    case .modified:    return L("Modified")
    case .added:       return L("Added")
    case .deleted:     return L("Deleted")
    case .renamed:     return L("Renamed")
    case .copied:      return L("Copied")
    case .typeChanged: return L("Type changed")
    case .untracked:   return L("Untracked")
    case .ignored:     return L("Ignored")
    case .conflict:    return L("Conflict")
    }
}

/// "Modified" for an unstaged change, "Modified (staged)" when it is in the index — the distinction the
/// commit command depends on, and the one v1 porcelain could not report.
private func columnLabel(for file: PluginGit.FileStatus) -> String {
    let base = label(for: file.summary)
    guard file.isStaged, file.summary != .conflict else { return base }
    return String(format: L("%@ (staged)"), base)
}

private func setCString(_ s: String, _ dst: UnsafeMutableRawPointer, _ cap: Int) {
    s.withCString { _ = strlcpy(dst.assumingMemoryBound(to: CChar.self), $0, cap) }
}

// MARK: - PDX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ index: Int32, _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let fieldName, let units else { return Int32(PC_FT_NOMOREFIELDS) }
    units[0] = 0
    // NOT localized on purpose: the host derives the stable content-field id from this
    // name (PDXContentProvider.fieldID), and that id keys saved column sets. Localized
    // column HEADERS need a host-side id/title split — a separate task. Cell values
    // (ContentGetValue → columnLabel) and all dialogs ARE localized.
    switch index {
    case 0: _ = "Git Status".withCString { strlcpy(fieldName, $0, Int(maxlen)) }; return Int32(PC_FT_STRING)
    case 1: _ = "Branch".withCString { strlcpy(fieldName, $0, Int(maxlen)) }; return Int32(PC_FT_STRING)
    default: return Int32(PC_FT_NOMOREFIELDS)
    }
}

@_cdecl("ContentGetValue")
public func ContentGetValue(_ fileName: UnsafeMutablePointer<CChar>?, _ fieldIndex: Int32, _ unitIndex: Int32,
                            _ fieldValue: UnsafeMutableRawPointer?, _ maxlen: Int32, _ flags: Int32) -> Int32 {
    guard let fileName, let fieldValue else { return Int32(PC_FT_NOSUCHFIELD) }
    let path = String(cString: fileName)
    guard let (root, relative) = locate(path), let repo = status(forRoot: root) else {
        return Int32(PC_FT_FIELDEMPTY)
    }
    switch fieldIndex {
    case 0:
        // A directory carries the status of what is inside it: a folder holding a modified file is worth
        // seeing at a glance, which is what an overlay icon does in the reference products.
        if let file = repo.files[relative] {
            setCString(columnLabel(for: file), fieldValue, Int(maxlen))
            return Int32(PC_FT_STRING)
        }
        if !relative.isEmpty, let summary = directorySummary(repo, relative: relative) {
            setCString(summary, fieldValue, Int(maxlen))
            return Int32(PC_FT_STRING)
        }
        return Int32(PC_FT_FIELDEMPTY)
    case 1:
        let branch = repo.detached ? L("(detached)") : repo.branch
        guard !branch.isEmpty else { return Int32(PC_FT_FIELDEMPTY) }
        var text = branch
        if repo.ahead > 0 || repo.behind > 0 {
            text += String(format: "  ↑%lld ↓%lld", repo.ahead, repo.behind)
        }
        setCString(text, fieldValue, Int(maxlen))
        return Int32(PC_FT_STRING)
    default:
        return Int32(PC_FT_NOSUCHFIELD)
    }
}

/// "3 changes" for a directory that contains them, or nil when it is clean.
private func directorySummary(_ repo: PluginGit.RepoStatus, relative: String) -> String? {
    let prefix = relative.hasSuffix("/") ? relative : relative + "/"
    let count = repo.files.keys.reduce(into: 0) { total, path in
        if path.hasPrefix(prefix) { total += 1 }
    }
    guard count > 0 else { return nil }
    return String(format: L("%lld change(s)"), count)
}

// MARK: - Commands

/// Contribution commands on the cursor's repository.
///
/// Input is collected here, on the main thread; git runs on a queue; the report comes back on the main
/// thread. `services` is a stack value in the host and must be *copied* before the hop — keeping the
/// pointer would be a use-after-return.
@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let svc = services.pointee
    var buf = [CChar](repeating: 0, count: 4096)
    let ok = svc.cursorPath.map { $0(svc.host, &buf, 4096) } ?? 0
    let cursor = ok != 0 ? String(cString: buf) : FileManager.default.currentDirectoryPath

    guard gitExecutable() != nil else {
        svc.presentInfo?(svc.host, L("Git"), L("Git was not found on this Mac."))
        return
    }
    guard let (root, relative) = locate(cursor) else {
        svc.presentInfo?(svc.host, L("Git"), L("Not a Git repository."))
        return
    }

    /// Run `work` off the main thread, then report its output and refresh the panel.
    func background(_ title: String, _ work: @escaping () -> (out: String, ok: Bool)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async {
                invalidateCaches()                  // the repository moved under our cache
                svc.reloadActivePanel?(svc.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                svc.presentInfo?(svc.host, title,
                                 message.isEmpty ? (result.ok ? L("Done.") : L("Failed.")) : message)
            }
        }
    }

    switch id {
    case "plugin.git.status":
        // Reading is bounded and cached; keep it synchronous so the sheet appears at once.
        if let repo = status(forRoot: root) { showStatus(repo, root: root, svc) }
    case "plugin.git.stage":
        let target = relative.isEmpty ? "." : relative
        background(L("Git Add")) { runGit(["-C", root, "add", "--", target], combined: true) }
    case "plugin.git.commit":
        // The index, not `-a`: staging and committing were contradicting each other, so a file staged
        // with the command next to this one had no bearing on what was committed.
        guard let repo = status(forRoot: root) else { return }
        guard repo.files.values.contains(where: \.isStaged) else {
            svc.presentInfo?(svc.host, L("Git Commit"),
                             L("Nothing is staged. Use “Git Add (stage)” first."))
            return
        }
        guard let message = promptCommitMessage() else { return }
        background(L("Git Commit")) { runGit(["-C", root, "commit", "-m", message], combined: true) }
    case "plugin.git.push":
        background(L("Git Push")) { runGit(["-C", root, "push"], combined: true) }
    case "plugin.git.pull":
        background(L("Git Pull")) { runGit(["-C", root, "pull", "--ff-only"], combined: true) }
    default:
        break
    }
}

private func showStatus(_ repo: PluginGit.RepoStatus, root: String, _ svc: PcHostServices) {
    var lines = [String(format: L("Branch: %@"), repo.detached ? L("(detached)") : repo.branch)]
    if let upstream = repo.upstream {
        lines.append(String(format: L("Tracking: %@  ↑%lld ↓%lld"), upstream, repo.ahead, repo.behind))
    }
    lines.append("")
    let files = repo.ordered
    if files.isEmpty {
        lines.append(L("Working tree clean."))
    } else {
        let staged = files.filter(\.isStaged).count
        lines.append(String(format: L("%lld change(s), %lld staged:"), files.count, staged))
        for file in files.prefix(40) {
            lines.append("  \(columnLabel(for: file))  \(file.path)")
        }
        if files.count > 40 {
            lines.append(String(format: L("  … and %lld more"), files.count - 40))
        }
    }
    svc.presentInfo?(svc.host, L("Git Status"), lines.joined(separator: "\n"))
}

/// Modal commit-message prompt; nil if cancelled/empty.
private func promptCommitMessage() -> String? {
    let alert = NSAlert(); alert.messageText = L("Commit message")
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 22))
    alert.accessoryView = field; alert.addButton(withTitle: L("Commit")); alert.addButton(withTitle: L("Cancel"))
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    let msg = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return msg.isEmpty ? nil : msg
}
