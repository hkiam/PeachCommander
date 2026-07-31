// SPDX-License-Identifier: Apache-2.0
// uninstaller.swift — "Uninstall Application" as an external contribution plugin.
//
// Self-contained: brings its own residual-file scan and review window, and talks
// to the host only through the PcHostServices C-ABI table (cursor path, move to
// Trash / delete, reload). Placement — the File-menu item + panel context item,
// shown only for an .app (when: cursorIsApp) — is declared in Info.plist
// PCContributions; this file is only the behavior (PcRunCommand). Built into
// Uninstaller.ptxplugin by Tools/build-uninstaller-plugin.sh and dlopen'd by the
// host. The C types (PcHostServices) come from the SDK bridging header.

import AppKit

// MARK: - Contribution behavior entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PcRunCommand")
public func PcRunCommand(_ commandId: UnsafePointer<CChar>?, _ services: UnsafePointer<PcHostServices>?) {
    guard let services else { return }
    let svc = services.pointee
    let command = commandId.map { String(cString: $0) } ?? ""

    if command == "plugin.uninstaller.browse" {
        // No .app under the cursor needed: pick from all installed applications,
        // then run the same review/remove flow as for a cursor .app.
        let picker = InstalledAppsPicker(apps: installedApps())
        // Batch: review + remove each chosen app in turn (own review window each).
        for chosen in picker.runModal() { uninstall(appPath: chosen, svc: svc) }
        return
    }

    if command == "plugin.uninstaller.orphans" {
        // Find leftovers of apps that are no longer installed and review/remove them.
        let items = orphanItems()
        guard !items.isEmpty else {
            hostPresentInfo(svc, L("Find Leftover Files"), L("No leftover files were found."))
            return
        }
        let win = UninstallReviewWindow(
            appName: L("Find Leftover Files"), rescan: { _ in items },
            title: L("Find Leftover Files"),
            headerText: L("These files belong to applications that are no longer installed. Review before removing."),
            showDeep: false) { paths, permanent in
            withCStringArray(paths) { arr, count in
                if permanent { svc.deletePermanently?(svc.host, arr, count) }
                else { svc.moveToTrash?(svc.host, arr, count) }
            }
            svc.reloadActivePanel?(svc.host)
        }
        win.runModal()
        return
    }

    // Default (cursor / context-menu) command: operate on the .app under the cursor.
    guard let path = hostCursorPath(svc), path.lowercased().hasSuffix(".app") else {
        hostPresentInfo(svc, L("Uninstall Application"),
                        L("Select an application (.app) first."))
        return
    }
    uninstall(appPath: path, svc: svc)
}

