// HTTPDownloaderTests.swift - HTTP download + resume against a local server (F-330).
//
// Self-contained: starts a `python3 -m http.server` (Range-capable since 3.7) on a
// loopback port serving a temp file, and verifies a full download and a Range
// resume from a partial ".part". Skips if python3 is unavailable.

import XCTest
@testable import PCNet

final class HTTPDownloaderTests: XCTestCase {
    private var server: Process?
    private var socks: Process?
    private var socksLog: URL!
    private var socksPort = 0
    private var dir: URL!
    private var port = 0
    private var payload = Data()

    // A minimal HTTP proxy (absolute-URI GET forwarding); URLSession honors HTTP
    // proxies reliably (its SOCKS support via connectionProxyDictionary does not).
    private static let httpProxyScript = """
    import socket, threading, select, sys, urllib.parse
    def pipe(a,b):
        try:
            while True:
                r,_,_=select.select([a,b],[],[],30)
                if not r: break
                for s in r:
                    d=s.recv(65536)
                    if not d: return
                    (b if s is a else a).sendall(d)
        except Exception: pass
        finally:
            for s in (a,b):
                try: s.close()
                except Exception: pass
    def recvh(c):
        data=b""
        while b"\\r\\n\\r\\n" not in data:
            ch=c.recv(4096)
            if not ch: break
            data+=ch
        return data
    def handle(c):
        try:
            data=recvh(c)
            if not data: c.close(); return
            method,target,_=data.split(b"\\r\\n",1)[0].decode().split(" ")
            if method=="CONNECT":
                host,port=target.split(":"); port=int(port)
                print("CONNECT %s:%d"%(host,port),flush=True)
                up=socket.create_connection((host,port),timeout=10)
                c.sendall(b"HTTP/1.1 200 Connection Established\\r\\n\\r\\n"); pipe(c,up)
            else:
                u=urllib.parse.urlsplit(target); host=u.hostname; port=u.port or 80
                path=u.path+("?"+u.query if u.query else "")
                print("%s %s"%(method,target),flush=True)
                up=socket.create_connection((host,port),timeout=10)
                rest=data.split(b"\\r\\n",1)[1]
                up.sendall(("%s %s HTTP/1.1\\r\\n"%(method,path)).encode()+rest); pipe(c,up)
        except Exception:
            try: c.close()
            except Exception: pass
    srv=socket.socket(); srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    srv.bind(("127.0.0.1",int(sys.argv[1]))); srv.listen(50)
    print("ready", flush=True)
    while True:
        cc,_=srv.accept(); threading.Thread(target=handle,args=(cc,),daemon=True).start()
    """

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pc-http-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // ~400 KB of varied bytes → several chunks + a meaningful resume split.
        payload = Data((0..<400_000).map { UInt8(($0 &* 37 &+ 11) & 0xff) })
        try payload.write(to: dir.appendingPathComponent("file.bin"))

