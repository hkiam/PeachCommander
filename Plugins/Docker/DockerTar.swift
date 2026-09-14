// SPDX-License-Identifier: Apache-2.0
// DockerTar.swift — the tar the engine speaks, read as a stream and written by hand.
//
// Docker's file API is tar in both directions: `GET /containers/{id}/archive` answers with one,
// `PUT` takes one. So this file is the whole of the plugin's file transfer, and both halves have
// a reason to be written here rather than shelled out to `/usr/bin/tar`.
//
// **Reading** has to be a stream. The archive of a directory is *recursive* — a container's "/"
// is the entire filesystem — and a listing needs only the entries one level down. `TarScanner`
// is fed whatever arrived from the socket and reports entries as it crosses their headers, so a
// listing costs no memory whatever the archive's size, and a consumer that has seen enough can
// stop the transfer instead of finishing it.
//
// **Writing** has to be plain. Uploading with macOS's own `tar` looked like it worked and did
// not: BSD tar records `com.apple.provenance` as a PAX extended attribute on every file it
// packs, the Linux side of the engine refuses to set it, and the upload ends in
//
//     500 lsetxattr /tmp/x: xattr "com.apple.provenance": operation not supported
//
// *after* having written the file — a failure the user is told about for a copy that in fact
// happened. What goes out of here is therefore a bare USTAR entry: name, mode, size, mtime,
// type, and nothing else that another operating system could have an opinion about.

import Foundation

/// One entry in a tar stream.
struct TarEntry {
    enum Kind {
        case file
        case directory
        case symlink
        case hardlink
        case other
    }

    var name: String          // as recorded, relative and '/'-separated
    var size: Int64
    var mode: UInt32          // permission bits only (type lives in `kind`)
    var mtime: Int64
    var kind: Kind
    var linkName: String
    var uid: Int
    var gid: Int

    /// The leaf, with any trailing slash removed.
    var leaf: String {
        var path = name
        while path.hasSuffix("/") { path.removeLast() }
        guard let slash = path.lastIndex(of: "/") else { return path }
        return String(path[path.index(after: slash)...])
    }

    /// How many '/'-separated components the entry sits under, ignoring a trailing slash.
    var depth: Int {
        var path = name
        while path.hasSuffix("/") { path.removeLast() }
        return path.split(separator: "/").count
    }
}

/// A tar reader that is fed bytes as they arrive.
///
/// `onEntry` is called once per entry, before its data. Returning `.skip` discards the data,
/// `.take` routes it to `onData`, and `.stop` ends the scan — which the caller turns into
/// abandoning the HTTP response.
final class TarScanner {
    enum Disposition {
        case skip
        case take
        case stop
    }

    private enum State {
        case header
        case body(remaining: Int64, padding: Int, deliver: Bool)
        case longName(remaining: Int64, padding: Int, isLink: Bool)
        case pax(remaining: Int64, padding: Int)
        case finished
    }

    private var pending: [UInt8] = []
    private var state: State = .header
    /// A GNU long name or a PAX `path=` seen just before the entry it belongs to.
    private var overrideName: String?
    private var overrideLink: String?
    private var zeroBlocks = 0

    private let onEntry: (TarEntry) throws -> Disposition
    private let onData: (UnsafeRawBufferPointer) throws -> Void

    init(onEntry: @escaping (TarEntry) throws -> Disposition,
         onData: @escaping (UnsafeRawBufferPointer) throws -> Void = { _ in }) {
        self.onEntry = onEntry
        self.onData = onData
        pending.reserveCapacity(1024)
    }

    var isFinished: Bool { if case .finished = state { return true }; return false }

