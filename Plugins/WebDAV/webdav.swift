// SPDX-License-Identifier: Apache-2.0
// webdav.swift — WebDAV as an external PFX file-system plugin.
//
// Implements the PFX "connect" facet: an interactive connect (prompt for URL +
// password), then WFX-style whole-file operations over HTTP using the WebDAV
// verbs PROPFIND/GET/PUT/MKCOL/DELETE/MOVE. Self-contained (Foundation only) —
// it links no app frameworks; passwords are persisted through the host's
// Keychain-backed crypt callback. The host adapts this to its streaming VFS.
// Built into WebDAV.pfxplugin by Tools/build-webdav-plugin.sh.
//
// All blocking network calls run on the host's dedicated per-connection queue
// (the host never calls a connection from two threads at once), so bridging
// URLSession to synchronous calls with a semaphore here is safe.

import AppKit

// MARK: - C-string helper

private func setCString(_ string: String, _ dst: UnsafeMutablePointer<CChar>, _ capacity: Int) {
    string.withCString { _ = strlcpy(dst, $0, capacity) }
}

// MARK: - Connection & find state (opaque handles across the ABI)

final class WebDAVConnection {
    let baseURL: URL
    let authHeader: String?
    let hostName: String
    let session: URLSession

    init(baseURL: URL, authHeader: String?, hostName: String) {
        self.baseURL = baseURL
        self.authHeader = authHeader
        self.hostName = hostName
        let c = URLSessionConfiguration.ephemeral
        c.httpAdditionalHeaders = ["User-Agent": "PeachCommander-WebDAV/1"]
        self.session = URLSession(configuration: c)
    }

    func url(for path: String, directory: Bool = false) -> URL {
        var p = path
        while p.hasPrefix("/") { p.removeFirst() }
        var u = p.isEmpty ? baseURL : baseURL.appendingPathComponent(p)
        if directory, !u.absoluteString.hasSuffix("/") {
            u = URL(string: u.absoluteString + "/") ?? u
        }
        return u
    }

    func request(_ method: String, _ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        if let authHeader { r.setValue(authHeader, forHTTPHeaderField: "Authorization") }
        return r
    }

    /// Synchronous request (blocks the calling thread). Returns (data, status, ok).
    func send(_ r: URLRequest) -> (Data?, Int) {
        let sem = DispatchSemaphore(value: 0)
        var data: Data?; var status = 0
        session.dataTask(with: r) { d, resp, _ in
            data = d
            status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            sem.signal()
        }.resume()
        sem.wait()
        return (data, status)
    }
}

final class WebDAVFind {
    let entries: [DavEntry]
    var index = 0
    init(_ entries: [DavEntry]) { self.entries = entries }
}

struct DavEntry { let name: String; let size: Int64; let mtime: Int64; let isDir: Bool }

// MARK: - PROPFIND body & status mapping

private let propfindBody = Data("""
<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:"><D:prop>\
<D:resourcetype/><D:getcontentlength/><D:getlastmodified/><D:displayname/>\
</D:prop></D:propfind>
""".utf8)

private func ok(_ status: Int) -> Bool { (200...299).contains(status) || status == 207 }

private func pcError(_ status: Int) -> Int32 {
    switch status {
    case 401, 403: return Int32(PC_E_ECREATE)     // permission → host maps to denied
    case 404: return Int32(PC_E_EOPEN)             // not found
    default: return Int32(PC_E_BAD_DATA)
    }
}

// MARK: - PROPFIND parser (namespace-agnostic, ported from PCNet.WebDAVListParser)

private final class DavParser: NSObject, XMLParserDelegate {
    private final class R { var href: String?; var isCollection = false; var length: Int64?; var modified: Int64? }
    private var responses: [R] = []
    private var current: R?
    private var text = ""
    private var inResourceType = false

    private static let httpDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    static func parse(_ data: Data, excludingPath: String?) -> [DavEntry] {
        let d = DavParser()
        let p = XMLParser(data: data)
        p.shouldProcessNamespaces = true
        p.delegate = d
        p.parse()
        let selfKey = excludingPath.map(normalize)
        var out: [DavEntry] = []
        for r in d.responses {
            guard let href = r.href else { continue }
            let path = normalize(hrefPath(href))
            if let selfKey, path == selfKey { continue }
            let name = (path as NSString).lastPathComponent
            guard !name.isEmpty, name != "/" else { continue }
            out.append(DavEntry(name: name,
                                size: r.isCollection ? -1 : (r.length ?? 0),
                                mtime: r.modified ?? 0,
                                isDir: r.isCollection))
        }
        return out
    }

