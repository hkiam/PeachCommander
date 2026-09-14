// SPDX-License-Identifier: Apache-2.0
// DockerEngine.swift — the transport under the Docker provider: HTTP/1.1 spoken straight
// to the engine's socket.
//
// Foundation's URLSession cannot address a Unix domain socket, and the Docker engine on a
// developer's Mac is *always* one — Docker Desktop, Colima, Rancher, Podman's compatibility
// socket. So the HTTP client is written here: connect(2), write the request, read the reply.
// It is a small client on purpose, because it only ever talks to one server whose answers it
// already knows the shape of.
//
// Two things about this that are not obvious and were learned from the engine itself:
//
//   * **The API version has to be negotiated.** A modern daemon rejects a version prefix it
//     considers too old with 400 and a message, not with a fallback — `/v1.43/containers/json`
//     against Docker 29 answers "client version 1.43 is too old". `GET /_ping` reports the
//     version the daemon speaks in its `Api-Version` header, and that is what every later
//     request is prefixed with. A daemon that does not answer the ping is addressed without a
//     prefix, which the engine reads as "latest".
//
//   * **A body can be gigabytes.** A container's root directory comes back as a tar of the whole
//     filesystem, so every response is readable as a *stream* and only the small ones (JSON) are
//     collected into memory. `send` buffers, `stream` does not, and the tar reader is built on
//     the second.
//
// Blocking calls throughout: the host runs every call on one connection on its own serial
// queue and never calls a connection from two threads at once, so a synchronous client is the
// simple correct thing here rather than a compromise.

import Foundation

// MARK: - Where the engine is

/// A Docker-compatible engine endpoint, and how to reach it.
struct DockerEndpoint: Equatable {
    enum Transport: Equatable {
        case unix(path: String)
        case tcp(host: String, port: UInt16)
    }

    let transport: Transport
    /// The `DOCKER_HOST`-style URL this came from — the stable identity of the endpoint.
    let url: String
    /// Short label for the drive chip and the mount title ("Docker", "Colima", "Podman").
    let label: String

    init(transport: Transport, url: String, label: String) {
        self.transport = transport
        self.url = url
        self.label = label
    }

    /// Parse a `DOCKER_HOST` value. Only the two schemes that can be spoken without TLS are
    /// accepted; `ssh://` and `tcp://` with TLS are a later step and are refused here rather
    /// than half-attempted, because a half-attempt would fail later with a confusing error.
    static func parse(_ value: String, label: String) -> DockerEndpoint? {
        if value.hasPrefix("unix://") {
            let path = String(value.dropFirst("unix://".count))
            guard !path.isEmpty else { return nil }
            return DockerEndpoint(transport: .unix(path: path), url: value, label: label)
        }
        if value.hasPrefix("tcp://") || value.hasPrefix("http://") {
            let rest = value.drop(while: { $0 != "/" }).drop(while: { $0 == "/" })
            let hostPort = rest.prefix(while: { $0 != "/" })
            let parts = hostPort.split(separator: ":")
            guard let host = parts.first, !host.isEmpty else { return nil }
            let port = parts.count > 1 ? UInt16(parts[1]) ?? 2375 : 2375
            return DockerEndpoint(transport: .tcp(host: String(host), port: port), url: value, label: label)
        }
        // A bare path is what someone types when they mean a socket file.
        if value.hasPrefix("/") {
            return DockerEndpoint(transport: .unix(path: value), url: "unix://" + value, label: label)
        }
        return nil
    }

    /// Whether the endpoint is there at all, without connecting.
    ///
    /// Used to decide whether to publish a drive chip at load time, which happens before any
    /// window exists and must not block on a socket that may be dead.
    var looksReachable: Bool {
        switch transport {
        case .unix(let path): return FileManager.default.fileExists(atPath: path)
        case .tcp: return true
        }
    }
}

/// Finds the engines this Mac can talk to, in the order a `docker` command would.
enum DockerDiscovery {