/// Shared flow: scan an app's residual files, review them, and remove the chosen
/// ones. Used both for a cursor .app and for a pick from the installed-apps list.
func uninstall(appPath: String, svc: PcHostServices) {
    let appName = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
    let bundleID = bundleIdentifier(ofApp: appPath)

    // Warn if the app is managed by Homebrew (manual removal leaves brew metadata);
    // note App Store origin in the review header.
    let source = installSource(appPath: appPath, appName: appName)
    if let cask = source.cask {
        let alert = NSAlert()
        alert.messageText = String(format: L("“%@” was installed with Homebrew."), appName)
        alert.informativeText = String(format: L("Remove it cleanly with:  brew uninstall --cask %@\n\nContinue with a manual uninstall anyway?"), cask)
        alert.addButton(withTitle: L("Continue"))
        alert.addButton(withTitle: L("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
    }
    let masHeader: String? = source.mas
        ? String(format: L("These items belong to “%@”. Uncheck anything you want to keep."), appName)
            + "\n" + L("This app came from the App Store.")
        : nil

    let win = UninstallReviewWindow(appName: appName, rescan: { level in
        residualItems(appPath: appPath, bundleID: bundleID, appName: appName, level: level)
    }, headerText: masHeader) { paths, permanent in
        // Quit the running app and unload its launchd jobs BEFORE removing files,
        // so the bundle can be trashed and no agent respawns it.
        stopApp(bundleID: bundleID, selectedPaths: paths)
        withCStringArray(paths) { arr, count in
            if permanent { svc.deletePermanently?(svc.host, arr, count) }
            else { svc.moveToTrash?(svc.host, arr, count) }
        }
        // #4: offer to also remove vendor folders left empty by the removal.
        removeEmptyVendorFolders(after: paths, permanent: permanent, svc: svc)
        svc.reloadActivePanel?(svc.host)
    }
    win.runModal()
}

/// After removal, find vendor folders (a level under a known data dir, e.g.
/// "…/Application Support/<Company>") that are now empty because we removed their
/// only contents, and offer to trash them too. Only empty dirs, never a data-dir
/// root, always with confirmation.
func removeEmptyVendorFolders(after removed: [String], permanent: Bool, svc: PcHostServices) {
    let fm = FileManager.default
    let dataRoots: Set<String> = ["Application Support", "Caches", "Containers", "Group Containers",
                                  "Logs", "Preferences", "HTTPStorages", "WebKit", "Application Scripts"]
    var candidates: [String] = []
    var seen = Set<String>()
    for path in removed {
        let parent = (path as NSString).deletingLastPathComponent
        let parentName = (parent as NSString).lastPathComponent
        let grandName = ((parent as NSString).deletingLastPathComponent as NSString).lastPathComponent
        // Parent must itself sit directly under a data-dir root (i.e. a vendor folder),
        // never be the root, and be empty now (ignoring .DS_Store).
        guard dataRoots.contains(grandName), !dataRoots.contains(parentName), !seen.contains(parent) else { continue }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue else { continue }
        let remaining = (try? fm.contentsOfDirectory(atPath: parent))?.filter { $0 != ".DS_Store" } ?? []
        if remaining.isEmpty { seen.insert(parent); candidates.append(parent) }
    }
    guard !candidates.isEmpty else { return }

    let list = candidates.map { ($0 as NSString).abbreviatingWithTildeInPath }.joined(separator: "\n")
    let alert = NSAlert()
    alert.messageText = L("Remove empty leftover folders?")
    alert.informativeText = String(format: L("These folders are now empty:\n%@"), list)
    alert.addButton(withTitle: permanent ? L("Delete Permanently") : L("Move to Trash"))
    alert.addButton(withTitle: L("Keep"))
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    withCStringArray(candidates) { arr, count in
        if permanent { svc.deletePermanently?(svc.host, arr, count) }
        else { svc.moveToTrash?(svc.host, arr, count) }
    }
}

/// Terminate any running instance of the app and unload its user launchd jobs
/// (LaunchAgents/Daemons among the selected items) so removal is clean and nothing
/// relaunches it. Best-effort: system daemons may need root and are skipped on
/// failure.
func stopApp(bundleID: String?, selectedPaths: [String]) {
    if let id = bundleID, !id.isEmpty {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
        if !running.isEmpty {
            running.forEach { $0.terminate() }
            Thread.sleep(forTimeInterval: 0.5)
            NSRunningApplication.runningApplications(withBundleIdentifier: id).forEach { $0.forceTerminate() }
            Thread.sleep(forTimeInterval: 0.2)
        }
    }
    // Deregister the app's launchd jobs among the selected items — this is the
    // removable "login item" mechanism for a third party. Modern SMAppService
    // background items are owned by the OS and can't be removed here. Prefer
    // `bootout` (current API); fall back to `unload` for older systems.
    let uid = getuid()
    for path in selectedPaths where path.hasSuffix(".plist")
        && (path.contains("/LaunchAgents/") || path.contains("/LaunchDaemons/")) {
        let domain = path.contains("/LaunchAgents/") ? "gui/\(uid)" : "system"  // system needs root
        launchctl(["bootout", domain, path])
        launchctl(["unload", path])
    }
}

/// Run a launchctl subcommand, ignoring output/failures (best-effort).
private func launchctl(_ args: [String]) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    task.arguments = args
    task.standardError = FileHandle.nullDevice
    task.standardOutput = FileHandle.nullDevice
    try? task.run()
    task.waitUntilExit()
}

// MARK: - Host-services helpers

private func hostCursorPath(_ svc: PcHostServices) -> String? {
    guard let fn = svc.cursorPath else { return nil }
    var buf = [CChar](repeating: 0, count: 4096)
    return fn(svc.host, &buf, 4096) != 0 ? String(cString: buf) : nil
}

private func hostPresentInfo(_ svc: PcHostServices, _ title: String, _ message: String) {
    svc.presentInfo?(svc.host, title, message)
}

/// Build a NUL-terminated C array of C strings for a host callback, then free it.
private func withCStringArray(_ strings: [String], _ body: (UnsafePointer<UnsafePointer<CChar>?>, Int32) -> Void) {
    let dups = strings.map { strdup($0) }
    defer { dups.forEach { free($0) } }
    let ptrs: [UnsafePointer<CChar>?] = dups.map { UnsafePointer($0) }
    ptrs.withUnsafeBufferPointer { body($0.baseAddress!, Int32(strings.count)) }
}

// MARK: - Residual-file scan (self-contained copy)

struct CleanupItem { let path: String; let size: Int64; let category: String; var deep: Bool = false }

func bundleIdentifier(ofApp appPath: String) -> String? {
    let plist = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
    guard let data = FileManager.default.contents(atPath: plist),
          let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    else { return nil }
    return dict["CFBundleIdentifier"] as? String
}

func residualItems(appPath: String, bundleID: String?, appName: String, level: Int = 0) -> [CleanupItem] {
    let fm = FileManager.default
    let userLib = (NSHomeDirectory() as NSString).appendingPathComponent("Library")
    var items: [CleanupItem] = []
    var seen = Set<String>()
    func add(_ path: String, _ category: String, deep: Bool = false) {
        guard !seen.contains(path) else { return }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }
        seen.insert(path)
        items.append(CleanupItem(path: path, size: size(of: path, isDir: isDir.boolValue, fm: fm),
                                 category: category, deep: deep))
    }
    // Match a filename to the bundle id on a dot boundary: "<id>.plist",
    // "<id>.helper.plist", ByHost "<id>.<uuid>.plist" — but NOT "<id>Other". This
    // is tighter than a bare substring "contains" (fewer false positives) while
    // still catching an app's helper/agent prefs (Pearcleaner-style bundle anchoring).
    func addPrefixed(in dir: String, prefix id: String, _ category: String) {
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
        let lower = id.lowercased()
        for n in names {
            let nl = n.lowercased()
            if nl == lower || nl.hasPrefix(lower + ".") {
                add((dir as NSString).appendingPathComponent(n), category)
            }
        }
    }
    // Match a filename to an app NAME on a separator boundary ("<Name>_…" / "<Name>-…"),
    // for crash reports like "AppName_2024-…-….ips".
    func addNamePrefixed(in dir: String, prefix name: String, _ category: String) {
        guard name.count >= 3, let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
        let lower = name.lowercased()
        for n in names {
            let nl = n.lowercased()
            if nl.hasPrefix(lower + "_") || nl.hasPrefix(lower + "-") {
                add((dir as NSString).appendingPathComponent(n), category)
            }
        }
    }
    // Scan Containers / Group Containers by their sandbox metadata identifier
    // (MCMMetadataIdentifier) rather than by folder name — group-container folders
    // are named "<team>.<group>", so name matching misses or mis-hits them.
    func addContainers(in dir: String, id: String, _ category: String) {
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for n in names {
            let folder = (dir as NSString).appendingPathComponent(n)
            let meta = (folder as NSString).appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
            guard let data = fm.contents(atPath: meta),
                  let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let mid = dict["MCMMetadataIdentifier"] as? String, mid == id
            else { continue }
            add(folder, category)
        }
    }

    add(appPath, "Application")
    if let id = bundleID, !id.isEmpty {
        // Per-user (~/Library), bundle-id anchored.
        add("\(userLib)/Application Support/\(id)", "Application Support")
        add("\(userLib)/Application Scripts/\(id)", "Application Scripts")
        add("\(userLib)/Caches/\(id)", "Caches")
        add("\(userLib)/Containers/\(id)", "Container")
        add("\(userLib)/Saved Application State/\(id).savedState", "Saved State")
        add("\(userLib)/HTTPStorages/\(id)", "HTTP Storage")
        add("\(userLib)/WebKit/\(id)", "WebKit Data")
        add("\(userLib)/Logs/\(id)", "Logs")
        add("\(userLib)/Cookies/\(id).binarycookies", "Cookies")
        addPrefixed(in: "\(userLib)/Preferences", prefix: id, "Preferences")
        addPrefixed(in: "\(userLib)/Preferences/ByHost", prefix: id, "Preferences (ByHost)")
        addPrefixed(in: "\(userLib)/LaunchAgents", prefix: id, "Launch Agent")
        addContainers(in: "\(userLib)/Containers", id: id, "Container")
        addContainers(in: "\(userLib)/Group Containers", id: id, "Group Container")
        // System-wide (/Library) components — removal may need admin rights (the host
        // op engine prompts). Reads can be blocked by Full Disk Access; then skipped.
        add("/Library/Application Support/\(id)", "Application Support (System)")
        add("/Library/Caches/\(id)", "Caches (System)")
        add("/Library/Logs/\(id)", "Logs (System)")
        addPrefixed(in: "/Library/Preferences", prefix: id, "Preferences (System)")
        addPrefixed(in: "/Library/LaunchAgents", prefix: id, "Launch Agent (System)")
        addPrefixed(in: "/Library/LaunchDaemons", prefix: id, "Launch Daemon (System)")
        addPrefixed(in: "/Library/PrivilegedHelperTools", prefix: id, "Privileged Helper")
        // Installer package receipts (apps installed via a .pkg). Removing the
        // .bom/.plist effectively forgets the receipt. Root-owned → host prompts
        // for admin on removal.
        addPrefixed(in: "/var/db/receipts", prefix: id, "Installer Receipt")
    }
    if !appName.isEmpty {
        add("\(userLib)/Application Support/\(appName)", "Application Support")
        add("\(userLib)/Logs/\(appName)", "Logs")
        // Crash reports are named "<AppName>_<date>_<host>.ips|.crash".
        addNamePrefixed(in: "\(userLib)/Logs/DiagnosticReports", prefix: appName, "Crash Reports")
    }

    // Confidence levels beyond the precise (bundle-id-anchored) matches above:
    //   level 1 (enhanced): folder/file NAMES containing an app-name/company term.
    //   level 2 (deep):     enhanced + a capped Spotlight (mdfind) sweep.
    // These lower-confidence hits are flagged `deep` → left UNCHECKED for review.
    if level >= 1 {
        let terms = deepTerms(bundleID: bundleID, appName: appName)
        if !terms.isEmpty {
            let dataDirs = ["Application Support", "Caches", "Containers", "Group Containers",
                            "Logs", "Preferences", "HTTPStorages", "WebKit"]
            for base in [userLib, "/Library"] {
                for sub in dataDirs {
                    let dir = "\(base)/\(sub)"
                    guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                    for n in names {
                        let nl = n.lowercased()
                        if terms.contains(where: { nl.contains($0) }) {
                            add((dir as NSString).appendingPathComponent(n), "\(sub) (name match)", deep: true)
                        }
                    }
                }
            }
            if level >= 2 {
                for hit in spotlightMatches(terms: terms, limit: 40) { add(hit, "Spotlight", deep: true) }
            }
        }
    }

    return items.sorted { a, b in
        if (a.category == "Application") != (b.category == "Application") { return a.category == "Application" }
        if a.deep != b.deep { return !a.deep }        // precise matches first, deep last
        return a.size > b.size
    }
}

