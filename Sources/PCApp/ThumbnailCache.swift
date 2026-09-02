// SPDX-License-Identifier: Apache-2.0
// ThumbnailCache.swift - The cache performance.md has always described (F-479 follow-up).
//
// `docs/architecture/performance.md` lists "Thumbnail cache | path+mtime+size | 128 MB LRU" among
// the app's caches. It did not exist. `QLThumbnailGenerator` was called at exactly one place with
// nothing in front of it, so gallery view asked the system for every file in the directory again on
// every partial batch of a listing — and a large directory arrives in hundreds of batches.
//
// Locally that was churn nobody noticed, because QuickLook's own daemon caches behind our back. It
// stops being invisible the moment a thumbnail costs a *read*: on a share, and for an archive member
// that has to be unpacked first, there is no daemon to save us.
//
// Thin on purpose. The eviction lives in `PCFoundation.ByteBudgetCache`, where it can be tested —
// PCApp has no unit-test bundle. What is left here is the two things that need AppKit: asking an
// image what it decoded to, and the keys.

import AppKit
import PCFoundation

@MainActor
final class ThumbnailCache {

    /// Shared: a thumbnail is a fact about a file, not about a panel, and both panels show the same
    /// directories all day.
    static let shared = ThumbnailCache()

    /// From performance.md. Counted in decoded pixels, which is what the images actually cost —
    /// a 128×128 thumbnail at 2× is 256 KB, so this is a few hundred of them.
    private let store = ByteBudgetCache<NSImage>(maxBytes: 128 * 1024 * 1024)
    private var pressureSource: DispatchSourceMemoryPressure?

    init() {
        // Caches give way under pressure rather than compete with the app that filled them
        // (performance.md); `ArchiveDirectoryCache` and `MemberStage` hook the same source.
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.removeAll() }
        }
        source.resume()
        pressureSource = source
    }

    /// The key for a file on disk: identity, not merely location. A file replaced in place keeps its
    /// path, so a path-only key would hand back the previous file's picture for the rest of the
    /// session — which is the same reason `ArchiveDirectoryCache` keys on `FileStamp`.
    static func key(path: String, modified: Date, size: Int64) -> String {
        "\(path)|\(modified.timeIntervalSince1970)|\(size)"
    }

    /// The key for something inside a mount, where there is no local path to stamp. Unused today and
    /// the reason the key is a string at all: an archive member's thumbnail is the next thing to want
    /// one, and it must not need a second cache.
    static func key(mount: String, member: String, size: Int64) -> String {
        "\(mount)#\(member)|\(size)"
    }

    func image(for key: String) -> NSImage? { store.value(for: key) }

    func store(_ image: NSImage, for key: String) {
        store.store(image, bytes: Self.cost(of: image), for: key)
    }

    func removeAll() { store.removeAll() }

    /// What the cache holds, for the harness.
    var report: (count: Int, bytes: Int) { store.report }

    /// Decoded size in bytes, from the representation's *pixels* and not from `size`, which is in
    /// points — on a 2× display the two differ by a factor of four, and budgeting in points would
    /// hold four times what the number says.
    private static func cost(of image: NSImage) -> Int {
        let pixels = image.representations.reduce(0) { $0 + $1.pixelsWide * $1.pixelsHigh }
        if pixels > 0 { return pixels * 4 }
        return max(1, Int(image.size.width * image.size.height)) * 4
    }
}