        guard let python = ["/usr/bin/python3", "/opt/homebrew/bin/python3"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw XCTSkip("python3 unavailable")
        }
        // A minimal Range-capable server (stdlib http.server ignores Range), so the
        // resume path can be exercised.
        let script = """
        import http.server, os, sys
        DIR = sys.argv[2]
        class H(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                # Echo a named request header back as the body (for header tests).
                if self.path.startswith('/echo-header/'):
                    name = self.path[len('/echo-header/'):]
                    body = (self.headers.get(name) or '').encode()
                    self.send_response(200); self.send_header('Content-Length', str(len(body)))
                    self.end_headers(); self.wfile.write(body); return
                path = os.path.join(DIR, self.path.lstrip('/').split('?')[0])
                if not os.path.isfile(path):
                    self.send_response(404); self.end_headers(); return
                size = os.path.getsize(path); start = 0
                rng = self.headers.get('Range')
                if rng and rng.startswith('bytes='):
                    try: start = int(rng[6:].split('-')[0])
                    except Exception: start = 0
                with open(path,'rb') as f:
                    f.seek(start); data = f.read()
                self.send_response(206 if start > 0 else 200)
                if start > 0: self.send_header('Content-Range', 'bytes %d-%d/%d' % (start, size-1, size))
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Accept-Ranges', 'bytes')
                self.end_headers(); self.wfile.write(data)
            def log_message(self, *a): pass
        http.server.HTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
        """
        let scriptURL = dir.appendingPathComponent("server.py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        // Try a few ports until one binds and answers.
        for candidate in [18723, 18845, 19012, 19137] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: python)
            p.arguments = [scriptURL.path, "\(candidate)", dir.path]
            p.standardOutput = Pipe(); p.standardError = Pipe()
            do { try p.run() } catch { continue }
            if waitUntilReachable(port: candidate, timeout: 3) { server = p; port = candidate; break }
            p.terminate()
        }
        if server == nil { throw XCTSkip("could not start test http server") }

        // A SOCKS5 proxy that logs each CONNECT target (for the proxy test).
        let socksURL = dir.appendingPathComponent("socks.py")
        try Self.httpProxyScript.write(to: socksURL, atomically: true, encoding: .utf8)
        socksLog = dir.appendingPathComponent("socks.log")
        FileManager.default.createFile(atPath: socksLog.path, contents: nil)
        for candidate in [11723, 11845, 12012, 12137] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: python)
            p.arguments = [socksURL.path, "\(candidate)"]
            p.standardOutput = try FileHandle(forWritingTo: socksLog)
            p.standardError = Pipe()
            do { try p.run() } catch { continue }
            if waitUntilReachable(port: candidate, timeout: 3) { socks = p; socksPort = candidate; break }
            p.terminate()
        }
    }

    override func tearDownWithError() throws {
        server?.terminate(); server = nil
        socks?.terminate(); socks = nil
        try? FileManager.default.removeItem(at: dir)
    }

    private func waitUntilReachable(port: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            defer { close(fd) }
            let ok = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            if ok == 0 { return true }
            usleep(100_000)
        }
        return false
    }

    func testFullDownload() async throws {
        let dest = dir.appendingPathComponent("out.bin").path
        let result = try await HTTPDownloader().download(urlString: "http://127.0.0.1:\(port)/file.bin", to: dest)
        XCTAssertFalse(result.resumed)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: dest)), payload, "download must byte-match")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest + ".part"), ".part must be renamed on success")
    }

    func testResumeFromPartial() async throws {
        let dest = dir.appendingPathComponent("resumed.bin").path
        // Pre-seed a ".part" with the first 150 KB, as if a prior download was interrupted.
        let head = payload.prefix(150_000)
        try Data(head).write(to: URL(fileURLWithPath: dest + ".part"))
        let result = try await HTTPDownloader().download(urlString: "http://127.0.0.1:\(port)/file.bin", to: dest)
        XCTAssertTrue(result.resumed, "should resume via Range from the .part file")
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: dest)), payload, "resumed file must byte-match")
    }

    func testCustomHeaderAndBasicAuthAreSent() async throws {
        // A custom header (Referer/Cookie are just headers) reaches the server.
        let dest = dir.appendingPathComponent("hdr.txt").path
        let opts = HTTPDownloadOptions(username: "alice", password: "secret",
                                       extraHeaders: ["Referer": "https://ref.test/page"])
        _ = try await HTTPDownloader().download(
            urlString: "http://127.0.0.1:\(port)/echo-header/Referer", to: dest, options: opts)
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: dest), encoding: .utf8), "https://ref.test/page")

        // Basic auth is sent as the expected header.
        let dest2 = dir.appendingPathComponent("auth.txt").path
        _ = try await HTTPDownloader().download(
            urlString: "http://127.0.0.1:\(port)/echo-header/Authorization", to: dest2, options: opts)
        let expected = "Basic " + Data("alice:secret".utf8).base64EncodedString()
        XCTAssertEqual(try String(contentsOf: URL(fileURLWithPath: dest2), encoding: .utf8), expected)
    }

    func testDownloadThroughHTTPProxy() async throws {
        try XCTSkipUnless(socks != nil, "HTTP proxy did not start")
        let dest = dir.appendingPathComponent("via-proxy.bin").path
        let opts = HTTPDownloadOptions(proxy: ProxyConfig(kind: .http, host: "127.0.0.1", port: socksPort))
        let result = try await HTTPDownloader().download(
            urlString: "http://127.0.0.1:\(port)/file.bin", to: dest, options: opts)
        XCTAssertEqual(result.bytes, Int64(payload.count))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: dest)), payload, "proxied download must byte-match")
        // Prove the request actually went through the proxy (it logged the forwarded GET).
        let log = (try? String(contentsOf: socksLog, encoding: .utf8)) ?? ""
        XCTAssertTrue(log.contains("http://127.0.0.1:\(port)/file.bin"),
                      "proxy should have forwarded the request; log: \(log)")
    }

    func test404IsReported() async throws {
        do {
            _ = try await HTTPDownloader().download(urlString: "http://127.0.0.1:\(port)/missing.bin",
                                                    to: dir.appendingPathComponent("x").path)
            XCTFail("expected a 404 error")
        } catch let HTTPDownloadError.httpStatus(code) {
            XCTAssertEqual(code, 404)
        }
    }
}
