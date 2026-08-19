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

/// "● Modified" for an unstaged change, "● Modified (staged)" when it is in the index — the distinction
/// the commit command depends on, and the one v1 porcelain could not report.
///
/// The leading glyph (F-419) is what makes a listing scannable: "which of these forty files is in
/// conflict" becomes a glance instead of reading every row. It is deliberately *not* an icon — the PDX
/// content ABI hands back strings, and a real icon column is host work the plan records in §6.2. A glyph
/// in front of the word is what a plugin can do today, and it costs the host nothing.
private func columnLabel(for file: PluginGit.FileStatus) -> String {
    let base = label(for: file.summary)
    guard file.isStaged, file.summary != .conflict else { return base }
    return String(format: L("%@ (staged)"), base)
}

/// The column's value: `symbolName\ttext` where there is a symbol, plain text otherwise (F-428).
///
/// The glyph that used to lead this string is gone — the host now draws a real icon, and keeping both
/// would say the same thing twice in a column three words wide. Where a host cannot draw icons, the words
/// still carry the whole meaning.
private func columnValue(for file: PluginGit.FileStatus) -> String {
    let text = columnLabel(for: file)
    guard let symbol = PluginGit.symbolName(for: file.summary) else { return text }
    return symbol + "\t" + text
}

private func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

private func setCString(_ s: String, _ dst: UnsafeMutableRawPointer, _ cap: Int) {
    s.withCString { _ = strlcpy(dst.assumingMemoryBound(to: CChar.self), $0, cap) }
}

// MARK: - PDX entry points

/// The host switched palette (contrib.h): re-read the colours everywhere this plugin draws (F-431).
///
/// Without this a window opened under one theme keeps it — and the panel, which lives as long as the
/// sidebar does, would never follow a change at all.
@_cdecl("PcNotifyThemeChanged")
public func PcNotifyThemeChanged() {
    MainActor.assumeIsolated {
        for window in openWindows {
            (window.contentView as? GitLogView)?.applyTheme()
            (window.contentView as? GitBlameView)?.applyTheme()
            (window.contentView as? GitBranchesView)?.applyTheme()
            (window.contentView as? GitConflictView)?.applyTheme()
            (window.contentView as? GitRebaseView)?.applyTheme()
        }
        panelView?.applyTheme()
    }
}

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

