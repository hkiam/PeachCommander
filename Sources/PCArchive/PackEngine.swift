// SPDX-License-Identifier: Apache-2.0
// PackEngine.swift - Create archives in multiple formats with optional AES
// encryption and multi-volume splitting, by driving the system packers
// (7z / tar / zip / rar). F-132 / F-136 / F-138.
//
// 7-Zip (p7zip) is the workhorse: it writes .7z and .zip with AES-256, splits
// into volumes (-v), and handles high compression. tar[.gz/.bz2/.xz] use the
// system tar. RAR creation needs the proprietary `rar` binary (extraction stays
// via unar); when it is absent, packing to RAR reports toolNotFound.

import Foundation

public enum PackFormat: String, Sendable, CaseIterable {
    case zip          // deflate; AES-256 + split when requested (via 7z)
    case sevenZip     // .7z LZMA2; AES-256 + header-encryption + split
    case tar          // uncompressed
    case tarGz        // .tar.gz
    case tarBz2       // .tar.bz2
    case tarXz        // .tar.xz
    case rar          // requires the `rar` binary

    /// The archive filename suffix (no leading dot).
    public var fileExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .tar: return "tar"
        case .tarGz: return "tar.gz"
        case .tarBz2: return "tar.bz2"
        case .tarXz: return "tar.xz"
        case .rar: return "rar"
        }
    }

    /// Whether this format supports a password / multi-volume split.
    public var supportsEncryption: Bool { self == .zip || self == .sevenZip || self == .rar }
    public var supportsSplit: Bool { self == .zip || self == .sevenZip || self == .rar }
}

public struct PackOptions: Sendable {
    public var format: PackFormat
    /// AES-256 password (formats that `supportsEncryption`). nil/empty = none.
    public var password: String?
    /// Bytes per volume for a multi-volume archive (nil = single file).
    public var splitSize: Int64?
    /// Compression level 0…9 (0 = store). Ignored by tar (uncompressed) itself.
    public var level: Int

    public init(format: PackFormat, password: String? = nil, splitSize: Int64? = nil, level: Int = 5) {
        self.format = format
        self.password = password
        self.splitSize = splitSize
        self.level = level
    }
}

public enum PackError: Error, Equatable {
    case toolNotFound(String)
    case unsupportedOption(String)
    case noItems
    case failed(String, Int32)
}

public enum PackEngine {
    /// Directories searched for the packer binaries.
    private static let binDirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    /// Resolve a tool to an absolute path, or nil if not installed.
    public static func toolPath(_ name: String) -> String? {
        binDirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Pack `items` (which must share a parent directory) into `archivePath` per
    /// `options`. Runs from the items' parent so entries are stored by basename.
    public static func pack(items: [String], to archivePath: String, options: PackOptions) throws {
        guard !items.isEmpty else { throw PackError.noItems }
        let hasPassword = !(options.password ?? "").isEmpty
        if hasPassword && !options.format.supportsEncryption {
            throw PackError.unsupportedOption("encryption not supported for \(options.format.rawValue)")
        }
        if options.splitSize != nil && !options.format.supportsSplit {
            throw PackError.unsupportedOption("split not supported for \(options.format.rawValue)")
        }
        let parent = (items[0] as NSString).deletingLastPathComponent
        let names = items.map { ($0 as NSString).lastPathComponent }
        // 7z refuses to add to an existing archive of a different content; remove first.
        try? FileManager.default.removeItem(atPath: archivePath)
        for vol in existingVolumes(of: archivePath) { try? FileManager.default.removeItem(atPath: vol) }

        let (tool, args, stdin) = try command(for: options, archivePath: archivePath, names: names)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: parent.isEmpty ? "/" : parent)
        let err = Pipe()
        process.standardError = err
        process.standardOutput = FileHandle.nullDevice
        // The password goes down the pipe, never into the argument list — see `command(for:…)`.
        let input = Pipe()
        process.standardInput = stdin == nil ? FileHandle.nullDevice : input
        do { try process.run() } catch { throw PackError.failed("\(error)", -1) }
        if let stdin {
            // Twice: the packers ask for the password and then for a confirmation.
            try? input.fileHandleForWriting.write(contentsOf: Data("\(stdin)\n\(stdin)\n".utf8))
            try? input.fileHandleForWriting.close()
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw PackError.failed(msg.isEmpty ? "exit \(process.terminationStatus)" : msg, process.terminationStatus)
        }
    }