/// Derive lower-confidence search terms (≥4 chars, generic words dropped) from the
/// bundle id (last-two components, company) and app-name variants (as-is, version
/// stripped, letters-only) — the Pearcleaner-style widened match set.
func deepTerms(bundleID: String?, appName: String) -> [String] {
    var terms = Set<String>()
    if let id = bundleID, !id.isEmpty {
        let comps = id.split(separator: ".").map(String.init)
        if comps.count >= 2 { terms.insert(comps.suffix(2).joined(separator: ".").lowercased()) }
        if comps.count >= 3 { terms.insert(comps[comps.count - 2].lowercased()) }   // company
    }
    let name = appName.lowercased()
    terms.insert(name)
    terms.insert(name.replacingOccurrences(of: "\\s+\\d[\\d.]*$", with: "", options: .regularExpression))
    terms.insert(String(name.unicodeScalars.filter { CharacterSet.letters.contains($0) }))
    let generic: Set<String> = ["app", "mac", "macos", "apple", "the", "com", "helper", "agent", "user", "data"]
    return terms.filter { $0.count >= 4 && !generic.contains($0) }
}

/// Capped Spotlight (mdfind) sweep for files whose name contains a term, scoped to
/// the Library trees. Best-effort; returns [] if mdfind is unavailable/blocked.
func spotlightMatches(terms: [String], limit: Int) -> [String] {
    let userLib = (NSHomeDirectory() as NSString).appendingPathComponent("Library")
    var results: [String] = []
    for term in terms.prefix(3) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        task.arguments = ["-onlyin", userLib, "-onlyin", "/Library",
                          "kMDItemFSName == \"*\(term)*\"cd"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { continue }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            results.append(String(line))
            if results.count >= limit { return results }
        }
    }
    return results
}