/// The localized header for a column (F-428).
///
/// The *name* above stays English because the host derives the stable field id from it — that id keys saved
/// column sets — and this is the part that may change with the language. Both strings are already
/// translated: they are the same words the status dialog uses.
@_cdecl("ContentGetSupportedFieldTitle")
public func ContentGetSupportedFieldTitle(_ index: Int32, _ title: UnsafeMutablePointer<CChar>?,
                                          _ maxlen: Int32) -> Int32 {
    guard let title, maxlen > 0 else { return 0 }
    let text: String
    switch index {
    case 0: text = L("Git Status")
    case 1: text = L("Branch")
    default: return 0
    }
    setCString(text, UnsafeMutableRawPointer(title), Int(maxlen))
    return 1
}

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
    case 0:
        _ = "Git Status".withCString { strlcpy(fieldName, $0, Int(maxlen)) }
        // Unit "icon" opts this column into an icon (F-428), the same way Notes opts into a name-cell
        // badge with "badge". The value then reads `symbolName\ttext`.
        _ = "icon".withCString { strlcpy(units, $0, Int(maxlen)) }
        return Int32(PC_FT_STRING)
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
            setCString(columnValue(for: file), fieldValue, Int(maxlen))
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
    // The cursor item if there is one, else the *panel's directory* — not the process's working
    // directory, which is wherever the app was launched from and in a developer's case is another
    // repository entirely: the log window opened on PeachCommander itself while the panel was in the
    // repository the reader was looking at (F-417).
    var buf = [CChar](repeating: 0, count: 4096)
    let ok = svc.cursorPath.map { $0(svc.host, &buf, 4096) } ?? 0
    var cursor = ok != 0 ? String(cString: buf) : ""
    if cursor.isEmpty, let get = svc.getContext {
        var dirBuf = [CChar](repeating: 0, count: 4096)
        if get(svc.host, "dir", &dirBuf, 4096) != 0 { cursor = String(cString: dirBuf) }
    }
    if cursor.isEmpty { cursor = FileManager.default.currentDirectoryPath }

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
    case "plugin.git.log", "plugin.git.history":
        // The whole repository's history, or one file's. Same view; the path is what differs (F-417).
        let forFile = id == "plugin.git.history" && !relative.isEmpty
        // The host calls PcRunCommand on the main thread (ContributionRegistry is @MainActor); windows
        // must be built there, and asserting that is honest where a hop would merely hide it.
        MainActor.assumeIsolated { showLogWindow(root: root, path: forFile ? relative : nil, svc) }
    case "plugin.git.branches":
        MainActor.assumeIsolated { showBranchesWindow(root: root, svc) }
    case "plugin.git.conflict":
        // The resolver, not the comparison. Phase 3 opened *ours* against *theirs* here and left the
        // reader with `<<<<<<<` still in the file, which means the conflict ended somewhere else — a
        // terminal, usually. The window lists the file's conflicted regions and decides them; the
        // comparison is one of its buttons, so nothing that worked before is gone (F-420).
        guard !relative.isEmpty, let repo = PluginGitRepo.status(root: root),
              repo.files[relative]?.summary == .conflict else {
            svc.presentInfo?(svc.host, L("Git"), L("That file has no conflict."))
            return
        }
        MainActor.assumeIsolated { showConflictWindow(root: root, relative: relative, svc) }
    case "plugin.git.blame":
        guard !relative.isEmpty else {
            svc.presentInfo?(svc.host, L("Git"), L("Select a file to blame.")); return
        }
        MainActor.assumeIsolated { showBlameWindow(root: root, path: relative, svc) }
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
    case "plugin.git.ignore.name", "plugin.git.ignore.extension", "plugin.git.ignore.directory":
        // Writing .gitignore rather than shelling out: git has no "add a pattern" command, and the file
        // is the interface. The pattern itself is decided (and unit-tested) in the SDK, because a leading
        // slash is the difference between ignoring this build directory and every directory called build.
        guard !relative.isEmpty else {
            svc.presentInfo?(svc.host, L("Git"), L("Select a file or folder first."))
            return
        }
        let kind: PluginGit.IgnoreKind = id.hasSuffix("extension") ? .extensionGlob
            : id.hasSuffix("directory") ? .directory : .name
        guard kind != .directory || isDirectory(cursor) else {
            svc.presentInfo?(svc.host, L("Git"), L("That is not a folder."))
            return
        }
        guard let pattern = PluginGit.ignorePattern(kind: kind, relativePath: relative) else {
            svc.presentInfo?(svc.host, L("Git"), L("That file has no extension to ignore."))
            return
        }
        let file = (root as NSString).appendingPathComponent(".gitignore")
        let existing = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        guard let updated = PluginGit.appendingIgnore(pattern, to: existing) else {
            svc.presentInfo?(svc.host, L("Git"),
                             String(format: L("“%@” is already in .gitignore."), pattern))
            return
        }
        do {
            try updated.write(toFile: file, atomically: true, encoding: .utf8)
        } catch {
            svc.presentInfo?(svc.host, L("Git"), L("Could not write .gitignore."))
            return
        }
        PluginGitRepo.invalidate()
        svc.reloadActivePanel?(svc.host)
        svc.presentInfo?(svc.host, L("Git"),
                         String(format: L("Added “%@” to .gitignore."), pattern))
    case "plugin.git.blame.gutter":
        // Blame where the code is: the host's editor gutter (F-426). Declared asynchronous, because
        // `blame` on a large file takes seconds and the reader should see progress rather than a frozen
        // window — this is the first command outside push/pull to use that path.
        guard !relative.isEmpty else {
            svc.presentInfo?(svc.host, L("Git"), L("Select a file first."))
            return
        }
        let handle = L("Blame").withCString { svc.beginProgress?(svc.host, $0) }
        let result = PluginGitRepo.run(["-C", root] + PluginGit.blameArguments + [relative])
        let lines = result.ok ? PluginGit.parseBlame(result.out) : []
        if let handle { svc.endProgress?(svc.host, handle) }
        guard !lines.isEmpty else {
            DispatchQueue.main.async {
                svc.presentInfo?(svc.host, L("Blame"), result.ok
                    ? L("No lines.") : result.out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        let buffer = PluginGit.gutterAnnotations(lines, dateText: formatter.string(from:),
                                                uncommittedLabel: L("(uncommitted)"))
        let absolute = (root as NSString).appendingPathComponent(relative)
        DispatchQueue.main.async {
            MainActor.assumeIsolated { gutterBlame = (root: root, path: relative, lines: lines) }
            var shown = false
            absolute.withCString { path in
                buffer.withCString { annotations in
                    L("Blame").withCString { title in
                        "plugin.git.blame.commit".withCString { command in
                            shown = svc.annotateLines?(svc.host, path, annotations, title, command) == 1
                        }
                    }
                }
            }
            if !shown {
                // An older host has no `annotateLines` at all, and one that has it can still refuse (a
                // file it cannot open in an editor). Saying so beats a command that silently does nothing.
                svc.presentInfo?(svc.host, L("Blame"),
                                 L("This file could not be annotated. Use “Blame…” for the list instead."))
            }
        }
    case "plugin.git.blame.commit":
        // The gutter was clicked. Which line is in the host's context, and what it means is in the blame
        // this plugin computed for that file — no state travels through the ABI but the line number.
        //
        // Deliberately NOT declared `async`: this opens a window, and PORTING.md's first rule for an
        // asynchronous command is that it may not touch AppKit. Declaring it async cost a crash on the
        // first click — `MainActor.assumeIsolated` off the main thread does not fail politely, it traps,
        // which is the same trap F-422 fixed one level down in the host bridge (F-426).
        MainActor.assumeIsolated { showCommitOfBlamedLine(svc) }
    case "plugin.git.rebase":
        // The commits ahead of the upstream, and what to do with each (F-423). A window rather than a
        // command with arguments: the plan is the point, and it is built by looking at the list.
        MainActor.assumeIsolated { showRebaseWindow(root: root, svc) }
    case "plugin.git.credentials":
        // Diagnose, and offer exactly one action: git's own helper. No secret is read, shown or stored
        // here — see the plan's 5b for why a store of our own could only be a stale copy of git's.
        let upstream = PluginGitRepo.status(root: root)?.upstream
        DispatchQueue.global(qos: .userInitiated).async {
            let remote = PluginGitRepo.remote(root: root, upstream: upstream)
            let helper = PluginGitRepo.run(["-C", root, "config", "--get", "credential.helper"])
            let agent = PluginGitRepo.runTool("/usr/bin/ssh-add", ["-l"])
            let report = PluginGit.CredentialReport(
                remoteName: remote.name, remoteURL: remote.url,
                helper: helper.ok ? helper.out.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                agentKeys: PluginGit.parseAgentKeys(output: agent.out, exitCode: agent.code))
            DispatchQueue.main.async {
                MainActor.assumeIsolated { showCredentialReport(report, root: root, svc) }
            }
        }
    case "plugin.git.web":
        // The file (or the repository) on the hosting service. No API, no token, no account: the URL is
        // built from the remote, and only for hosts whose shape is known (plan 5c).
        guard let repo = PluginGitRepo.status(root: root) else { return }
        let remote = PluginGitRepo.remote(root: root, upstream: repo.upstream)
        guard !remote.url.isEmpty else {
            svc.presentInfo?(svc.host, L("Git"),
                             String(format: L("“%@” has no remote to open."), remote.name))
            return
        }
        let target: PluginGit.WebTarget = relative.isEmpty
            ? .repository
            : .file(path: relative, ref: PluginGit.webRef(repo))
        // The host calls PcRunCommand on the main thread (ContributionRegistry is @MainActor); the alert
        // this may raise must be built there, and asserting it is honest where a hop would hide it.
        MainActor.assumeIsolated { openOnTheWeb(remote: remote.url, target: target, svc) }
    case "plugin.git.push", "plugin.git.pull":
        // Declared `"async": true` in the manifest, so this runs OFF the main thread (F-422): it may block
        // on git, report each line into the host's progress window, and be cancelled — which is the whole
        // difference between a push to an unreachable host and an application that appears to have died.
        let isPush = id == "plugin.git.push"
        let title = isPush ? L("Git Push") : L("Git Pull")
        let arguments = isPush ? ["-C", root, "push"] : ["-C", root, "pull", "--ff-only"]
        let handle = title.withCString { svc.beginProgress?(svc.host, $0) }
        let result = PluginGitRepo.runCancellable(arguments) { line in
            guard let handle else { return true }   // no progress window: nothing to cancel from either
            return line.withCString { svc.updateProgress?(svc.host, handle, -1, $0) != 0 } ?? true
        }
        if let handle { svc.endProgress?(svc.host, handle) }
        PluginGitRepo.invalidate()
        let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        // Back to the main thread by hand: this code is no longer on it, and the services that touch the
        // window insist on it.
        DispatchQueue.main.async {
            svc.reloadActivePanel?(svc.host)
            svc.presentInfo?(svc.host, title, result.cancelled
                ? L("Cancelled.")
                : (message.isEmpty ? (result.ok ? L("Done.") : L("Failed.")) : message))
        }
    default:
        break
    }
}

private func showStatus(_ repo: PluginGit.RepoStatus, root: String, _ svc: PcHostServices) {
    var lines = [String(format: L("Branch: %@"), repo.detached ? L("(detached)") : repo.branch)]
    if let upstream = repo.upstream {
        lines.append(String(format: L("Tracking: %@  ↑%lld ↓%lld"), upstream, repo.ahead, repo.behind))
    }
    if PluginGitRepo.rebaseIsRunning(root: root) {
        lines.append(L("A rebase is half-finished — use “Rebase…” to continue or abort it."))
    }
    lines.append("")
    let files = repo.ordered
    if files.isEmpty {
        lines.append(L("Working tree clean."))
    } else {
        let staged = files.filter(\.isStaged).count
        lines.append(String(format: L("%lld change(s), %lld staged:"), files.count, staged))
        for file in files.prefix(40) {
            // The glyph stays here: this dialog is text, nothing draws an icon in it, and a list of forty
            // files is what the glyph was for (the column itself now gets a real icon, F-428).
            let glyph = PluginGit.glyph(for: file.summary)
            lines.append("  \(glyph.isEmpty ? "" : glyph + " ")\(columnLabel(for: file))  \(file.path)")
        }
        if files.count > 40 {
            lines.append(String(format: L("  … and %lld more"), files.count - 40))
        }
    }
    svc.presentInfo?(svc.host, L("Git Status"), lines.joined(separator: "\n"))
}

/// Open a target on the hosting service, or say why not.
///
/// An unknown host gets the repository page *after asking*, because the alternative — guessing
/// `/blob/main/…` at a service that spells it differently — is a 404 that reads as a defect here.
@MainActor
func openOnTheWeb(remote: String, target: PluginGit.WebTarget, _ svc: PcHostServices) {
    if let link = PluginGit.webURL(remote: remote, target: target), let url = URL(string: link) {
        NSWorkspace.shared.open(url)
        return
    }
    guard let root = PluginGit.webURL(remote: remote, target: .repository),
          let url = URL(string: root) else {
        svc.presentInfo?(svc.host, L("Git"), L("That remote is not a web address."))
        return
    }
    let alert = NSAlert()
    alert.messageText = L("This host's link layout is unknown.")
    // The URL goes on its own line rather than into the sentence: a key with an embedded newline is one
    // every translator has to reproduce exactly, for no gain.
    alert.informativeText = L("A direct link would be a guess. Open the repository page instead?")
        + "\n\n" + root
    alert.addButton(withTitle: L("Open repository"))
    alert.addButton(withTitle: L("Cancel"))
    if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
}

/// What this repository authenticates with, in words, plus the one action worth offering.
///
/// Every line here is advice, not a secret: no passphrase is read, shown or stored, and the single action
/// sets git's own `credential.helper` so the secret lives in the macOS Keychain under git's management.
@MainActor
private func showCredentialReport(_ report: PluginGit.CredentialReport, root: String,
                                  _ svc: PcHostServices) {
    let findings = PluginGit.findings(report)
    var lines: [String] = []
    if !report.remoteURL.isEmpty {
        lines.append(String(format: L("Remote “%@”: %@"), report.remoteName, report.remoteURL))
    }
    for finding in findings {
        switch finding {
        case .noRemote:
            lines.append(L("This repository has no remote, so nothing needs credentials."))
        case .httpsWithoutHelper:
            lines.append(L("An HTTPS remote asks for a password on every push, and no credential helper is configured."))
        case .httpsWithHelper:
            lines.append(String(format: L("An HTTPS remote, with the credential helper “%@”. git stores and finds the secret itself."),
                                report.helper ?? ""))
        case .sshAgentReady:
            lines.append(String(format: L("An SSH remote, and the agent holds %lld key(s). Nothing to do."),
                                report.agentKeys ?? 0))
        case .sshAgentEmpty:
            lines.append(L("An SSH remote, but the SSH agent holds no key. Add one with “ssh-add”."))
        case .sshAgentUnreachable:
            lines.append(L("An SSH remote, and no SSH agent answered. Start one, or add your key with “ssh-add --apple-use-keychain”."))
        case .gitProtocolAnonymous:
            lines.append(L("A git:// remote: read-only and anonymous. Pushing needs an SSH or HTTPS URL."))
        case .localRemote:
            lines.append(L("A remote on this Mac. No credentials are involved."))
        case .unknownTransport:
            lines.append(L("This remote's form is not one of SSH, HTTPS, git:// or a local path."))
        }
    }
    // No blank element: the paragraphs are joined with a blank line already, and an empty entry showed up
    // in the real dialog as two of them (checked in the running app).
    lines.append(L("This plugin never asks for, shows or stores a passphrase — it only configures git's own helper and points at the SSH agent."))

    let alert = NSAlert()
    alert.messageText = L("Git Credentials")
    alert.informativeText = lines.joined(separator: "\n\n")
    let offersKeychain = PluginGit.offersKeychainHelper(findings)
    if offersKeychain { alert.addButton(withTitle: L("Use the macOS Keychain")) }
    alert.addButton(withTitle: L("Close"))
    let response = alert.runModal()
    guard offersKeychain, response == .alertFirstButtonReturn else { return }

    DispatchQueue.global(qos: .userInitiated).async {
        let result = PluginGitRepo.run(PluginGit.keychainHelperArguments, combined: true)
        let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            svc.presentInfo?(svc.host, L("Git Credentials"), result.ok
                ? L("git will now keep credentials in the macOS Keychain (credential.helper = osxkeychain).")
                : (message.isEmpty ? L("Failed.") : message))
        }
    }
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

// MARK: - History windows (phase 2, F-417)

/// The blame this plugin last put into the host's gutter, so a click on it can be answered (F-426).
///
/// Held here rather than sent through the ABI: the host reports *which line* was clicked, and what a line
/// means is the plugin's own knowledge — sending commit hashes into the host would make it carry state it
/// has no use for.
@MainActor private var gutterBlame: (root: String, path: String, lines: [PluginGit.BlameLine])?

/// The commit behind a clicked gutter annotation, against its parent, in the host's compare window.
@MainActor
private func showCommitOfBlamedLine(_ svc: PcHostServices) {
    guard let blame = gutterBlame else { return }
    var buffer = [CChar](repeating: 0, count: 64)
    let ok = "gutterAnnotationLine".withCString { key in
        svc.getContext?(svc.host, key, &buffer, Int32(buffer.count)) == 1
    }
    guard ok, let line = Int(String(cString: buffer)),
          let blamed = blame.lines.first(where: { $0.line == line }) else { return }
    guard !blamed.isUncommitted else {
        svc.presentInfo?(svc.host, L("Blame"), L("That line is not committed yet."))
        return
    }
    let root = blame.root, path = blame.path, hash = blamed.hash
    DispatchQueue.global(qos: .userInitiated).async {
        let newer = PluginGitRepo.writeBlob(root: root, spec: "\(hash):\(path)", path: path, base: .head)
        let parentResult = PluginGitRepo.run(["-C", root, "rev-parse", "\(hash)^"])
        let parent = parentResult.ok
            ? parentResult.out.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let older = parent.flatMap {
            PluginGitRepo.writeBlob(root: root, spec: "\($0):\(path)", path: path, base: .index)
        } ?? PluginGitRepo.writeEmptyBlob(path: path)
        DispatchQueue.main.async {
            guard let newer, let older else {
                svc.presentInfo?(svc.host, L("Git"), L("That version could not be read."))
                return
            }
            let short = String(hash.prefix(8))
            let leftTitle = parent.map { "\(String($0.prefix(8))):\(path)" } ?? L("(added)")
            older.withCString { a in
                newer.withCString { b in
                    leftTitle.withCString { at in
                        "\(short):\(path)".withCString { bt in
                            svc.compareFiles?(svc.host, a, b, at, bt)
                        }
                    }
                }
            }
        }
    }
}

/// The plugin's own windows, held so they are not deallocated the moment the command returns. The host
/// removes its menus when a window closes (contrib.h), so there is no teardown call to make.
@MainActor private var openWindows: [NSWindow] = []

/// A window around a plugin view, registered with the host so it gets the standard Edit menu.
@MainActor
private func showToolWindow(title: String, view: NSView, size: NSSize, _ svc: PcHostServices) {
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
    window.title = title
    window.contentView = view
    window.center()
    openWindows.append(window)
    NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                          object: window, queue: .main) { _ in
        MainActor.assumeIsolated { openWindows.removeAll { $0 === window } }
    }
    let pointer = Unmanaged.passUnretained(window).toOpaque()
    title.withCString { name in
        svc.registerToolWindow?(svc.host, pointer, nil, nil, name)
    }
    window.makeKeyAndOrderFront(nil)
}