    /// Every endpoint worth offering, most likely first, without duplicates.
    static func candidates(environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: String = NSHomeDirectory()) -> [DockerEndpoint] {
        var found: [DockerEndpoint] = []
        var seen = Set<String>()
        func add(_ endpoint: DockerEndpoint?) {
            guard let endpoint, !seen.contains(endpoint.url) else { return }
            seen.insert(endpoint.url)
            found.append(endpoint)
        }

        // DOCKER_HOST wins, as it does for the CLI: someone who exported it means it.
        if let value = environment["DOCKER_HOST"], !value.isEmpty {
            add(DockerEndpoint.parse(value, label: "DOCKER_HOST"))
        }
        add(currentContextEndpoint(home: home))
        for candidate in wellKnownSockets(environment: environment, home: home) {
            if FileManager.default.fileExists(atPath: candidate.path) {
                add(DockerEndpoint(transport: .unix(path: candidate.path),
                                   url: "unix://" + candidate.path, label: candidate.label))
            }
        }
        return found
    }

    /// The first candidate that is actually present, or nil when Docker is not installed.
    static func preferred(environment: [String: String] = ProcessInfo.processInfo.environment,
                          home: String = NSHomeDirectory()) -> DockerEndpoint? {
        candidates(environment: environment, home: home).first(where: { $0.looksReachable })
    }

    private static func wellKnownSockets(environment: [String: String],
                                         home: String) -> [(path: String, label: String)] {
        var list: [(String, String)] = [
            (home + "/.docker/run/docker.sock", "Docker Desktop"),
            ("/var/run/docker.sock", "Docker"),
            (home + "/.colima/default/docker.sock", "Colima"),
            (home + "/.rd/docker.sock", "Rancher Desktop"),
            (home + "/.lima/docker/sock/docker.sock", "Lima"),
        ]
        // Podman serves the same API on its own socket, which is why this plugin is a
        // *container* provider rather than a Docker one: nothing below this file knows the
        // difference, so Podman costs one entry here instead of a second implementation.
        if let runtime = environment["XDG_RUNTIME_DIR"], !runtime.isEmpty {
            list.append((runtime + "/podman/podman.sock", "Podman"))
        }
        list.append((home + "/.local/share/containers/podman/machine/podman.sock", "Podman"))
        list.append(("/run/podman/podman.sock", "Podman"))
        return list.map { (path: $0.0, label: $0.1) }
    }

    /// The endpoint of the `docker context` that is currently selected.
    ///
    /// Read by scanning the context metadata for the one whose `Name` matches, rather than by
    /// hashing the name into the directory it lives in — the directory is `sha256(name)`, and a
    /// scan of a handful of small files needs no crypto and cannot drift if Docker ever changes
    /// the digest.
    static func currentContextEndpoint(home: String) -> DockerEndpoint? {
        let configPath = home + "/.docker/config.json"
        guard let data = FileManager.default.contents(atPath: configPath),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let current = root["currentContext"] as? String, !current.isEmpty,
              current != "default" else { return nil }
        let metaRoot = home + "/.docker/contexts/meta"
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: metaRoot) else { return nil }
        for dir in dirs.sorted() {
            let path = metaRoot + "/" + dir + "/meta.json"
            guard let data = FileManager.default.contents(atPath: path),
                  let meta = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  meta["Name"] as? String == current,
                  let endpoints = meta["Endpoints"] as? [String: Any],
                  let docker = endpoints["docker"] as? [String: Any],
                  let host = docker["Host"] as? String else { continue }
            return DockerEndpoint.parse(host, label: current)
        }
        return nil
    }
}

// MARK: - Errors

enum DockerError: Error {
    /// The socket could not be reached, or died mid-request. The mount is over.
    case unreachable(String)
    /// The engine answered, with this status and (where it sent one) its own message.
    case http(status: Int, message: String)
    /// The engine answered something this client cannot read.
    case malformed(String)
    /// The user stopped the transfer. Carried as an error because that is how a write in progress
    /// unwinds, and mapped to `PC_E_EABORTED` so the host reads it as a cancellation.
    case cancelled

    /// The engine's own sentence, when it sent one — worth showing, because Docker's messages
    /// name the thing that is wrong ("container … is not running", "read-only file system").
    var engineMessage: String? {
        if case .http(_, let message) = self, !message.isEmpty { return message }
        return nil
    }
}

// MARK: - The client

/// One connection to one engine.
///
/// Not thread-safe, and does not need to be: the host serialises every call on a mount, and the
/// only other user is the mount's own teardown, which runs after the last call has returned.
final class DockerClient {
    let endpoint: DockerEndpoint

