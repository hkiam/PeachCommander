// SPDX-License-Identifier: Apache-2.0
// AutomationRunner.swift - DEBUG-only scripted automation of the running app.
//
// Enabled with the launch flag `-AutomationScript <path>` (DEBUG builds only).
// After the window loads, the script runs one verb per line so tests/tools can
// drive the REAL app deterministically — including the network connect path —
// without fragile GUI clicking. Not compiled into release builds.
//
//   left  <path>          load a directory in the left panel
//   right <path>          load a directory in the right panel
//   active left|right     set the active panel
//   cmd   <cm_Name>       run a registered command by name
//   connect <url>         quick-connect (ftp://user:pass@host/… , sftp://… )
//   disconnect            leave the active panel's network mount
//   wait  <ms>            sleep (let an async connect/list settle)
//   dump  <file>          write the active panel's path + entry names to a file
//   bardrop <path>        add a bar button for <path>, as a drop on free space would
//   theme <id>            select a colour palette ("system", "norton", …)
//   quit                  terminate the app
//   # …                   comment / blank lines are ignored

#if DEBUG
import AppKit
import PCFoundation
import PCNet
import PCOperations
import PCAutomation
import PCVFS

/// Retains editor windows opened by the `editdump` automation verb.
private var automationEditors: [EditorWindowController] = []
/// Retains lister windows opened by the `view` automation verb.
private var automationListers: [ListerWindowController] = []
/// Retains sync windows opened by the `syncdemo` automation verb (F-192).
private var automationSyncWindows: [SyncWindowController] = []
/// Retains type-colour editors opened by the `typecolors` verb (F-032).
private var automationTypeColorEditors: [TypeColorsWindowController] = []
private var automationDiffWindows: [DiffWindowController] = []
private var automationProgressDialogs: [ProgressDialog] = []

