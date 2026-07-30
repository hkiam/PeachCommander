// IconLoader.swift - Asynchronous file-icon pipeline for panel lists
//
// SPEC-002 §7: icon modes none/standard/all; by-type icons cached by UTType;
// .app icons cached by path (small LRU); load async on first display; generic
// placeholder until resolved; NO I/O in draw.
//
// The loader never blocks the main thread on disk I/O. Cells ask for an icon
// synchronously (getting a cached icon or a placeholder) and register a
// completion that fires on the main actor when the real icon resolves. Cells
// pass a monotonically increasing generation token so a recycled cell can
// ignore a stale resolution (cancel-on-scroll semantics).

import AppKit
import UniformTypeIdentifiers
import PCVFS
import PCFoundation

/// Icon display mode (SPEC-002 §7).
enum IconMode {
    case none       // no icons
    case standard   // per-UTType icons only (fast, fully cached)
    case all        // per-file icons incl. app-specific / custom icons (default)
}

/// Describes what icon a row needs, independent of any view.
struct IconRequest {
    let fullPath: String
    let ext: String
    let isDirectory: Bool
    let isApplication: Bool
    let isSymlink: Bool
}

/// Resolves file icons off the main thread with layered caches.
@MainActor
final class IconLoader {
    static let shared = IconLoader()

    var mode: IconMode = .all

    /// Generic placeholders resolved once.
    let genericFile: NSImage
    let genericFolder: NSImage

    /// Per-UTType (or synthetic key) cache — icons that depend only on type.
    private var typeCache: [String: NSImage] = [:]

    /// Path-keyed LRU for per-file icons (app bundles, custom icons).
    private var pathCache = LRUCache<String, NSImage>(capacity: 512)

    /// Background queue for NSWorkspace lookups (they touch disk / LaunchServices).
    private let queue = DispatchQueue(label: "com.peachcommander.iconloader", qos: .userInitiated, attributes: .concurrent)

    private let logger = PCFoundationLogger.logger

    private init() {
        let ws = NSWorkspace.shared
        genericFolder = ws.icon(for: .folder)
        genericFile = ws.icon(for: .data)
        genericFolder.size = NSSize(width: 16, height: 16)
        genericFile.size = NSSize(width: 16, height: 16)
    }

    /// A synchronous best-effort icon: a cached real icon when available,
    /// otherwise a generic placeholder. Never touches disk.
    func cachedOrPlaceholder(for req: IconRequest) -> NSImage {
        if mode == .none {
            return NSImage(size: NSSize(width: 16, height: 16))
        }
        if let cached = lookupCache(for: req) {
            return cached
        }
        return req.isDirectory ? genericFolder : genericFile
    }

    /// Returns true when a real (non-placeholder) icon is already cached, so the
    /// caller can skip scheduling async work entirely.
    func hasCachedIcon(for req: IconRequest) -> Bool {
        mode == .none || lookupCache(for: req) != nil
    }

    /// Resolve the real icon asynchronously. `completion` runs on the main actor
    /// only if the resolution is still relevant (the loader does not itself track
    /// staleness — the caller compares its generation token before applying).
    func resolve(_ req: IconRequest, completion: @escaping (NSImage) -> Void) {
        if mode == .none { return }
        if let cached = lookupCache(for: req) {
            completion(cached)
            return
        }
        let mode = self.mode
        queue.async { [weak self] in
            let image = IconLoader.resolveOffMain(req, mode: mode)
            image.size = NSSize(width: 16, height: 16)
            DispatchQueue.main.async {
                guard let self else { return }
                self.store(image, for: req)
                completion(image)
            }
        }
    }

    // MARK: - Cache

    private func cacheKey(for req: IconRequest) -> String {
        // In `all` mode, app bundles and items with custom icons vary by path.
        if mode == .all && (req.isApplication || req.ext.lowercased() == "app") {
            return "path:\(req.fullPath)"
        }
        if req.isDirectory {
            return "type:folder"
        }
        if req.ext.isEmpty {
            return "type:public.data"
        }
        return "type:.\(req.ext.lowercased())"
    }

    private func lookupCache(for req: IconRequest) -> NSImage? {
        let key = cacheKey(for: req)
        if key.hasPrefix("path:") {
            return pathCache.value(forKey: key)
        }
        return typeCache[key]
    }

    private func store(_ image: NSImage, for req: IconRequest) {
        let key = cacheKey(for: req)
        if key.hasPrefix("path:") {
            pathCache.set(image, forKey: key)
        } else {
            typeCache[key] = image
        }
    }

    /// Number of cached type + path icons (for diagnostics / tests).
    var cacheCount: Int { typeCache.count + pathCache.count }

    // MARK: - Off-main resolution

    private nonisolated static func resolveOffMain(_ req: IconRequest, mode: IconMode) -> NSImage {
        let ws = NSWorkspace.shared
        if req.isDirectory {
            return ws.icon(for: .folder)
        }
        switch mode {
        case .none:
            return NSImage(size: NSSize(width: 16, height: 16))
        case .standard:
            // Type-only icon: derive UTType from extension, avoid per-path disk hit.
            if !req.ext.isEmpty, let type = UTType(filenameExtension: req.ext) {
                return ws.icon(for: type)
            }
            return ws.icon(for: .data)
        case .all:
            // Per-file icon (honors app bundles and custom Finder icons).
            return ws.icon(forFile: req.fullPath)
        }
    }
}

/// Minimal LRU cache (insertion/access-ordered) for value types / class refs.
final class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var store: [Key: Value] = [:]
    private var order: [Key] = []

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var count: Int { store.count }

    func value(forKey key: Key) -> Value? {
        guard let value = store[key] else { return nil }
        touch(key)
        return value
    }

    func set(_ value: Value, forKey key: Key) {
        store[key] = value
        touch(key)
        evictIfNeeded()
    }

    private func touch(_ key: Key) {
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
        order.append(key)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let oldest = order.removeFirst()
            store.removeValue(forKey: oldest)
        }
    }
}