    static func hrefPath(_ href: String) -> String {
        let raw: String
        if let comps = URLComponents(string: href), comps.host != nil { raw = comps.percentEncodedPath }
        else { raw = href }
        return raw.removingPercentEncoding ?? raw
    }

    static func normalize(_ path: String) -> String {
        var s = path
        if !s.hasPrefix("/") { s = "/" + s }
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s
    }

    func parser(_ parser: XMLParser, didStartElement e: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        text = ""
        switch e {
        case "response": current = R()
        case "resourcetype": inResourceType = true
        case "collection": if inResourceType { current?.isCollection = true }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement e: String, namespaceURI: String?, qualifiedName: String?) {
        let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "response": if let current { responses.append(current) }; current = nil
        case "resourcetype": inResourceType = false
        case "href": if current?.href == nil { current?.href = v }
        case "getcontentlength": current?.length = Int64(v)
        case "getlastmodified": current?.modified = DavParser.httpDate.date(from: v).map { Int64($0.timeIntervalSince1970) }
        default: break
        }
        text = ""
    }
}

// MARK: - Connect dialog

/// Saved WebDAV site URLs (no passwords — those live in the Keychain).
enum WebDAVSites {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PeachCommander/webdav", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("sites.json")
    }
    static func load() -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(contentsOf: fileURL))) ?? []
    }
    static func add(_ url: String) {
        var list = load(); list.removeAll { $0 == url }; list.insert(url, at: 0)
        if list.count > 30 { list = Array(list.prefix(30)) }
        try? JSONEncoder().encode(list).write(to: fileURL, options: .atomic)
    }
}

final class ConnectDialog: NSObject {
    private let window: NSWindow
    private let urlCombo = NSComboBox()
    private let pwField = NSSecureTextField(string: "")
    private let sites: [String]
    private var confirmed = false

    init(sites: [String]) {
        self.sites = sites
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 150),
                          styleMask: [.titled], backing: .buffered, defer: false)
        super.init()
        window.title = L("Connect to WebDAV Server")
        window.center()
        // AppKit releases a programmatically created window when it closes
        // (isReleasedWhenClosed defaults to true, and only NSWindowController turns it
        // off). This object keeps a strong reference, so leaving it on means the window
        // is freed while we still point at it — an over-release that crashed in
        // -[_NSWindowTransformAnimation dealloc] once the close animation released it
        // again. The hang used to mask it: the app froze before anything touched the
        // freed window.
        window.isReleasedWhenClosed = false
        build()
    }

    /// Returns (urlString, password) or nil if cancelled.
    func run() -> (String, String)? {
        NSApp.runModal(for: window)
        window.orderOut(nil)
        guard confirmed else { return nil }
        return (urlCombo.stringValue.trimmingCharacters(in: .whitespaces), pwField.stringValue)
    }

    private func build() {
        guard let content = window.contentView else { return }
        urlCombo.addItems(withObjectValues: sites)
        urlCombo.stringValue = sites.first ?? "https://"
        urlCombo.completes = true
        let urlLabel = NSTextField(labelWithString: L("URL (e.g. https://user@host/dav/):"))
        let pwLabel = NSTextField(labelWithString: L("Password:"))
        for v in [urlLabel, pwLabel, urlCombo, pwField] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        let connect = NSButton(title: L("Connect"), target: self, action: #selector(ok))
        connect.bezelStyle = .rounded; connect.keyEquivalent = "\r"
        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancel))
        cancel.bezelStyle = .rounded; cancel.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancel, connect])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            urlLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            urlLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            urlCombo.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 4),
            urlCombo.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            urlCombo.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            pwLabel.topAnchor.constraint(equalTo: urlCombo.bottomAnchor, constant: 10),
            pwLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            pwField.leadingAnchor.constraint(equalTo: pwLabel.trailingAnchor, constant: 8),
            pwField.centerYAnchor.constraint(equalTo: pwLabel.centerYAnchor),
            pwField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
        ])
    }

    @objc private func ok() { confirmed = true; NSApp.stopModal() }
    @objc private func cancel() { confirmed = false; NSApp.stopModal() }
}