private func size(of path: String, isDir: Bool, fm: FileManager) -> Int64 {
    if !isDir { return (try? fm.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0 }
    var total: Int64 = 0
    if let e = fm.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
        for case let f as URL in e {
            let v = try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            total += Int64(v?.totalFileAllocatedSize ?? v?.fileSize ?? 0)
        }
    }
    return total
}

private func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Installed-apps enumeration + picker

/// One locally installed application (global or user). Size is filled in lazily
/// (recursive sizing is slow) so the list can appear immediately.
final class InstalledApp {
    let path: String
    let name: String
    let installed: Date?
    var size: Int64?
    private var cachedIcon: NSImage?
    var icon: NSImage {
        if let cachedIcon { return cachedIcon }
        let img = NSWorkspace.shared.icon(forFile: path); img.size = NSSize(width: 32, height: 32)
        cachedIcon = img; return img
    }
    init(path: String, fm: FileManager) {
        self.path = path
        self.name = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let attrs = try? fm.attributesOfItem(atPath: path)
        self.installed = (attrs?[.creationDate] as? Date) ?? (attrs?[.modificationDate] as? Date)
    }
}

/// Enumerate applications in the global and user Applications folders.
func installedApps() -> [InstalledApp] {
    let fm = FileManager.default
    let dirs = ["/Applications", "/Applications/Utilities",
                (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
    var apps: [InstalledApp] = []
    var seen = Set<String>()
    for dir in dirs {
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for n in names where n.hasSuffix(".app") {
            let p = (dir as NSString).appendingPathComponent(n)
            guard !seen.contains(p) else { continue }
            // Hide Apple system apps (Safari, Mail, …) — not for this uninstaller.
            if (bundleIdentifier(ofApp: p) ?? "").hasPrefix("com.apple.") { continue }
            seen.insert(p)
            apps.append(InstalledApp(path: p, fm: fm))
        }
    }
    return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

// MARK: - Install source (App Store / Homebrew) detection

private var cachedCasks: Set<String>?

/// Homebrew cask tokens installed on this machine (cached; empty if no brew).
func homebrewCasks() -> Set<String> {
    if let c = cachedCasks { return c }
    var result = Set<String>()
    for brew in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        where FileManager.default.isExecutableFile(atPath: brew) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brew)
        task.arguments = ["list", "--cask", "-1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        if (try? task.run()) != nil {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                result.insert(String(line))
            }
        }
        break
    }
    cachedCasks = result
    return result
}

