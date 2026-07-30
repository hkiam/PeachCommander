// SPDX-License-Identifier: Apache-2.0
// archive.swift — read-only archive browser as a PCX packer plugin.
//
// Implements the WCX-style PCX C-ABI (OpenArchive → ReadHeaderEx/ProcessFile loop
// → CloseArchive) on top of the system libarchive via /usr/bin/tar (bsdtar) — so
// it browses/extracts 7z and the tar family (tar, tgz, txz, tzst, tbz2, tar.*)
// with no bundled or user-installed dependency. Listing parses `tar -tvf`;
// extraction streams one member with `tar -xOf -- name`. Read-only (no PackFiles/
// DeleteFiles). The host mounts it as a VirtualFileSystem via PCXArchiveFS.
//
// A lone single-stream file (.gz/.bz2/.xz/.zst that is not a tar) is exposed as a
// one-entry archive: the entry is the decompressed name, extracted by piping the
// stream through the matching decompressor (gz/bz2 are always present on macOS;
// xz/zst use their CLI if installed). If no decompressor is available OpenArchive
// fails cleanly and the host treats the file normally.

import Foundation

// MARK: - Archive state (opaque PC_HANDLE)

private struct ArcEntry { let name: String; let size: Int64; let isDir: Bool; let mtime: Int64 }

private final class ArchiveState {
    let path: String
    let entries: [ArcEntry]
    /// Non-nil for a single-stream file (lone .gz/.bz2/.xz/.zst): the argv that
    /// decompresses `path` to stdout.
    let extractCmd: [String]?
    /// Non-nil for a lsar/unar-handled archive (e.g. RAR): the `unar` executable
    /// used to extract one member to stdout.
    let unarPath: String?
    var index = 0
    init(path: String, entries: [ArcEntry], extractCmd: [String]? = nil, unarPath: String? = nil) {
        self.path = path; self.entries = entries; self.extractCmd = extractCmd; self.unarPath = unarPath
    }
}

// MARK: - libarchive (bsdtar) helpers

private let tarPath = "/usr/bin/tar"

/// Run `argv` (argv[0] is the executable); capture stdout (unless streamed to
/// `toFile`). Returns (stdout, exit status). stderr is discarded to avoid
/// pipe-buffer deadlocks.
private func runProcess(_ argv: [String], toFile: String? = nil) -> (out: String, status: Int32) {
    guard let exe = argv.first else { return ("", -1) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = Array(argv.dropFirst())
    p.standardError = FileHandle.nullDevice
    let outPipe = Pipe()
    if let toFile {
        FileManager.default.createFile(atPath: toFile, contents: nil)
        guard let fh = try? FileHandle(forWritingTo: URL(fileURLWithPath: toFile)) else { return ("", -1) }
        p.standardOutput = fh
    } else {
        p.standardOutput = outPipe
    }
    do { try p.run() } catch { return ("", -1) }
    var data = Data()
    if toFile == nil { data = outPipe.fileHandleForReading.readDataToEndOfFile() }
    p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus)
}

private func runTar(_ args: [String], toFile: String? = nil) -> (out: String, status: Int32) {
    runProcess([tarPath] + args, toFile: toFile)
}

