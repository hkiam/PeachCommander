// SPDX-License-Identifier: Apache-2.0
// FileHeadLine.swift - The first line of a file, without reading the rest of it.
//
// Written because a comment claimed this and the code did not do it. `SyncStateStore.records()` says
// "only the header line of each file is read, so listing a hundred pairs does not mean reading a
// hundred trees' worth of entries" — and then called `Data(contentsOf:)`, which reads the whole
// file into memory before splitting it. For a pair with two hundred thousand paths that is the
// entire record, per row, to show a table of four columns.
//
// So the bounded read lives in one place, and both record stores use it. The cap is what makes it
// bounded and it is also the refusal: a file whose first line does not end inside `maxBytes` is not
// a file with a header, and answering nil is how such a record still gets listed as unreadable
// rather than silently costing whatever it happens to be big.

import Foundation

public enum FileHeadLine {

    /// Everything before the first `\n`, or nil.
    ///
    /// Nil for a file that cannot be opened, an empty file, and — deliberately — a file whose first
    /// line is longer than `maxBytes`. The last is a refusal, not a truncation: half a JSON object
    /// would decode as nothing anyway, and a caller that got a shortened line back could not tell
    /// that from a genuinely broken one.
    ///
    /// A file with no newline at all is its own first line, provided it fits. That is the
    /// hand-written case — every writer here terminates the header — and reading it costs at most
    /// the cap.
    public static func read(at url: URL, maxBytes: Int = 64 * 1024) -> Data? {
        guard maxBytes > 0, let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var accumulated = Data()
        let chunkSize = 4096
        while accumulated.count < maxBytes {
            let wanted = min(chunkSize, maxBytes - accumulated.count)
            guard let chunk = try? handle.read(upToCount: wanted), !chunk.isEmpty else {
                break                                  // end of file
            }
            accumulated.append(chunk)
            if let newline = accumulated.firstIndex(of: UInt8(ascii: "\n")) {
                let line = accumulated[accumulated.startIndex..<newline]
                return line.isEmpty ? nil : Data(line)
            }
        }
        // No newline. Either the file ended — then what we have is the whole of it — or the cap was
        // reached, which is the refusal above.
        guard accumulated.count < maxBytes, !accumulated.isEmpty else { return nil }
        return accumulated
    }
}
