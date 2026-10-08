// SPDX-License-Identifier: Apache-2.0
// FileDragPasteboard.swift - Reading file paths out of a drag, in one place.
//
// The same four lines had been written three times — on the button bar, on its droppable buttons and
// on the panel list — and the workspace chip strip would have been the fourth (F-499). None of the
// copies was wrong, which is exactly why they were worth collecting: a drag-and-drop reader that is
// right in three places and subtly different in the fourth is a defect nobody goes looking for.
//
// A drag does not always carry files. A mail dragged out of Outlook or Mail, a picture out of Photos:
// those apps put a *file promise* on the pasteboard — the file is written only once the drop target
// names a folder for it. The Finder fulfils those and gets an .eml; a panel that read only file URLs
// refused the drop outright. `filePromises` and `receive` are that second way in.

import AppKit

enum FileDragPasteboard {

    /// Everything a file drop target registers for: plain file URLs plus every file-promise flavour,
    /// the legacy `NSFilesPromisePboardType` included, which is the one Outlook writes.
    static let draggedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    /// The file paths a drag is carrying, or an empty array when it carries something else.
    ///
    /// `urlReadingFileURLsOnly` is what keeps a dragged web link out: without it a URL from a browser
    /// arrives as a perfectly good `NSURL` and every drop target here would try to treat it as a file.
    static func paths(from sender: NSDraggingInfo) -> [String] {
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return [] }
        return urls.map(\.path)
    }

    /// The file promises a drag is carrying — asked only when it carries no file URLs, since an app
    /// that offers both (Photos does) is better taken at the file it already has.
    static func filePromises(from sender: NSDraggingInfo) -> [NSFilePromiseReceiver] {
        sender.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self])
            as? [NSFilePromiseReceiver] ?? []
    }

    /// True when a drop of this drag would bring files: real ones, or promised ones.
    static func carriesFiles(_ sender: NSDraggingInfo) -> Bool {
        !paths(from: sender).isEmpty || !filePromises(from: sender).isEmpty
    }

    /// Have the source app write its promised files into a fresh staging folder, then hand their paths
    /// to `completion` on the main thread — empty when nothing arrived.
    ///
    /// Staged rather than written straight into the panel's folder: the panel may be an SFTP share or a
    /// folder row the drop landed on, and the existing drop path (`performDrop`) already knows every one
    /// of those, with its conflict dialog and its progress. The caller moves the files on from here.
    ///
    /// The writing happens on a queue of our own. On the main queue a source that writes synchronously
    /// in its delegate would be waiting for a thread that is waiting for it.
    ///
    /// Only from inside a drop that is being performed. A receiver read from any other pasteboard — the
    /// drag pasteboard included, outside a drag session — trips an assertion in AppKit
    /// (NSFilePromiseReceiver.m) when asked to receive. That is also why no automation verb covers this:
    /// a scripted promise fails there, which was measured, not assumed.
    static func receive(_ promises: [NSFilePromiseReceiver],
                        completion: @escaping @MainActor ([String]) -> Void) {
        let staging: URL
        do {
            staging = try makeStagingFolder()
        } catch {
            NSLog("FileDragPasteboard: no staging folder for a promised drop: \(error)")
            Task { @MainActor in completion([]) }
            return
        }
        let received = ReceivedFiles()
        let group = DispatchGroup()
        for promise in promises {
            // One reader call per promised file, and a receiver may promise several. A legacy promise
            // can name none until it is fulfilled, so the count is a floor of one and the extra calls
            // are not allowed to leave the group a second time — that would trap.
            let expected = max(1, promise.fileNames.count)
            for _ in 0..<expected { group.enter() }
            let pending = received.expect(expected)
            promise.receivePromisedFiles(atDestination: staging, options: [:],
                                         operationQueue: promiseQueue) { url, error in
                if let error {
                    NSLog("FileDragPasteboard: a promised file did not arrive: \(error)")
                } else {
                    received.add(url.path)
                }
                if received.consume(pending) { group.leave() }
            }
        }
        group.notify(queue: .main) {
            let paths = received.paths
            MainActor.assumeIsolated { completion(paths) }
        }
    }

    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "PeachCommander.FilePromises"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// `…/tmp/PeachCommander-Drops/<uuid>`. Folders an earlier drop emptied by moving its files on are
    /// swept here, not after the move: the move runs in the background queue and may still be going.
    private static func makeStagingFolder() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("PeachCommander-Drops", isDirectory: true)
        if let old = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for dir in old where (try? fm.contentsOfDirectory(atPath: dir.path))?.isEmpty == true {
                try? fm.removeItem(at: dir)
            }
        }
        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The reader is called on `promiseQueue`, one file at a time or not — collected under a lock.
    /// It also keeps, per promise, how many reader calls may still leave the dispatch group.
    private final class ReceivedFiles: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [String] = []
        private var remaining: [Int] = []
        func add(_ path: String) { lock.lock(); list.append(path); lock.unlock() }
        var paths: [String] { lock.lock(); defer { lock.unlock() }; return list }
        /// Registers a promise expecting `count` reader calls; returns its slot.
        func expect(_ count: Int) -> Int {
            lock.lock(); defer { lock.unlock() }
            remaining.append(count)
            return remaining.count - 1
        }
        /// True while the promise in `slot` still has a group entry to give back.
        func consume(_ slot: Int) -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard remaining[slot] > 0 else { return false }
            remaining[slot] -= 1
            return true
        }
    }
}