/// Locate an executable by candidate names in the usual bin dirs + PATH.
private func which(_ names: [String]) -> String? {
    var dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    if let path = ProcessInfo.processInfo.environment["PATH"] { dirs += path.split(separator: ":").map(String.init) }
    for name in names {
        for dir in dirs {
            let p = "\(dir)/\(name)"
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
    }
    return nil
}

/// For a lone single-stream compressed file, the decompressed entry name + the
/// argv that writes the decompressed bytes to stdout — or nil if unsupported /
/// no decompressor is available. (gz/bz2 are always available on macOS; xz/zst
/// need their CLI, e.g. via Homebrew.)
private func singleStream(_ path: String) -> (name: String, cmd: [String])? {
    let ext = (path as NSString).pathExtension.lowercased()
    let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    let tool: String?
    switch ext {
    case "gz":  tool = which(["gzip", "gunzip"])
    case "bz2": tool = which(["bzip2", "bunzip2"])
    case "xz":  tool = which(["xz", "unxz"])
    case "zst": tool = which(["zstd", "zstdcat"])
    default:    tool = nil
    }
    guard let tool, !base.isEmpty else { return nil }
    return (base, [tool, "-dc", path])
}

// lsar -l row: "  N. Flags Size Ratio Mode Date Time Name" (The Unarchiver).
private let lsarLine = try! NSRegularExpression(
    pattern: #"^\s*\d+\.\s+(\S+)\s+(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+(.+)$"#)

/// List a lsar/unar-supported archive (e.g. RAR) via `lsar -l`, or nil if lsar is
/// unavailable or the file isn't a recognized archive.
private func lsarList(_ path: String) -> [ArcEntry]? {
    guard let lsar = which(["lsar"]) else { return nil }
    let (out, status) = runProcess([lsar, "-l", path])
    guard status == 0 else { return nil }
    var result: [ArcEntry] = []
    for line in out.split(separator: "\n", omittingEmptySubsequences: true) {
        let s = String(line); let ns = s as NSString
        guard let m = lsarLine.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { continue }
        let flags = ns.substring(with: m.range(at: 1))
        let size = Int64(ns.substring(with: m.range(at: 2))) ?? -1
        let name = ns.substring(with: m.range(at: 3))
        let isDir = flags.uppercased().contains("D")
        result.append(ArcEntry(name: name, size: isDir ? -1 : size, isDir: isDir, mtime: 0))
    }
    return result.isEmpty ? nil : result
}

private let verboseLine = try! NSRegularExpression(
    pattern: #"^(\S+)\s+\S+\s+\S+\s+\S+\s+(\d+)\s+(\w{3})\s+(\d{1,2})\s+(\S+)\s+(.+)$"#)

private func listEntries(_ path: String) -> (entries: [ArcEntry], ok: Bool) {
    let (out, status) = runTar(["-tvf", path])
    guard status == 0 else { return ([], false) }
    var result: [ArcEntry] = []
    for line in out.split(separator: "\n", omittingEmptySubsequences: true) {
        let s = String(line)
        let ns = s as NSString
        guard let m = verboseLine.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { continue }
        let perms = ns.substring(with: m.range(at: 1))
        let size = Int64(ns.substring(with: m.range(at: 2))) ?? -1
        let mtime = parseDate(mon: ns.substring(with: m.range(at: 3)),
                              day: ns.substring(with: m.range(at: 4)),
                              timeOrYear: ns.substring(with: m.range(at: 5)))
        var name = ns.substring(with: m.range(at: 6))
        if let r = name.range(of: " -> ") { name = String(name[..<r.lowerBound]) }   // symlink target
        let isDir = perms.hasPrefix("d") || name.hasSuffix("/")
        result.append(ArcEntry(name: name, size: isDir ? -1 : size, isDir: isDir, mtime: mtime))
    }
    return (result, true)
}

/// Parse a bsdtar verbose date ("Jul 24 14:04" or "Jul 24 2024") to epoch seconds.
private func parseDate(mon: String, day: String, timeOrYear: String) -> Int64 {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone.current
    let hasYear = !timeOrYear.contains(":")
    let year = hasYear ? timeOrYear : "\(Calendar.current.component(.year, from: Date()))"
    let time = hasYear ? "00:00" : timeOrYear
    f.dateFormat = "MMM d yyyy HH:mm"
    guard let d = f.date(from: "\(mon) \(day) \(year) \(time)") else { return 0 }
    return Int64(d.timeIntervalSince1970)
}

private func setCString(_ s: String, _ dst: UnsafeMutablePointer<CChar>, _ cap: Int) {
    s.withCString { _ = strlcpy(dst, $0, cap) }
}

// MARK: - PCX entry points

@_cdecl("PcGetApiVersion")
public func PcGetApiVersion() -> Int32 { 1 }

@_cdecl("GetPackerCaps")
public func GetPackerCaps() -> Int32 { PC_CAP_MULTIPLE }

@_cdecl("OpenArchive")
public func OpenArchive(_ data: UnsafeMutablePointer<PcOpenArchiveData>?) -> UnsafeMutableRawPointer? {
    guard let data, let arcName = data.pointee.arcName else { return nil }
    let path = String(cString: arcName)
    let (entries, ok) = listEntries(path)
    if ok {
        data.pointee.openResult = Int32(PC_OK)
        return Unmanaged.passRetained(ArchiveState(path: path, entries: entries, extractCmd: nil)).toOpaque()
    }
    // Not a tar-family/7z archive — try a lone single-stream compressed file.
    if let (name, cmd) = singleStream(path) {
        let mtime = ((try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date)
            .map { Int64($0.timeIntervalSince1970) } ?? 0
        let entry = ArcEntry(name: name, size: -1, isDir: false, mtime: mtime)
        data.pointee.openResult = Int32(PC_OK)
        return Unmanaged.passRetained(ArchiveState(path: path, entries: [entry], extractCmd: cmd)).toOpaque()
    }
    // Formats libarchive can't read but The Unarchiver can (e.g. RAR), if installed.
    if let unar = which(["unar"]), let entries = lsarList(path) {
        data.pointee.openResult = Int32(PC_OK)
        return Unmanaged.passRetained(ArchiveState(path: path, entries: entries, unarPath: unar)).toOpaque()
    }
    data.pointee.openResult = Int32(PC_E_BAD_ARCHIVE)
    return nil
}

@_cdecl("ReadHeaderEx")
public func ReadHeaderEx(_ hArc: UnsafeMutableRawPointer?, _ hdr: UnsafeMutablePointer<PcHeaderDataEx>?) -> Int32 {
    guard let hArc, let hdr else { return Int32(PC_E_BAD_DATA) }
    let state = Unmanaged<ArchiveState>.fromOpaque(hArc).takeUnretainedValue()
    guard state.index < state.entries.count else { return Int32(PC_E_END_ARCHIVE) }
    let e = state.entries[state.index]
    state.index += 1
    setCString(e.name, &hdr.pointee.fileName.0, 1024)
    hdr.pointee.unpSize = e.size
    hdr.pointee.packSize = e.size
    hdr.pointee.fileTime = e.mtime
    hdr.pointee.fileAttr = e.isDir ? UInt32(PC_ATTR_DIR) : 0
    hdr.pointee.fileCRC = 0
    hdr.pointee.method = 0
    return Int32(PC_OK)
}

@_cdecl("ProcessFile")
public func ProcessFile(_ hArc: UnsafeMutableRawPointer?, _ operation: Int32,
                        _ destPath: UnsafeMutablePointer<CChar>?, _ destName: UnsafeMutablePointer<CChar>?) -> Int32 {
    guard let hArc else { return Int32(PC_E_BAD_DATA) }
    let state = Unmanaged<ArchiveState>.fromOpaque(hArc).takeUnretainedValue()
    guard operation == Int32(PC_EXTRACT) else { return Int32(PC_OK) }   // SKIP / TEST
    let idx = state.index - 1
    guard state.entries.indices.contains(idx) else { return Int32(PC_E_BAD_DATA) }
    let e = state.entries[idx]
    guard !e.isDir else { return Int32(PC_OK) }
    guard let destName else { return Int32(PC_E_ECREATE) }
    let dest = String(cString: destName)
    let status: Int32
    if let unar = state.unarPath {
        status = runProcess([unar, "-q", "-o", "-", "-D", state.path, e.name], toFile: dest).status
    } else if let cmd = state.extractCmd {
        status = runProcess(cmd, toFile: dest).status   // single-stream: decompress to dest
    } else {
        status = runTar(["-xOf", state.path, "--", e.name], toFile: dest).status
    }
    return status == 0 ? Int32(PC_OK) : Int32(PC_E_EWRITE)
}

@_cdecl("CloseArchive")
public func CloseArchive(_ hArc: UnsafeMutableRawPointer?) -> Int32 {
    guard let hArc else { return Int32(PC_OK) }
    Unmanaged<ArchiveState>.fromOpaque(hArc).release()
    return Int32(PC_OK)
}

// Required no-op callback registrations (this reader uses neither).
@_cdecl("SetChangeVolProc")
public func SetChangeVolProc(_ hArc: UnsafeMutableRawPointer?, _ proc: UnsafeMutableRawPointer?) {}

@_cdecl("SetProcessDataProc")
public func SetProcessDataProc(_ hArc: UnsafeMutableRawPointer?, _ proc: UnsafeMutableRawPointer?) {}