    /// The API version prefix, e.g. "/v1.51" — empty when the daemon did not answer the ping,
    /// which the engine reads as "the newest version I speak".
    private(set) var versionPrefix = ""
    /// What the daemon called itself, for the connection title and for Inspect.
    private(set) var serverVersion = ""

    /// The last failure worth reporting to the host through `PfxLastError`.
    var lastError: Int32 = 0

    private var socket: Socket?
    private let timeout: TimeInterval

    init(endpoint: DockerEndpoint, timeout: TimeInterval = 60) {
        self.endpoint = endpoint
        self.timeout = timeout
    }

    deinit { socket?.close() }

    func close() {
        socket?.close()
        socket = nil
    }

    // MARK: Handshake

    /// Ask the daemon who it is. Throws when there is nothing there — which is how a connect
    /// attempt to a stopped engine fails early instead of at the first listing.
    func handshake() throws {
        let response = try send(method: "HEAD", path: "/_ping", versioned: false)
        guard response.status == 200 else {
            throw DockerError.http(status: response.status, message: response.message)
        }
        if let version = response.headers["api-version"], !version.isEmpty {
            versionPrefix = "/v" + version
        }
        serverVersion = response.headers["server"] ?? ""
    }

    // MARK: Requests

    struct Response {
        let status: Int
        let headers: [String: String]
        let body: Data

        /// The engine's `{"message": …}`, or "".
        var message: String {
            guard !body.isEmpty,
                  let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
                  let text = object["message"] as? String else { return "" }
            return text
        }
    }

    /// A request body. A file upload is a tar whose middle is the file itself, and a file can be
    /// larger than this machine's memory — so a body is something that knows how to *write*
    /// itself and how long it will be, not a `Data` that has to exist first.
    struct RequestBody {
        let length: Int
        let write: (Socket) throws -> Void

        static let empty = RequestBody(length: 0) { _ in }

        static func data(_ value: Data) -> RequestBody {
            RequestBody(length: value.count) { socket in
                if !value.isEmpty { try socket.write(value) }
            }
        }

        /// `head`, then `path`'s first `size` bytes, then `tail` — the shape of a one-file tar.
        /// `onProgress` is handed the number of file bytes sent so far and returns false to abort.
        static func tarredFile(head: Data, path: String, size: Int64, tail: Data,
                               onProgress: @escaping (Int64) -> Bool) -> RequestBody {
            RequestBody(length: head.count + Int(size) + tail.count) { socket in
                try socket.write(head)
                guard let handle = FileHandle(forReadingAtPath: path) else {
                    throw DockerError.malformed("cannot read \(path)")
                }
                defer { try? handle.close() }
                var sent: Int64 = 0
                while sent < size {
                    let want = Int(min(Int64(1 << 20), size - sent))
                    var chunk = handle.readData(ofLength: want)
                    // A file that shrank under us still has to fill the length the header
                    // promised, or the engine reads the tar's trailer as file content.
                    if chunk.count < want { chunk.append(Data(repeating: 0, count: want - chunk.count)) }
                    try socket.write(chunk)
                    sent += Int64(want)
                    // Its own error rather than `malformed`, which the host renders as a data
                    // fault: stopping a copy is not the copy having been corrupt.
                    if !onProgress(sent) { throw DockerError.cancelled }
                }
                try socket.write(tail)
            }
        }
    }

    /// A request whose whole answer is collected — for JSON, and for nothing else.
    @discardableResult
    func send(method: String, path: String, query: [String: String] = [:],
              body: Data? = nil, contentType: String? = nil,
              versioned: Bool = true) throws -> Response {
        try send(method: method, path: path, query: query,
                 body: body.map(RequestBody.data) ?? .empty,
                 contentType: contentType, versioned: versioned)
    }

    @discardableResult
    func send(method: String, path: String, query: [String: String] = [:],
              body: RequestBody, contentType: String? = nil,
              versioned: Bool = true) throws -> Response {
        var collected = Data()
        let (status, headers) = try stream(method: method, path: path, query: query, body: body,
                                           contentType: contentType, versioned: versioned) { chunk in
            collected.append(contentsOf: chunk)
            return true
        }
        return Response(status: status, headers: headers, body: collected)
    }