@MainActor
private func showRebaseWindow(root: String, _ svc: PcHostServices) {
    let name = (root as NSString).lastPathComponent
    showToolWindow(title: String(format: L("Rebase — %@"), name),
                   view: GitRebaseView(services: svc, root: root),
                   size: NSSize(width: 720, height: 420), svc)
}

@MainActor
private func showConflictWindow(root: String, relative: String, _ svc: PcHostServices) {
    let view = GitConflictView(services: svc, root: root, relative: relative)
    showToolWindow(title: String(format: L("Resolve Conflict — %@"), relative), view: view,
                   size: NSSize(width: 780, height: 440), svc)
}

@MainActor
private func showLogWindow(root: String, path: String?, _ svc: PcHostServices) {
    let name = (root as NSString).lastPathComponent
    let title = path.map { String(format: L("History of %@"), $0) }
        ?? String(format: L("Git Log — %@"), name)
    let view = GitLogView(services: svc, root: root, path: path)
    // "Blame this file" from the history: the log window asks, this factory knows how a blame window is
    // built — so neither view has to know about the other (F-424).
    view.blameRequested = { file in showBlameWindow(root: root, path: file, svc) }
    showToolWindow(title: title, view: view, size: NSSize(width: 820, height: 460), svc)
}

@MainActor
private func showBranchesWindow(root: String, _ svc: PcHostServices) {
    let view = GitBranchesView(services: svc, root: root)
    // Wider than before: the window carries three lists since tags arrived (F-425), and 780 points gave
    // each of them less than the minimum they ask for.
    showToolWindow(title: String(format: L("Branches — %@"), (root as NSString).lastPathComponent),
                   view: view, size: NSSize(width: 1000, height: 460), svc)
}

