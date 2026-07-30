import XCTest
import Network
@testable import PCNet

/// A tiny in-process TCP server that speaks just enough FTP to exercise the live
/// NWFTPControlTransport over a real loopback socket: it sends a greeting, then
/// replies to each received command line from a scripted map. Opt-in (sockets),
/// so the default test run stays deterministic.
private final class LoopbackFTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "pcnet.test.server")
    private let greeting: String
    private let replies: [String: String]   // command verb → reply line
    private var conn: NWConnection?
    private(set) var port: UInt16 = 0

    init(greeting: String, replies: [String: String]) throws {
        self.greeting = greeting
        self.replies = replies
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce()
            listener.stateUpdateHandler = { [weak self] state in
                if case .ready = state, let self, let p = self.listener.port {
                    self.port = p.rawValue
                    if once.fire() { cont.resume() }
                }
            }
            listener.newConnectionHandler = { [weak self] c in self?.serve(c) }
            listener.start(queue: queue)
        }
    }

    private func serve(_ c: NWConnection) {
        conn = c
        c.start(queue: queue)
        send(c, greeting)
        receiveLoop(c)
    }

    private func send(_ c: NWConnection, _ line: String) {
        c.send(content: Data((line + "\r\n").utf8), completion: .contentProcessed { _ in })
    }

    private func receiveLoop(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, _ in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                for raw in text.split(separator: "\r\n") {
                    let verb = raw.split(separator: " ").first.map(String.init)?.uppercased() ?? ""
                    self.send(c, self.replies[verb] ?? "500 unknown")
                }
            }
            if !isComplete { self.receiveLoop(c) }
        }
    }

    func stop() { conn?.cancel(); listener.cancel() }
}

final class FTPLoopbackTests: XCTestCase {
    func testLiveControlRoundTripOverLoopback() async throws {
        guard ProcessInfo.processInfo.environment["PC_FTP_LOOPBACK"] != nil else {
            throw XCTSkip("Set PC_FTP_LOOPBACK=1 to run the live loopback socket test.")
        }
        let server = try LoopbackFTPServer(greeting: "220 loopback ready", replies: [
            "USER": "331 need password",
            "PASS": "230 login ok",
            "TYPE": "200 type set",
            "PWD": "257 \"/home/test\" is current directory",
            "QUIT": "221 bye"
        ])
        await server.start()
        defer { server.stop() }

        let transport = NWFTPControlTransport(host: "127.0.0.1", port: Int(server.port))
        let conn = FTPControlConnection(transport: transport, controlHost: "127.0.0.1")
        try await conn.connectAndLogin(user: "alice", password: "secret")
        let cwd = try await conn.printWorkingDirectory()
        XCTAssertEqual(cwd, "/home/test")
        await conn.quit()
    }
}