// MARK: - PFX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("PfxGetCapabilities")
public func PfxGetCapabilities() -> Int32 { PC_PFX_CAP_READ | PC_PFX_CAP_WRITE | PC_PFX_CAP_RENAME }

@_cdecl("PfxGetConnectTitle")
public func PfxGetConnectTitle(_ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let out else { return 0 }
    setCString(L("WebDAV Connect…"), out, Int(maxlen))
    return 1
}

@_cdecl("PfxConnect")
public func PfxConnect(_ services: UnsafePointer<PfxHostServices>?) -> UnsafeMutableRawPointer? {
    let svc = services?.pointee
    // Test hook: PC_WEBDAV_URL lets connect run without the modal dialog (for
    // automated end-to-end tests). Ignored in normal use.
    let entered: (String, String)?
    let fromEnvironment: Bool
    if let env = ProcessInfo.processInfo.environment["PC_WEBDAV_URL"], !env.isEmpty {
        entered = (env, ProcessInfo.processInfo.environment["PC_WEBDAV_PASSWORD"] ?? "")
        fromEnvironment = true
    } else {
        entered = ConnectDialog(sites: WebDAVSites.load()).run()
        fromEnvironment = false
    }
    guard let (urlString, typedPassword) = entered,
          !urlString.isEmpty, let comps = URLComponents(string: urlString),
          let hostName = comps.host, comps.scheme == "http" || comps.scheme == "https" else {
        return nil
    }
    let user = comps.user ?? ""
    var password = typedPassword.isEmpty ? (comps.password ?? "") : typedPassword
    let store = "webdav:\(hostName):\(user)"

    // Keychain via host: load a saved password if none entered; else save the new one.
    if let svc, let crypt = svc.crypt, !user.isEmpty {
        if password.isEmpty {
            var buf = [CChar](repeating: 0, count: 512)
            let rc = store.withCString { crypt(svc.host, Int32(PC_CRYPT_COPY_PASSWORD), $0, &buf, 512) }
            if rc == PC_OK { password = String(cString: buf) }
        } else {
            store.withCString { s in
                _ = password.withCString { p in
                    crypt(svc.host, Int32(PC_CRYPT_SAVE_PASSWORD), s, UnsafeMutablePointer(mutating: p), 0)
                }
            }
        }
    }

    // Remember the site (with user, without password) for next time — but not when the connect
    // came from the test hook. `WebDAVSites` writes to the real Application Support directory and
    // does not know about the host's `-ConfigRoot`, so an automated run would otherwise leave a
    // throwaway localhost URL in the user's own history, once per run.
    var siteComps = comps; siteComps.password = nil
    if fromEnvironment == false, let site = siteComps.url?.absoluteString { WebDAVSites.add(site) }

    var baseComps = comps
    baseComps.user = nil; baseComps.password = nil
    guard let baseURL = baseComps.url else { return nil }
    let authHeader = user.isEmpty ? nil : "Basic " + Data("\(user):\(password)".utf8).base64EncodedString()
    let conn = WebDAVConnection(baseURL: baseURL, authHeader: authHeader, hostName: hostName)
    return Unmanaged.passRetained(conn).toOpaque()
}

@_cdecl("PfxConnectionId")
public func PfxConnectionId(_ conn: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<CChar>?, _ maxlen: Int32) -> Int32 {
    guard let conn, let out else { return 0 }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    setCString("webdav:\(c.hostName)", out, Int(maxlen))
    return 1
}

@_cdecl("PfxDisconnect")
public func PfxDisconnect(_ conn: UnsafeMutableRawPointer?) {
    guard let conn else { return }
    Unmanaged<WebDAVConnection>.fromOpaque(conn).release()
}

@_cdecl("PfxFindFirst")
public func PfxFindFirst(_ conn: UnsafeMutableRawPointer?, _ dir: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    guard let conn, let dir else { return nil }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    let path = String(cString: dir)
    let requestURL = c.url(for: path, directory: true)
    var r = c.request("PROPFIND", requestURL)
    r.setValue("1", forHTTPHeaderField: "Depth")
    r.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
    r.httpBody = propfindBody
    let (data, status) = c.send(r)
    guard ok(status), let data else { return nil }
    let entries = DavParser.parse(data, excludingPath: requestURL.path)
    return Unmanaged.passRetained(WebDAVFind(entries)).toOpaque()
}