extension MainWindowController {
    func runAutomationScript(_ path: String) async {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            NSLog("[automation] cannot read script: \(path)")
            return
        }
        NSLog("[automation] running \(path)")
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
            let verb = parts[0].lowercased()
            let arg = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            NSLog("[automation] > \(line)")
            switch verb {
            case "left":       await leftPanelController?.loadDirectory(arg)
            case "right":      await rightPanelController?.loadDirectory(arg)
            case "active":     arg.lowercased().hasPrefix("r") ? activateRightPanel() : activateLeftPanel()
            case "focus":      activePanel?.tableView.focusEntry(named: arg)   // move cursor onto <name>
            case "enter":      activePanel?.tableView.enterUnderCursor()   // descend into the cursor item
            case "reordertab":                                            // reorder tabs: reordertab <from> <to> (F-008)
                let p = arg.split(separator: " ").compactMap { Int($0) }
                if p.count == 2 { activePanel?.reorderTab(from: p[0], to: p[1]) }
            case "cmd":        runCommandNamed(arg)
            case "pfxmount":                                              // pfxmount <volume-name> (e.g. TaskManager): mount a pfx drive volume by name into the active panel
                if let vol = FileSystemPluginRegistry.shared.driveVolumes().first(where: { $0.name == arg && $0.path.hasPrefix("pfxmount:") }) {
                    mountPluginVolume(pluginId: String(vol.path.dropFirst("pfxmount:".count)), into: activePanel)
                } else { NSLog("[automation] pfxmount: no pfx volume named \(arg)") }
            case "connect":
                if let url = FtpURL.parse(arg) {
                    connectToSite(url.toSite(), password: url.password ?? "")
                } else {
                    NSLog("[automation] bad url: \(arg)")
                }
            case "disconnect": disconnectActivePanelNetwork()
            case "wait":
                let ms = UInt64(arg) ?? 500
                try? await Task.sleep(nanoseconds: ms * 1_000_000)
            case "dump":       await dumpActivePanel(to: arg)
            case "symbols":    dumpSymbols(arg)
            case "editdump":   await editDump(arg)
            case "editfilter": await editFilter(arg)   // editfilter <src>|<command>|<out> (F-356)
            case "editfilterdlg": await editFilterDialog(arg)   // editfilterdlg <src> (F-356)
            case "editlines":  await editLines(arg)     // editlines <src>|<out> (F-359)
            case "editstruct": await editStructure(arg) // editstruct <src>|<needle>|<out> (F-369)
            case "sftpget":                             // sftpget <remote>|<local>|<out>|<partial> (F-366)
                await sftpGet(arg)
            case "sftpput":                             // sftpput <local>|<remote>|<out>|<partial> (F-212)
                await sftpPut(arg)
            case "sftpchmod":                           // sftpchmod <path>|<octal>|<out> (F-364)
                await sftpChmod(arg)
            case "widenleft":                           // give the left panel almost the whole window, so a
                // wide opt-in column is actually *in* the screenshot. The report can pass with the column
                // clipped out of view; the picture then proves nothing, which is the whole reason the
                // pictures exist.
                automationWidenLeftPanel()
            case "comment":                             // comment <name>|<text>: set a file's comment the
                // way Ctrl+Z does, so a scenario can put one there without typing into a modal dialog.
                let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count == 2, let panel = activePanel {
                    panel.tableView.focusEntry(named: parts[0])
                    _ = await panel.setCursorComment(parts[1])
                }
            case "listerdump":                          // listerdump <outfile>: what the viewer window shows
                var out = ""
                if let win = automationListers.last ?? nil {
                    out = win.automationSummary()
                } else if let win = NSApp.windows.first(where: { $0.windowController is ListerWindowController }),
                          let controller = win.windowController as? ListerWindowController {
                    out = controller.automationSummary()
                } else {
                    out = "ERROR: no lister window\n"
                }
                try? out.write(toFile: arg, atomically: true, encoding: .utf8)
            case "previewpanel":                        // previewpanel on|off: *set* it, do not toggle
                // A toggle depends on what the previous scenario left behind — this scenario measured a
                // closed panel in the full run and an open one when run alone, which is how a layout
                // conflict hid for as long as it did.
                if let panel = previewPanelForAutomation() {
                    let wantOpen = arg.lowercased() != "off"
                    if panel.frame.width <= 1 || panel.isHidden { if wantOpen { togglePreviewPanel() } }
                    else if !wantOpen { togglePreviewPanel() }
                }
            case "previewtab":                          // previewtab <title>: pick a preview panel tab
                if let panel = previewPanelForAutomation() {
                    NSLog("[automation] previewtab \(arg): \(panel.automationSelectTab(titled: arg))")
                }
            case "commentread":                         // commentread <name>|<out> (F-372)
                let parts = arg.split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count == 2, let panel = activePanel {
                    let path = (await panel.getCurrentPath() as NSString).appendingPathComponent(parts[0])
                    panel.refreshComments()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    let out = "hostComment=\(contribFileComment(path) ?? "<none>")\n"
                        + "column=\(panel.tableView.automationComment(forName: parts[0]) ?? "<none>")\n"
                    try? out.write(toFile: parts[1], atomically: true, encoding: .utf8)
                }
            case "sidebarsetfield":                     // sidebarsetfield <text> (F-372)
                // Type into the *plugin's* comment field and commit it, the way a user leaving the field
                // does. Proving the read direction alone would leave the write path — the one that changes
                // a file on disk — unverified.
                if let panel = previewPanelForAutomation() {
                    NSLog("[automation] sidebarsetfield: \(automationCommitFirstEditableField(in: panel, text: arg))")
                }
            case "sidebardump":                         // sidebardump <outfile> (F-372)
                dumpSidebar(arg)
            case "column":                              // column <fieldID>: switch an opt-in column on
                if let panel = activePanel, !panel.tableView.hasColumn(arg) { toggleColumn(arg, panel: panel) }
            case "commentcarry":                        // commentcarry <dir>|<name>|<newName>|<out> (F-372)
                await commentCarryProbe(arg)
            case "mkfile":                              // mkfile <path> (F-361): create a file the way
                // another program would — not through a panel operation, so nothing asks the panel to
                // reload. If the file shows up, the watcher is what put it there.
                try? "auto\n".write(toFile: arg, atomically: true, encoding: .utf8)
            case "view":       openViewer(arg)
            case "menudump":   dumpMenu(arg)
            case "a11ydump":   dumpAccessibility(arg)   // a11ydump <outfile> (I19 T06)
            case "keyloop":    dumpKeyLoop(arg)         // keyloop <outfile> (I19 T06)
            case "keyloopmodal":                        // keyloopmodal <outfile> (I19 T06)
                // Call *before* opening a modal dialog: `runModal` does not return until the dialog is
                // dismissed, so a `keyloop` line after it never runs. Scheduling in the modal run-loop
                // modes is how the rest of this codebase reaches into a modal session.
                // A delay, and a Timer rather than a queue block: performing immediately dumped the
                // *main* window because the dialog had not opened yet — a false pass, caught only by
                // reading the report. The timer is added to the modal modes so it fires while the
                // dialog is up.
                let target = arg
                let timer = Timer(timeInterval: 1.2, repeats: false) { [weak self] _ in
                    self?.dumpKeyLoop(target)
                }
                RunLoop.main.add(timer, forMode: .modalPanel)
                RunLoop.main.add(timer, forMode: .default)
            case "overwritedlg": showOverwriteDialogForShot()   // screenshot the conflict dialog (F-086)
            case "hotlistmanage": showHotlistManager()   // open the hotlist manager (F-061)
            case "typecolors":                             // open the file-type colour editor (F-032)
                let editor = TypeColorsWindowController(config: arg)
                automationTypeColorEditors.append(editor)
                editor.showWindow(nil); editor.window?.makeKeyAndOrderFront(nil)
            case "syncdemo":                               // syncdemo <left>|<right>[|hidden] (F-192): open sync + compare
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count >= 2 {
                    let win = SyncWindowController(leftDir: a[0], rightDir: a[1])
                    automationSyncWindows.append(win)
                    win.showWindow()
                    if a.count >= 3, a[2] == "hidden" { win.automationSetIgnoreHidden(true) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { win.compareNow() }
                }
            case "settingspage":                           // open Settings + select a page (F-274)
                showSettings()
                let title = arg
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.settingsWindow?.showPage(titled: title)
                }
            case "findercomment":                          // findercomment <path>|<text> (F-023): write + read-back
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    FinderComment.write(a[1], to: a[0])
                    NSLog("[automation] finder-comment readback: \(FinderComment.read(a[0]) ?? "<nil>")")
                }
            case "errorlog":   showErrorLogForShot()   // screenshot the operation error log (F-089)
            case "bgcopyfail":                          // bgcopyfail <realsrc>|<dstdir> (F-089 background log)
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let items = [a[0], a[0] + ".missing"]   // one real, one missing → skipped + logged
                    TransferManager.shared.enqueue(.copy(items: items, toDirectory: a[1], options: CopyOptions()),
                                                   title: "Copy demo")
                }
            case "dllist":                                 // dllist <src>|<dstdir> (F-215): enqueue a held download-list job
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    TransferManager.shared.enqueue(.copy(items: [a[0]], toDirectory: a[1], options: CopyOptions()),
                                                   title: "Download \((a[0] as NSString).lastPathComponent)", startHeld: true)
                    showTransferManager()
                }
            case "packplugin":                             // packplugin <archivePath>|<srcDir>|<f1>,<f2> (F-137)
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 3 {
                    let files = a[2].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    let ok = await activePanel?.resolvePackerPack?(a[0], a[1], files) ?? false
                    NSLog("[automation] packplugin result: \(ok)")
                }
            case "findtab":                                // findtab <index> (F-150): open Find dialog + select an options tab
                showFindFiles()
                let tab = Int(arg) ?? 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.findWindow?.selectTab(tab) }
            case "findrun":                                // findrun <mask> (F-150): open Find + run a search to verify wiring
                showFindFiles()
                let mask = arg.isEmpty ? "*.*" : arg
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.findWindow?.automationStart(mask: mask) }
            case "httpget":                                // httpget <url>|<dir>|<name>[|<sha256>] (F-330)
                let a = arg.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count >= 3 {
                    let sha = a.count >= 4 ? a[3] : nil
                    enqueueURLDownload(url: a[0], name: a[2], into: a[1],
                                       options: HTTPDownloadOptions(), expectedSHA256: sha, held: false)
                }
            case "dlstart":  TransferManager.shared.startAllQueued()   // F-215: start the whole download list
            case "ctxdump":                                // ctxdump <name>|<outfile> (F-068): dump the context menu tree
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    activePanel?.tableView.focusEntry(named: a[0])
                    let dump = activePanel?.tableView.automationContextMenuDump() ?? ""
                    try? dump.write(toFile: a[1], atomically: true, encoding: .utf8)
                }
            case "rowdrop":                                // rowdrop <row>|<f1>,<f2> (F-067): drop files onto a folder row
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2, let row = Int(a[0]) {
                    let files = a[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    activePanel?.tableView.automationDropOnRow(row, paths: files, move: false)
                }
            case "zipdelete":                              // zipdelete <zip>|<rel> (F-192): delete an entry from a zip via sync
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let item = SyncItem(relativePath: a[1], isDirectory: false,
                                        leftSize: nil, leftModified: nil,
                                        rightSize: 0, rightModified: nil)
                    let result = SyncResult(action: .deleteRight, item: item)
                    let errs = SyncExecutor.execute([result], left: .localDir("/tmp"),
                                                    right: .zip(a[0]), toTrash: false)
                    NSLog("[automation] zipdelete errors: \(errs)")
                }
            case "subbar":                                 // subbar <barfile> (F-253): descend into a subbar
                runBarButton(BarButton(cmd: arg))
            case "buttondrop":                             // buttondrop <targetdir>|<f1>,<f2> (F-067): drop files on a dir button
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let files = a[1].split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    handleButtonDrop(BarButton(cmd: a[0]), files: files)   // a dir-target button
                }
            case "diffdemo":                               // diffdemo <a>|<b> (F-190): open the text diff window
                let a = arg.split(separator: "|", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                if a.count == 2 {
                    let win = DiffWindowController(leftPath: a[0], rightPath: a[1])
                    automationDiffWindows.append(win)
                    win.showWindow()
                }
            case "progressdemo":                           // progressdemo (I04): show a sample transfer progress dialog
                let dlg = ProgressDialog(title: "Copying 128 items…", control: OperationControl())
                automationProgressDialogs.append(dlg)
                dlg.present(over: window)
                dlg.update(OpProgress(filesTotal: 128, filesDone: 47,
                                      bytesTotal: 2_400_000_000, bytesDone: 900_000_000,
                                      currentItem: "vacation.mov", bytesPerSecond: 82_000_000))
            case "help":       NSApplication.shared.showHelp(nil)   // open the Help Book in Help Viewer
            case "automate":   await automateCoreTool(arg)          // drive the Automation Core: automate <tool>|<json>
            case "bardrop":                                // bardrop <path> — as if dropped on free bar space
                // The drag itself cannot be scripted, but everything after it can: this is the
                // exact entry point the bar view calls, so a scripted run exercises the real path.
                addBarButtons(for: [arg], at: 0)
            case "theme":                                  // theme <id> — select a colour palette (F-2xx)
                // Documentation screenshots of a theme have to be reproducible, and driving the
                // Settings popup by hand is not. Goes through the same sink as the popup, so the
                // screenshot shows exactly what a user gets.
                applyStringOption("Colors.Theme", arg)
            case "presentview": contribPresentSidebarView(viewId: arg, root: NSHomeDirectory())  // mount a plugin sidebar view (verification)
            case "contribcmd": _ = await ContributionRegistry.shared.dispatch(arg, host: self)   // run a plugin contribution command (verification)
            case "quit":       NSApp.terminate(nil)
            default:           NSLog("[automation] unknown verb: \(verb)")
            }
        }
        NSLog("[automation] done")
    }

    /// Diagnostic: present the REAL interactive overwrite-conflict dialog with two
    /// sample files, so a screenshot can confirm the "Append" button (F-086). Both
    /// facts are regular files, so Append is offered.
    private func showOverwriteDialogForShot() {
        // Write real fixtures so the F-086 preview thumbnails render (an image
        // source over a text target).
        let dir = FileManager.default.temporaryDirectory
        let imgURL = dir.appendingPathComponent("pc-owshot.png")
        let txtURL = dir.appendingPathComponent("pc-owshot-old.txt")
        let swatch = NSImage(size: NSSize(width: 96, height: 96))
        swatch.lockFocus(); NSColor.systemOrange.setFill(); NSRect(x: 0, y: 0, width: 96, height: 96).fill()
        NSColor.white.setFill(); NSRect(x: 24, y: 24, width: 48, height: 48).fill(); swatch.unlockFocus()
        if let tiff = swatch.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: imgURL) }
        try? "old contents".data(using: .utf8)?.write(to: txtURL)

        let src = FileFacts(path: imgURL.path, name: "banner.png", size: 2048,
                            modified: Date(timeIntervalSince1970: 1_720_000_000), isDirectory: false)
        let dst = FileFacts(path: txtURL.path, name: "banner.png", size: 1024,
                            modified: Date(timeIntervalSince1970: 1_700_000_000), isDirectory: false)
        let resolver = InteractiveResolver(parentWindow: window)
        Task { _ = await resolver.resolveOverwrite(source: src, target: dst) }
    }

    /// Diagnostic: present the REAL end-of-operation error log (F-089) with sample
    /// skipped-file entries so a screenshot can confirm the summary window.
    private func showErrorLogForShot() {
        let entries = [
            (path: "/Users/maik1/src/locked.bin", message: "writeFailed(\"/Volumes/Backup/locked.bin\")"),
            (path: "/Users/maik1/src/secret.key", message: "readFailed(\"/Users/maik1/src/secret.key\")"),
            (path: "/Users/maik1/src/huge.iso", message: "cannotCreateFile(\"/Volumes/Backup/huge.iso\")"),
        ]
        ErrorLogWindowController.present(over: window,
                                         summary: String(localized: "\(entries.count) item(s) were skipped due to errors."),
                                         entries: entries)
    }

    /// Diagnostic: run the REAL symbol-outline pipeline on a source file and write the
    /// resulting tree (kind/line/name, flagging blank names) to a file.
    /// Usage: `symbols <srcFile> <outFile>`.
    private func dumpSymbols(_ arg: String) {
        let a = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] symbols needs <src> <out>"); return }
        let src = a[0], outFile = a[1]
        let ext = (src as NSString).pathExtension.lowercased()
        guard let text = try? String(contentsOfFile: src, encoding: .utf8),
              let h = SymbolOutline.handles(ext: ext) else {
            try? "ERROR: cannot read or unsupported ext\n".write(toFile: outFile, atomically: true, encoding: .utf8)
            return
        }
        let roots = SymbolOutline.parse(text, query: h.query, language: h.language)
        var lines: [String] = []
        func walk(_ nodes: [SymbolNode], _ depth: Int) {
            for n in nodes {
                let blank = n.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                lines.append("\(blank ? "BLANK!" : "  ok  ")\(String(repeating: "  ", count: depth))[\(n.kind)] line=\(n.line) name=[\(n.name)]")
                walk(n.children, depth + 1)
            }
        }
        walk(roots, 0)
        try? (lines.joined(separator: "\n") + "\n").write(toFile: outFile, atomically: true, encoding: .utf8)
        NSLog("[automation] symbols of \(src) → \(outFile) (\(lines.count) rows)")
    }

    /// Open the built-in viewer (Lister) directly on a file, for visual checks.
    /// `view <file>` opens normally; `view <file> wrap` forces word-wrap on;
    /// `view <file> binary` forces the binary/fixed-width mode.
    private func openViewer(_ arg: String) {
        // Usage: view <file> [wrap|binary] [search:<term>]
        let tokens = arg.split(separator: " ").map(String.init)
        guard let path = tokens.first else { return }
        Task { @MainActor in
            let plugins = await self.makeListerPlugins()   // load PLX listers so plugin modes work (F-119)
            let lc = ListerWindowController(files: [path], startIndex: 0, plugins: plugins)
            automationListers.append(lc)
            lc.showWindow(nil)
            lc.window?.makeKeyAndOrderFront(nil)
            for token in tokens.dropFirst() {
                if token == "wrap" { lc.automationEnableWrap() }
                else if token == "binary" { lc.automationForceBinary() }
                else if token.hasPrefix("hex:") { lc.automationForceHex(bytesPerRow: Int(token.dropFirst(4)) ?? 16) }
                else if token.hasPrefix("search:") { lc.applyInitialSearch(String(token.dropFirst("search:".count))) }
            }
            NSLog("[automation] view repr items: \(lc.automationReprItems().joined(separator: ", "))")
        }
    }

    /// Dump the top-level menus and their item titles (+ represented command) to a
    /// file, so a driver can assert menu structure/order without opening menus.
    private func dumpMenu(_ file: String) {
        guard let main = NSApp.mainMenu else { return }
        var lines: [String] = []
        for top in main.items {
            guard let sub = top.submenu else { continue }
            lines.append("# \(sub.title)")
            for it in sub.items {
                if it.isSeparatorItem { lines.append("  ----"); continue }
                // The key equivalent belongs in the dump: a shortcut audit that reads the source
                // instead of the built menu is auditing what was meant, not what is bound (I19 T06).
                let key = it.keyEquivalent.isEmpty ? "" : "  key=" + Self.describe(
                    key: it.keyEquivalent, mask: it.keyEquivalentModifierMask)
                let cmd = (it.representedObject as? String).map { "  [\($0)]" } ?? ""
                lines.append("  \(it.title)\(cmd)\(key)\(it.isEnabled ? "" : "  disabled")")
            }
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] menudump → \(file)")
    }

    /// A shortcut in the scheme files' notation (C=Ctrl A=Alt S=Shift W=Cmd), so the menu dump and the
    /// keymap can be compared without a translation table in the middle.
    static func describe(key: String, mask: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if mask.contains(.control) { parts.append("C") }
        if mask.contains(.option) { parts.append("A") }
        if mask.contains(.shift) { parts.append("S") }
        if mask.contains(.command) { parts.append("W") }
        // An uppercase letter as a key equivalent means Shift, whether or not the mask says so.
        var token = key
        if token.count == 1, let ch = token.first, ch.isUppercase {
            if !parts.contains("S") { parts.append("S") }
            token = token.lowercased()
        }
        let named: [String: String] = ["\u{1b}": "ESC", "\r": "RETURN", "\t": "TAB",
                                      "\u{8}": "BACKSPACE", "\u{7f}": "DELETE", " ": "SPACE",
                                      "\u{f700}": "UP", "\u{f701}": "DOWN", "\u{f702}": "LEFT",
                                      "\u{f703}": "RIGHT", "\u{f704}": "F1", "\u{f705}": "F2",
                                      "\u{f706}": "F3", "\u{f707}": "F4", "\u{f708}": "F5",
                                      "\u{f709}": "F6", "\u{f70a}": "F7", "\u{f70b}": "F8",
                                      "\u{f70c}": "F9", "\u{f70d}": "F10", "\u{f70e}": "F11",
                                      "\u{f70f}": "F12"]
        return (parts + [named[token] ?? token.uppercased()]).joined(separator: "+")
    }

    /// Write what pressing Tab reaches in the key window, and what it cannot (I19 T06).
    ///
    /// A dialog can be perfectly labelled for a screen reader and still be unusable without a mouse: an
    /// element that is not in the key-view loop is never focused, so its label is never read either.
    /// Only the loop the running window actually has can answer that, which is why this is asked of the
    /// app rather than reasoned about from the layout code.
    private func dumpKeyLoop(_ file: String) {
        // A modal window is the only one the user can touch while it is up, so it is the one to report.
        guard let window = NSApp.modalWindow ?? NSApp.keyWindow
                ?? NSApp.windows.first(where: { $0.isVisible }) else {
            NSLog("[automation] keyloop: no visible window")
            return
        }
        // Which control has focus right now, resolved through the field editor. A text field that is
        // being edited hands first-responder status to a shared NSTextView and *itself* then reports
        // `acceptsFirstResponder == false` — so without this the focused field looks like a control that
        // refuses focus, and its field editor looks like an unreachable stray view. Both readings are
        // wrong, and the first version of this dump made exactly that mistake.
        let fieldEditor = (window.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? $0 : nil }
        let editing = fieldEditor?.delegate as? NSView
        var lines = ["window: \(window.title)",
                     "fullKeyboardAccess: \(NSApp.isFullKeyboardAccessEnabled)",
                     "focused: " + (editing.map { Self.describe($0) + " (editing)" }
                                    ?? (window.firstResponder as? NSView).map(Self.describe)
                                    ?? String(describing: type(of: window.firstResponder as Any))),
                     // The suspected cause of a loop that reaches nothing: for a window built in code
                     // this is false, so AppKit never links the controls and only accidents are reachable.
                     "autorecalculatesKeyViewLoop: \(window.autorecalculatesKeyViewLoop)",
                     "initialFirstResponder: \(window.initialFirstResponder.map { String(describing: type(of: $0)) } ?? "nil")"]

        // Every view that says it can take focus, in tree order — plus, for the ones that say they
        // cannot, why. "It is not in the loop" and "it refuses focus" are different defects with
        // different fixes, and guessing which one it is has already cost time here.
        var candidates: [NSView] = []
        var refusers: [String] = []
        func collect(_ view: NSView) {
            if view.canBecomeKeyView {
                candidates.append(view)
            } else if view === editing {
                // Focused, hence "refusing": it is being edited this very moment.
                candidates.append(view)
            } else if Self.isInteractive(view) {
                let control = view as? NSControl
                refusers.append("\(Self.describe(view)) "
                    + "accepts=\(view.acceptsFirstResponder) hidden=\(view.isHidden) "
                    + "enabled=\(control?.isEnabled ?? true) "
                    + "refuses=\(control?.refusesFirstResponder ?? false)")
            }
            view.subviews.forEach(collect)
        }
        if let content = window.contentView { collect(content) }
        lines.append("focusRefused: \(refusers.count)")
        for entry in refusers { lines.append("  REFUSES: \(entry)") }

        // The loop as AppKit would walk it.
        var visited: [NSView] = []
        var cursor = (window.initialFirstResponder ?? (window.firstResponder as? NSView))
            ?? candidates.first
        var guardCount = 0
        while let view = cursor, guardCount < 200 {
            if visited.contains(where: { $0 === view }) { break }
            visited.append(view)
            lines.append("  tab[\(visited.count)]: \(Self.describe(view))")
            cursor = view.nextValidKeyView
            guardCount += 1
        }
        lines.append("loopClosed: \(cursor != nil)")

        // A composite control is reached through its owner: focus lands on the NSTabView and the arrow
        // keys drive the segmented control AppKit builds inside it, so counting that segmented control as
        // unreachable is a false alarm — and a report with false alarms in it gets ignored. Only an
        // ancestor that is itself a control counts, or the content view would make everything "reachable".
        func reachable(_ candidate: NSView) -> Bool {
            if visited.contains(where: { $0 === candidate }) { return true }
            var parent = candidate.superview
            while let view = parent {
                if view is NSControl || view is NSTabView, visited.contains(where: { $0 === view }) {
                    return true
                }
                parent = view.superview
            }
            return false
        }
        var missed = candidates.filter { !reachable($0) }
        if let editing, !visited.contains(where: { $0 === editing }) {
            // A control that holds focus is reachable by definition — Tab simply starts from it.
            missed.removeAll { $0 === editing }
        }
        missed.removeAll { $0 === fieldEditor }
        lines.append("unreachable: \(missed.count)")
        for view in missed { lines.append("  MISSED: \(Self.describe(view))") }
        // A focusable control with nothing to announce is the other half of the same problem. Scaffolding
        // — a container, a clip view, a scroller — legitimately has none, so only interactive views count.
        let unlabelled = visited.filter {
            Self.isInteractive($0) && ($0.accessibilityLabel() ?? "").isEmpty && Self.title(of: $0).isEmpty
        }
        lines.append("unlabelled: \(unlabelled.count)")
        for view in unlabelled { lines.append("  UNLABELLED: \(String(describing: type(of: view)))") }

        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] keyloop → \(file) (\(visited.count) stops, \(missed.count) unreachable)")
    }

    /// Whether a screen reader would treat this view as something to operate.
    ///
    /// A static label is an `NSTextField` that is neither editable nor selectable — it is not a control
    /// that refuses focus, it is a caption, and reporting it as a defect only trains people to ignore
    /// the report.
    private static func isInteractive(_ view: NSView) -> Bool {
        // Scrollers are operated by role and value, not by a name; AppKit's own do not carry labels and
        // do not need any.
        if view is NSScroller { return false }
        if let field = view as? NSTextField { return field.isEditable || field.isSelectable }
        if view is NSTextView { return true }
        if view is NSTableView { return true }
        return view is NSControl
    }

    /// A control's own words: its title, its placeholder, or the label it exposes.
    private static func title(of view: NSView) -> String {
        if let button = view as? NSButton, !button.title.isEmpty { return button.title }
        if let field = view as? NSTextField {
            if !field.stringValue.isEmpty { return field.stringValue }
            if let placeholder = field.placeholderString, !placeholder.isEmpty { return placeholder }
        }
        if let popup = view as? NSPopUpButton { return popup.titleOfSelectedItem ?? "" }
        return ""
    }

    private static func describe(_ view: NSView) -> String {
        let kind = String(describing: type(of: view))
        let label = view.accessibilityLabel() ?? ""
        let own = title(of: view)
        let words = [label, own].filter { !$0.isEmpty }.joined(separator: " / ")
        return words.isEmpty ? kind : "\(kind) | \(words)"
    }

    /// Walk the key window's accessibility tree and write what a screen reader would find.
    ///
    /// Asked of the app itself rather than through an accessibility *client*: a client needs the
    /// Accessibility permission, which cannot be granted unattended in a fresh VM, while a process may
    /// always inspect its own tree. That makes "is the drive bar reachable" checkable in the harness
    /// instead of only by hand — which matters, because the failure mode for a hand-drawn control is
    /// not a wrong label but no element at all, and nothing on screen looks different either way.
    ///
    /// Typed calls, not KVC. The first version asked for "accessibilityRole" by key and reflected on a
    /// selector, and it crashed the app inside the automation script — NSView does not answer those
    /// through KVC, and a reflected cast to a Role was never going to be sound.
    private func dumpAccessibility(_ file: String) {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }),
              let root = window.contentView else {
            NSLog("[automation] a11ydump: no visible window")
            return
        }
        var lines = ["window: \(window.title)"]
        // Cycle detection over *views* only, and holding them. Keying a set on ObjectIdentifier while
        // walking freshly created elements was wrong in a way the first dump showed straight away: the
        // hand-drawn chips are built on demand and released as the walk moves on, so the allocator
        // reused an address and the second drive bar's "Favorites" chip was mistaken for one already
        // visited — it silently vanished from the report. Views live as long as the window, so their
        // identity means something.
        var seenViews: [NSView] = []

        func describe(_ node: Any, depth: Int) {
            guard depth < 12 else { return }
            let role: NSAccessibility.Role?
            let label: String?
            let value: Any?
            let children: [Any]
            switch node {
            case let view as NSView:
                role = view.accessibilityRole()
                label = view.accessibilityLabel()
                value = view.accessibilityValue()
                children = view.accessibilityChildren() ?? []
            case let element as NSAccessibilityElement:
                role = element.accessibilityRole()
                label = element.accessibilityLabel()
                value = element.accessibilityValue()
                children = element.accessibilityChildren() ?? []
            default:
                return
            }
            // A view tree can be a graph; visiting one twice would recurse until the stack runs out.
            if let view = node as? NSView {
                guard !seenViews.contains(where: { $0 === view }) else { return }
                seenViews.append(view)
            }
            // Only rows that say something: an unnamed group is scaffolding, not content.
            if role != nil || !(label ?? "").isEmpty {
                var row = String(repeating: "  ", count: depth) + (role?.rawValue ?? "?")
                if let label, !label.isEmpty { row += " | \(label)" }
                if let value, !(value is NSNull) { row += " = \(value)" }
                lines.append(row)
            }
            for child in children { describe(child, depth: depth + 1) }
        }

        describe(root, depth: 0)
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] a11ydump → \(file) (\(lines.count) rows)")
    }

    /// Open the real editor on a file, let its sidebar parse, and dump the strings
    /// actually rendered into the outline rows (live NSOutlineView path).
    /// Usage: `editdump <srcFile> <outFile>`.
    private func editDump(_ arg: String) async {
        let a = arg.split(separator: " ", maxSplits: 1).map(String.init)
        guard a.count == 2 else { NSLog("[automation] editdump needs <src> <out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        win.automationShowSidebar()                          // visible during the natural load
        try? await Task.sleep(nanoseconds: 1_400_000_000)   // let the background parse + reload settle
        let cells = win.automationRenderedSymbols()          // read live state, no forced reload
        var text = "count=\(cells.count)\n" + cells.enumerated().map { i, s in
            let blank = s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return "\(blank ? "BLANK!" : "  ok  ")[\(i)] \(s)"
        }.joined(separator: "\n") + "\n"
        // The status line as it stands after loading — the caret is at the top, so the breadcrumb must
        // describe the top — and then the path for a caret placed in the middle of the document.
        text += "status=\(win.automationStatusLine())\n"
        text += "crumb@0=\(win.automationBreadcrumb(at: 0))\n"
        let middle = ((try? String(contentsOfFile: a[0], encoding: .utf8))?.utf16.count ?? 0) / 2
        text += "crumb@mid=\(win.automationBreadcrumb(at: middle))\n"
        try? text.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editdump \(cells.count) rendered rows → \(a[1])")
    }

    /// Download a file over a real SFTP connection twice: once whole, then — after truncating the local
    /// copy to `partial` bytes — again with resume, reporting what each pass transferred (F-366).
    ///
    /// The second pass is the point: `written` must be the tail only and `resumedAt` the truncation point.
    /// Whether the *result* is correct is not judged here at all; the harness compares the file with the
    /// original over ssh, because a downloader reporting on its own output is no witness.
    private func sftpGet(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 4, let partial = Int64(a[3]) else {
            NSLog("[automation] sftpget needs <remote>|<local>|<out>|<partialBytes>"); return
        }
        let session = SFTPSession()
        let destination = URL(fileURLWithPath: a[1])
        var report = ""
        do {
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil)
            let fs = SFTPFileSystem(session: session)
            let path = VFSPath(filesystemId: "sftp", path: a[0])
            let whole = try await fs.downloadFile(path, to: destination, resume: false)
            report += "full=\(whole.written)\n"
            // Simulate a transfer that stopped: keep the first `partial` bytes and ask for the rest.
            let handle = try FileHandle(forWritingTo: destination)
            try handle.truncate(atOffset: UInt64(partial))
            try handle.close()
            let resumed = try await fs.downloadFile(path, to: destination, resume: true)
            report += "resumedAt=\(resumed.resumedAt)\ntail=\(resumed.written)\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpget → \(a[2])")
    }

    /// Upload a file over a real SFTP connection, then truncate the remote copy to `partial` bytes and
    /// upload again with resume — reporting what each pass sent (F-212).
    ///
    /// Truncating the *remote* file is what an interrupted upload leaves behind. Whether the result is
    /// correct is decided by `cmp` in the harness, not here.
    private func sftpPut(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 4, let partial = Int64(a[3]) else {
            NSLog("[automation] sftpput needs <local>|<remote>|<out>|<partialBytes>"); return
        }
        let session = SFTPSession()
        var report = ""
        do {
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil)
            let fs = SFTPFileSystem(session: session)
            let source = URL(fileURLWithPath: a[0])
            let remote = VFSPath(filesystemId: "sftp", path: a[1])
            let whole = try await fs.uploadFile(source, to: remote, resume: false)
            report += "full=\(whole.written)\n"
            // Cut the remote copy back: the state an upload that stopped halfway leaves.
            let cut = try await session.read(a[1]).prefix(Int(partial))
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("pc-cut-\(UUID().uuidString)")
            try Data(cut).write(to: temporary)
            _ = try await session.upload(temporary, to: a[1], from: 0)
            try? FileManager.default.removeItem(at: temporary)
            let resumed = try await fs.uploadFile(source, to: remote, resume: true)
            report += "resumedAt=\(resumed.resumedAt)\ntail=\(resumed.written)\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpput → \(a[2])")
    }

    /// Change a file's mode over a real SFTP connection and report what the server says afterwards.
    ///
    /// Against the guest's own sshd, authenticated by key — `SFTPSession` finds ~/.ssh/id_ed25519 itself,
    /// so no password appears anywhere in the harness. The point is the read-back: an implementation that
    /// accepts the request and discards it (which is what SFTP did) passes every other kind of check.
    private func sftpChmod(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3, let mode = UInt16(a[1], radix: 8) else {
            NSLog("[automation] sftpchmod needs <path>|<octal>|<out>"); return
        }
        let session = SFTPSession()
        var report = "requested=\(String(mode, radix: 8))\n"
        do {
            try await session.connect(host: "127.0.0.1", port: 22, user: NSUserName(),
                                      password: nil, keyFile: nil, keyPassphrase: nil)
            // Only the change is done here. What the mode *is* afterwards is read by the harness with
            // `stat` over ssh — an independent witness, because a wrapper reporting on its own write is
            // exactly the kind of evidence that let the empty implementation pass for so long.
            try await session.setAttributes(a[0], mode: mode)
            report += "applied=ok\n"
        } catch {
            report += "error=\(error)\n"
        }
        await session.close()
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] sftpchmod → \(a[2])")
    }

    /// Open `src` in the editor, pipe the whole document through `command`, and write what the editor
    /// shows afterwards to `out` (F-356). The window is left open so the screenshot shows the result.
    private func editFilter(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] editfilter needs <src>|<command>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)   // let the load and the first highlight settle
        let report = await win.automationFilter(a[1])
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] editfilter \(a[1]) → \(a[2])")
    }

    /// Open `src` in the editor, run every built-in line operation, and report the result (F-359).
    private func editLines(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 2 else { NSLog("[automation] editlines needs <src>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 800_000_000)
        let report = win.automationLineOperations()
        try? report.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editlines → \(a[1])")
    }

    /// Open `src`, put the caret on `needle`, and drive the Structure menu (F-369).
    ///
    /// Usage: `editstruct <src>|<needle>|<out>`. The sidebar is shown so the screenshot proves the tree
    /// and the navigation belong to the same document.
    private func editStructure(_ arg: String) async {
        let a = arg.split(separator: "|").map(String.init)
        guard a.count == 3 else { NSLog("[automation] editstruct needs <src>|<needle>|<out>"); return }
        let win = EditorWindowController(path: a[0])
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        win.automationShowSidebar()
        try? await Task.sleep(nanoseconds: 1_400_000_000)      // let the background parse settle
        let report = win.automationStructure(startAt: a[1])
        try? report.write(toFile: a[2], atomically: true, encoding: .utf8)
        NSLog("[automation] editstruct → \(a[2])")
    }

    /// Put `text` into the first editable text field of `root` and commit it as ending an edit does.
    private func automationCommitFirstEditableField(in root: NSView, text: String) -> String {
        func find(_ view: NSView) -> NSTextField? {
            if let field = view as? NSTextField, field.isEditable, !field.isHidden { return field }
            for sub in view.subviews { if let hit = find(sub) { return hit } }
            return nil
        }
        guard let field = find(root) else { return "no editable field" }
        field.stringValue = text
        // The delegate acts on the end of editing, not on every keystroke, so that is what is simulated.
        field.delegate?.controlTextDidEndEditing?(
            Notification(name: NSControl.textDidEndEditingNotification, object: field))
        return "committed"
    }

    /// Write every string a plugin's sidebar view is *showing* to a file (F-372).
    ///
    /// The preview panel is the host's "sidebar" view container, so a plugin view mounted there is a real
    /// NSView inside the host's window — which means the host can read it, and a claim about what a plugin
    /// displays does not have to be taken on trust. Nothing in the ABI would allow asking the plugin.
    private func dumpSidebar(_ file: String) {
        var lines: [String] = []
        func walk(_ view: NSView, depth: Int) {
            let pad = String(repeating: "  ", count: depth)
            if let field = view as? NSTextField {
                let kind = field.isEditable ? "field" : "label"
                lines.append("\(pad)\(kind)=\(field.stringValue)"
                             + (field.placeholderString.map { " placeholder=\($0)" } ?? ""))
            } else if let text = view as? NSTextView {
                lines.append("\(pad)text=\(text.string.replacingOccurrences(of: "\n", with: "⏎").prefix(120))")
            }
            for sub in view.subviews { walk(sub, depth: depth + 1) }
        }
        if let panel = previewPanelForAutomation() {
            walk(panel, depth: 0)
        } else {
            lines.append("ERROR: no preview panel view")
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] sidebardump → \(file) (\(lines.count) rows)")
    }

    /// Does a file's comment follow the file through a rename, in the running app (F-372)?
    ///
    /// Usage: `commentcarry <dir>|<name>|<newName>|<out>`. Sets a comment through the panel's own path
    /// (the same one Ctrl+Z uses), renames through the panel's rename, and reports what the *panel* shows
    /// in its Comment column afterwards — not what the store returns. The column is the thing the user
    /// looks at, and it is fed by a separate read.
    private func commentCarryProbe(_ arg: String) async {
        let a = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard a.count == 4, let panel = activePanel else {
            NSLog("[automation] commentcarry needs <dir>|<name>|<newName>|<out>"); return
        }
        let (dir, name, newName, out) = (a[0], a[1], a[2], a[3])
        await panel.loadDirectory(dir)
        panel.tableView.focusEntry(named: name)
        var report = ""
        let set = await panel.setCursorComment("carried through the rename")
        report += "set=\(set)\n"
        panel.refreshComments()
        try? await Task.sleep(nanoseconds: 500_000_000)
        report += "beforeRename=\(panel.tableView.automationComment(forName: name) ?? "<none>")\n"
        _ = panel.performRenames(dir: dir, pairs: [(old: name, new: newName)])
        try? await Task.sleep(nanoseconds: 900_000_000)      // the carry runs in a detached Task
        await panel.loadDirectory(dir)
        panel.refreshComments()
        try? await Task.sleep(nanoseconds: 500_000_000)
        report += "afterRename=\(panel.tableView.automationComment(forName: newName) ?? "<none>")\n"
        report += "oldName=\(panel.tableView.automationComment(forName: name) ?? "<none>")\n"
        // …and what the cell actually draws, which is not the same claim.
        report += "renderedCell=\(panel.tableView.automationRenderedComment(forName: newName))\n"
        panel.tableView.automationScrollToLastColumn()
        try? report.write(toFile: out, atomically: true, encoding: .utf8)
        NSLog("[automation] commentcarry → \(out)")
    }

    /// Open `src` in the editor and put the filter prompt on screen for a screenshot (F-356).
    private func editFilterDialog(_ arg: String) async {
        let win = EditorWindowController(path: arg)
        automationEditors.append(win)
        win.showWindow(nil)
        win.window?.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 600_000_000)
        win.automationShowFilterDialog()
    }

    /// Write the active panel's current path and visible entry names to `file`, so a
    /// driver can assert on what the panel actually shows (local or remote).
    private func dumpActivePanel(to file: String) async {
        guard let panel = activePanel else {
            try? "ERROR: no active panel\n".write(toFile: file, atomically: true, encoding: .utf8)
            return
        }
        let path = await panel.getCurrentPath()
        let names = panel.tableView.currentVisibleEntries().map { $0.name }
        let out = "path=\(path)\ncount=\(names.count)\n" + names.joined(separator: "\n") + "\n"
        try? out.write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] dumped \(names.count) entries of \(path) → \(file)")
    }

    /// Drive the Automation Core end-to-end against the running app:
    ///   automate <tool>|<json-args>[|auto]
    /// Logs the outcome (ok payload / needs-confirmation plan+token / refused /
    /// failed). `auto` uses an autonomous policy so a gated write actually runs.
    private func automateCoreTool(_ spec: String) async {
        let parts = spec.split(separator: "|", maxSplits: 2).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        guard let tool = parts.first, !tool.isEmpty else {
            NSLog("[automation] automate: missing tool name"); return
        }
        let json: Data? = parts.count > 1 && !parts[1].isEmpty ? Data(parts[1].utf8) : nil
        let policy: PermissionPolicy = (parts.count > 2 && parts[2] == "auto")
            ? PermissionPolicy(autonomy: .autonomous) : .standard
        let line: String
        do {
            let outcome = try await automationCore.invoke(tool: tool, arguments: json, policy: policy)
            switch outcome {
            case .ok(let payload):
                let s = payload.flatMap { String(data: $0, encoding: .utf8) } ?? "(no payload)"
                line = "automate \(tool) -> ok: \(s)"
            case .needsConfirmation(let plan, let token):
                line = "automate \(tool) -> needsConfirmation: \(plan) [token=\(token)]"
            case .refused(let reason):
                line = "automate \(tool) -> refused: \(reason)"
            case .failed(let error):
                line = "automate \(tool) -> failed: \(error)"
            }
        } catch {
            line = "automate \(tool) -> throw: \(error)"
        }
        NSLog("[automation] \(line)")
        // Also append to a file so headless verification can read outcomes reliably.
        let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("pc-automate.log")
        if let data = (line + "\n").data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: logURL) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}
#endif
