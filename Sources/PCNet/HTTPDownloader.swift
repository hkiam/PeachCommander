// SPDX-License-Identifier: Apache-2.0
// HTTPDownloader.swift - wget-style HTTP(S) file download with resume (F-330).
//
// Streams a URL to a file on disk (constant memory) via URLSession, resuming a
// partial ".part" file with a Range request when possible. Supports HTTP + HTTPS
// (with an opt-in self-signed override), Basic auth, a Bearer token, and custom
// headers. Progress + cooperative pause/cancel are reported through closures so
// the caller can drive the transfer manager's UI and OperationControl.

import Foundation
import PCFoundation

public struct HTTPDownloadOptions: Sendable {
    public var username: String?
    public var password: String?
    public var bearerToken: String?
    public var extraHeaders: [String: String]
    public var allowInsecureTLS: Bool
    public var timeout: TimeInterval
    /// Route the request through an HTTP or SOCKS5 proxy (F-330).
    public var proxy: ProxyConfig?

    public init(username: String? = nil, password: String? = nil, bearerToken: String? = nil,
                extraHeaders: [String: String] = [:], allowInsecureTLS: Bool = false,
                timeout: TimeInterval = 60, proxy: ProxyConfig? = nil) {
        self.username = username
        self.password = password
        self.bearerToken = bearerToken
        self.extraHeaders = extraHeaders
        self.allowInsecureTLS = allowInsecureTLS
        self.timeout = timeout
        self.proxy = proxy
    }
}

public enum HTTPDownloadError: Error, Equatable, Sendable {
    case invalidURL
    case httpStatus(Int)
    case io(String)
}

public struct HTTPDownloadResult: Sendable {
    /// Final on-disk path (the ".part" renamed on success).
    public let path: String
    public let bytes: Int64
    /// True when the transfer picked up from an existing partial file.
    public let resumed: Bool
    /// The server-suggested filename from Content-Disposition, if any.
    public let suggestedName: String?
}

public final class HTTPDownloader: Sendable {
    public init() {}

    /// Download `urlString` to `destinationPath`, resuming from a sibling ".part"
    /// file when the server supports Range. Streams to disk. `progress(done,total)`
    /// reports bytes (total <= 0 = unknown length). `checkpoint` is awaited between
    /// chunks so the caller can pause/cancel (throw to abort — the ".part" is kept
    /// so a later call resumes).
    public func download(urlString: String, to destinationPath: String,
                         options: HTTPDownloadOptions = HTTPDownloadOptions(),
                         progress: @Sendable (Int64, Int64) -> Void = { _, _ in },
                         checkpoint: @Sendable () async throws -> Void = {}) async throws -> HTTPDownloadResult {
        guard let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" else {
            throw HTTPDownloadError.invalidURL
        }
        let fm = FileManager.default
        let partPath = destinationPath + ".part"
        var existing = (try? fm.attributesOfItem(atPath: partPath)[.size] as? Int64) ?? nil ?? 0
        if existing < 0 { existing = 0 }

        var request = URLRequest(url: url, timeoutInterval: options.timeout)
        request.httpMethod = "GET"
        if let user = options.username {
            let creds = "\(user):\(options.password ?? "")"
            let b64 = Data(creds.utf8).base64EncodedString()
            request.setValue("Basic \(b64)", forHTTPHeaderField: "Authorization")
        } else if let token = options.bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in options.extraHeaders { request.setValue(v, forHTTPHeaderField: k) }
        if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }

        let sink = ChunkSink(allowInsecureTLS: options.allowInsecureTLS)
        let configuration = URLSessionConfiguration.ephemeral
        if let proxy = options.proxy {                     // route via HTTP/SOCKS5 proxy (F-330)
            configuration.connectionProxyDictionary = proxy.urlSessionProxyDictionary
        }
        let session = URLSession(configuration: configuration, delegate: sink, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: request)
        task.resume()

        // Await the response headers (throws if the connection fails first).
        let response = try await sink.awaitResponse()
        let status = response.statusCode
        let suggested = (response.value(forHTTPHeaderField: "Content-Disposition"))
            .flatMap { DownloadName.filename(fromContentDisposition: $0) }

        // 416: the requested range is past EOF → the file is already complete.
        if status == 416, existing > 0 {
            task.cancel()
            try? fm.removeItem(atPath: destinationPath)
            try fm.moveItem(atPath: partPath, toPath: destinationPath)
            return HTTPDownloadResult(path: destinationPath, bytes: existing, resumed: true, suggestedName: suggested)
        }
        guard (200...299).contains(status) else {
            task.cancel()
            throw HTTPDownloadError.httpStatus(status)
        }

        // 206 => resume (append); 200 => server ignored Range, restart from zero.
        let resuming = (status == 206 && existing > 0)
        var written: Int64 = resuming ? existing : 0
        let total: Int64 = {
            let len = response.expectedContentLength
            guard len > 0 else { return -1 }
            return resuming ? existing + len : len
        }()

        if !resuming { fm.createFile(atPath: partPath, contents: nil) }
        guard let handle = FileHandle(forWritingAtPath: partPath) else {
            task.cancel()
            throw HTTPDownloadError.io("cannot open \(partPath)")
        }
        if resuming { try? handle.seekToEnd() } else { try? handle.truncate(atOffset: 0) }
        defer { try? handle.close() }

        progress(written, total)
        do {
            for try await chunk in sink.stream {
                try await checkpoint()            // pause/cancel between chunks (keeps .part)
                try handle.write(contentsOf: chunk)
                written += Int64(chunk.count)
                progress(written, total)
            }
        } catch {
            task.cancel()
            throw error                            // .part remains on disk for a later resume
        }
        try? handle.close()

        // Success: replace any existing destination with the completed download.
        try? fm.removeItem(atPath: destinationPath)
        try fm.moveItem(atPath: partPath, toPath: destinationPath)
        return HTTPDownloadResult(path: destinationPath, bytes: written, resumed: resuming, suggestedName: suggested)
    }
}

/// URLSession data delegate that streams chunks into an AsyncThrowingStream and
/// exposes the response headers, with an opt-in self-signed TLS override.
private final class ChunkSink: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let stream: AsyncThrowingStream<Data, Error>
    private let allowInsecureTLS: Bool
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation!
    private var responseCont: CheckedContinuation<HTTPURLResponse, Error>?
    private var responseDelivered = false
    private var earlyError: Error?

    init(allowInsecureTLS: Bool) {
        self.allowInsecureTLS = allowInsecureTLS
        var cont: AsyncThrowingStream<Data, Error>.Continuation!
        self.stream = AsyncThrowingStream { cont = $0 }
        super.init()
        self.continuation = cont
    }

    /// The HTTP response headers, once received (throws if the task fails first).
    func awaitResponse() async throws -> HTTPURLResponse {
        try await withCheckedThrowingContinuation { cont in
            lock.lock()
            if responseDelivered { lock.unlock(); return }   // already handled
            if let err = earlyError { earlyError = nil; lock.unlock(); cont.resume(throwing: err); return }
            responseCont = cont
            lock.unlock()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            lock.lock()
            responseDelivered = true
            let cont = responseCont; responseCont = nil
            lock.unlock()
            cont?.resume(returning: http)
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        continuation.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            // Fail a pending response wait, else fail the stream.
            lock.lock()
            let cont = responseCont; responseCont = nil
            if cont == nil && !responseDelivered { earlyError = error }
            lock.unlock()
            if let cont { cont.resume(throwing: error) } else { continuation.finish(throwing: error) }
        } else {
            continuation.finish()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if allowInsecureTLS,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