    /// A request whose body is handed over in pieces as it arrives.
    ///
    /// `onChunk` returns false to stop early; the connection is then dropped rather than drained,
    /// because draining a container's root filesystem to be polite would cost exactly what
    /// stopping early was for.
    @discardableResult
    func stream(method: String, path: String, query: [String: String] = [:],
                body: Data? = nil, contentType: String? = nil, versioned: Bool = true,
                onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> (Int, [String: String]) {
        try stream(method: method, path: path, query: query,
                   body: body.map(RequestBody.data) ?? .empty,
                   contentType: contentType, versioned: versioned, onChunk: onChunk)
    }

    @discardableResult
    func stream(method: String, path: String, query: [String: String] = [:],
                body: RequestBody, contentType: String? = nil, versioned: Bool = true,
                onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> (Int, [String: String]) {
        let request = buildRequest(method: method, path: path, query: query,
                                   length: body.length, contentType: contentType,
                                   versioned: versioned)
        // Whether this call is about to reuse a connection that has been sitting idle. Only then
        // is a retry right: a kept-alive socket the daemon has since closed fails on the write,
        // which is indistinguishable from the daemon being gone until a second attempt says which
        // it was — but a *fresh* socket that fails means the engine really is unreachable, and
        // retrying that only doubles the wait before the user is told.
        let reusing = socket != nil
        // Whether any of the answer has already reached the caller. A retry that re-sends the
        // request also re-delivers the body from the beginning — into a consumer that is mid-state.
        // For a download that means the tar scanner is half-way through an entry and the file on
        // disk already holds what arrived before the drop: the second attempt appends a fresh
        // stream to it, and the result is a file that is neither. A connection that dies *mid-body*
        // is not retryable; only one that dies before answering is.
        var delivered = false
        do {
            return try perform(request, method: method, body: body,
                               delivered: &delivered, onChunk: onChunk)
        } catch DockerError.unreachable where reusing && !delivered {
            close()
            return try perform(request, method: method, body: body,
                               delivered: &delivered, onChunk: onChunk)
        }
    }

    private func perform(_ request: Data, method: String, body: RequestBody,
                         delivered: inout Bool,
                         onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> (Int, [String: String]) {
        // Any way out of here but the last line leaves a connection with an unread answer still in
        // it, and the next request would read the tail of this one as its own response head. The
        // socket is therefore dropped on every error path rather than on the ones that were thought
        // of: a scanner that throws, a malformed chunk size, a body that ends early.
        var completed = false
        defer { if !completed { close() } }
        let socket = try connectedSocket()
        try socket.write(request)
        try body.write(socket)

        let head = try socket.readHead()
        let (status, headers) = try Self.parseHead(head)
        // A response the connection cannot be reused after: read to EOF and drop the socket.
        let closeAfter = (headers["connection"] ?? "").lowercased().contains("close")

        var keepReading = true
        let report: (UnsafeRawBufferPointer) throws -> Bool = { chunk in
            delivered = true
            return try onChunk(chunk)
        }
        // A response to HEAD has no body, whatever its headers say — and Docker's headers say
        // plenty: `HEAD …/archive` answers with the Content-Length a GET would have had. Reading
        // that many bytes waits for a body the daemon is never going to send, which is a hang per
        // stat rather than a wrong answer. Every `PfxStat` in this plugin goes through a HEAD.
        let hasBody = method != "HEAD" && status != 204 && status != 304 && !(100..<200).contains(status)
        if !hasBody {
            // nothing to read
        } else if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            keepReading = try socket.readChunked(report)
        } else if let lengthText = headers["content-length"], let length = Int(lengthText) {
            keepReading = try socket.readFixed(length, report)
        } else {
            keepReading = try socket.readToEOF(report)
            self.socket = nil   // no framing: the body ended because the connection did
        }
        if closeAfter || !keepReading { close() }
        completed = true
        return (status, headers)
    }

    /// The same as `send`, but a non-2xx answer throws instead of being returned — which is what
    /// every caller that is not probing wants.
    @discardableResult
    func expect(method: String, path: String, query: [String: String] = [:],
                body: Data? = nil, contentType: String? = nil) throws -> Data {
        let response = try send(method: method, path: path, query: query,
                                body: body, contentType: contentType)
        guard (200..<300).contains(response.status) else {
            throw DockerError.http(status: response.status, message: response.message)
        }
        return response.body
    }

    /// A JSON request whose answer is decoded into Foundation objects.
    func json(method: String = "GET", path: String, query: [String: String] = [:],
              body: [String: Any]? = nil) throws -> Any {
        var encoded: Data?
        if let body { encoded = try JSONSerialization.data(withJSONObject: body) }
        let data = try expect(method: method, path: path, query: query,
                              body: encoded, contentType: encoded == nil ? nil : "application/json")
        guard !data.isEmpty else { return [String: Any]() }
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            throw DockerError.malformed("the engine did not answer with JSON")
        }
        return object
    }

    // MARK: Building & parsing

    private func buildRequest(method: String, path: String, query: [String: String],
                              length: Int, contentType: String?, versioned: Bool) -> Data {
        var target = (versioned ? versionPrefix : "") + path
        if !query.isEmpty {
            // Sorted so a request is reproducible — which matters for the tests, and costs
            // nothing here.
            let items = query.keys.sorted().map { key in
                Self.percentEncode(key) + "=" + Self.percentEncode(query[key]!)
            }
            target += "?" + items.joined(separator: "&")
        }
        var text = "\(method) \(target) HTTP/1.1\r\n"
        text += "Host: docker\r\n"
        text += "User-Agent: PeachCommander-Docker/1\r\n"
        text += "Accept: */*\r\n"
        if let contentType { text += "Content-Type: \(contentType)\r\n" }
        text += "Content-Length: \(length)\r\n"
        text += "\r\n"
        return Data(text.utf8)
    }

    /// Percent-encode for a query value. Deliberately strict — `/` and `+` in a container path
    /// must not survive as themselves, and `CharacterSet.urlQueryAllowed` lets both through.
    static func percentEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func parseHead(_ head: Data) throws -> (Int, [String: String]) {
        guard let text = String(data: head, encoding: .utf8) else {
            throw DockerError.malformed("unreadable response header")
        }
        var lines = text.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else { throw DockerError.malformed("empty response") }
        let statusParts = statusLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: false)
        guard statusParts.count >= 2, let status = Int(statusParts[1]) else {
            throw DockerError.malformed("bad status line")
        }
        lines.removeFirst()
        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[line.startIndex..<colon].lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }
        return (status, headers)
    }

    // MARK: Socket

    private func connectedSocket() throws -> Socket {
        if let socket { return socket }
        let made = try Socket(endpoint: endpoint, timeout: timeout)
        socket = made
        return made
    }

    /// A blocking stream socket with an HTTP-shaped reader on top.
    final class Socket {
        private var fd: Int32 = -1
        private var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        private var start = 0
        private var end = 0

        init(endpoint: DockerEndpoint, timeout: TimeInterval) throws {
            switch endpoint.transport {
            case .unix(let path): try openUnix(path: path, timeout: timeout)
            case .tcp(let host, let port): try openTCP(host: host, port: port, timeout: timeout)
            }
        }

        deinit { close() }

        func close() {
            if fd >= 0 { _ = Darwin.close(fd) }
            fd = -1
        }

        private func configure(timeout: TimeInterval) {
            var on: Int32 = 1
            // Without this a daemon that hangs up mid-write kills the whole application with
            // SIGPIPE rather than returning EPIPE to this one call.
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        }

        private func openUnix(path: String, timeout: TimeInterval) throws {
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let capacity = MemoryLayout.size(ofValue: address.sun_path)
            let bytes = Array(path.utf8)
            guard bytes.count < capacity else {
                throw DockerError.unreachable("the socket path is too long: \(path)")
            }
            withUnsafeMutableBytes(of: &address.sun_path) { raw in
                raw.copyBytes(from: bytes)
                raw[bytes.count] = 0
            }
            address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

            fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw DockerError.unreachable("no socket: \(errnoText())") }
            configure(timeout: timeout)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
                    Darwin.connect(fd, generic, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard result == 0 else {
                close()
                throw DockerError.unreachable(errnoText())
            }
        }

        private func openTCP(host: String, port: UInt16, timeout: TimeInterval) throws {
            var hints = addrinfo(ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
                                 ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil,
                                 ai_addr: nil, ai_next: nil)
            var list: UnsafeMutablePointer<addrinfo>?
            let code = getaddrinfo(host, String(port), &hints, &list)
            guard code == 0, let head = list else {
                throw DockerError.unreachable("cannot resolve \(host)")
            }
            defer { freeaddrinfo(head) }
            var current: UnsafeMutablePointer<addrinfo>? = head
            while let info = current {
                fd = Darwin.socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)
                if fd >= 0 {
                    configure(timeout: timeout)
                    if Darwin.connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 { return }
                    close()
                }
                current = info.pointee.ai_next
            }
            throw DockerError.unreachable("cannot connect to \(host):\(port)")
        }

        private func errnoText() -> String { String(cString: strerror(errno)) }

        func write(_ data: Data) throws {
            try data.withUnsafeBytes { raw in
                var offset = 0
                while offset < raw.count {
                    let written = Darwin.write(fd, raw.baseAddress!.advanced(by: offset), raw.count - offset)
                    if written > 0 { offset += written; continue }
                    if written < 0 && errno == EINTR { continue }
                    throw DockerError.unreachable(errnoText())
                }
            }
        }

        /// Refill the buffer. Returns false at end of stream.
        private func fill() throws -> Bool {
            if start > 0 {
                if start < end { buffer.replaceSubrange(0..<(end - start), with: buffer[start..<end]) }
                end -= start
                start = 0
            }
            if end == buffer.count { buffer.append(contentsOf: [UInt8](repeating: 0, count: buffer.count)) }
            let read: Int = buffer.withUnsafeMutableBytes { raw in
                Darwin.read(fd, raw.baseAddress!.advanced(by: end), raw.count - end)
            }
            if read > 0 { end += read; return true }
            if read == 0 { return false }
            if errno == EINTR { return try fill() }
            throw DockerError.unreachable(errnoText())
        }

        /// Everything up to and including the blank line that ends the headers.
        func readHead() throws -> Data {
            var searched = 0
            while true {
                if end - start >= 4 {
                    var index = start + max(0, searched - 3)
                    while index + 3 < end {
                        if buffer[index] == 13, buffer[index + 1] == 10,
                           buffer[index + 2] == 13, buffer[index + 3] == 10 {
                            let head = Data(buffer[start..<index])
                            start = index + 4
                            return head
                        }
                        index += 1
                    }
                    searched = end - start
                }
                guard try fill() else { throw DockerError.unreachable("the engine closed the connection") }
            }
        }

        /// Hand out `length` bytes. Returns false when the consumer asked to stop.
        func readFixed(_ length: Int, _ onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> Bool {
            var remaining = length
            while remaining > 0 {
                if start == end {
                    guard try fill() else { throw DockerError.unreachable("truncated response body") }
                }
                let take = min(remaining, end - start)
                let keepGoing = try buffer.withUnsafeBytes { raw -> Bool in
                    try onChunk(UnsafeRawBufferPointer(rebasing: raw[start..<(start + take)]))
                }
                start += take
                remaining -= take
                if !keepGoing { return false }
            }
            return true
        }

        func readToEOF(_ onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> Bool {
            while true {
                if start == end {
                    guard try fill() else { return true }
                }
                let keepGoing = try buffer.withUnsafeBytes { raw -> Bool in
                    try onChunk(UnsafeRawBufferPointer(rebasing: raw[start..<end]))
                }
                start = end
                if !keepGoing { return false }
            }
        }

        func readChunked(_ onChunk: (UnsafeRawBufferPointer) throws -> Bool) throws -> Bool {
            while true {
                let sizeLine = try readLine()
                let sizeText = sizeLine.split(separator: ";").first.map(String.init) ?? sizeLine
                guard let size = Int(sizeText.trimmingCharacters(in: .whitespaces), radix: 16) else {
                    throw DockerError.malformed("bad chunk size")
                }
                if size == 0 {
                    while !(try readLine()).isEmpty {}   // trailers
                    return true
                }
                if try !readFixed(size, onChunk) { return false }
                _ = try readLine()   // the CRLF after the chunk
            }
        }

        private func readLine() throws -> String {
            var bytes: [UInt8] = []
            while true {
                if start == end {
                    guard try fill() else { throw DockerError.unreachable("truncated chunked body") }
                }
                let byte = buffer[start]
                start += 1
                if byte == 10 {
                    if bytes.last == 13 { bytes.removeLast() }
                    return String(decoding: bytes, as: UTF8.self)
                }
                bytes.append(byte)
            }
        }
    }
}
