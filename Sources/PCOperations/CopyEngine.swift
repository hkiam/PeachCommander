// SPDX-License-Identifier: Apache-2.0
// CopyEngine.swift - Recursive local copy with progress, cancel/pause and
// metadata preservation (SPEC-004 §1/§3).
//
// Strategy per regular file: try clonefile(2) on the same volume (instant,
// preserves everything); otherwise stream in chunks (cancellable, pausable,
// partial target removed on failure) then copy metadata via copyfile(3).

import Foundation
import PCFoundation

public final class CopyEngine {
    private let options: CopyOptions
    private let control: OperationControl
    private let resolver: OperationResolver
    private let progress: @Sendable (OpProgress) -> Void
    private let logger = PCFoundationLogger.logger

    private var state = OpProgress()
    private var processed: [String] = []
    private let startTime = Date()

    public init(options: CopyOptions,
                control: OperationControl,
                resolver: OperationResolver,
                progress: @escaping @Sendable (OpProgress) -> Void) {
        self.options = options
        self.control = control
        self.resolver = resolver
        self.progress = progress
    }

    /// Copy each item into `dstDir`. Returns the source paths fully processed.
    @discardableResult
    public func run(items: [String], toDirectory dstDir: String) async throws -> [String] {
        let totals = planTotals(items)
        state.filesTotal = totals.files
        state.bytesTotal = totals.bytes
        report()

        for src in items {
            try await control.checkpoint()
            var leaf = (src as NSString).lastPathComponent
            if let mask = options.renameMask { leaf = CopyRenameMask.apply(mask, to: leaf) }   // F-080
            let dst = (dstDir as NSString).appendingPathComponent(leaf)
            // Per-item error resolution (F-089): retry / skip (continue) / abort.
            while true {
                do {
                    try await copyNode(from: src, to: dst)
                    processed.append(src)
                    break
                } catch let error as OperationError {
                    if error == .cancelled { throw error }
                    switch await resolver.resolveError(error, path: src) {
                    case .retry: continue
                    case .skip: break
                    case .abort: throw error
                    }
                    break
                }
            }
        }
        return processed
    }

    // MARK: - Planning

    private func planTotals(_ items: [String]) -> (files: Int, bytes: Int64) {
        var files = 0
        var bytes: Int64 = 0
        var stack = items
        while let path = stack.popLast() {
            guard let kind = FSLowLevel.kind(of: path) else { continue }
            switch kind {
            case .file, .symlink:
                files += 1
                bytes += FSLowLevel.size(of: path)
            case .directory:
                if let children = try? FileManager.default.contentsOfDirectory(atPath: path) {
                    for c in children { stack.append((path as NSString).appendingPathComponent(c)) }
                }
            }
        }
        return (files, bytes)
    }

    // MARK: - Recursion

    private func copyNode(from src: String, to dst: String) async throws {
        try await control.checkpoint()
        guard let kind = FSLowLevel.kind(of: src) else { throw OperationError.sourceNotFound(src) }
        switch kind {
        case .symlink:
            try await copySymlink(from: src, to: dst)
        case .directory:
            try await copyDirectory(from: src, to: dst)
        case .file:
            try await copyRegularFile(from: src, to: dst)
        }
    }

    private func copyDirectory(from src: String, to dst: String) async throws {
        // Merge into an existing directory; otherwise create it.
        if let existing = FSLowLevel.kind(of: dst) {
            if existing != .directory {
                let decision = await resolveOverwrite(src: src, dst: dst)
                switch decision {
                case .skip: return
                case .abort: throw OperationError.aborted(dst)
                case .overwrite, .append: try removeItem(dst)   // append is meaningless for a dir target
                case .rename: break // renaming a dir merge target is unusual; fall through to create
                }
            }
        }
        if !FSLowLevel.exists(dst) {
            guard mkdirPath(dst, 0o755) == 0 else { throw OperationError.cannotCreateDirectory(dst) }
        }
        let children = (try? FileManager.default.contentsOfDirectory(atPath: src)) ?? []
        for child in children.sorted() {
            try await control.checkpoint()
            let cs = (src as NSString).appendingPathComponent(child)
            let cd = (dst as NSString).appendingPathComponent(child)
            try await copyNode(from: cs, to: cd)
        }
        if options.preserveMetadata { copyMetadata(from: src, to: dst) }
    }

    private func copySymlink(from src: String, to dst: String) async throws {
        if options.followSymlinks {
            // Resolve and copy the target instead.
            let resolved = (src as NSString).resolvingSymlinksInPath
            try await copyNode(from: resolved, to: dst)
            return
        }
        if FSLowLevel.exists(dst) {
            switch await resolveOverwrite(src: src, dst: dst) {
            case .skip: state.filesDone += 1; report(); return
            case .abort: throw OperationError.aborted(dst)
            case .overwrite, .rename, .append: try removeItem(dst)   // append n/a for a symlink target
            }
        }
        guard let target = FSLowLevel.readSymlink(src) else { throw OperationError.readFailed(src) }
        let rc = target.withCString { t in dst.withCString { d in symlink(t, d) } }
        guard rc == 0 else { throw OperationError.writeFailed(dst) }
        state.filesDone += 1
        report()
    }

