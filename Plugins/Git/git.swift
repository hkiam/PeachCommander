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

// Running git, the repository lookup and the status cache live in GitRepo.swift; the panel (phase 1,
// F-416) shares them. The decisions — parsing, which git, cache freshness — live in
// Plugins/SDK/PluginGit.swift, where they are unit-tested.

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
    guard let (root, relative) = PluginGitRepo.item(path), let repo = PluginGitRepo.status(root: root) else {
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

    guard PluginGitRepo.executable() != nil else {
        svc.presentInfo?(svc.host, L("Git"), L("Git was not found on this Mac."))
        return
    }
    guard let (root, relative) = PluginGitRepo.item(cursor) else {
        svc.presentInfo?(svc.host, L("Git"), L("Not a Git repository."))
        return
    }

    /// Run `work` off the main thread, then report its output and refresh the panel.
    func background(_ title: String, _ work: @escaping () -> (out: String, ok: Bool)) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async {
                PluginGitRepo.invalidate()          // the repository moved under our cache
                svc.reloadActivePanel?(svc.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                svc.presentInfo?(svc.host, title,
                                 message.isEmpty ? (result.ok ? L("Done.") : L("Failed.")) : message)
            }
        }
    }

    switch id {
    case "plugin.git.panel.show":
        // The panel is a declared view; this is the menu route to it, rooted at the repository the
        // cursor is in so it does not have to guess which of several open repositories is meant.
        gitPanelViewId.withCString { viewId in
            root.withCString { rootPath in
                svc.presentSidebarView?(svc.host, viewId, rootPath)
            }
        }
    case "plugin.git.diff":
        // Compare the cursor file with the version git has: the index when there is a staged change,
        // HEAD otherwise. The host's own compare window does the showing (F-416).
        guard !relative.isEmpty, let repo = PluginGitRepo.status(root: root),
              let file = repo.files[relative] else {
            svc.presentInfo?(svc.host, L("Git"), L("This file has no changes to compare."))
            return
        }
        let section: PluginGit.Section = file.isStaged ? .staged : .changed
        let base = PluginGit.diffBase(for: file, section: section)
        guard let spec = PluginGit.showSpec(base: base, path: relative) else {
            svc.presentInfo?(svc.host, L("Git"), L("An untracked file has nothing to compare with."))
            return
        }
        let working = cursor
        DispatchQueue.global(qos: .userInitiated).async {
            let blob = PluginGitRepo.writeBlob(root: root, spec: spec, path: relative, base: base)
            DispatchQueue.main.async {
                guard let blob else {
                    svc.presentInfo?(svc.host, L("Git"), L("That version could not be read."))
                    return
                }
                let title = PluginGit.diffTitle(base: base, path: relative)
                blob.withCString { left in
                    working.withCString { right in
                        title.withCString { leftTitle in
                            L("Working tree").withCString { rightTitle in
                                svc.compareFiles?(svc.host, left, right, leftTitle, rightTitle)
                            }
                        }
                    }
                }
            }
        }
    case "plugin.git.status":
        // Reading is bounded and cached; keep it synchronous so the sheet appears at once.
        if let repo = PluginGitRepo.status(root: root) { showStatus(repo, root: root, svc) }
    case "plugin.git.stage":
        let target = relative.isEmpty ? "." : relative
        background(L("Git Add")) { PluginGitRepo.run(["-C", root, "add", "--", target], combined: true) }
    case "plugin.git.commit":
        // The index, not `-a`: staging and committing were contradicting each other, so a file staged
        // with the command next to this one had no bearing on what was committed.
        guard let repo = PluginGitRepo.status(root: root) else { return }
        guard repo.files.values.contains(where: \.isStaged) else {
            svc.presentInfo?(svc.host, L("Git Commit"),
                             L("Nothing is staged. Use “Git Add (stage)” first."))
            return
        }
        guard let message = promptCommitMessage() else { return }
        background(L("Git Commit")) { PluginGitRepo.run(["-C", root, "commit", "-m", message], combined: true) }
    case "plugin.git.push":
        background(L("Git Push")) { PluginGitRepo.run(["-C", root, "push"], combined: true) }
    case "plugin.git.pull":
        background(L("Git Pull")) { PluginGitRepo.run(["-C", root, "pull", "--ff-only"], combined: true) }
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

// MARK: - The Git panel (phase 1, F-416)

/// Views the plugin can build, by the id declared in Info.plist.
private let gitPanelViewId = "plugin.git.panel"

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let viewId, let services, String(cString: viewId) == gitPanelViewId else { return nil }
    // The services struct is a stack value in the host; copy it, since the view outlives this call.
    let view = MainActor.assumeIsolated { GitPanelView(services: services.pointee) }
    return Unmanaged.passRetained(view).toOpaque()
}

@_cdecl("PcCloseView")
public func PcCloseView(_ view: UnsafeMutableRawPointer?) {
    guard let view else { return }
    Unmanaged<GitPanelView>.fromOpaque(view).release()
}

@_cdecl("PcNotifyView")
public func PcNotifyView(_ view: UnsafeMutableRawPointer?, _ key: UnsafePointer<CChar>?,
                         _ value: UnsafePointer<CChar>?) {
    guard let view, let key, let value else { return }
    let panel = Unmanaged<GitPanelView>.fromOpaque(view).takeUnretainedValue()
    let k = String(cString: key), v = String(cString: value)
    MainActor.assumeIsolated { panel.notify(key: k, value: v) }
}