@_cdecl("PfxFindNext")
public func PfxFindNext(_ find: UnsafeMutableRawPointer?, _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let find, let out else { return 0 }
    let f = Unmanaged<WebDAVFind>.fromOpaque(find).takeUnretainedValue()
    guard f.index < f.entries.count else { return 0 }
    let e = f.entries[f.index]; f.index += 1
    setCString(e.name, &out.pointee.name.0, 1024)
    out.pointee.size = e.size
    out.pointee.mtime = e.mtime
    out.pointee.isDir = e.isDir ? 1 : 0
    out.pointee.mode = 0
    return 1
}

@_cdecl("PfxFindClose")
public func PfxFindClose(_ find: UnsafeMutableRawPointer?) {
    guard let find else { return }
    Unmanaged<WebDAVFind>.fromOpaque(find).release()
}

@_cdecl("PfxStat")
public func PfxStat(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?, _ out: UnsafeMutablePointer<PfxFindData>?) -> Int32 {
    guard let conn, let path, let out else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    var r = c.request("PROPFIND", c.url(for: String(cString: path)))
    r.setValue("0", forHTTPHeaderField: "Depth")
    r.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
    r.httpBody = propfindBody
    let (data, status) = c.send(r)
    guard ok(status), let data, let e = DavParser.parse(data, excludingPath: nil).first else { return pcError(status) }
    setCString(e.name, &out.pointee.name.0, 1024)
    out.pointee.size = e.size; out.pointee.mtime = e.mtime; out.pointee.isDir = e.isDir ? 1 : 0; out.pointee.mode = 0
    return Int32(PC_OK)
}

@_cdecl("PfxGetFile")
public func PfxGetFile(_ conn: UnsafeMutableRawPointer?, _ remote: UnsafePointer<CChar>?, _ local: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let remote, let local else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    let (data, status) = c.send(c.request("GET", c.url(for: String(cString: remote))))
    guard ok(status), let data else { return pcError(status) }
    do { try data.write(to: URL(fileURLWithPath: String(cString: local)), options: .atomic); return Int32(PC_OK) }
    catch { return Int32(PC_E_ECREATE) }
}

@_cdecl("PfxPutFile")
public func PfxPutFile(_ conn: UnsafeMutableRawPointer?, _ local: UnsafePointer<CChar>?, _ remote: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let local, let remote else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: String(cString: local))) else { return Int32(PC_E_EOPEN) }
    var r = c.request("PUT", c.url(for: String(cString: remote)))
    r.httpBody = data
    let (_, status) = c.send(r)
    return ok(status) ? Int32(PC_OK) : pcError(status)
}

@_cdecl("PfxMkDir")
public func PfxMkDir(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let path else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    let (_, status) = c.send(c.request("MKCOL", c.url(for: String(cString: path), directory: true)))
    return ok(status) ? Int32(PC_OK) : pcError(status)
}

@_cdecl("PfxDelete")
public func PfxDelete(_ conn: UnsafeMutableRawPointer?, _ path: UnsafePointer<CChar>?) -> Int32 {
    guard let conn, let path else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    let (_, status) = c.send(c.request("DELETE", c.url(for: String(cString: path))))
    return ok(status) ? Int32(PC_OK) : pcError(status)
}

@_cdecl("PfxRenMov")
public func PfxRenMov(_ conn: UnsafeMutableRawPointer?, _ from: UnsafePointer<CChar>?, _ to: UnsafePointer<CChar>?, _ move: Int32) -> Int32 {
    guard let conn, let from, let to else { return Int32(PC_E_NOT_SUPPORTED) }
    let c = Unmanaged<WebDAVConnection>.fromOpaque(conn).takeUnretainedValue()
    var r = c.request("MOVE", c.url(for: String(cString: from)))
    r.setValue(c.url(for: String(cString: to)).absoluteString, forHTTPHeaderField: "Destination")
    r.setValue("T", forHTTPHeaderField: "Overwrite")
    let (_, status) = c.send(r)
    return ok(status) ? Int32(PC_OK) : pcError(status)
}
