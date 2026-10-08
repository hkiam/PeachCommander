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
    /// Everything this run left behind, at any depth: a conflict answered "skip", a file the
    /// `onlyNewer` option held back, an error the resolver skipped.
    ///
    /// `processed` names the top-level items that finished, which is not the same question. A
    /// directory whose child was skipped still "finished" — and `MoveEngine` used to read that as
    /// permission to delete the source tree, child included. Anything that deletes a source after
    /// copying it has to be able to ask whether the copy is complete.
    public private(set) var skipped: [String] = []
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
        // Counted beside the copy rather than before it. Counting first meant a large tree on a slow
        // share sat at nothing for minutes before the first byte moved; the totals now arrive while
        // the bytes already do, and `report` folds in whatever has been counted so far.
        let tally = Tally()
        let follow = options.followSymlinks
        let counting = Task.detached(priority: .utility) { Self.countTotals(items, followSymlinks: follow, into: tally) }
        defer { counting.cancel() }
        self.tally = tally
        self.topItems = items
        report()

        for src in items {
            try await control.checkpoint()
            var leaf = (src as NSString).lastPathComponent
            if let mask = options.renameMask { leaf = CopyRenameMask.apply(mask, to: leaf) }   // F-080
            let dst = (dstDir as NSString).appendingPathComponent(leaf)
            // Per-item error resolution (F-089): retry / skip (continue) / abort.
            while true {
                do {
                    let landed = try await copyNode(from: src, to: dst)
                    processed.append(src)
                    // The copy gets the comment too, and the source keeps its own (F-372). A name
                    // collision may have renamed the target, so the comment goes where the file actually
                    // landed — not to the name that was asked for.
                    if let landed {
                        await CommentStore.carryLocal(from: src, to: landed, keepSource: true)
                    }
                    break
                } catch let error as OperationError {
                    if error == .cancelled { throw error }
                    switch await resolver.resolveError(error, path: src) {
                    case .retry: continue
                    case .skip: skipped.append(src)
                    case .abort: throw error
                    }
                    break
                }
            }
        }
        // The last report carries the finished totals, not whatever the count had reached when the
        // final byte went out — a small tree can be copied before its count returns.
        await counting.value
        // Everything that was copied had arrived; a delivery too quick to be measured counts too.
        state.bytesReceived = state.bytesToReceive
        report()
        return processed
    }

    // MARK: - Planning

    /// Totals counted so far, written by the counting task and read by `report`.
    final class Tally: @unchecked Sendable {
        private let lock = NSLock()
        private var files = 0
        private var bytes: Int64 = 0
        private var unreceived: Int64 = 0
        private var finished = false

        /// `unreceived` is what the files lack on disk — size beyond the allocated bytes. Only a
        /// coordinated copy uses it: it is what another app still has to deliver.
        func add(files: Int, bytes: Int64, unreceived: Int64 = 0) {
            lock.lock(); self.files += files; self.bytes += bytes; self.unreceived += unreceived; lock.unlock()
        }
        func finish() { lock.lock(); finished = true; lock.unlock() }
        var snapshot: (files: Int, bytes: Int64, unreceived: Int64, finished: Bool) {
            lock.lock(); defer { lock.unlock() }
            return (files, bytes, unreceived, finished)
        }
    }

    private var tally: Tally?
    /// The items `run` was given — what a wait for a source measures the delivery across.
    private var topItems: [String] = []

    /// Count what `items` will copy. Directory by directory through `getattrlistbulk`, so the cost on
    /// a network volume is a round trip per directory rather than two per file; per file only where
    /// the volume cannot answer that way. Stops early when the copy it runs beside is over.
    static func countTotals(_ items: [String], followSymlinks: Bool, into tally: Tally) {
        var stack: [String] = []
        // Only needed for the followed-symlink walk below, where a link can point back at a folder
        // already on the stack. A plain tree walk cannot revisit a path.
        var seen = Set<String>()
        func countOne(_ path: String, kind: FSKind,
                      size: @autoclosure () -> (size: Int64, allocated: Int64)) {
            switch kind {
            case .file:
                let s = size()
                tally.add(files: 1, bytes: s.size, unreceived: max(0, s.size - s.allocated))
            case .symlink:
                // With `followSymlinks` the copy takes what the link points at, which may be a whole
                // directory — counted as one file here, the total was short by everything inside it
                // and the progress bar filled past its own end.
                guard followSymlinks else { tally.add(files: 1, bytes: size().size); return }
                let resolved = (path as NSString).resolvingSymlinksInPath
                guard resolved != path, seen.insert(resolved).inserted,
                      let target = FSLowLevel.kind(of: resolved) else { return }
                countOne(resolved, kind: target, size: FSLowLevel.sizeAndAllocated(of: resolved))
            case .directory:
                stack.append(path)
            }
        }
        // The top-level items are named by the caller, so their kinds have to be asked for.
        for path in items {
            guard let kind = FSLowLevel.kind(of: path) else { continue }
            countOne(path, kind: kind, size: FSLowLevel.sizeAndAllocated(of: path))
        }
        while let dir = stack.popLast() {
            if Task.isCancelled { return }
            if let entries = FSLowLevel.bulkEntries(of: dir) {
                for entry in entries {
                    let path = (dir as NSString).appendingPathComponent(entry.name)
                    if let kind = entry.kind {
                        countOne(path, kind: kind, size: (entry.size, entry.allocated))
                    } else if let kind = FSLowLevel.kind(of: path) {
                        countOne(path, kind: kind, size: FSLowLevel.sizeAndAllocated(of: path))
                    }
                }
            } else if let children = DeepPath.contentsOfDirectory(dir) {
                for child in children {
                    let path = (dir as NSString).appendingPathComponent(child)
                    if let kind = FSLowLevel.kind(of: path) {
                        countOne(path, kind: kind, size: FSLowLevel.sizeAndAllocated(of: path))
                    }
                }
            }
        }
        tally.finish()
    }

    // MARK: - Recursion

    /// The path the copy ended up at, or nil if it was skipped.
    ///
    /// The path rather than nothing: a name collision may have renamed the target, and the caller has to
    /// know the name the copy actually has to carry the file's comment to it (F-372).
    @discardableResult
    private func copyNode(from src: String, to dst: String) async throws -> String? {
        try await control.checkpoint()
        guard let kind = FSLowLevel.kind(of: src) else { throw OperationError.sourceNotFound(src) }
        // A directory cannot be merged into itself: it would walk its own children and copy each one
        // onto itself, destroying every file inside. Nor into something below itself, which recurses
        // into what it is creating. Both are refused here because no later decision can rescue them.
        //
        // A *file* is checked further down instead, after the overwrite conflict has been resolved —
        // the resolver may answer "rename", and a copy into the source's own directory under a new
        // name is exactly what Shift+F5 does. Checking it here refused that too, which the comment
        // tests caught.
        if kind == .directory, FSLowLevel.isSameFile(src, dst) || Self.isInside(dst, src) {
            throw OperationError.sameFile(src)
        }
        switch kind {
        case .symlink:
            return try await copySymlink(from: src, to: dst)
        case .directory:
            return try await copyDirectory(from: src, to: dst)
        case .file:
            return try await copyRegularFile(from: src, to: dst)
        }
    }

    @discardableResult
    private func copyDirectory(from src: String, to dst0: String) async throws -> String? {
        var dst = dst0
        // Merge into an existing directory; otherwise create it.
        // A loop, not one question: a `.rename` may land on a name that is taken too, and
        // `OverwriteRules.autoRenameName` documents that case as "a further conflict simply
        // re-prompts" — which nothing did.
        var rounds = 0
        while let existing = FSLowLevel.kind(of: dst), existing != .directory {
            rounds += 1
            guard rounds <= Self.maximumConflictRounds else { throw OperationError.aborted(dst) }
            switch await resolveOverwrite(src: src, dst: dst) {
            case .skip: skipped.append(src); return nil
            case .abort: throw OperationError.aborted(dst)
            case .overwrite, .append: try removeItem(dst)   // append is meaningless for a dir target
            case .rename(let newLeaf):
                // Used to be `break` with a comment saying it fell through to create — it did not:
                // the file stayed, `exists(dst)` was true so no directory was made, and the children
                // were then copied into paths underneath a regular file.
                let next = ((dst as NSString).deletingLastPathComponent as NSString)
                    .appendingPathComponent(newLeaf)
                guard next != dst else { throw OperationError.aborted(dst) }
                dst = next
            }
        }
        if !FSLowLevel.exists(dst) {
            guard mkdirPath(dst, 0o755) == 0 else { throw OperationError.cannotCreateDirectory(dst) }
        }
        // Before listing: a presenter of the folder may still be creating what is inside it.
        try await coordinateRead(src)
        let children = DeepPath.contentsOfDirectory(src) ?? []
        for child in children.sorted() {
            try await control.checkpoint()
            let cs = (src as NSString).appendingPathComponent(child)
            let cd = (dst as NSString).appendingPathComponent(child)
            try await copyNode(from: cs, to: cd)
        }
        if options.preserveMetadata { copyMetadata(from: src, to: dst) }
        return dst
    }

    @discardableResult
    private func copySymlink(from src: String, to dst0: String) async throws -> String? {
        if options.followSymlinks {
            // Resolve and copy the target instead.
            let resolved = (src as NSString).resolvingSymlinksInPath
            // A link that resolves to itself would recurse until the stack ran out.
            guard resolved != src else { throw OperationError.readFailed(src) }
            return try await copyNode(from: resolved, to: dst0)
        }
        var dst = dst0
        var rounds = 0
        while FSLowLevel.exists(dst) {
            rounds += 1
            guard rounds <= Self.maximumConflictRounds else { throw OperationError.aborted(dst) }
            switch await resolveOverwrite(src: src, dst: dst) {
            case .skip: skipped.append(src); state.filesDone += 1; report(); return nil
            case .abort: throw OperationError.aborted(dst)
            case .rename(let newLeaf):
                let next = ((dst as NSString).deletingLastPathComponent as NSString)
                    .appendingPathComponent(newLeaf)
                guard next != dst else { throw OperationError.aborted(dst) }
                dst = next
            case .overwrite, .append:                       // append n/a for a symlink target
                // Not removed here: the new link is made under a temporary name and renamed over the
                // old one, so a failure in between leaves the old link rather than nothing.
                break
            }
            break
        }
        guard let target = FSLowLevel.readSymlink(src) else { throw OperationError.readFailed(src) }
        if FSLowLevel.exists(dst) {
            let temp = Self.temporaryName(for: dst)
            guard DeepPath.symlink(target, at: temp) == 0 else { throw OperationError.writeFailed(dst) }
            guard DeepPath.rename(temp, to: dst) == 0 else {
                _ = DeepPath.unlink(temp)
                throw OperationError.writeFailed(dst)
            }
        } else {
            guard DeepPath.symlink(target, at: dst) == 0 else { throw OperationError.writeFailed(dst) }
        }
        state.filesDone += 1
        report()
        return dst
    }

    /// How many times a conflict may be re-resolved before the run gives up.
    ///
    /// A resolver that answers `.rename` with a name that is always taken would otherwise ask for
    /// ever. Sixty-four is far past anything a person would click through and far short of a hang.
    private static let maximumConflictRounds = 64

    /// A sibling name to write to before taking the target's place.
    ///
    /// A sibling rather than a temporary directory, because `rename(2)` is only atomic within one
    /// filesystem and the point of the whole exercise is that the replacement cannot half-happen.
    private static func temporaryName(for dst: String) -> String {
        let dir = (dst as NSString).deletingLastPathComponent
        let leaf = (dst as NSString).lastPathComponent
        return (dir as NSString).appendingPathComponent(".\(leaf).pc-part-\(UUID().uuidString.prefix(8))")
    }

    @discardableResult
    private func copyRegularFile(from src: String, to dst0: String) async throws -> String? {
        var dst = dst0
        var append = false
        let size = FSLowLevel.size(of: src)

        if FSLowLevel.exists(dst), options.onlyNewer, !isSourceNewer(src: src, dst: dst) {
            skipped.append(src)
            state.filesDone += 1; state.bytesDone += size; report(); return nil
        }
        // A loop: a `.rename` can land on a name that is taken too, and the answer to that is to ask
        // again — which is what `OverwriteRules.autoRenameName` has documented all along ("a further
        // conflict simply re-prompts") and what nothing did. Silently, the second name was written
        // over whatever had it.
        var rounds = 0
        while FSLowLevel.exists(dst) {
            rounds += 1
            guard rounds <= Self.maximumConflictRounds else { throw OperationError.aborted(dst) }
            switch await resolveOverwrite(src: src, dst: dst) {
            case .skip:
                skipped.append(src)
                state.filesDone += 1; state.bytesDone += size; report(); return nil
            case .abort:
                throw OperationError.aborted(dst)
            case .rename(let newLeaf):
                let next = ((dst as NSString).deletingLastPathComponent as NSString)
                    .appendingPathComponent(newLeaf)
                // The new name can be the one the source already has — a rename into the source's
                // own directory that keeps the name. That used to fall straight through to the write
                // and truncate the source to nothing: the `.overwrite` and `.append` cases below both
                // guarded against arriving at the same file, and this one did not.
                if FSLowLevel.isSameFile(src, next) { throw OperationError.sameFile(src) }
                guard next != dst else { throw OperationError.aborted(dst) }
                dst = next
                continue
            case .overwrite:
                // Here, and not earlier: `.rename` above may just have moved the target somewhere
                // else, and copying into the source's own directory under a new name is legitimate —
                // it is what Shift+F5 does. What is never legitimate is arriving at the *same file*
                // and then removing it, which deletes the only copy and leaves the read with nothing.
                if FSLowLevel.isSameFile(src, dst) { throw OperationError.sameFile(src) }
                // The target is *not* removed here any more. It is replaced at the end of the write,
                // by renaming the finished copy over it — see `copyFileData`.
            case .append:
                // Appending a file to itself reads what it is writing: it does not converge.
                if FSLowLevel.isSameFile(src, dst) { throw OperationError.sameFile(src) }
                append = true   // F-086: keep the target, stream the source onto its end
            }
            break
        }

        state.currentItem = (src as NSString).lastPathComponent
        // Until the presenter has answered, the bytes on disk may be a placeholder — see
        // `CopyOptions.coordinateSourceReads`. The size is read again for the same reason.
        let readSize = try await coordinateRead(src) ? FSLowLevel.size(of: src) : size
        try await copyFileData(from: src, to: dst, size: readSize, appendMode: append)
        // On append we keep the target's own metadata (merging content, not replacing).
        if options.preserveMetadata, !append { copyMetadata(from: src, to: dst) }
        state.filesDone += 1
        report()
        // An append merges content into a file that keeps its identity, so it keeps its own comment; the
        // source's comment must not overwrite it (F-372).
        return append ? nil : dst
    }

    /// Append the source file's bytes to an existing target (F-086), without
    /// prompting. Used by MoveEngine to fulfil an append decision on move.
    func appendRegularFile(from src: String, to dst: String) async throws {
        // The same refusal `copyRegularFile` makes, and the reason it has to be repeated here: this
        // is the entry `MoveEngine` uses for an append, so the guard one function away never ran for
        // it. Appending a file onto itself reads what it is writing — it does not converge, it fills
        // the volume.
        if FSLowLevel.isSameFile(src, dst) { throw OperationError.sameFile(src) }
        state.currentItem = (src as NSString).lastPathComponent
        try await copyFileData(from: src, to: dst, size: FSLowLevel.size(of: src), appendMode: true)
    }

    // MARK: - Data copy

    private func copyFileData(from src: String, to dst: String, size: Int64, appendMode: Bool = false) async throws {
        // Replacing something? Then write beside it and take its place at the end.
        //
        // The old order was: remove the target, then write in its place. A cancel or an error in
        // between left neither the old file nor a whole new one — measured with a throttled copy and
        // a Stop after 400 ms, the target was simply gone. The user had pressed Stop on a copy and
        // lost the file that was already there. Writing to a sibling and renaming makes the swap the
        // last, indivisible step: `rename(2)` either replaces the target or does nothing.
        //
        // Append is exempt: it adds to a file that keeps its identity, so there is nothing to swap.
        let replacing = !appendMode && FSLowLevel.exists(dst)
        let writeTo = replacing ? Self.temporaryName(for: dst) : dst
        state.currentFileBytesTotal = size
        state.currentFileBytesDone = 0

        func finish() throws {
            guard replacing else { return }
            guard DeepPath.rename(writeTo, to: dst) == 0 else {
                _ = DeepPath.unlink(writeTo)
                throw OperationError.writeFailed(dst)
            }
        }

        // Clone fast path (same volume, target must not exist). Never for append. The temporary name
        // is free by construction, so a replacement can use it too.
        if !appendMode, options.useCloneWhenPossible, !FSLowLevel.exists(writeTo) {
            let rc = DeepPath.clone(src, to: writeTo)
            if rc == 0 {
                try finish()
                state.bytesDone += size
                state.currentFileBytesDone = size
                report()
                return
            }
            if replacing { _ = DeepPath.unlink(writeTo) }   // a half-made clone is not a copy
            // errno EXDEV / ENOTSUP / EEXIST → fall through to streaming.
        }

        let inFD = DeepPath.open(src, O_RDONLY)
        guard inFD >= 0 else { throw OperationError.readFailed(src) }
        defer { close(inFD) }

        // Append opens the existing target for O_APPEND writes; a normal copy
        // truncates (or creates) the target.
        let outFlags = appendMode ? (O_WRONLY | O_APPEND | O_CREAT) : (O_WRONLY | O_CREAT | O_TRUNC)
        let outFD = DeepPath.open(writeTo, outFlags, 0o644)
        guard outFD >= 0 else { throw OperationError.cannotCreateFile(dst) }

        let buf = UnsafeMutableRawPointer.allocate(byteCount: options.chunkSize, alignment: 16)
        defer { buf.deallocate() }

        // Only when somebody asked, and only here: the clone path above never reads the bytes, so
        // there is nothing to hash there and forcing a read would make the copy slower than not
        // hashing at all. See `CopyOptions.digestSink`.
        let hasher = options.digestSink != nil ? ChecksumHasher(.crc32) : nil
        do {
            while true {
                try await control.checkpoint()
                let n = read(inFD, buf, options.chunkSize)
                if n == 0 { break }
                if n < 0 { throw OperationError.readFailed(src) }
                // Hashed from the same buffer the write goes out of, so the bytes are read once.
                hasher?.update(Data(bytes: buf, count: n))
                var off = 0
                while off < n {
                    let w = write(outFD, buf + off, n - off)
                    if w <= 0 { throw OperationError.writeFailed(writeTo) }
                    off += w
                }
                state.bytesDone += Int64(n)
                state.currentFileBytesDone += Int64(n)
                report()
                await throttleIfNeeded()
            }
        } catch {
            close(outFD)
            // Clean up the partial write; never unlink an append target (that would destroy the
            // pre-existing data we appended to). When replacing, the partial has the temporary name,
            // so removing it leaves the original exactly as it was.
            if !appendMode { _ = DeepPath.unlink(writeTo) }   // SPEC-004 §1
            throw error
        }
        close(outFD)
        try finish()
        // After `finish`, so a copy that could not be completed reports no digest: a digest for a
        // file that did not land is worse than none, because the verifier would compare the
        // destination against it and call the mismatch a corruption.
        if let hasher, let sink = options.digestSink { sink(src, hasher.finalizeHex()) }
    }

    // MARK: - Metadata / helpers

    /// A coordinated read of `src` with an empty accessor, when the options ask for one: by the time it
    /// returns, the presenter of `src` has delivered. True when that happened, false when nothing was
    /// coordinated or the coordination failed.
    ///
    /// Per folder and per file, because a coordinated read asks the presenter of exactly that item —
    /// not the presenters of what a folder contains, nor of the folders above a file. Measured: a read
    /// of a folder left every file presenter inside unasked, and reads of the files left the folder's
    /// presenter unasked. So each presenter is asked once, by the read of its own item.
    ///
    /// Asynchronous and on its own queue because the wait is a download over RDP: blocking a thread
    /// of the cooperative pool for that long starves every other task. Stop cancels the coordination
    /// — a presenter whose session has gone away never answers, and the copy must not wait for it.
    /// A coordination that fails otherwise is logged and the copy goes on: without a presenter it
    /// reads what is there, as it always did.
    @discardableResult
    private func coordinateRead(_ src: String) async throws -> Bool {
        guard options.coordinateSourceReads else { return false }
        // What the sources lack has to be counted before any of it is asked for: counted while it
        // arrives, the figure would come out short and the bar would overrun it.
        while let tally, !tally.snapshot.finished {
            try await control.checkpoint()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        let control = self.control
        let watcher = Task {
            while !Task.isCancelled {
                if await control.isCancelled { coordinator.cancel(); return }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { watcher.cancel() }
        let intent = NSFileAccessIntent.readingIntent(with: URL(fileURLWithPath: src))
        // The wait is where the time goes — the copy after it is a clone — so it is shown as a wait on
        // this item rather than as a bar standing at the last figure.
        state.currentItem = (src as NSString).lastPathComponent
        state.isWaitingForSource = true
        report()
        let delivery = DeliveryMeter(items: topItems, followSymlinks: options.followSymlinks,
                                     toReceive: state.bytesToReceive, received: state.bytesReceived)
        let metering = state.bytesToReceive > state.bytesReceived
            ? Task.detached(priority: .utility) { [state, progress] in
                await delivery.watch(from: state, report: progress)
            }
            : nil
        let error: Error? = await withCheckedContinuation { done in
            coordinator.coordinate(with: [intent], queue: Self.coordinationQueue) { done.resume(returning: $0) }
        }
        // Awaited, not just cancelled: a report it sends after this one would put the wait back up.
        metering?.cancel()
        await metering?.value
        if delivery.hasMeasured { delivery.measure() }   // a long wait: take what it ended with
        state.bytesReceived = delivery.received
        state.isWaitingForSource = false
        report()
        try await control.checkpoint()
        guard let error else { return true }
        logger.warning("Coordinated read of \(src) failed: \(error.localizedDescription)")
        return false
    }

    /// How much of what the sources lacked has arrived, measured while a coordinated read waits.
    ///
    /// The Windows App writes the content into its placeholders in place — measured: the allocated
    /// bytes grew from nothing to the full size over the download, the inode stayed the same — so
    /// what the sources still lack, size beyond allocated, falls as the content arrives. It is the
    /// same walk the totals were counted with, so the two figures agree. A writer that `fsync`s its
    /// placeholder makes APFS allocate all of it at once; the bar then fills early, never backwards.
    ///
    /// Only after the wait has lasted a moment: a presenter that answers at once — any local source —
    /// costs nothing but the wait. The reports go out from here with the state the wait began with,
    /// so the engine's own state is touched only by the engine.
    final class DeliveryMeter: @unchecked Sendable {
        private let items: [String], followSymlinks: Bool, toReceive: Int64
        private let lock = NSLock()
        private var best: Int64
        private var measured = false

        init(items: [String], followSymlinks: Bool, toReceive: Int64, received: Int64) {
            self.items = items; self.followSymlinks = followSymlinks
            self.toReceive = toReceive; self.best = received
        }

        var received: Int64 { lock.lock(); defer { lock.unlock() }; return best }
        var hasMeasured: Bool { lock.lock(); defer { lock.unlock() }; return measured }

        /// One walk. Never lower than before — a figure that fell back would move the bar backwards —
        /// and an unfinished walk counts for nothing, because it would read as everything delivered.
        func measure() {
            let now = Tally()
            CopyEngine.countTotals(items, followSymlinks: followSymlinks, into: now)
            let snapshot = now.snapshot
            guard snapshot.finished else { return }
            let arrived = min(toReceive, max(0, toReceive - snapshot.unreceived))
            lock.lock(); best = max(best, arrived); measured = true; lock.unlock()
        }

        func watch(from state: OpProgress, report: @Sendable (OpProgress) -> Void) async {
            var state = state
            while true {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                measure()
                if Task.isCancelled { return }
                state.bytesReceived = received
                report(state)
            }
        }
    }

    private static let coordinationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "CopyEngine.coordinatedRead"
        return q
    }()

    private func copyMetadata(from src: String, to dst: String) {
        DeepPath.copyMetadata(from: src, to: dst)
    }

    private func removeItem(_ path: String) throws {
        guard DeepPath.removeItem(path) else { throw OperationError.writeFailed(path) }
    }

    private func mkdirPath(_ path: String, _ mode: mode_t) -> Int32 {
        DeepPath.mkdir(path, mode)
    }

    /// Whether `path` lies inside `directory` — the recursion check for copying a folder into itself.
    ///
    /// Compared on standardised paths with a trailing separator, so `/a/bc` is not read as being
    /// inside `/a/b`. Case-insensitively, because that is how the volume this runs on normally
    /// behaves; being too eager here refuses a copy, being too lax destroys the folder.
    static func isInside(_ path: String, _ directory: String) -> Bool {
        let p = (path as NSString).standardizingPath
        var d = (directory as NSString).standardizingPath
        if !d.hasSuffix("/") { d += "/" }
        return p.lowercased().hasPrefix(d.lowercased())
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
        // The control's limit wins when one is set: it can be changed while this transfer runs,
        // which is what "slow this one down" means. Without one, the operation's own option stands.
        let limit = await control.speedLimit ?? options.maxBytesPerSecond
        guard limit > 0 else {
            state.bytesPerSecond = throughput()
            return
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let expected = Double(state.bytesDone) / Double(limit)
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

    private func report() {
        if let counted = tally?.snapshot {
            // Never below what is already done: the copy can run ahead of the count.
            state.filesTotal = max(counted.files, state.filesDone)
            state.bytesTotal = max(counted.bytes, state.bytesDone)
            state.isCounting = !counted.finished
            if options.coordinateSourceReads { state.bytesToReceive = counted.unreceived }
        }
        progress(state)
    }
}
