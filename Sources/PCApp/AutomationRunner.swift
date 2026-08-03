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
            case "view":       openViewer(arg)
            case "menudump":   dumpMenu(arg)
            case "a11ydump":   dumpAccessibility(arg)   // a11ydump <outfile> (I19 T06)
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
                if it.isSeparatorItem { lines.append("  ----") }
                else { lines.append("  \(it.title)\((it.representedObject as? String).map { "  [\($0)]" } ?? "")") }
            }
        }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: file, atomically: true, encoding: .utf8)
        NSLog("[automation] menudump → \(file)")
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
        let text = "count=\(cells.count)\n" + cells.enumerated().map { i, s in
            let blank = s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return "\(blank ? "BLANK!" : "  ok  ")[\(i)] \(s)"
        }.joined(separator: "\n") + "\n"
        try? text.write(toFile: a[1], atomically: true, encoding: .utf8)
        NSLog("[automation] editdump \(cells.count) rendered rows → \(a[1])")
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
