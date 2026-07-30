// SPDX-License-Identifier: Apache-2.0
// git.swift — "Git Status" / "Branch" columns as an external PDX content plugin.
//
// Implements the PDX content C-ABI (ContentGetSupportedField / ContentGetValue) on
// top of the system git. The host shows the two fields as extra panel columns and
// fetches values lazily per file. To avoid running git per file, the porcelain
// status + branch are computed once per directory and cached (keyed by the file's
// parent directory); the host clears its own side-cache per listing, and this
// plugin's cache is bounded/refreshed by directory. Self-contained (Foundation).

import AppKit

private let gitPath = "/usr/bin/git"

private struct RepoInfo { let branch: String; let status: [String: String] }   // abspath -> label

private let cacheLock = NSLock()
private var dirCache: [String: RepoInfo?] = [:]   // file's parent dir -> repo info (nil = not a repo)

// MARK: - git helpers

private func git(_ args: [String]) -> (out: String, ok: Bool) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: gitPath)
    p.arguments = args
    let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return ("", false) }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus == 0)
}

private func statusLabel(_ xy: String) -> String {
    if xy.contains("U") { return L("Conflict") }
    switch xy {
    case "??": return L("Untracked")
    case "!!": return L("Ignored")
    default: break
    }
    let code = Set(xy)
    if code.contains("A") { return L("Added") }
    if code.contains("D") { return L("Deleted") }
    if code.contains("R") { return L("Renamed") }
    if code.contains("C") { return L("Copied") }
    if code.contains("M") { return L("Modified") }
    return L("Changed")
}

private func computeRepoInfo(dir: String) -> RepoInfo? {
    let top = git(["-C", dir, "rev-parse", "--show-toplevel"])
    guard top.ok else { return nil }
    let root = top.out.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !root.isEmpty else { return nil }
    let branch = git(["-C", root, "rev-parse", "--abbrev-ref", "HEAD"]).out
        .trimmingCharacters(in: .whitespacesAndNewlines)
    var map: [String: String] = [:]
    let porcelain = git(["-C", root, "status", "--porcelain"])
    if porcelain.ok {
        for line in porcelain.out.split(separator: "\n", omittingEmptySubsequences: true) {
            let s = String(line)
            guard s.count > 3 else { continue }
            let xy = String(s.prefix(2))
            var rel = String(s.dropFirst(3))
            if let r = rel.range(of: " -> ") { rel = String(rel[r.upperBound...]) }   // rename: new name
            while rel.hasSuffix("/") { rel.removeLast() }                             // untracked dir
            let abs = (root as NSString).appendingPathComponent(rel)
            map[abs] = statusLabel(xy)
        }
    }
    return RepoInfo(branch: branch, status: map)
}

private func infoForFile(_ path: String) -> RepoInfo? {
    let dir = (path as NSString).deletingLastPathComponent
    cacheLock.lock()
    if let cached = dirCache[dir] { cacheLock.unlock(); return cached }
    cacheLock.unlock()
    let info = computeRepoInfo(dir: dir)
    cacheLock.lock(); if dirCache.count > 256 { dirCache.removeAll() }; dirCache[dir] = info; cacheLock.unlock()
    return info
}

private func setCString(_ s: String, _ dst: UnsafeMutableRawPointer, _ cap: Int) {
    s.withCString { _ = strlcpy(dst.assumingMemoryBound(to: CChar.self), $0, cap) }
}

// MARK: - PDX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

/// git with combined stdout+stderr (git prints useful info to stderr).
private func gitCombined(_ args: [String]) -> (out: String, ok: Bool) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: gitPath); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    do { try p.run() } catch { return ("git not available", false) }
    let data = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus == 0)
}

/// Repo root for the cursor item (dir itself if a directory, else its parent).
private func repoRoot(for path: String) -> String? {
    var isDir: ObjCBool = false
    let base = (FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        ? path : (path as NSString).deletingLastPathComponent
    let r = gitCombined(["-C", base, "rev-parse", "--show-toplevel"])
    guard r.ok else { return nil }
    let root = r.out.trimmingCharacters(in: .whitespacesAndNewlines)
    return root.isEmpty ? nil : root
}

/// Contribution commands (status + add/commit/push/pull) on the cursor's repo.
@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let commandId, let services else { return }
    let id = String(cString: commandId)
    let svc = services.pointee
    var buf = [CChar](repeating: 0, count: 4096)
    let ok = svc.cursorPath.map { $0(svc.host, &buf, 4096) } ?? 0
    let cursor = ok != 0 ? String(cString: buf) : FileManager.default.currentDirectoryPath
    guard let root = repoRoot(for: cursor) else {
        svc.presentInfo?(svc.host, L("Git"), L("Not a Git repository.")); return
    }

    func report(_ title: String, _ result: (out: String, ok: Bool)) {
        cacheLock.lock(); dirCache.removeAll(); cacheLock.unlock()   // status changed
        svc.reloadActivePanel?(svc.host)
        let msg = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        svc.presentInfo?(svc.host, title, msg.isEmpty ? (result.ok ? L("Done.") : L("Failed.")) : msg)
    }

    switch id {
    case "plugin.git.status":
        if let info = infoForFile(cursor) { showStatus(info, svc) }
    case "plugin.git.stage":
        report(L("Git Add"), gitCombined(["-C", root, "add", "--", cursor]))
    case "plugin.git.commit":
        guard let message = promptCommitMessage() else { return }
        report(L("Git Commit"), gitCombined(["-C", root, "commit", "-a", "-m", message]))
    case "plugin.git.push":
        report(L("Git Push"), gitCombined(["-C", root, "push"]))
    case "plugin.git.pull":
        report(L("Git Pull"), gitCombined(["-C", root, "pull", "--ff-only"]))
    default:
        break
    }
}

private func showStatus(_ info: RepoInfo, _ svc: PcHostServices) {
    var lines = [String(format: L("Branch: %@"), info.branch.isEmpty ? L("(detached)") : info.branch), ""]
    if info.status.isEmpty {
        lines.append(L("Working tree clean."))
    } else {
        lines.append(String(format: L("%lld change(s):"), info.status.count))
        for (p, label) in info.status.sorted(by: { $0.key < $1.key }).prefix(40) {
            lines.append("  \(label)  \((p as NSString).abbreviatingWithTildeInPath)")
        }
        if info.status.count > 40 {
            lines.append(String(format: L("  … and %lld more"), info.status.count - 40))
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

@_cdecl("ContentGetSupportedField")
public func ContentGetSupportedField(_ index: Int32, _ fieldName: UnsafeMutablePointer<CChar>?,
                                     _ units: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let fieldName, let units else { return Int32(PC_FT_NOMOREFIELDS) }
    units[0] = 0
    // NOT localized on purpose: the host derives the stable content-field id from this
    // name (PDXContentProvider.fieldID), and that id keys saved column sets. Localized
    // column HEADERS need a host-side id/title split — a separate task. Cell values
    // (ContentGetValue → statusLabel) and all dialogs ARE localized.
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
    guard let info = infoForFile(path) else { return Int32(PC_FT_FIELDEMPTY) }
    switch fieldIndex {
    case 0:
        guard let label = info.status[path] else { return Int32(PC_FT_FIELDEMPTY) }
        setCString(label, fieldValue, Int(maxlen))
        return Int32(PC_FT_STRING)
    case 1:
        guard !info.branch.isEmpty else { return Int32(PC_FT_FIELDEMPTY) }
        setCString(info.branch, fieldValue, Int(maxlen))
        return Int32(PC_FT_STRING)
    default:
        return Int32(PC_FT_NOSUCHFIELD)
    }
}