    /// Feed the next piece of the stream. Returns false once the scan is over, which the caller
    /// uses to stop reading the response.
    func feed(_ bytes: UnsafeRawBufferPointer) throws -> Bool {
        var offset = 0
        while offset < bytes.count {
            switch state {
            case .finished:
                return false

            case .body(let remaining, let padding, let deliver):
                let take = Int(min(remaining, Int64(bytes.count - offset)))
                if deliver, take > 0 {
                    try onData(UnsafeRawBufferPointer(rebasing: bytes[offset..<(offset + take)]))
                }
                offset += take
                let left = remaining - Int64(take)
                state = left > 0
                    ? .body(remaining: left, padding: padding, deliver: deliver)
                    : Self.skipping(padding)

            case .longName(let remaining, let padding, let isLink):
                let take = Int(min(remaining, Int64(bytes.count - offset)))
                pending.append(contentsOf: bytes[offset..<(offset + take)])
                offset += take
                let left = remaining - Int64(take)
                if left > 0 {
                    state = .longName(remaining: left, padding: padding, isLink: isLink)
                } else {
                    let text = Self.trimNul(pending)
                    if isLink { overrideLink = text } else { overrideName = text }
                    pending.removeAll(keepingCapacity: true)
                    state = Self.skipping(padding)
                }

            case .pax(let remaining, let padding):
                let take = Int(min(remaining, Int64(bytes.count - offset)))
                pending.append(contentsOf: bytes[offset..<(offset + take)])
                offset += take
                let left = remaining - Int64(take)
                if left > 0 {
                    state = .pax(remaining: left, padding: padding)
                } else {
                    applyPax(pending)
                    pending.removeAll(keepingCapacity: true)
                    state = Self.skipping(padding)
                }

            case .header:
                let need = 512 - pending.count
                let take = min(need, bytes.count - offset)
                pending.append(contentsOf: bytes[offset..<(offset + take)])
                offset += take
                guard pending.count == 512 else { continue }
                let block = pending
                pending.removeAll(keepingCapacity: true)
                if try !consumeHeader(block) { return false }
            }
        }
        return !isFinished
    }

    /// Padding is modelled as a body with nothing to deliver, so there is one place that counts
    /// bytes rather than two that could disagree.
    private static func skipping(_ padding: Int) -> State {
        padding == 0 ? .header : .body(remaining: Int64(padding), padding: 0, deliver: false)
    }

    private func consumeHeader(_ block: [UInt8]) throws -> Bool {
        if block.allSatisfy({ $0 == 0 }) {
            zeroBlocks += 1
            // Two zero blocks end a tar. One can legitimately appear inside a corrupt-looking
            // but valid stream, so it is not enough on its own.
            if zeroBlocks >= 2 { state = .finished; return false }
            state = .header
            return true
        }
        zeroBlocks = 0

        let name = overrideName ?? Self.string(block, 0, 100, prefix: Self.string(block, 345, 155))
        let mode = UInt32(Self.octal(block, 100, 8))
        let uid = Int(Self.octal(block, 108, 8))
        let gid = Int(Self.octal(block, 116, 8))
        let size = Self.octal(block, 124, 12)
        let mtime = Self.octal(block, 136, 12)
        let typeflag = block[156]
        let linkName = overrideLink ?? Self.string(block, 157, 100)
        let padding = size % 512 == 0 ? 0 : Int(512 - size % 512)

        switch typeflag {
        case UInt8(ascii: "L"):          // GNU long name
            state = .longName(remaining: size, padding: padding, isLink: false)
            return true
        case UInt8(ascii: "K"):          // GNU long link target
            state = .longName(remaining: size, padding: padding, isLink: true)
            return true
        case UInt8(ascii: "x"), UInt8(ascii: "X"), UInt8(ascii: "g"):   // PAX
            state = .pax(remaining: size, padding: padding)
            return true
        default:
            break
        }

        let kind: TarEntry.Kind
        switch typeflag {
        case UInt8(ascii: "0"), 0: kind = .file
        case UInt8(ascii: "5"): kind = .directory
        case UInt8(ascii: "2"): kind = .symlink
        case UInt8(ascii: "1"): kind = .hardlink
        default: kind = .other
        }

        overrideName = nil
        overrideLink = nil
        let entry = TarEntry(name: name, size: kind == .directory ? 0 : size, mode: mode & 0o7777,
                             mtime: mtime, kind: kind, linkName: linkName, uid: uid, gid: gid)
        let disposition = try onEntry(entry)
        switch disposition {
        case .stop:
            state = .finished
            return false
        case .take:
            state = size > 0 ? .body(remaining: size, padding: padding, deliver: true)
                             : Self.skipping(padding)
        case .skip:
            state = size > 0 ? .body(remaining: size, padding: padding, deliver: false)
                             : Self.skipping(padding)
        }
        return true
    }

