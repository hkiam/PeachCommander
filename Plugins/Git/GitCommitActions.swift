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

    static func report(_ services: PcHostServices, _ title: String, _ message: String) {
        services.presentInfo?(services.host, title, message)
    }
}