/// Detect whether an app came from the App Store (a _MASReceipt) or Homebrew (a
/// matching cask token). Fail-safe: unknown → (false, nil), no warning.
func installSource(appPath: String, appName: String) -> (mas: Bool, cask: String?) {
    let mas = FileManager.default.fileExists(
        atPath: (appPath as NSString).appendingPathComponent("Contents/_MASReceipt/receipt"))
    var cask: String?
    let casks = homebrewCasks()
    if !casks.isEmpty {
        let base = appName.lowercased()
        for cand in [base.replacingOccurrences(of: " ", with: "-"),
                     base.replacingOccurrences(of: " ", with: "")] where casks.contains(cand) {
            cask = cand; break
        }
    }
    return (mas, cask)
}

// MARK: - Orphaned-file scan (leftovers of apps that are no longer installed)

/// Bundle ids of every installed app (including Apple/system apps) — the set an
/// orphaned-file must NOT belong to.
func installedBundleIDs() -> Set<String> {
    let fm = FileManager.default
    let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications",
                "/System/Applications/Utilities",
                (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
    var ids = Set<String>()
    for dir in dirs {
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for n in names where n.hasSuffix(".app") {
            if let id = bundleIdentifier(ofApp: (dir as NSString).appendingPathComponent(n)) {
                ids.insert(id.lowercased())
            }
        }
    }
    return ids
}

/// The sandbox metadata identifier of a (Group) Container folder, if any.
func containerMetadataID(_ folder: String) -> String? {
    let meta = (folder as NSString).appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
    guard let data = FileManager.default.contents(atPath: meta),
          let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    else { return nil }
    return dict["MCMMetadataIdentifier"] as? String
}

/// Looks like a reverse-DNS bundle id (≥3 dotted components, no spaces/slashes),
/// so we only treat clearly app-owned entries as orphan candidates.
func looksLikeBundleID(_ s: String) -> Bool {
    guard !s.contains(" "), !s.contains("/") else { return false }
    return s.split(separator: ".").count >= 3
}

/// Find bundle-id-named leftovers whose owning app is no longer installed. Only
/// reliable (bundle-id / container-metadata) matches are used — name-only folders
/// are skipped to avoid false positives.
func orphanItems() -> [CleanupItem] {
    let fm = FileManager.default
    let installed = installedBundleIDs()
    let userLib = (NSHomeDirectory() as NSString).appendingPathComponent("Library")
    var items: [CleanupItem] = []
    var seen = Set<String>()

    func isInstalled(_ id: String) -> Bool {
        let l = id.lowercased()
        return installed.contains(l) || installed.contains(where: { l.hasPrefix($0 + ".") })
    }
    func addOrphan(_ path: String, _ category: String) {
        guard !seen.contains(path) else { return }
        seen.insert(path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }
        items.append(CleanupItem(path: path, size: size(of: path, isDir: isDir.boolValue, fm: fm), category: category))
    }
    // Directories whose top-level entries are named "<bundle-id><suffix>".
    let idNamed: [(sub: String, strip: String?, cat: String)] = [
        ("Application Support", nil, "Application Support"), ("Caches", nil, "Caches"),
        ("Preferences", ".plist", "Preferences"), ("HTTPStorages", nil, "HTTP Storage"),
        ("WebKit", nil, "WebKit Data"), ("Logs", nil, "Logs"),
        ("Saved Application State", ".savedState", "Saved State"),
    ]
    for entry in idNamed {
        let dir = "\(userLib)/\(entry.sub)"
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for n in names {
            var id = n
            if let strip = entry.strip, n.hasSuffix(strip) { id = String(n.dropLast(strip.count)) }
            guard looksLikeBundleID(id), !isInstalled(id) else { continue }
            addOrphan((dir as NSString).appendingPathComponent(n), entry.cat)
        }
    }
    // Containers / Group Containers by metadata id.
    for (sub, cat) in [("Containers", "Container"), ("Group Containers", "Group Container")] {
        let dir = "\(userLib)/\(sub)"
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for n in names {
            let folder = (dir as NSString).appendingPathComponent(n)
            guard let id = containerMetadataID(folder), !isInstalled(id) else { continue }
            addOrphan(folder, cat)
        }
    }
    return items.sorted { $0.size > $1.size }
}

/// Modal list of installed apps (icon / name / size / install date). Returns the
/// chosen .app path, or nil if cancelled. Sizes are computed off-main and the list
/// refreshes when they arrive.
final class InstalledAppsPicker: NSObject, NSTableViewDataSource, NSTableViewDelegate,
                                 NSSearchFieldDelegate, NSWindowDelegate {
    private let window: NSWindow
    private let table = NSTableView()
    private let searchField = NSSearchField()
    private let apps: [InstalledApp]
    private var displayed: [InstalledApp] = []
    private var chosenPaths: [String] = []
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    init(apps: [InstalledApp]) {
        self.apps = apps
        self.displayed = apps
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("Uninstall Application")
        window.center()
        super.init()
        window.delegate = self   // so closing the window ends the modal session
        build()
        computeSizesInBackground()
    }

    /// Returns the chosen .app paths (one per selected row), or [] if cancelled.

    /// End the modal session when the window goes away by any route.
    ///
    /// These windows are `.closable`, so the red button (or ⌘W) dismisses them without any of
    /// our buttons running. `NSApp.runModal(for:)` then never returns and the *whole app*
    /// stays modal: the main window ignores clicks and its title-bar buttons do nothing while
    /// the menu bar still works — exactly how this was reported.
    ///
    /// Guarded on modalWindow so the ordinary OK/Cancel path, which already called stopModal,
    /// cannot stop a session that is no longer ours.
    func windowWillClose(_ notification: Notification) {
        guard NSApp.modalWindow === window else { return }
        // Deferred, but scheduled on the *run loop* including the modal mode — not
        // DispatchQueue.main.
        //
        // Deferral is needed because stopping the session inside this notification lets
        // runModal(for:) return while AppKit is still tearing the window down; the caller
        // drops its last reference and the window is freed with a close animation
        // (_NSWindowTransformAnimation) still holding it, which crashed in objc_release.
        //
        // But a main-queue block is the wrong vehicle here. These dialogs are opened from a
        // main-actor Task (plugin command → PcRunCommand → runModal), and while that task
        // sits in a nested modal loop the main queue is not serviced — so the block would
        // never run and the app would stay modal, i.e. exactly the hang this fixes.
        // Measured, not assumed: from a main-actor Task, DispatchQueue.main.async never
        // returns from runModal while perform(inModes:) does.
        RunLoop.main.perform(inModes: [.modalPanel, .default, .common]) { NSApp.stopModal() }
    }

    func runModal() -> [String] {
        NSApp.runModal(for: window)
        if window.isVisible { window.orderOut(nil) }
        return chosenPaths
    }

    private func build() {
        guard let content = window.contentView else { return }
        let header = NSTextField(wrappingLabelWithString:
            L("Choose an application to uninstall, then review the files to remove."))
        header.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(header)

        searchField.placeholderString = L("Filter")
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(searchField)

        for (id, title, width, sortable) in [("icon", "", CGFloat(36), false), ("name", L("Name"), 300, true),
                                             ("size", L("Size"), 90, true), ("date", L("Installed"), 130, true)] {
            let col = NSTableColumn(identifier: .init(id))
            col.title = title; col.width = width
            if sortable { col.sortDescriptorPrototype = NSSortDescriptor(key: id, ascending: true) }
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 36
        table.allowsMultipleSelection = true   // batch uninstall
        table.doubleAction = #selector(uninstallSelected)
        table.target = self
        table.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.documentView = table
        content.addSubview(scroll)

        let uninstall = NSButton(title: L("Uninstall…"), target: self, action: #selector(uninstallSelected))
        uninstall.bezelStyle = .rounded; uninstall.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, uninstall])
        buttons.orientation = .horizontal; buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            searchField.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
    }

    /// Recompute `displayed` from the search query + current sort, preserving the
    /// selected app across the reload.
    private func applyFilterSort() {
        let selected = (table.selectedRow >= 0 && table.selectedRow < displayed.count) ? displayed[table.selectedRow] : nil
        let query = searchField.stringValue
        var list = query.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
        if let sd = table.sortDescriptors.first, let key = sd.key {
            list = list.sorted { a, b in
                let asc: Bool
                switch key {
                case "size": asc = (a.size ?? -1) < (b.size ?? -1)
                case "date": asc = (a.installed ?? .distantPast) < (b.installed ?? .distantPast)
                default: asc = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                return asc
            }
            if !sd.ascending { list.reverse() }
        }
        displayed = list
        table.reloadData()
        if let selected, let idx = displayed.firstIndex(where: { $0 === selected }) {
            table.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
    }

    func controlTextDidChange(_ obj: Notification) { applyFilterSort() }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applyFilterSort()
    }

    private func computeSizesInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            for app in self.apps {
                var isDir: ObjCBool = false
                _ = fm.fileExists(atPath: app.path, isDirectory: &isDir)
                app.size = size(of: app.path, isDir: isDir.boolValue, fm: fm)
                // Reload only this app's Size cell (preserves selection; no reorder).
                RunLoop.main.perform(inModes: [.default, .modalPanel]) { [weak self] in
                    guard let self, let row = self.displayed.firstIndex(where: { $0 === app }) else { return }
                    let sizeCol = self.table.column(withIdentifier: .init("size"))
                    guard sizeCol >= 0, row < self.table.numberOfRows else { return }
                    self.table.reloadData(forRowIndexes: IndexSet(integer: row),
                                          columnIndexes: IndexSet(integer: sizeCol))
                }
            }
        }
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { displayed.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = displayed[row]
        let id = tableColumn?.identifier.rawValue ?? ""
        if id == "icon" {
            let iv = tableView.makeView(withIdentifier: .init("iconCell"), owner: self) as? NSImageView
                ?? { let v = NSImageView(); v.identifier = .init("iconCell"); return v }()
            iv.image = app.icon
            return iv
        }
        let cellId = NSUserInterfaceItemIdentifier("textCell_\(id)")
        let field = (tableView.makeView(withIdentifier: cellId, owner: self) as? NSTextField)
            ?? { let f = NSTextField(labelWithString: ""); f.identifier = cellId
                 f.lineBreakMode = .byTruncatingTail; return f }()
        switch id {
        case "name": field.stringValue = app.name
        case "size": field.stringValue = app.size.map(formatBytes) ?? L("…")
        case "date": field.stringValue = app.installed.map { dateFmt.string(from: $0) } ?? "—"
        default: field.stringValue = ""
        }
        return field
    }

    @objc private func uninstallSelected() {
        let paths = table.selectedRowIndexes.compactMap { $0 < displayed.count ? displayed[$0].path : nil }
        guard !paths.isEmpty else { return }
        chosenPaths = paths
        NSApp.stopModal()
    }

    @objc private func cancel() { chosenPaths = []; NSApp.stopModal() }
}

// MARK: - Review window (self-contained)

/// A vertical stack used as an NSScrollView documentView must be flipped.
///
/// AppKit puts a non-flipped document view's origin at the *bottom* left, so the object
/// list sat at the foot of the scroll view instead of growing downwards from the top (and
/// a long list opened scrolled to its end). Matches how the host overrides isFlipped for
/// its own scroll contents.
final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class UninstallReviewWindow: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let appName: String
    private let rescan: (Int) -> [CleanupItem]
    private let onRemove: ([String], Bool) -> Void
    private var items: [CleanupItem] = []
    private var checks: [(NSButton, CleanupItem)] = []

    private let header = NSTextField(wrappingLabelWithString: "")
    private let itemsStack = FlippedStackView()
    private let levelControl = NSSegmentedControl()
    private let summary = NSTextField(labelWithString: "")
    private let trash = NSButton(title: "", target: nil, action: nil)
    private let del = NSButton(title: "", target: nil, action: nil)

    private let title: String
    private let headerText: String?
    private let showDeep: Bool

    init(appName: String, rescan: @escaping (Int) -> [CleanupItem],
         title: String? = nil, headerText: String? = nil, showDeep: Bool = true,
         onRemove: @escaping ([String], Bool) -> Void) {
        self.appName = appName
        self.rescan = rescan
        self.title = title ?? String(format: L("Uninstall %@"), appName)
        self.headerText = headerText
        self.showDeep = showDeep
        self.onRemove = onRemove
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 460),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = self.title
        window.center()
        super.init()
        window.delegate = self   // so closing the window ends the modal session
        items = rescan(0)
        build()
        populate()
    }


    /// End the modal session when the window goes away by any route.
    ///
    /// These windows are `.closable`, so the red button (or ⌘W) dismisses them without any of
    /// our buttons running. `NSApp.runModal(for:)` then never returns and the *whole app*
    /// stays modal: the main window ignores clicks and its title-bar buttons do nothing while
    /// the menu bar still works — exactly how this was reported.
    ///
    /// Guarded on modalWindow so the ordinary OK/Cancel path, which already called stopModal,
    /// cannot stop a session that is no longer ours.
    func windowWillClose(_ notification: Notification) {
        guard NSApp.modalWindow === window else { return }
        // Deferred, but scheduled on the *run loop* including the modal mode — not
        // DispatchQueue.main.
        //
        // Deferral is needed because stopping the session inside this notification lets
        // runModal(for:) return while AppKit is still tearing the window down; the caller
        // drops its last reference and the window is freed with a close animation
        // (_NSWindowTransformAnimation) still holding it, which crashed in objc_release.
        //
        // But a main-queue block is the wrong vehicle here. These dialogs are opened from a
        // main-actor Task (plugin command → PcRunCommand → runModal), and while that task
        // sits in a nested modal loop the main queue is not serviced — so the block would
        // never run and the app would stay modal, i.e. exactly the hang this fixes.
        // Measured, not assumed: from a main-actor Task, DispatchQueue.main.async never
        // returns from runModal while perform(inModes:) does.
        RunLoop.main.perform(inModes: [.modalPanel, .default, .common]) { NSApp.stopModal() }
    }

    func runModal() {
        NSApp.runModal(for: window)
        // Only if it is still on screen: when the user closed it themselves, AppKit has
        // already taken it down and ordering it out again is pointless churn.
        if window.isVisible { window.orderOut(nil) }
    }

    private func build() {
        guard let content = window.contentView else { return }
        header.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(header)

        itemsStack.orientation = .vertical; itemsStack.alignment = .leading; itemsStack.spacing = 4
        itemsStack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.documentView = itemsStack
        content.addSubview(scroll)

        if showDeep {
            levelControl.segmentCount = 3
            levelControl.setLabel(L("Precise"), forSegment: 0)
            levelControl.setLabel(L("Enhanced"), forSegment: 1)
            levelControl.setLabel(L("Deep"), forSegment: 2)
            levelControl.selectedSegment = 0
            levelControl.segmentStyle = .rounded
            levelControl.target = self; levelControl.action = #selector(levelChanged)
            levelControl.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(levelControl)
        }

        summary.font = NSFont.systemFont(ofSize: 11)
        summary.textColor = .secondaryLabelColor
        summary.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(summary)

        trash.title = L("Move to Trash"); trash.target = self; trash.action = #selector(moveToTrash)
        trash.bezelStyle = .rounded; trash.keyEquivalent = "\r"
        del.title = L("Delete Permanently"); del.target = self; del.action = #selector(deletePermanently)
        del.bezelStyle = .rounded
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, del, trash])
        buttons.orientation = .horizontal; buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            itemsStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            summary.topAnchor.constraint(equalTo: showDeep ? levelControl.bottomAnchor : scroll.bottomAnchor,
                                         constant: showDeep ? 8 : 10),
            summary.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            summary.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
        if showDeep {
            NSLayoutConstraint.activate([
                levelControl.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 10),
                levelControl.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            ])
        }
    }

    /// Rebuild the checkbox list from `items`. Precise matches are checked; deep
    /// (lower-confidence) matches are listed but left UNCHECKED for the user to opt in.
    private func populate() {
        itemsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        checks.removeAll()
        if items.isEmpty {
            header.stringValue = String(format: L("No files were found for “%@”."), appName)
        } else {
            header.stringValue = headerText
                ?? String(format: L("These items belong to “%@”. Uncheck anything you want to keep."), appName)
        }
        for item in items {
            let tildePath = (item.path as NSString).abbreviatingWithTildeInPath
            let box = NSButton(checkboxWithTitle:
                "[\(item.category)]  \(tildePath)  —  \(formatBytes(item.size))",
                target: self, action: #selector(itemToggled))
            box.state = item.deep ? .off : .on
            box.toolTip = item.path
            // Right-click a row → reveal that file/folder in Finder.
            let menu = NSMenu()
            let reveal = NSMenuItem(title: L("Reveal in Finder"), action: #selector(revealItem(_:)), keyEquivalent: "")
            reveal.target = self; reveal.representedObject = item.path
            menu.addItem(reveal)
            box.menu = menu
            checks.append((box, item))
            itemsStack.addArrangedSubview(box)
        }
        trash.isEnabled = !items.isEmpty
        del.isEnabled = !items.isEmpty
        updateSummary()
    }

    @objc private func levelChanged() {
        items = rescan(levelControl.selectedSegment)
        populate()
    }

    /// Show the count + total size of the checked items, and warn when any need
    /// admin rights (system locations / non-writable parents).
    private func updateSummary() {
        let checked = checks.filter { $0.0.state == .on }.map { $0.1 }
        let total = checked.reduce(Int64(0)) { $0 + $1.size }
        var text = String(format: L("%d item(s) · %@"), checked.count, formatBytes(total))
        let fm = FileManager.default
        let needsAdmin = checked.contains { item in
            item.path.hasPrefix("/Library") || item.path.hasPrefix("/var")
                || !fm.isWritableFile(atPath: (item.path as NSString).deletingLastPathComponent)
        }
        if needsAdmin { text += "  —  " + L("some items may require administrator rights") }
        summary.stringValue = text
    }

    @objc private func itemToggled() { updateSummary() }

    @objc private func revealItem(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private var selectedPaths: [String] { checks.filter { $0.0.state == .on }.map { $0.1.path } }

    @objc private func moveToTrash() { finish(permanent: false) }
    @objc private func deletePermanently() { finish(permanent: true) }
    @objc private func cancel() { NSApp.stopModal() }

    private func finish(permanent: Bool) {
        let paths = selectedPaths
        if !paths.isEmpty { onRemove(paths, permanent) }
        NSApp.stopModal()
    }
}