    /// PAX records are `"<len> key=value\n"`; only `path` and `linkpath` matter here.
    private func applyPax(_ bytes: [UInt8]) {
        // Walked over BYTES, and that is the whole point. A record is `<len> key=value` plus a
        // newline, where <len> counts the record's length **in bytes** — while a Swift `String`
        // indexes in Characters, and `index(_:offsetBy:)` on one advances that many *Characters*.
        // The two agree for ASCII and part company the moment a name is not: a 60-character name of
        // umlauts is 120 bytes, the length check `length <= rest.count` then compared 130 against
        // 61, the record was thrown away, and the listing fell back to the truncated USTAR field —
        // which for UTF-8 is not merely short but cut through the middle of a character.
        var index = 0
        while index < bytes.count {
            guard let space = bytes[index...].firstIndex(of: UInt8(ascii: " ")) else { return }
            guard let length = Int(String(decoding: bytes[index..<space], as: UTF8.self)),
                  length > 0, index + length <= bytes.count else { return }
            let recordEnd = index + length
            // The value ends before the record's trailing newline, which is part of its length.
            var valueEnd = recordEnd
            if valueEnd > space + 1, bytes[valueEnd - 1] == UInt8(ascii: "\n") { valueEnd -= 1 }
            let record = bytes[(space + 1)..<valueEnd]
            if let equals = record.firstIndex(of: UInt8(ascii: "=")) {
                let key = String(decoding: record[record.startIndex..<equals], as: UTF8.self)
                let value = String(decoding: record[record.index(after: equals)...], as: UTF8.self)
                if key == "path" { overrideName = value }
                if key == "linkpath" { overrideLink = value }
            }
            index = recordEnd
        }
    }

    // MARK: Field decoding

    private static func trimNul(_ bytes: [UInt8]) -> String {
        let end = bytes.firstIndex(of: 0) ?? bytes.count
        return String(decoding: bytes[..<end], as: UTF8.self)
    }

    private static func string(_ block: [UInt8], _ offset: Int, _ length: Int,
                               prefix: String = "") -> String {
        let slice = Array(block[offset..<(offset + length)])
        let value = trimNul(slice)
        guard !prefix.isEmpty else { return value }
        return value.isEmpty ? prefix : prefix + "/" + value
    }

    private static func octal(_ block: [UInt8], _ offset: Int, _ length: Int) -> Int64 {
        // GNU base-256: the high bit of the first byte marks a binary field, used for sizes and
        // times that do not fit in octal. A tar from a container with a >8 GB file arrives this
        // way, and reading it as octal would report a nonsense size.
        if block[offset] & 0x80 != 0 {
            var value: Int64 = Int64(block[offset] & 0x7F)
            for index in (offset + 1)..<(offset + length) {
                value = (value << 8) | Int64(block[index])
            }
            return value
        }
        var value: Int64 = 0
        for index in offset..<(offset + length) {
            let byte = block[index]
            if byte == 0 || byte == 32 { continue }
            guard byte >= 48, byte <= 55 else { continue }
            value = value * 8 + Int64(byte - 48)
        }
        return value
    }
}

/// A minimal USTAR writer: exactly the fields the engine needs, and nothing else.
enum TarWriter {

    /// Whether USTAR can carry `name` at all, and how it splits if it can.
    ///
    /// The name field is 100 bytes and the prefix field 155, joined by a "/" — so a name is
    /// representable only if it can be cut at a separator into two pieces that fit. A **file name**
    /// has no separator, so anything over 100 bytes cannot be represented at all.
    static func ustarSplit(_ name: String) -> (prefix: String, name: String)? {
        if Array(name.utf8).count <= 100 { return ("", name) }
        let components = name.split(separator: "/", omittingEmptySubsequences: false)
        var chosen: (String, String)?
        // The latest split that works, so as much as possible stays in the prefix.
        for split in 1..<max(components.count, 1) {
            let head = components[0..<split].joined(separator: "/")
            let tail = components[split...].joined(separator: "/")
            guard Array(head.utf8).count <= 155, Array(tail.utf8).count <= 100 else { continue }
            chosen = (head, tail)
        }
        return chosen
    }

    /// A PAX extended header carrying the real name, for a name USTAR cannot hold.
    ///
    /// Without it the writer truncated such a name to 99 bytes and sent it, and the engine accepted
    /// that: the copy reported success and the file arrived inside the container under a *different
    /// name*. macOS allows 255-byte file names, so an ordinary long name reaches this — measured,
    /// with a 124-byte name that landed as 99 characters.
    ///
    /// Both readers that matter understand it: the engine's own is Go's `archive/tar`, and the test
    /// fixture's is Python's `tarfile`.
    static func paxHeader(for name: String) -> Data {
        // A PAX record is `<len> key=value` followed by a newline, where <len> counts its own
        // digits — so the length is a fixed point: adding a digit to it can make it one longer.
        let suffix = " path=" + name + "\n"
        var length = suffix.utf8.count + 1
        while String(length).utf8.count + suffix.utf8.count != length {
            length = String(length).utf8.count + suffix.utf8.count
        }
        let records = Data((String(length) + suffix).utf8)
        // A fixed name for the header entry itself: it is never extracted, and one built from the
        // real name could overflow the very field this exists to get around.
        var out = header(name: "PaxHeaders/0", size: Int64(records.count), mode: 0o644,
                         mtime: 0, type: "x", linkName: "", pax: false)
        out.append(records)
        out.append(padding(for: Int64(records.count)))
        return out
    }