@MainActor
private func showBlameWindow(root: String, path: String, _ svc: PcHostServices) {
    let view = GitBlameView(services: svc, root: root, path: path)
    showToolWindow(title: String(format: L("Blame: %@"), path), view: view,
                   size: NSSize(width: 820, height: 500), svc)
}

// MARK: - The Git panel (phase 1, F-416)

/// Views the plugin can build, by the id declared in Info.plist.
private let gitPanelViewId = "plugin.git.panel"

/// The mounted panel view, weakly: the host owns it (PcMakeView/PcCloseView), and this is only so a palette
/// change can be handed to it (F-431).
@MainActor private weak var panelView: GitPanelView?

@_cdecl("PcMakeView")
public func PcMakeView(_ viewId: UnsafePointer<CChar>?, _ containerId: UnsafePointer<CChar>?,
                       _ services: UnsafePointer<PcHostServices>?) -> UnsafeMutableRawPointer? {
    guard let viewId, let services, String(cString: viewId) == gitPanelViewId else { return nil }
    // The services struct is a stack value in the host; copy it, since the view outlives this call.
    let view = MainActor.assumeIsolated { GitPanelView(services: services.pointee) }
    // Weakly, so a theme change can reach the panel while the host owns its lifetime (F-431).
    MainActor.assumeIsolated { panelView = view }
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
