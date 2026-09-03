// SPDX-License-Identifier: Apache-2.0
// StringScanJob.swift - Runs `BinaryStrings` over a whole file (or a whole editor buffer)
// without blocking the window (F-489).
//
// The scanner is a pure function of a byte array; everything that makes running it over a
// real file awkward lives here:
//
//   * **Chunking.** A 2 GB disk image must not be read into memory to be scanned. Windows
//     of a megabyte are read one at a time, and each window is extended past its end by the
//     longest a single finding can be — otherwise a string that straddles a window boundary
//     would come back cut in half. Only findings that *start* inside the window's own
//     megabyte are kept, which is what stops the overlap from reporting them twice.
//   * **Cancellation.** Typing in the length field re-scans; the answer to the previous
//     question must not arrive afterwards and overwrite the answer to this one. The running
//     scan holds a token that the next `start` invalidates, and the token — not the job —
//     is what the background thread is allowed to touch.
//   * **A ceiling.** A file that is nothing but text has a finding every few bytes, and a
//     table with eleven million rows in it helps nobody. The scan stops at the cap and says
//     so, rather than pretending the list is complete.
//
// Reading is `pread` on a plain descriptor rather than the viewer's `FileSlice`: that one is
// documented main-thread-only, and this work is the whole reason there is a background
// thread here at all.

import Foundation
import PCFoundation

/// A cancellable, chunked strings scan whose results arrive on the main thread.
@MainActor
final class StringScanJob {

    /// What to scan. The viewer has a path; the hex editor has an edited buffer that is not
    /// on disk in that form and must be scanned as it stands.
    enum Source: Sendable {
        case file(String)
        case bytes([UInt8])
    }

    /// The one piece of state the background thread may read. Everything else on this class
    /// is main-actor isolated, which is what keeps a scan from racing the panel that owns it.
    private final class Token: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }
        func cancel() {
            lock.lock(); cancelled = true; lock.unlock()
        }
    }

    /// Bytes per window. Big enough that the per-window overhead disappears, small enough
    /// that progress moves and a cancel is noticed promptly.
    private static let step = 1 << 20
    /// Findings past this are not collected; the scan stops and reports itself truncated.
    static let maximumResults = 200_000

    private let queue = DispatchQueue(label: "com.peachcommander.strings", qos: .utility)
    private var token: Token?

    /// Whether a scan is in flight (the panel shows it).
    private(set) var isRunning = false

    /// Start a scan, replacing any scan already running.
    ///
    /// `onProgress` is called with a 0…1 fraction as windows complete; `onFinished` receives
    /// the findings in file order and whether the cap cut them short.
    func start(_ source: Source,
               options: StringScanOptions,
               onProgress: @escaping @MainActor (Double) -> Void,
               onFinished: @escaping @MainActor ([FoundString], Bool) -> Void) {
        cancel()
        let token = Token()
        self.token = token
        isRunning = true
        let step = Self.step
        let cap = Self.maximumResults
        let overlap = min(options.maximumByteLength, step)

        queue.async {
            var found: [FoundString] = []
            var truncated = false

            func report(_ fraction: Double) {
                DispatchQueue.main.async {
                    guard !token.isCancelled else { return }
                    MainActor.assumeIsolated { onProgress(fraction) }
                }
            }

            switch source {
            case .bytes(let bytes):
                // Already in memory and bounded by what the hex editor will open: one pass.
                found = BinaryStrings.scan(bytes, options: options)
                if found.count > cap {
                    found.removeSubrange(cap...)
                    truncated = true
                }
                report(1)

            case .file(let path):
                let fd = path.withCString { open($0, O_RDONLY) }
                if fd >= 0 {
                    defer { close(fd) }
                    var info = stat()
                    let total = fstat(fd, &info) == 0 ? Int64(info.st_size) : 0
                    var windowStart: Int64 = 0
                    var buffer = [UInt8](repeating: 0, count: step + overlap)

                    while windowStart < total, !token.isCancelled {
                        let wanted = Int(min(Int64(step + overlap), total - windowStart))
                        let read = buffer.withUnsafeMutableBytes { raw -> Int in
                            pread(fd, raw.baseAddress, wanted, off_t(windowStart))
                        }
                        guard read > 0 else { break }
                        // Findings starting past the window's own megabyte belong to the next
                        // window; the tail was read only so that a string crossing the seam
                        // is decoded whole rather than cut at it.
                        let limit = windowStart + Int64(step)
                        let window = Array(buffer[0..<read])
                        for hit in BinaryStrings.scan(window, baseOffset: windowStart, options: options)
                        where hit.offset < limit {
                            found.append(hit)
                        }
                        if found.count > cap {
                            found.removeSubrange(cap...)
                            truncated = true
                            break
                        }
                        windowStart += Int64(step)
                        report(total > 0 ? min(1, Double(windowStart) / Double(total)) : 1)
                    }
                }
            }

            let result = found
            let wasTruncated = truncated
            DispatchQueue.main.async {
                guard !token.isCancelled else { return }
                MainActor.assumeIsolated {
                    onFinished(result, wasTruncated)
                }
            }
        }
    }

    /// Abandon whatever is running. Nothing further is delivered.
    func cancel() {
        token?.cancel()
        token = nil
        isRunning = false
    }

    /// Called on the main thread once a delivered `onFinished` has been handled, so the panel
    /// and the job agree that nothing is in flight.
    func markFinished() { isRunning = false }
}