    /// A tar holding one regular file, read from `localPath` and named `name` inside the archive.
    static func file(named name: String, from localPath: String, mode: UInt32, mtime: Int64) throws -> Data {
        guard let handle = FileHandle(forReadingAtPath: localPath) else {
            throw DockerError.malformed("cannot read \(localPath)")
        }
        defer { try? handle.close() }
        let attributes = try? FileManager.default.attributesOfItem(atPath: localPath)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        var out = Data()
        out.append(header(name: name, size: size, mode: mode, mtime: mtime, type: "0", linkName: ""))
        var written: Int64 = 0
        while true {
            let chunk = handle.readData(ofLength: 1 << 20)
            if chunk.isEmpty { break }
            out.append(chunk)
            written += Int64(chunk.count)
        }
        // A file that grew or shrank between the stat and the read would make a tar whose header
        // and body disagree, which the engine unpacks as a truncated or corrupt file. Pad or trim
        // to the size the header promises instead.
        if written < size {
            out.append(Data(repeating: 0, count: Int(size - written)))
        } else if written > size {
            out.removeLast(Int(written - size))
        }
        out.append(padding(for: size))
        out.append(Data(repeating: 0, count: 1024))
        return out
    }

    /// A tar holding one directory entry.
    static func directory(named name: String, mode: UInt32 = 0o755, mtime: Int64) -> Data {
        var out = Data()
        var leaf = name
        if !leaf.hasSuffix("/") { leaf += "/" }
        out.append(header(name: leaf, size: 0, mode: mode, mtime: mtime, type: "5", linkName: ""))
        out.append(Data(repeating: 0, count: 1024))
        return out
    }

    static func padding(for size: Int64) -> Data {
        let remainder = size % 512
        return remainder == 0 ? Data() : Data(repeating: 0, count: Int(512 - remainder))
    }

    /// One 512-byte USTAR header. Names longer than 100 bytes are split over the `prefix` field,
    /// which is what USTAR is for; a name that cannot be split that way is rejected rather than
    /// silently truncated into a write to the wrong path.
    static func header(name: String, size: Int64, mode: UInt32, mtime: Int64,
                       type: Character, linkName: String, pax: Bool = true) -> Data {
        // A name USTAR cannot represent gets a PAX record in front of it carrying the truth; the
        // fields below then hold a truncation that no reader uses. `pax: false` is for the PAX
        // header entry itself, which must not recurse.
        var prelude = Data()
        if pax, ustarSplit(name) == nil { prelude = paxHeader(for: name) }
        var block = [UInt8](repeating: 0, count: 512)

        func put(_ text: String, _ offset: Int, _ length: Int) {
            for (index, byte) in Array(text.utf8).prefix(length - 1).enumerated() {
                block[offset + index] = byte
            }
        }
        func putOctal(_ value: Int64, _ offset: Int, _ length: Int) {
            let text = String(value, radix: 8)
            let padded = String(repeating: "0", count: max(0, length - 1 - text.count)) + text
            put(padded, offset, length)
        }

        var recorded = name
        var prefix = ""
        if let split = ustarSplit(name) {
            prefix = split.prefix
            recorded = split.name
        } else if Array(recorded.utf8).count > 100 {
            // Nothing here can represent it, so what goes in the field is a truncation and the
            // PAX record above is what the reader actually uses.
        }

        put(recorded, 0, 100)
        putOctal(Int64(mode & 0o7777), 100, 8)
        putOctal(0, 108, 8)                       // uid — see the note in DockerFS.upload
        putOctal(0, 116, 8)                       // gid
        putOctal(size, 124, 12)
        putOctal(mtime, 136, 12)
        for index in 148..<156 { block[index] = 32 }   // checksum field counts as spaces
        block[156] = String(type).utf8.first ?? UInt8(ascii: "0")
        put(linkName, 157, 100)
        put("ustar", 257, 6)
        block[263] = UInt8(ascii: "0"); block[264] = UInt8(ascii: "0")
        put("root", 265, 32)
        put("root", 297, 32)
        put(prefix, 345, 155)

        let checksum = block.reduce(0) { $0 + Int($1) }
        let text = String(checksum, radix: 8)
        let padded = String(repeating: "0", count: max(0, 6 - text.count)) + text
        put(padded, 148, 7)
        block[154] = 0
        block[155] = 32

        var out = prelude
        out.append(Data(block))
        return out
    }
}