    private func copyRegularFile(from src: String, to dst0: String) async throws {
        var dst = dst0
        var append = false
        let size = FSLowLevel.size(of: src)

        if FSLowLevel.exists(dst) {
            if options.onlyNewer, !isSourceNewer(src: src, dst: dst) {
                state.filesDone += 1; state.bytesDone += size; report(); return
            }
            switch await resolveOverwrite(src: src, dst: dst) {
            case .skip:
                state.filesDone += 1; state.bytesDone += size; report(); return
            case .abort:
                throw OperationError.aborted(dst)
            case .rename(let newLeaf):
                dst = ((dst as NSString).deletingLastPathComponent as NSString).appendingPathComponent(newLeaf)
            case .overwrite:
                try removeItem(dst)
            case .append:
                append = true   // F-086: keep the target, stream the source onto its end
            }
        }

        state.currentItem = (src as NSString).lastPathComponent
        try await copyFileData(from: src, to: dst, size: size, appendMode: append)
        // On append we keep the target's own metadata (merging content, not replacing).
        if options.preserveMetadata, !append { copyMetadata(from: src, to: dst) }
        state.filesDone += 1
        report()
    }

    /// Append the source file's bytes to an existing target (F-086), without
    /// prompting. Used by MoveEngine to fulfil an append decision on move.
    func appendRegularFile(from src: String, to dst: String) async throws {
        state.currentItem = (src as NSString).lastPathComponent
        try await copyFileData(from: src, to: dst, size: FSLowLevel.size(of: src), appendMode: true)
    }

    // MARK: - Data copy

    private func copyFileData(from src: String, to dst: String, size: Int64, appendMode: Bool = false) async throws {
        // Clone fast path (same volume, target must not exist). Never for append.
        if !appendMode, options.useCloneWhenPossible, !FSLowLevel.exists(dst) {
            let rc = src.withCString { s in dst.withCString { d in clonefile(s, d, 0) } }
            if rc == 0 {
                state.bytesDone += size
                report()
                return
            }
            // errno EXDEV / ENOTSUP / EEXIST → fall through to streaming.
        }

        let inFD = src.withCString { open($0, O_RDONLY) }
        guard inFD >= 0 else { throw OperationError.readFailed(src) }
        defer { close(inFD) }

        // Append opens the existing target for O_APPEND writes; a normal copy
        // truncates (or creates) the target.
        let outFlags = appendMode ? (O_WRONLY | O_APPEND | O_CREAT) : (O_WRONLY | O_CREAT | O_TRUNC)
        let outFD = dst.withCString { open($0, outFlags, 0o644) }
        guard outFD >= 0 else { throw OperationError.cannotCreateFile(dst) }

        let buf = UnsafeMutableRawPointer.allocate(byteCount: options.chunkSize, alignment: 16)
        defer { buf.deallocate() }

        do {
            while true {
                try await control.checkpoint()
                let n = read(inFD, buf, options.chunkSize)
                if n == 0 { break }
                if n < 0 { throw OperationError.readFailed(src) }
                var off = 0
                while off < n {
                    let w = write(outFD, buf + off, n - off)
                    if w <= 0 { throw OperationError.writeFailed(dst) }
                    off += w
                }
                state.bytesDone += Int64(n)
                report()
                await throttleIfNeeded()
            }
        } catch {
            close(outFD)
            // Clean up a partially written NEW target; never unlink an append target
            // (that would destroy the pre-existing data we appended to).
            if !appendMode { _ = dst.withCString { unlink($0) } }   // SPEC-004 §1
            throw error
        }
        close(outFD)
    }

    // MARK: - Metadata / helpers

    private func copyMetadata(from src: String, to dst: String) {
        _ = src.withCString { s in
            dst.withCString { d in
                copyfile(s, d, nil, copyfile_flags_t(COPYFILE_METADATA))
            }
        }
    }

    private func removeItem(_ path: String) throws {
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            throw OperationError.writeFailed(path)
        }
    }

    private func mkdirPath(_ path: String, _ mode: mode_t) -> Int32 {
        path.withCString { mkdir($0, mode) }
    }

    private func isSourceNewer(src: String, dst: String) -> Bool {
        let s = FSLowLevel.facts(of: src)?.modified ?? .distantPast
        let d = FSLowLevel.facts(of: dst)?.modified ?? .distantPast
        return s > d
    }

    private func resolveOverwrite(src: String, dst: String) async -> OverwriteDecision {
        let sf = FSLowLevel.facts(of: src) ?? FileFacts(path: src, name: (src as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        let df = FSLowLevel.facts(of: dst) ?? FileFacts(path: dst, name: (dst as NSString).lastPathComponent, size: 0, modified: nil, isDirectory: false)
        return await resolver.resolveOverwrite(source: sf, target: df)
    }

    private func throttleIfNeeded() async {
        guard options.maxBytesPerSecond > 0 else {
            state.bytesPerSecond = throughput()
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let expected = Double(state.bytesDone) / Double(options.maxBytesPerSecond)
        if expected > elapsed {
            let sleepNs = UInt64((expected - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNs)
        }
        state.bytesPerSecond = throughput()
    }

    private func throughput() -> Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return elapsed > 0 ? Double(state.bytesDone) / elapsed : 0
    }

    private func report() { progress(state) }
}
