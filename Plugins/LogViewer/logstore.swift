// SPDX-License-Identifier: Apache-2.0
// logstore.swift — memory-mapped, lazily-indexed backing store for the Log Viewer.
//
// Opens a log file with mmap (instant regardless of size) and builds a line-offset
// index on a background queue, publishing counts incrementally so the window can
// show rows as they are found. Only the lines currently on screen are decoded to
// String (in `line(_:)`), so memory stays bounded even for multi-GB logs. Supports
// extending the index when the file grows (live tail) by remapping.

import Foundation

/// Read-only POSIX memory map of a file. Remappable for a growing file (tail).
final class MappedFile {
    private(set) var ptr: UnsafePointer<UInt8>?
    private(set) var size: Int = 0
    private let fd: Int32
    private var base: UnsafeMutableRawPointer?

    init?(path: String) {
        fd = open(path, O_RDONLY)
        guard fd >= 0 else { return nil }
        remap()
        if size > 0 && base == nil { close(fd); return nil }
    }

    /// Re-read the current file size and (re)establish the mapping; returns the size.
    @discardableResult
    func remap() -> Int {
        var st = stat()
        guard fstat(fd, &st) == 0 else { return size }
        let newSize = Int(st.st_size)
        if let base, size > 0 { munmap(base, size); self.base = nil; self.ptr = nil }
        size = newSize
        guard newSize > 0 else { return 0 }
        let m = mmap(nil, newSize, PROT_READ, MAP_PRIVATE, fd, 0)
        if let m, m != MAP_FAILED {
            base = m
            ptr = UnsafeRawPointer(m).assumingMemoryBound(to: UInt8.self)
        }
        return newSize
    }

    deinit {
        if let base, size > 0 { munmap(base, size) }
        if fd >= 0 { close(fd) }
    }
}

/// Line-offset index + lazy line decode over a MappedFile. Main-thread facing:
/// `count`/`line(_:)`/`extend` are used from the UI; the initial scan runs on a
/// background queue and publishes offsets back on the main queue.
final class LogStore {
    private let file: MappedFile
    /// Byte offset where each line starts. Line i spans [starts[i], end(i)).
    private var starts: [Int] = [0]
    /// Bytes scanned so far (also the exclusive end of the last line).
    private var scannedEnd: Int = 0
    private let queue = DispatchQueue(label: "com.peachcommander.logviewer.index", qos: .userInitiated)

    /// Called on the main thread as the index grows (new total line count).
    var onProgress: ((Int) -> Void)?

    init?(path: String) {
        guard let f = MappedFile(path: path) else { return nil }
        file = f
    }

    /// Number of displayable lines. `starts` records the offset after every '\n',
    /// so a file ending in '\n' leaves a trailing offset == scannedEnd — an empty
    /// "phantom" line that is excluded here but promoted to a real line the moment
    /// growth (tail) appends bytes after it.
    var count: Int {
        if starts.count == 1 { return scannedEnd == 0 ? 0 : 1 }
        return starts.last == scannedEnd ? starts.count - 1 : starts.count
    }
    var byteSize: Int { file.size }
    /// Bytes indexed so far — equals byteSize once the background build completes.
    var indexedBytes: Int { scannedEnd }

    /// Decode line `i` (trailing CR/LF stripped). Empty string if out of range.
    func line(_ i: Int) -> String {
        guard i >= 0, i < starts.count, let ptr = file.ptr else { return "" }
        let start = starts[i]
        let end = i + 1 < starts.count ? starts[i + 1] : scannedEnd
        guard end > start else { return "" }
        var hi = end
        if hi > start, ptr[hi - 1] == 0x0A { hi -= 1 }          // \n
        if hi > start, ptr[hi - 1] == 0x0D { hi -= 1 }          // \r
        guard hi > start else { return "" }
        let buf = UnsafeBufferPointer(start: ptr + start, count: hi - start)
        return String(decoding: buf, as: UTF8.self)
    }

    /// Decode only the first `maxBytes` bytes of line `i` (no trailing strip) — used
    /// for cheap entry-boundary detection without decoding whole lines.
    func linePrefix(_ i: Int, maxBytes: Int) -> String {
        guard i >= 0, i < starts.count, let ptr = file.ptr else { return "" }
        let start = starts[i]
        let end = i + 1 < starts.count ? starts[i + 1] : scannedEnd
        let hi = min(end, start + maxBytes)
        guard hi > start else { return "" }
        return String(decoding: UnsafeBufferPointer(start: ptr + start, count: hi - start), as: UTF8.self)
    }

    /// Scan the whole mapped file for line starts on a background queue, publishing
    /// the growing count on the main thread.
    func buildIndex() {
        queue.async { [weak self] in
            guard let self else { return }
            self.scan(from: 0, upTo: self.file.size)
        }
    }

    /// Remap a grown file and index the appended bytes (live tail). Runs sync on the
    /// caller (main) — call after the initial build has completed.
    func extendForGrowth() -> Bool {
        let old = file.size
        let new = file.remap()
        guard new > old else { return false }
        scan(from: scannedEnd, upTo: new, publishOnMain: false)
        return true
    }

    private func scan(from: Int, upTo end: Int, publishOnMain: Bool = true) {
        guard let ptr = file.ptr, end > from else { scannedEnd = max(scannedEnd, end); return }
        var found: [Int] = []
        var i = from
        while i < end {
            if ptr[i] == 0x0A { found.append(i + 1) }   // offset after every '\n'
            i += 1
            // Publish in batches so a huge file streams into the UI.
            if publishOnMain, found.count >= 50_000 {
                let batch = found; found.removeAll(keepingCapacity: true)
                let scanned = i
                DispatchQueue.main.async { [weak self] in self?.publish(batch, scanned: scanned) }
            }
        }
        if publishOnMain {
            let batch = found
            DispatchQueue.main.async { [weak self] in self?.publish(batch, scanned: end) }
        } else {
            starts.append(contentsOf: found)
            scannedEnd = end
        }
    }

    private func publish(_ batch: [Int], scanned: Int) {
        starts.append(contentsOf: batch)
        scannedEnd = max(scannedEnd, scanned)
        onProgress?(starts.count)
    }
}