    /// Build (tool, arguments, stdin) for the requested format/options.
    ///
    /// A password is returned as `stdin` rather than placed in the arguments. `-p<password>` puts it in
    /// the process's argument list, where `ps` shows it in full to anything running as the same user for
    /// as long as the archive takes to write — measured, not supposed. `7z -p` with no value reads it
    /// from standard input instead, which is where it belongs.
    /// Internal rather than private so a test can assert the one thing that cannot be seen from
    /// outside: that the password is never in `args`.
    static func command(for options: PackOptions, archivePath: String, names: [String]) throws
        -> (tool: String, args: [String], stdin: String?) {
        let pw = options.password.flatMap { $0.isEmpty ? nil : $0 }
        switch options.format {
        case .tar, .tarGz, .tarBz2, .tarXz:
            guard let tar = toolPath("tar") else { throw PackError.toolNotFound("tar") }
            let flag: String
            switch options.format {
            case .tarGz: flag = "-czf"
            case .tarBz2: flag = "-cjf"
            case .tarXz: flag = "-cJf"
            default: flag = "-cf"
            }
            // `--` before the names: without it a file called "-x.txt" is read as a *switch*. tar then
            // said "Can't specify both -x and -c" and the whole pack failed — and a file named "-C"
            // would have been worse than a failure, because tar would have changed directory and
            // archived something else. Measured, not assumed: both tar and 7z honour `--` here.
            return (tar, [flag, archivePath, "--"] + names, nil)

        case .zip, .sevenZip:
            guard let sevenZip = toolPath("7z") ?? toolPath("7za") else { throw PackError.toolNotFound("7z") }
            var args = ["a", options.format == .zip ? "-tzip" : "-t7z", "-y", "-bso0", "-bsp0",
                        "-mx=\(max(0, min(9, options.level)))"]
            if pw != nil {
                args.append("-p")                 // value on stdin, not in argv
                if options.format == .zip { args.append("-mem=AES256") }
                else { args.append("-mhe=on") }   // 7z: also encrypt headers/names
            }
            if let split = options.splitSize { args.append("-v\(split)b") }
            args.append(archivePath)
            args.append("--")               // see the tar branch: a name may begin with a dash
            args.append(contentsOf: names)
            return (sevenZip, args, pw)

        case .rar:
            guard let rar = toolPath("rar") else { throw PackError.toolNotFound("rar") }
            var args = ["a", "-r", "-ep1", "-m\(max(0, min(5, options.level / 2)))"]
            if pw != nil { args.append("-hp") }           // -hp also encrypts headers; value on stdin
            if let split = options.splitSize { args.append("-v\(split)b") }
            args.append(archivePath)
            args.append("--")               // as above; `rar` is not installed here, so this one is by
            args.append(contentsOf: names)  // its documentation rather than by measurement
            return (rar, args, pw)
        }
    }

    /// Existing volume files for a split archive base path (name.7z.001, …).
    private static func existingVolumes(of archivePath: String) -> [String] {
        let dir = (archivePath as NSString).deletingLastPathComponent
        let base = (archivePath as NSString).lastPathComponent
        let all = (try? FileManager.default.contentsOfDirectory(atPath: dir.isEmpty ? "." : dir)) ?? []
        return all.filter { $0.hasPrefix(base + ".") && $0.dropFirst(base.count + 1).allSatisfy(\.isNumber) }
            .map { (dir as NSString).appendingPathComponent($0) }
    }
}
