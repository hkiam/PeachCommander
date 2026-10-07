// SPDX-License-Identifier: Apache-2.0
// GitCommitActions.swift — what can be done with one commit, shared by the log window and the panel.
//
// Moved out of GitLogView when the panel grew a history of its own (phase 6): revert and cherry-pick,
// "open on the web" and "compare this file as of that commit" were private to the log window, and a
// second copy in the panel would have been a second set of refusals and alerts to keep in step.

import AppKit

@MainActor
enum GitCommitActions {
    enum Sequencer { case revert, cherryPick }

    /// Undo a commit on top of the branch, or replay it here.
    ///
    /// Both refuse before they start when the working tree is not clean: git's sequencer requires that and
    /// says so in terms of overwritten local changes, which reads as if the chosen commit were the problem.
    /// A conflicting result is *not* an error — git stops mid-sequence and leaves the conflict markers, and
    /// saying that plainly is more use than a red "failed", since the next step is the conflict command.
    static func runSequencer(_ kind: Sequencer, commit: PluginGit.Commit, root: String,
                             services: PcHostServices, busy: NSProgressIndicator?,
                             done: @escaping () -> Void) {
        let title = kind == .revert ? L("Revert commit") : L("Cherry-pick")
        if let repo = PluginGitRepo.status(root: root),
           let refusal = PluginGit.refusal(forCommitActionIn: repo) {
            report(services, title, refusal == .conflictOpen
                ? L("There is an unresolved conflict. Finish it first.")
                : L("The working tree has changes. Commit or stash them first."))
            return
        }

        let alert = NSAlert()
        alert.messageText = kind == .revert
            ? String(format: L("Revert %@?"), commit.shortHash)
            : String(format: L("Cherry-pick %@ onto the current branch?"), commit.shortHash)
        alert.informativeText = commit.subject
        alert.addButton(withTitle: kind == .revert ? L("Revert") : L("Cherry-pick"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        busy?.startAnimation(nil)
        let arguments = kind == .revert
            ? PluginGit.revertArguments(commit.hash)
            : PluginGit.cherryPickArguments(commit.hash)
        let box = ServicesBox(services)     // the host's services are not Sendable; the box carries them
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PluginGitRepo.run(["-C", root] + arguments, combined: true)
            DispatchQueue.main.async {
                let services = box.services
                busy?.stopAnimation(nil)
                PluginGitRepo.invalidate()          // HEAD and the index both moved
                services.reloadActivePanel?(services.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                report(services, title, message.isEmpty ? L("Done.") : message)
                done()
            }
        }
    }

    /// This commit on the hosting service — no API and no token, just the remote's URL (F-421).
    static func openCommitOnTheWeb(hash: String, root: String, services: PcHostServices) {
        let upstream = PluginGitRepo.status(root: root)?.upstream
        let remote = PluginGitRepo.remote(root: root, upstream: upstream)
        guard !remote.url.isEmpty else {
            report(services, L("Git"), String(format: L("“%@” has no remote to open."), remote.name))
            return
        }
        openOnTheWeb(remote: remote.url, target: .commit(hash), services)
    }

    /// Compare `file` as of `commit` with the same file at that commit's first parent, in the host's own
    /// compare window. `oldPath` is the name the parent had it under, for a rename or copy — read under
    /// the new name, the parent has no such file and a renamed file looks entirely new.
    static func compareFile(_ file: String, oldPath: String? = nil, in commit: PluginGit.Commit,
                            root: String, services: PcHostServices, busy: NSProgressIndicator?) {
        let parent = commit.parents.first
        let before = oldPath ?? file
        busy?.startAnimation(nil)
        let box = ServicesBox(services)
        DispatchQueue.global(qos: .userInitiated).async {
            let newer = PluginGitRepo.writeBlob(root: root, spec: "\(commit.hash):\(file)",
                                                path: file, base: .head)
            let older = parent.flatMap {
                PluginGitRepo.writeBlob(root: root, spec: "\($0):\(before)", path: before, base: .index)
            }
            DispatchQueue.main.async {
                let services = box.services
                busy?.stopAnimation(nil)
                guard newer != nil || older != nil else {
                    report(services, L("Git"), L("That version could not be read."))
                    return
                }
                // A file this commit added has no older side, and one it deleted no newer side; comparing
                // the other with an empty temp file is more honest than refusing, and it is what the
                // reference products show.
                let left = older ?? PluginGitRepo.writeEmptyBlob(path: file)
                let right = newer ?? PluginGitRepo.writeEmptyBlob(path: file)
                let leftTitle = older != nil ? "\(String(parent!.prefix(8))):\(before)" : L("(added)")
                let rightTitle = newer != nil ? "\(String(commit.hash.prefix(8))):\(file)" : L("(deleted)")
                guard let left, let newer = right else { return }
                left.withCString { a in
                    newer.withCString { b in
                        leftTitle.withCString { at in
                            rightTitle.withCString { bt in
                                services.compareFiles?(services.host, a, b, at, bt)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - From the history's context menu (phase 7)

    /// Run one git call off the main thread, report what git said, and call `done` — the tail every
    /// action below shares. Refreshing the panels is part of it: each of them moves HEAD, a ref or the
    /// working tree.
    static func run(_ arguments: [String], title: String, root: String, services: PcHostServices,
                    busy: NSProgressIndicator?, done: @escaping () -> Void) {
        busy?.startAnimation(nil)
        let box = ServicesBox(services)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PluginGitRepo.run(["-C", root] + arguments, combined: true)
            DispatchQueue.main.async {
                let services = box.services
                busy?.stopAnimation(nil)
                PluginGitRepo.invalidate()
                services.reloadActivePanel?(services.host)
                let message = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
                if !result.ok || !message.isEmpty {
                    report(services, title, message.isEmpty ? (result.ok ? L("Done.") : L("Failed.")) : message)
                }
                done()
            }
        }
    }

    /// A question with one destructive or consequential button; true when that button was pressed.
    private static func confirm(_ message: String, _ detail: String, button: String, style: NSAlert.Style = .informational) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: L("Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// The refusal a merge, a rebase or a reset gets before it starts: the same two the sequencer gets.
    private static func refused(_ title: String, root: String, services: PcHostServices) -> Bool {
        guard let repo = PluginGitRepo.status(root: root),
              let refusal = PluginGit.refusal(forCommitActionIn: repo) else { return false }
        report(services, title, refusal == .conflictOpen
            ? L("There is an unresolved conflict. Finish it first.")
            : L("The working tree has changes. Commit or stash them first."))
        return true
    }

    static func checkout(_ commit: PluginGit.Commit, root: String, services: PcHostServices,
                         busy: NSProgressIndicator?, done: @escaping () -> Void) {
        let title = L("Check out this commit")
        guard confirm(String(format: L("Check out %@?"), commit.shortHash),
                      L("HEAD is then detached: new commits belong to no branch until you create one."),
                      button: L("Check out")) else { return }
        run(PluginGit.checkoutCommitArguments(commit.hash), title: title, root: root, services: services,
            busy: busy, done: done)
    }

    static func branchHere(_ commit: PluginGit.Commit, root: String, services: PcHostServices,
                           busy: NSProgressIndicator?, done: @escaping () -> Void) {
        guard let name = gitPrompt(String(format: L("New branch at %@"), commit.shortHash), L("Name:")) else { return }
        run(PluginGit.branchAtArguments(name: name, commit: commit.hash), title: L("New branch"), root: root,
            services: services, busy: busy, done: done)
    }

    static func tagHere(_ commit: PluginGit.Commit, root: String, services: PcHostServices,
                        busy: NSProgressIndicator?, done: @escaping () -> Void) {
        guard let tag = gitPromptTag(String(format: L("New tag at %@"), commit.shortHash)) else { return }
        run(PluginGit.createTagArguments(name: tag.name, message: tag.message, at: commit.hash), title: L("New tag"),
            root: root, services: services, busy: busy, done: done)
    }

    static func merge(_ commit: PluginGit.Commit, root: String, services: PcHostServices,
                      busy: NSProgressIndicator?, done: @escaping () -> Void) {
        let title = L("Merge")
        guard !refused(title, root: root, services: services) else { return }
        let ref = PluginGit.preferredRefName(commit)
        let name = ref == commit.hash ? commit.shortHash : ref
        guard confirm(String(format: L("Merge %@ into the current branch?"), name),
                      L("A merge that conflicts stops and leaves the conflicts to resolve."),
                      button: L("Merge")) else { return }
        run(PluginGit.mergeArguments(ref), title: title, root: root, services: services, busy: busy, done: done)
    }

    static func rebaseOnto(_ commit: PluginGit.Commit, root: String, services: PcHostServices,
                           busy: NSProgressIndicator?, done: @escaping () -> Void) {
        let title = L("Rebase")
        guard !refused(title, root: root, services: services) else { return }
        let ref = PluginGit.preferredRefName(commit)
        let name = ref == commit.hash ? commit.shortHash : ref
        guard confirm(String(format: L("Rebase the current branch onto %@?"), name),
                      L("Its own commits are replaced by new ones on top of that commit. If any of them has been pushed already, the branch will have to be force-pushed. A rebase that conflicts stops; continue or abort it in the Rebase window."),
                      button: L("Rebase"), style: .warning) else { return }
        run(PluginGit.rebaseOntoArguments(ref), title: title, root: root, services: services, busy: busy, done: done)
    }

    /// Reset asks which kind, because the three differ in what survives: soft keeps the changes staged,
    /// mixed keeps them unstaged, hard throws them away — and hard says so in its own alert.
    static func reset(to commit: PluginGit.Commit, root: String, services: PcHostServices,
                      busy: NSProgressIndicator?, done: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = String(format: L("Reset the current branch to %@?"), commit.shortHash)
        alert.informativeText = L("Soft keeps the changes of the commits after it staged, Mixed keeps them in the working tree, Hard discards them together with every uncommitted change.")
        alert.addButton(withTitle: L("Mixed"))
        alert.addButton(withTitle: L("Soft"))
        alert.addButton(withTitle: L("Hard…"))
        alert.addButton(withTitle: L("Cancel"))
        let mode: PluginGit.ResetMode
        switch alert.runModal() {
        case .alertFirstButtonReturn: mode = .mixed
        case .alertSecondButtonReturn: mode = .soft
        case .alertThirdButtonReturn:
            guard confirm(L("Discard every change after this commit?"),
                          L("The commits after it and every uncommitted change are gone from the working tree. This cannot be undone here."),
                          button: L("Reset hard"), style: .critical) else { return }
            mode = .hard
        default: return
        }
        run(PluginGit.resetArguments(mode, to: commit.hash), title: L("Reset"), root: root, services: services,
            busy: busy, done: done)
    }

    static func report(_ services: PcHostServices, _ title: String, _ message: String) {
        services.presentInfo?(services.host, title, message)
    }
}
