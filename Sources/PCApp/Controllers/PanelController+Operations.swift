// SPDX-License-Identifier: Apache-2.0
// PanelController+Operations.swift - F5/F6/F7/F8 file operations (I04).
//
// Presents the target/confirm dialogs, runs a TransferQueue with a live progress
// dialog and an interactive overwrite/error resolver, then unmarks the processed
// items and reloads the panel.

import AppKit
import PCFoundation
import PCVFS
import PCOperations
import PCArchive

extension PanelController {

    /// A `CopyOptions` seeded from the Options "Copy/Delete" settings (F-271).
    func defaultCopyOptions() -> CopyOptions {
        var o = CopyOptions()
        o.preserveMetadata = copyPreserveMetadata
        o.useCloneWhenPossible = copyUseClone
        o.onlyNewer = copyOnlyNewer
        o.maxBytesPerSecond = Int64(max(0, copySpeedLimitKBps)) * 1024   // 0 = unlimited
        return o
    }

    /// Copy options carrying an optional wildcard rename mask (F-080) and a
    /// per-operation "only newer" override (nil = keep the global default).
    private func copyOptions(mask: String?, onlyNewer: Bool? = nil) -> CopyOptions {
        var o = defaultCopyOptions()
        o.renameMask = mask
        if let onlyNewer { o.onlyNewer = onlyNewer }
        return o
    }

    /// Split a target field into (directory, mask?). A last component with `*`/`?`
    /// is a rename mask (F-080); the directory part is resolved against `baseDir`
    /// (the pre-filled target) when it's bare or relative. Without a mask the whole
    /// field is the directory, unchanged.
    private func splitTargetMask(_ dest: String, relativeTo baseDir: String) -> (dir: String, mask: String?) {
        let last = (dest as NSString).lastPathComponent
        guard CopyRenameMask.isMask(last) else { return (dest, nil) }
        var dir = (dest as NSString).deletingLastPathComponent
        if dir.isEmpty {
            dir = baseDir
        } else if !(dir as NSString).isAbsolutePath {
            dir = (baseDir as NSString).appendingPathComponent(dir)
        }
        return (dir, last)
    }

    // MARK: - PanelControllerProtocol (I04)

    func currentDirectory() async -> String { await getCurrentPath() }

    func reload() async { await loadDirectory(await getCurrentPath()) }

    /// Upload the selection into a directory on `targetFS` (F-367).
    ///
    /// Until now F5 into a network panel handed the *remote* path to the local copy engine, which either
    /// failed or wrote to a same-named local path and reported success — the worst of the two, because the
    /// user has no reason to check. Files stream through the filesystem's own upload, resuming a partial
    /// remote file where the protocol allows it (F-212).
    ///
    /// Only local sources: sending from one server to another is FXP (F-216) and is refused rather than
    /// routed through a temp file behind the user's back.
    func uploadSelection(to targetDir: String, on targetFS: VirtualFileSystem) async {
        guard let uploader = targetFS as? ResumableFileUploading else {
            presentError(String(localized: "Copy"),
                         detail: String(localized: "This location cannot receive uploads."))
            return
        }
        guard currentFileSystem is LocalFS else {
            presentError(String(localized: "Copy"),
                         detail: String(localized: "Copying straight from one server to another is not supported. Download the files first, then upload them."))
            return
        }
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        guard let (rawDest, _, _, _) = promptTarget(title: String(localized: "Upload"),
                                                   count: items.count, initial: targetDir) else { return }
        let (dest, mask) = splitTargetMask(rawDest, relativeTo: targetDir)

        var uploaded = 0, failed = 0, resumed = 0
        for item in items {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item, isDirectory: &isDir) else { failed += 1; continue }
            if isDir.boolValue {
                // One level only for now: a recursive upload needs directory creation and progress
                // reporting, and saying so is better than half-copying a tree.
                failed += 1
                continue
            }
            let leaf = (item as NSString).lastPathComponent
            let name = mask.map { CopyRenameMask.apply($0, to: leaf) } ?? leaf
            let remote = VFSPath(filesystemId: targetFS.scheme,
                                 path: (dest as NSString).appendingPathComponent(name))
            do {
                let result = try await uploader.uploadFile(URL(fileURLWithPath: item), to: remote,
                                                           resume: true)
                uploaded += 1
                if result.resumedAt > 0 { resumed += 1 }
            } catch {
                failed += 1
                logger.error("upload of \(leaf, privacy: .public) failed: \(error)")
            }
        }
        let note = failed > 0 ? String(format: String(localized: ", %d failed (folders are not uploaded yet)"), failed) : ""
        let continued = resumed > 0 ? String(format: String(localized: ", %d continued"), resumed) : ""
        presentInfo(String(localized: "Upload"),
                    String(format: String(localized: "%1$d file(s) uploaded%2$@%3$@."), uploaded, continued, note))
    }

    func copySelection(to targetDir: String) async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        guard let (rawDest, background, onlyNewer, queueForLater) = promptTarget(
            title: isInArchive ? String(localized: "Extract") : String(localized: "Copy"),
            count: items.count, initial: targetDir, allowBackground: !isInArchive) else { return }
        let (dest, mask) = splitTargetMask(rawDest, relativeTo: targetDir)
        if isInArchive {
            await extractItems(items, to: dest)
        } else if background {
            startBackgroundCopy(items: items, dest: dest, mask: mask,
                                onlyNewer: onlyNewer, queueForLater: queueForLater)
        } else {
            await runTransfer(.copy(items: items, toDirectory: dest, options: copyOptions(mask: mask, onlyNewer: onlyNewer)),
                              title: String(localized: "Copying"))
            registerUndo(label: String(localized: "Copy"), undoCopy: items, at: dest, mask: mask)
            await offerPrivilegedTransfer(items, destDir: dest, mask: mask, move: false)   // F-099
            if await config.bool("Operation", "VerifyAfterCopy", default: false) {
                await verifyCopiedItems(items, destDir: dest, mask: mask)
            }
        }
    }

    /// Copy the selection INTO the archive at `archiveZip`, placed under `subPath`
    /// (the target panel's location inside that archive). When the source panel is
    /// itself inside an archive, the selection is first extracted to a temp folder,
    /// then added — so this covers both local→archive (F-133) and archive→archive
    /// (F-139). The archive is rewritten via ArchiveEditor.add (zip only).
    func copyInto(archiveZip: String, subPath: String) async {
        await addToArchive(archiveZip: archiveZip, subPath: subPath, removingSources: false)
    }

    /// Move the selection INTO the archive: the same add, then the sources go to the Trash
    /// once the archive has actually been rewritten (F-133/F-139).
    ///
    /// Before this existed, F6 onto an archive panel fell through to an ordinary move whose
    /// destination was the panel's path *inside* the zip — so it did not add to the archive
    /// at all and wrote to a bogus location.
    func moveInto(archiveZip: String, subPath: String) async {
        await addToArchive(archiveZip: archiveZip, subPath: subPath, removingSources: true)
    }

    /// Shared implementation for copy/move into a rewritable archive.
    ///
    /// Prompts first, like every other copy target. The archive path used to be taken
    /// straight from the target panel with no dialog at all, so the operation ran
    /// immediately and the entry name could not be changed — for a single item the prompt is
    /// therefore seeded with the full path *including* the name, which is what makes
    /// renaming on the way in possible.
    private func addToArchive(archiveZip: String, subPath: String, removingSources: Bool) async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        let sub = subPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Seed: "sub/name" for one item (name editable), "sub/" for several (a target folder).
        let single = items.count == 1 ? (items[0] as NSString).lastPathComponent : nil
        var initial = sub
        if let single { initial = sub.isEmpty ? single : sub + "/" + single }
        else if !sub.isEmpty { initial = sub + "/" }

        let archiveName = (archiveZip as NSString).lastPathComponent
        let title = removingSources
            ? String(localized: "Move into \(archiveName)")
            : String(localized: "Copy into \(archiveName)")
        // No background option: the archive is rewritten in one synchronous pass.
        guard let (raw, _, _, _) = promptTarget(title: title, count: items.count,
                                               initial: initial, allowBackground: false) else { return }

        let entered = raw.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        // One item: the whole entry path was editable, so use it verbatim unless the user
        // ended it with "/" to mean "into this folder, keep the name".
        let targetDir: String
        let renamedTo: String?
        if single != nil && !raw.hasSuffix("/") {
            targetDir = (entered as NSString).deletingLastPathComponent
            let base = (entered as NSString).lastPathComponent
            renamedTo = base.isEmpty ? nil : base
        } else {
            targetDir = entered
            renamedTo = nil
        }
        func arc(for name: String) -> String {
            let leaf = renamedTo ?? name
            return targetDir.isEmpty ? leaf : targetDir + "/" + leaf
        }

        var entries: [(localPath: String, arcPath: String)] = []
        var tempDir: URL?
        if isInArchive {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-a2a-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            tempDir = tmp
            await extractItems(items, to: tmp.path)   // extract source archive → temp
            for item in items {
                let name = (item as NSString).lastPathComponent
                entries.append((tmp.appendingPathComponent(name).path, arc(for: name)))
            }
        } else {
            for item in items { entries.append((item, arc(for: (item as NSString).lastPathComponent))) }
        }

        // zip is rewritten in Swift; tar and 7z are added to in place by the tools themselves. Which
        // one — and, when neither, *why* — is ArchiveWriteSupport's answer (F-139). Before this, every
        // non-zip archive reached the zip rewriter and came back with "unreadableArchive", which was
        // the opposite of true: the archive was readable, it simply was not a zip.
        var added = false
        do {
            let url = URL(fileURLWithPath: archiveZip)
            switch ArchiveWriteSupport.capability(forArchiveAt: archiveZip) {
            case .rewrite:
                try ArchiveEditor.add(to: url, entries: entries)
            case .appendTar, .sevenZip:
                try ShellArchiveEditor.add(to: url, entries: entries)
            case .unsupported(let reason):
                presentError(title, detail: Self.explain(reason,
                                                         archive: (archiveZip as NSString).lastPathComponent))
                if let tempDir { try? FileManager.default.removeItem(at: tempDir) }
                return
            }
            added = true
        } catch {
            presentError(title, detail: "\(error)")
        }
        if let tempDir { try? FileManager.default.removeItem(at: tempDir) }

        // Sources go only after the archive was actually rewritten — a failed add must never
        // cost the originals. To the Trash rather than unlinked, so a mistaken F6 into an
        // archive stays recoverable.
        guard removingSources, added else { return }
        if isInArchive {
            // Archive → archive: remove the entries from the *source* zip.
            await deleteInArchive(items)
        } else {
            await runTransfer(.trash(items: items), title: String(localized: "Moving to Trash"))
            registerUndo(label: String(localized: "Move"), undoMove: items, at: archiveZip)
        }
    }

    /// After a foreground copy, verify each copied file against its source by
    /// CRC-32 (F-090). Recurses into directories; reports missing/mismatched files.
    private func verifyCopiedItems(_ items: [String], destDir: String, mask: String? = nil) async {
        let fm = FileManager.default
        func filePairs(src: String, dst: String) -> [(src: String, dst: String)] {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: src, isDirectory: &isDir) else { return [] }
            guard isDir.boolValue else { return [(src, dst)] }
            let children = (try? fm.contentsOfDirectory(atPath: src)) ?? []
            return children.flatMap { child in
                filePairs(src: (src as NSString).appendingPathComponent(child),
                          dst: (dst as NSString).appendingPathComponent(child))
            }
        }
        var pairs: [(src: String, dst: String)] = []
        for item in items {
            let leaf = (item as NSString).lastPathComponent
            let name = mask.map { CopyRenameMask.apply($0, to: leaf) } ?? leaf   // F-080
            let dst = (destDir as NSString).appendingPathComponent(name)
            pairs.append(contentsOf: filePairs(src: item, dst: dst))
        }

        let localFS = LocalFS()
        func digest(_ path: String) async -> String? {
            try? await ChecksumEngine.compute(VFSPath(filesystemId: localFS.scheme, path: path),
                                              on: localFS, algorithm: .crc32)
        }

        var mismatches: [String] = []
        var verified = 0
        for pair in pairs {
            guard fm.fileExists(atPath: pair.dst) else {
                mismatches.append((pair.dst as NSString).lastPathComponent + " (missing)")
                continue
            }
            let (a, b) = (await digest(pair.src), await digest(pair.dst))
            verified += 1
            if a == nil || b == nil || a != b {
                mismatches.append((pair.dst as NSString).lastPathComponent)
            }
        }

        if mismatches.isEmpty {
            presentInfo(String(localized: "Verify After Copy"),
                        String(localized: "\(verified) file(s) verified — all match."))
        } else {
            let list = mismatches.prefix(20).joined(separator: "\n")
            let more = mismatches.count > 20 ? String(localized: "\n… and \(mismatches.count - 20) more.") : ""
            presentError(String(localized: "Verify After Copy"),
                         detail: String(localized: "\(mismatches.count) file(s) did not match:\n\(list)\(more)"))
        }
    }

    /// Drag & drop landed on this panel: copy (or move) the dropped paths into the
    /// panel's current directory. No target prompt — the destination is where the
    /// user dropped. Items already living in the destination are ignored.
    func performDrop(paths: [String], move: Bool, into folder: String? = nil) async {
        guard !isInArchive else { NSSound.beep(); return }   // dropping into an archive: not yet
        // A folder row was the drop target (F-067): copy/move into it; otherwise the
        // panel's current directory.
        let dest: String
        if let folder { dest = folder } else { dest = await getCurrentPath() }
        let items = paths.filter {
            // Skip no-ops (already in dest) and dropping a folder onto itself.
            !$0.isEmpty && ($0 as NSString).deletingLastPathComponent != dest && $0 != dest
        }
        guard !items.isEmpty else { return }
        // Drops run in the background transfer manager so the user keeps working.
        let kind: OperationKind = move
            ? .move(items: items, toDirectory: dest, options: defaultCopyOptions())
            : .copy(items: items, toDirectory: dest, options: defaultCopyOptions())
        let verb = move ? String(localized: "Move") : String(localized: "Copy")
        enqueueBackground(kind, title: "\(verb) \(items.count) → \((dest as NSString).lastPathComponent)")
    }

    func moveSelection(to targetDir: String) async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        // Archives are read-only here: F6 out of an archive extracts (no source delete).
        if isInArchive {
            guard let (dest, _, _, _) = promptTarget(title: String(localized: "Extract"),
                                               count: items.count, initial: targetDir) else { return }
            await extractItems(items, to: dest)
            return
        }
        guard let (rawDest, background, onlyNewer, queueForLater) = promptTarget(title: String(localized: "Move"),
                                                    count: items.count, initial: targetDir,
                                                    allowBackground: true) else { return }
        let (dest, mask) = splitTargetMask(rawDest, relativeTo: targetDir)
        if background {
            enqueueBackground(.move(items: items, toDirectory: dest, options: copyOptions(mask: mask, onlyNewer: onlyNewer)),
                              title: String(localized: "Move \(items.count) → \((dest as NSString).lastPathComponent)"),
                              startHeld: queueForLater)
        } else {
            await runTransfer(.move(items: items, toDirectory: dest, options: copyOptions(mask: mask, onlyNewer: onlyNewer)),
                              title: String(localized: "Moving"))
            registerUndo(label: String(localized: "Move"), undoMove: items, at: dest, mask: mask)
            await offerPrivilegedTransfer(items, destDir: dest, mask: mask, move: true)   // F-099
        }
    }

    /// Push an inverse for a just-completed foreground copy/move (F-101). Only
    /// items whose destination actually exists are acted on; a copy is undone by
    /// trashing the created items, a move by moving them back to their origin.
    /// (Conflict auto-renames aren't tracked — a v1 limitation.)
    private func registerUndo(label: String, undoCopy: [String]? = nil, undoMove: [String]? = nil,
                              at dest: String, mask: String? = nil) {
        let items = undoCopy ?? undoMove ?? []
        guard !items.isEmpty else { return }
        let isMove = undoMove != nil
        (view.window?.windowController as? MainWindowController)?.pushUndo(label) {
            let fm = FileManager.default
            for item in items {
                let leaf = (item as NSString).lastPathComponent
                let name = mask.map { CopyRenameMask.apply($0, to: leaf) } ?? leaf   // F-080: undo the renamed file
                let destPath = (dest as NSString).appendingPathComponent(name)
                guard fm.fileExists(atPath: destPath) else { continue }
                if isMove {
                    try? fm.moveItem(atPath: destPath, toPath: item)   // move back to origin
                } else {
                    try? fm.trashItem(at: URL(fileURLWithPath: destPath), resultingItemURL: nil)
                }
            }
        }
    }

    func packSelection(to targetDir: String) async {
        guard !isInArchive else { return }
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        let base = items.count == 1
            ? ((items[0] as NSString).lastPathComponent as NSString).deletingPathExtension
            : "archive"
        // Choose format (zip/7z/tar…), optional AES password, and split size (F-132/F-136).
        // Format + compression default come from the Options "Zip/Packer" page (F-274).
        let defaultFormat = PackFormat(rawValue: packDefaultFormatRaw) ?? .zip
        let pluginFormats = await packerPluginFormats?() ?? []   // F-137: PCX packer formats
        let dialog = PackOptionsDialog(defaultBaseName: base, defaultFormat: defaultFormat,
                                       defaultLevel: packDefaultLevel, pluginFormats: pluginFormats)
        dialog.onPack = { archiveName, options in
            let archivePath = (targetDir as NSString).appendingPathComponent(archiveName)
            // Pack through the background transfer queue (F-138): PackEngine shells to
            // 7z/tar/rar off the main actor and the job shows in the manager.
            TransferManager.shared.enqueue(.custom(run: { _, progress in
                try PackEngine.pack(items: items, to: archivePath, options: options)
                progress(OpProgress(filesTotal: items.count, filesDone: items.count,
                                    currentItem: archiveName, bytesPerSecond: 0))
                return []
            }), title: String(localized: "Pack \(archiveName)"),
                onComplete: { [weak self] _ in Task { @MainActor in await self?.reload() } })
        }
        // Pack via a PCX packer plugin (F-137): files are packed relative to their
        // common parent directory.
        dialog.onPackPlugin = { [weak self] archiveName, _ in
            guard let self else { return }
            let archivePath = (targetDir as NSString).appendingPathComponent(archiveName)
            let sourceDir = (items[0] as NSString).deletingLastPathComponent
            let names = items.map { ($0 as NSString).lastPathComponent }
            TransferManager.shared.enqueue(.custom(run: { _, progress in
                guard await self.resolvePackerPack?(archivePath, sourceDir, names) == true else {
                    throw CocoaError(.fileWriteUnknown)
                }
                progress(OpProgress(filesTotal: names.count, filesDone: names.count,
                                    currentItem: archiveName, bytesPerSecond: 0))
                return []
            }), title: String(localized: "Pack \(archiveName)"),
                onComplete: { [weak self] _ in Task { @MainActor in await self?.reload() } })
        }
        dialog.runModal()
    }

    // MARK: - Multi-rename (I11)

    /// The directory + rename inputs for the current selection (or cursor item), local only.
    func renameInputs() async -> (dir: String, items: [RenameInput]) {
        let dir = await getCurrentPath()
        let parent = (dir as NSString).lastPathComponent
        let grand = ((dir as NSString).deletingLastPathComponent as NSString).lastPathComponent
        let paths = await selectedOrCursorPaths()
        var items: [RenameInput] = []
        for p in paths {
            let name = (p as NSString).lastPathComponent
            let attrs = try? FileManager.default.attributesOfItem(atPath: p)
            let modified = (attrs?[.modificationDate] as? Date) ?? Date()
            items.append(RenameInput(name: name, modified: modified, parentName: parent, grandparentName: grand))
        }
        return (dir, items)
    }

    /// Begin an in-cell rename of the cursor item (F-081, Shift+F6). Only for local
    /// files in the details view — returns false otherwise so the caller can fall
    /// back to the modal rename dialog (e.g. inside archives). The commit performs a
    /// collision-checked rename and reselects the renamed item.
    func beginInlineRename() -> Bool {
        guard currentFileSystem is LocalFS, !isInArchive, view.viewMode == .details else { return false }
        return tableView.beginInlineRename { [weak self] old, new in
            self?.commitInlineRename(old: old, newDisplay: new)
        }
    }

    private func commitInlineRename(old: String, newDisplay: String) {
        // A "/" the user typed maps to a POSIX ":" (Finder convention, F-100), so a
        // name like "12/31" is stored as "12:31" and shown back as "12/31".
        let new = (currentFileSystem is LocalFS) ? PathUtils.posixName(fromDisplay: newDisplay) : newDisplay
        guard RenameValidator.isValid(new) else { NSSound.beep(); return }
        Task { @MainActor in
            let dir = await getCurrentPath()
            let target = (dir as NSString).appendingPathComponent(new)
            if FileManager.default.fileExists(atPath: target) {
                let alert = NSAlert()
                alert.messageText = String(localized: "Rename")
                alert.informativeText = String(
                    format: NSLocalizedString("An item named “%@” already exists.", comment: ""), new)
                alert.runModal()
                return
            }
            _ = performRenames(dir: dir, pairs: [(old: old, new: new)])
            await reload()
            tableView.focusEntry(named: new)
        }
    }

    /// Rename files in `dir` (old→new) and return an undo log.
    ///
    /// The staging that survives a cycle (`a → b` with `b → a`) lives in `RenameBatchEngine`, where it
    /// can be tested; this keeps the parts that are the panel's business — carrying each file's comment
    /// to its new name, registering the undo, and saying so when a rename did not happen. That last one
    /// is new: names the batch could not deliver used to be dropped without a word (F-175).
    @discardableResult
    func performRenames(dir: String, pairs: [(old: String, new: String)]) -> [(from: String, to: String)] {
        let outcome = RenameBatchEngine.apply(dir: dir, pairs: pairs)
        for step in outcome.log {
            // This path does not go through the move engine, so the comment carry is its own (F-372).
            Task { await CommentStore.carryLocal(from: step.to, to: step.from, keepSource: false) }
        }
        let log = outcome.log.map { (from: $0.from, to: $0.to) }
        if !log.isEmpty {
            (view.window?.windowController as? MainWindowController)?
                .pushUndo(String(localized: "Rename")) { [weak self] in self?.performUndo(log) }
        }
        if !outcome.failed.isEmpty {
            let list = outcome.failed.prefix(10).map { "\($0.name): \($0.reason)" }.joined(separator: "\n")
            let more = outcome.failed.count > 10
                ? String(localized: "\n… and \(outcome.failed.count - 10) more.") : ""
            presentError(String(localized: "Rename"),
                         detail: String(localized: "\(outcome.failed.count) file(s) were not renamed:\n\(list)\(more)"))
        }
        return log
    }

    /// Reverse a rename log. Staged in two phases for the same reason the forward direction is: undoing
    /// a swap means putting `b` back while `a` still holds its place.
    func performUndo(_ log: [(from: String, to: String)]) {
        let steps = log.map { RenameBatchEngine.Step(from: $0.from, to: $0.to) }
        for step in RenameBatchEngine.undo(steps) {
            // Undo has to take the comment back too, or it is left on a name that no longer exists.
            Task { await CommentStore.carryLocal(from: step.from, to: step.to, keepSource: false) }
        }
    }

    func makeDirectory() async {
        let parent = await getCurrentPath()
        let dialog = InputDialog(title: String(localized: "New Folder"),
                                 prompt: String(localized: "Create directory (use / to nest, | for several):"),
                                 initialValue: "")
        var name: String?
        dialog.onConfirm = { name = $0 }
        dialog.runModalDialog()
        guard let spec = name, !spec.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            let created = try MkDirEngine.create(spec: spec, in: parent)
            if !created.isEmpty {
                (view.window?.windowController as? MainWindowController)?
                    .pushUndo(String(localized: "New Folder")) {
                        // Undo: trash the just-created folders (deepest first).
                        for p in created.sorted(by: { $0.count > $1.count }) {
                            try? FileManager.default.trashItem(at: URL(fileURLWithPath: p), resultingItemURL: nil)
                        }
                    }
            }
        } catch {
            presentError(String(localized: "Could not create directory."), detail: "\(error)")
        }
        await reload()
    }

    func deleteSelection(permanent explicitPermanent: Bool) async {
        let items = await selectedOrCursorPaths()
        guard !items.isEmpty else { return }
        if isInArchive {
            await deleteInArchive(items)
            return
        }
        let toTrashDefault = await config.bool("Operation", "DeleteToTrash", default: true)
        let permanent = explicitPermanent || !toTrashDefault
        let mustConfirm = await config.bool("Operation", "ConfirmDelete", default: true)
        if mustConfirm, !confirmDelete(count: items.count, permanent: permanent) { return }
        let kind: OperationKind = permanent ? .delete(items: items) : .trash(items: items)
        await runTransfer(kind, title: permanent ? String(localized: "Deleting")
                                                 : String(localized: "Moving to Trash"))
        // If a permanent delete left items behind, it was almost certainly a
        // permission error — offer an administrator retry (F-099).
        if permanent {
            let remaining = items.filter { FileManager.default.fileExists(atPath: $0) }
            if !remaining.isEmpty { await offerPrivilegedDelete(remaining) }
        }
    }

    /// The destination each item was meant to reach, honouring a copy mask (F-080).
    private func transferPairs(_ items: [String], destDir: String, mask: String?) -> [PrivilegedTransfer.Item] {
        items.map { item in
            let leaf = (item as NSString).lastPathComponent
            let name = mask.map { CopyRenameMask.apply($0, to: leaf) } ?? leaf
            return PrivilegedTransfer.Item(source: item,
                                           destination: (destDir as NSString).appendingPathComponent(name))
        }
    }

    /// After a copy or move, offer to redo what did not arrive with administrator privileges (F-099).
    ///
    /// Asked of the file system, not of the operation's error messages: those are localized, and
    /// matching on their text would work in English and quietly stop working in German. An item counts
    /// as failed when its destination is missing and its source is still there — a user who chose
    /// "skip" in the overwrite dialog leaves a destination that exists, which is how the two are told
    /// apart. And the offer only appears when the destination folder is one this user cannot write to;
    /// a copy that failed because the volume is full is not helped by doing it as root.
    private func offerPrivilegedTransfer(_ items: [String], destDir: String, mask: String?,
                                         move: Bool) async {
        let fm = FileManager.default
        let failed = PrivilegedTransfer.missing(transferPairs(items, destDir: destDir, mask: mask),
                                                exists: { fm.fileExists(atPath: $0) })
        guard !failed.isEmpty,
              PrivilegedTransfer.wouldPrivilegeHelp(destinationDirectory: destDir,
                                                    isWritable: { fm.isWritableFile(atPath: $0) }),
              let command = PrivilegedTransfer.command(for: failed, move: move) else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Retry as administrator?")
        alert.informativeText = move
            ? String(localized: "\(failed.count) item(s) could not be moved (permission denied). Move them with administrator privileges?")
            : String(localized: "\(failed.count) item(s) could not be copied (permission denied). Copy them with administrator privileges?")
        alert.addButton(withTitle: move ? String(localized: "Move as Administrator")
                                        : String(localized: "Copy as Administrator"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let error = PrivilegedRunner.runShell(command) {
            presentError(String(localized: "Administrator Operation Failed"), detail: error)
        }
        // What arrived is read back off the disk: the shell line runs each item independently, so a
        // partial success is the normal outcome and the run's own exit status would not say which.
        let stillMissing = PrivilegedTransfer.missing(transferPairs(items, destDir: destDir, mask: mask),
                                                      exists: { fm.fileExists(atPath: $0) })
        if !stillMissing.isEmpty {
            ErrorLogWindowController.present(
                over: view.window,
                summary: String(localized: "\(stillMissing.count) item(s) still could not be transferred."),
                entries: stillMissing.map { ($0.source, String(localized: "not created at \($0.destination)")) })
        }
        await reload()
    }

    /// Why nothing can be added to this archive, in words a user can act on.
    ///
    /// "This archive cannot be modified" tells nobody anything; "compressed tar archives cannot be
    /// added to" and "7z is not installed" both suggest what to do next.
    static func explain(_ reason: ArchiveWriteSupport.Reason, archive: String) -> String {
        switch reason {
        case .compressedStream:
            return String(localized: "\(archive) is a compressed archive — files cannot be added to it without repacking it.")
        case .toolMissing(let tool):
            return String(localized: "Adding to this archive needs the “\(tool)” tool, which is not installed.")
        case .formatNotWritable(let format):
            return String(localized: "Files cannot be added to a “\(format)” archive; this app only reads that format.")
        }
    }

    /// Offer to delete permission-protected items with administrator privileges.
    private func offerPrivilegedDelete(_ paths: [String]) async {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Retry as administrator?")
        alert.informativeText = String(localized: "\(paths.count) item(s) could not be deleted (permission denied). Delete them with administrator privileges?")
        alert.addButton(withTitle: String(localized: "Delete as Administrator"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let quoted = paths.map { PrivilegedRunner.shellQuote($0) }.joined(separator: " ")
        if let error = PrivilegedRunner.runShell("/bin/rm -rf \(quoted)") {
            presentError(String(localized: "Administrator Operation Failed"), detail: error)
        }
        await reload()
    }

    /// Delete entries inside a zip by rewriting it (F-133). Only zip-backed
    /// archives are rewritable; plugin/network mounts stay read-only.
    private func deleteInArchive(_ items: [String]) async {
        guard let zip = currentArchiveZipPath else {
            presentError(String(localized: "Read-only archive"),
                         detail: String(localized: "Files inside this archive cannot be deleted."))
            return
        }
        // Deleting *inside* an archive is a rewrite, and only zip is rewritten here. A tar or 7z used to
        // reach the zip rewriter and come back with "unreadableArchive" — which was false twice over:
        // the archive is readable, and the real answer is that this app does not rewrite that format.
        // Adding to them does work (F-139); removing from them does not, and says so.
        guard case .rewrite = ArchiveWriteSupport.capability(forArchiveAt: zip) else {
            presentError(String(localized: "Read-only archive"),
                         detail: String(localized: "Files can only be deleted inside .zip archives. Files can still be added to this one."))
            return
        }
        let mustConfirm = await config.bool("Operation", "ConfirmDelete", default: true)
        if mustConfirm, !confirmDelete(count: items.count, permanent: true) { return }
        do {
            try ArchiveEditor.remove(from: URL(fileURLWithPath: zip), paths: items)
        } catch {
            presentError(String(localized: "Delete failed."), detail: "\(error)")
            return
        }
        await reloadCurrentArchive()
    }

    // MARK: - Shared flow

    func selectedOrCursorPaths() async -> [String] {
        let selected = await getSelectionState().getSelectedPathList()
        if !selected.isEmpty { return selected }
        if let cursor = tableView.cursorItemFullPath() { return [cursor] }
        return []
    }

    func runTransfer(_ kind: OperationKind, title: String) async {
        let queue = TransferQueue()
        let resolver = InteractiveResolver(parentWindow: view.window)
        let progress = ProgressDialog(title: title, control: queue.control)
        progress.present(over: view.window)
        for await event in queue.run(kind, resolver: resolver) {
            switch event {
            case .progress(let p):
                progress.update(p)
            case .completed(let done):
                await getSelectionState().unmarkCompleted(done)
            case .failed(let error):
                presentError(String(localized: "Operation failed."), detail: "\(error)")
            case .cancelled, .log:
                break
            }
        }
        progress.finish()
        // Continue-on-error summary (F-089): if any files were skipped due to
        // errors, show a log window instead of silently dropping them.
        let problems = resolver.problems()
        if !problems.isEmpty {
            let summary = String(localized: "\(problems.count) item(s) were skipped due to errors.")
            ErrorLogWindowController.present(over: view.window, summary: summary,
                                             entries: problems.map { ($0.path, $0.message) })
        }
        await reload()
    }

    private func promptTarget(title: String, count: Int, initial: String,
                              allowBackground: Bool = false)
        -> (dest: String, background: Bool, onlyNewer: Bool, queueForLater: Bool)? {
        let dialog = InputDialog(title: title,
                                 prompt: String(localized: "\(count) item(s) to:"),
                                 initialValue: initial,
                                 checkboxTitle: allowBackground ? String(localized: "Run in background") : nil,
                                 secondCheckboxTitle: String(localized: "Only newer files"),
                                 secondCheckboxOn: copyOnlyNewer,   // seed from the global default
                                 thirdCheckboxTitle: allowBackground ? String(localized: "Queue for later") : nil)
        var result: String?
        dialog.onConfirm = { result = $0 }
        dialog.runModalDialog()
        guard let dest = result?.trimmingCharacters(in: .whitespaces), !dest.isEmpty else { return nil }
        // "Queue for later" implies a background job (it lands in the download list).
        let queueForLater = allowBackground && dialog.isThirdChecked
        return (dest, (allowBackground && dialog.isChecked) || queueForLater, dialog.isSecondChecked, queueForLater)
    }

    /// Run a copy/move in the background transfer manager (non-modal): unmark the
    /// processed items + reload on completion, and surface the manager window.
    /// Queue a copy and verify it afterwards if the user asked for that.
    ///
    /// Its own method so the automation verb drives the same wiring the F5 dialog does; a verb that
    /// rebuilt the closure would be testing a copy of it. "Verify files after copy" used to apply to
    /// foreground copies only, with nothing saying so — and the background queue is exactly what one
    /// picks for the large copies where a verification is worth having (F-090). The setting is read when
    /// the job finishes, so one changed while a held job waits still decides correctly.
    func startBackgroundCopy(items: [String], dest: String, mask: String?,
                             onlyNewer: Bool, queueForLater: Bool) {
        enqueueBackground(.copy(items: items, toDirectory: dest,
                                options: copyOptions(mask: mask, onlyNewer: onlyNewer)),
                          title: String(localized: "Copy \(items.count) → \((dest as NSString).lastPathComponent)"),
                          startHeld: queueForLater,
                          onFinished: { [weak self] in
                              guard let self,
                                    await self.config.bool("Operation", "VerifyAfterCopy", default: false)
                              else { return }
                              await self.verifyCopiedItems(items, destDir: dest, mask: mask)
                          })
    }

    /// `onFinished` runs once the queued job has actually finished — which is where "verify after copy"
    /// belongs for a background transfer, and where it was simply not happening (F-090).
    private func enqueueBackground(_ kind: OperationKind, title: String, startHeld: Bool = false,
                                   onFinished: (@MainActor () async -> Void)? = nil) {
        TransferManager.shared.enqueue(kind, title: title, startHeld: startHeld) { [weak self] done in
            guard let self else { return }
            Task { @MainActor in
                await self.getSelectionState().unmarkCompleted(done)
                await self.reload()
                await onFinished?()
            }
        }
        (view.window?.windowController as? MainWindowController)?.showTransferManager()
    }

    private func confirmDelete(count: Int, permanent: Bool) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = permanent ? .critical : .warning
        alert.messageText = permanent
            ? String(localized: "Permanently delete \(count) item(s)?")
            : String(localized: "Move \(count) item(s) to Trash?")
        if permanent {
            alert.informativeText = String(localized: "This cannot be undone.")
        }
        alert.addButton(withTitle: permanent ? String(localized: "Delete") : String(localized: "Move to Trash"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }

    private func presentInfo(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: String(localized: "OK"))
        alert.runModal()
    }
}
